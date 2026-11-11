import { View, div, svg } from "gpui-kit";
import { h_flex, v_flex } from "gpui-base";
import { spaces, panes, exec, run, theme, window, layout } from "herdr";

// Azure DevOps' resource id, for asking az for a token
const ADO = "499b84ac-1321-427f-aa17-267ca6975798";
const REFRESH_MS = 3 * 60 * 1000;
// How soon to try again when nothing was found or something failed
const RETRY_MS = 20 * 1000;
const FILTERS = [["all", "All"], ["mine", "Mine"], ["review", "Review"]];

function find(node, id) {
  if (node?.id === id) return node;
  for (const child of node?.children ?? []) {
    const found = find(child, id);
    if (found) return found;
  }
  return null;
}

// The sidebar is a rail when it's narrow, same test as the agents list
const narrow = () => (find(layout(), "sidebar")?.size?.px ?? Infinity) < 160;

// dev.azure.com/{org}/{project}/_git/{repo}, {org}.visualstudio.com/{project}/_git/{repo},
// or ssh.dev.azure.com:v3/{org}/{project}/{repo}
function parseRemote(url) {
  const m = /dev\.azure\.com\/([^/]+)\/([^/]+)\/_git\/([^/?#]+)/.exec(url)
    ?? /\/\/(?:[^@/]+@)?([^./]+)\.visualstudio\.com\/(?:DefaultCollection\/)?([^/]+)\/_git\/([^/?#]+)/.exec(url)
    ?? /ssh\.dev\.azure\.com:v3\/([^/]+)\/([^/]+)\/([^/\s]+)/.exec(url);
  if (!m) return null;
  const [org, project, repo] = m.slice(1).map(s => decodeURIComponent(s).replace(/\.git$/, ""));
  return { org, project, repo, key: `${org}/${project}/${repo}`.toLowerCase() };
}

// Every folder a space is working in: where it starts terminals and where its panes are now
function spaceFolders() {
  const tabSpace = {};
  for (const s of spaces()) for (const tab of s.tabs) tabSpace[tab.id] = s;
  const out = new Map();
  const add = (space, cwd) => { if (cwd) out.set(`${space.machine ?? ""}|${cwd}`, { id: `${space.machine ?? ""}|${cwd}`, space, cwd }); };
  for (const s of spaces()) add(s, s.folder);
  for (const p of panes()) if (tabSpace[p.tab]) add(tabSpace[p.tab], p.cwd);
  return [...out.values()];
}

// The vote that best sums up a PR's reviews
function verdict(pr) {
  const votes = (pr.reviewers ?? []).map(r => r.vote);
  if (votes.includes(-10)) return "rejected";
  if (votes.includes(-5)) return "waiting";
  if (votes.some(v => v >= 5)) return "approved";
  return "pending";
}

const ago = (date) => {
  const m = Math.max(0, Math.round((Date.now() - new Date(date).getTime()) / 60000));
  return m < 60 ? `${m}m` : m < 48 * 60 ? `${Math.round(m / 60)}h` : `${Math.round(m / 1440)}d`;
};
const branch = (ref) => ref?.replace(/^refs\/heads\//, "") ?? "";

export default class PullRequests extends View {
  init(_props, cx) {
    this.remotes = {};     // machine|folder -> parsed remote; only folders that answered are kept
    this.prs = {};         // repo key -> PRs
    this.me = {};          // org -> my identity id
    this.token = null;
    this.filter = localStorage.getItem("filter") ?? "all";
    this.folded = JSON.parse(localStorage.getItem("folded") ?? "{}");
    this.refresh(cx);
    cx.timer.every(REFRESH_MS, (cx) => this.refresh(cx));
    cx.timer.every(RETRY_MS, (cx) => { if (this.error || !this.repos?.length) this.refresh(cx); });
  }

  async az(args) {
    // az is a .cmd script on Windows, which only cmd can start
    const r = window()?.platform === "windows"
      ? await exec("cmd", ["/d", "/c", "az", ...args], { timeout: 60000 })
      : await exec("az", args, { timeout: 60000 });
    if (r.code !== 0) throw new Error((r.stderr || r.stdout).trim().split("\n").pop());
    return r.stdout;
  }

  async accessToken() {
    if (this.token && this.token.expires > Date.now() + 5 * 60 * 1000) return this.token.value;
    const t = JSON.parse(await this.az(["account", "get-access-token", "--resource", ADO, "-o", "json"]));
    const expires = t.expires_on ? t.expires_on * 1000 : new Date(t.expiresOn).getTime();
    this.token = { value: t.accessToken, expires };
    return t.accessToken;
  }

  async get(url) {
    const res = await fetch(url, { headers: { Authorization: `Bearer ${await this.accessToken()}` } });
    if (res.status === 401) this.token = null;
    if (!res.ok) throw new Error(`Azure DevOps answered ${res.status}`);
    return res.json();
  }

  // Asks git for each folder's remote. A failed lookup isn't remembered, so it's tried again next time.
  async findRepos() {
    const folders = spaceFolders();
    await Promise.all(folders.map(async ({ id, space, cwd }) => {
      if (id in this.remotes) return;
      const r = await exec("git", ["-C", cwd, "remote", "get-url", "origin"], { on: space.machine }).catch(() => null);
      if (r?.code === 0) this.remotes[id] = parseRemote(r.stdout.trim());
    }));
    const repos = new Map();
    for (const { id } of folders) {
      const remote = this.remotes[id];
      if (remote && !repos.has(remote.key)) repos.set(remote.key, remote);
    }
    this.folders = folders.map(f => f.id).sort().join("\n");
    return [...repos.values()];
  }

  refresh(cx) {
    if (this.loading) return;
    this.loading = true;
    cx.spawn(async (cx) => {
      cx.notify();
      try {
        const repos = await this.findRepos();
        const errors = [];
        await Promise.all(repos.map(async (repo) => {
          try {
            const base = `https://dev.azure.com/${encodeURIComponent(repo.org)}`;
            this.me[repo.org] ??= (await this.get(`${base}/_apis/connectionData`)).authenticatedUser.id;
            const data = await this.get(`${base}/${encodeURIComponent(repo.project)}/_apis/git/repositories/${encodeURIComponent(repo.repo)}/pullrequests?searchCriteria.status=active&$top=100&api-version=7.1`);
            this.prs[repo.key] = data.value;
          } catch (e) { errors.push(`${repo.repo}: ${e.message ?? e}`); }
        }));
        this.repos = repos;
        this.error = errors.length ? errors.join("\n") : null;
        this.updated = Date.now();
      } catch (e) { this.error = String(e.message ?? e); }
      finally { this.loading = false; cx.notify(); }
    });
  }

  open(repo, pr) {
    const url = `https://dev.azure.com/${encodeURIComponent(repo.org)}/${encodeURIComponent(repo.project)}/_git/${encodeURIComponent(repo.repo)}/pullrequest/${pr.pullRequestId}`;
    const platform = window()?.platform;
    if (platform === "windows") exec("rundll32", ["url.dll,FileProtocolHandler", url]);
    else exec(platform === "macos" ? "open" : "xdg-open", [url]);
  }

  setFilter(filter) {
    this.filter = filter;
    localStorage.setItem("filter", filter);
  }

  toggle(key) {
    this.folded[key] = !this.folded[key];
    localStorage.setItem("folded", JSON.stringify(this.folded));
  }

  shown(repo) {
    const me = this.me[repo.org];
    const list = this.prs[repo.key] ?? [];
    if (this.filter === "mine") return list.filter(pr => pr.createdBy?.id === me);
    if (this.filter === "review") return list.filter(pr => pr.createdBy?.id !== me && pr.reviewers?.some(r => r.id === me && r.vote === 0));
    return list;
  }

  row(repo, pr, branchSpaces, t) {
    const me = this.me[repo.org];
    const color = { approved: t.ansi2, waiting: t.blocked, rejected: t.ansi1, pending: t.dim }[verdict(pr)];
    const mine = pr.createdBy?.id === me;
    const needsMe = !mine && pr.reviewers?.some(r => r.id === me && r.vote === 0);
    const space = branchSpaces[branch(pr.sourceRefName)];
    const id = `${repo.key}-${pr.pullRequestId}`;
    const badge = (text, fg) => div().flex_none().px(4).rounded(4).border_1().border_color(t.border).text_size(10).text_color(fg).child(text);
    return v_flex().id(`pr-${id}`).flex_none().px(8).py(5).gap(1).rounded(7).cursor_pointer()
      .when(needsMe, el => el.bg(t.accent + "14"))
      .hover(s => s.bg(t.hover))
      .tooltip(`${pr.title}\n${branch(pr.sourceRefName)} → ${branch(pr.targetRefName)}`)
      .on_click(() => this.open(repo, pr))
      .child(h_flex().gap(7).items_center()
        .child(div().size(7).flex_none().rounded(4).bg(color))
        .child(div().flex_1().min_w(0).truncate().text_color(pr.isDraft ? t.muted : t.foreground).child(pr.title)))
      .child(h_flex().pl(14).gap(5).items_center().text_size(11).text_color(t.dim)
        .child(div().flex_none().child(`!${pr.pullRequestId}`))
        .child(div().flex_1().min_w(0).truncate().child(mine ? "you" : pr.createdBy?.displayName ?? ""))
        .when(pr.isDraft, el => el.child(badge("Draft", t.muted)))
        .when(pr.mergeStatus === "conflicts", el => el.child(badge("Conflicts", t.ansi1)))
        .when(needsMe, el => el.child(badge("Review", t.accent)))
        .when(Boolean(space), el => el.child(div().id(`pr-space-${id}`).flex_none().max_w(80).truncate().px(4).rounded(4).bg(t.raised).text_color(t.muted)
          .hover(s => s.text_color(t.foreground))
          .on_click((_e, cx) => { cx.stop_propagation(); run("space.select", { id: space.id }); })
          .child(space.name)))
        .child(div().flex_none().child(ago(pr.creationDate))));
  }

  render(cx) {
    const t = theme();
    // A space opened or moved somewhere new may be in a repo we haven't asked about
    if (!this.loading && this.folders !== undefined && spaceFolders().map(f => f.id).sort().join("\n") !== this.folders) this.refresh(cx);

    const repos = this.repos ?? [];
    const total = repos.reduce((n, repo) => n + this.shown(repo).length, 0);
    const root = v_flex().size_full().min_h(0).bg(t.chrome).border_t(1).border_color(t.border).text_size(12.5);

    if (narrow()) {
      return root.child(v_flex().id("prs-rail").pt(10).items_center().gap(3).text_color(t.dim).tooltip(`${total} pull requests`)
        .child(svg("mods/workspace-chrome/git-compare.svg").size(15))
        .child(div().text_size(10).child(String(total))));
    }

    // Spaces checked out on a PR's source branch, so a PR can jump to its space
    const branchSpaces = {};
    for (const s of spaces()) if (s.branch) branchSpaces[s.branch] ??= s;
    for (const p of panes()) if (p.branch) branchSpaces[p.branch] ??= spaces().find(s => s.tabs.some(tab => tab.id === p.tab));

    const chip = (key, label) => div().id(`filter-${key}`).px(7).h(20).flex().items_center().rounded(6).text_size(11)
      .bg(this.filter === key ? t.selected : t.chrome).text_color(this.filter === key ? t.foreground : t.dim)
      .hover(s => s.text_color(t.foreground)).on_click((_e, cx) => { this.setFilter(key); cx.notify(); }).child(label);

    const rows = repos.flatMap((repo) => {
      const list = this.shown(repo), folded = this.folded[repo.key];
      const header = h_flex().id(`repo-${repo.key}`).px(8).pt(8).h(30).flex_none().gap(6).items_center().text_size(11).font_medium().text_color(t.dim).cursor_pointer()
        .hover(s => s.text_color(t.foreground))
        .on_click((_e, cx) => { this.toggle(repo.key); cx.notify(); })
        .child(div().truncate().child(repo.repo))
        .child(div().child(String(list.length)))
        .child(div().flex_1())
        .child(svg(`mods/workspace-chrome/${folded ? "chevron-right" : "chevron-down"}.svg`).size(11).flex_none());
      if (folded) return [header];
      return [header, ...list.map(pr => this.row(repo, pr, branchSpaces, t)),
        ...(list.length ? [] : [div().px(8).py(3).flex_none().text_size(11).text_color(t.dim).child("No pull requests")])];
    });

    const empty = !this.repos ? "Loading pull requests…"
      : repos.length === 0 ? (this.loading ? "Looking for Azure DevOps repos…" : "No space is in an Azure DevOps repo") : null;

    return root
      .child(h_flex().px(16).h(41).pt(14).pb(5).flex_none().gap(6).items_center()
        .child(div().text_size(11.5).font_medium().text_color(t.dim).child("Pull requests"))
        .child(div().text_size(11).text_color(t.dim).child(String(total)))
        .child(div().flex_1())
        .child(div().id("prs-refresh").text_color(t.dim).hover(s => s.text_color(t.foreground)).tooltip("Refresh")
          .on_click((_e, cx) => this.refresh(cx))
          .child(this.loading ? svg("mods/workspace-chrome/spinner.svg").size(13).spin(900) : div().text_size(13).child("↻"))))
      .child(h_flex().px(12).pb(2).flex_none().gap(2).children(FILTERS.map(([key, label]) => chip(key, label))))
      .when(Boolean(empty), el => el.child(div().px(16).py(4).text_size(12).text_color(t.dim).child(empty)))
      .when(Boolean(this.error), el => el.child(div().px(16).py(4).flex_none().text_size(11).text_color(t.ansi1).child(this.error)))
      .child(v_flex().id("prs-list").flex_1().min_h(0).px(8).pb(8).overflow_y_scrollbar().mode("always").children(rows));
  }
}
