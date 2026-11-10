import { View, div, svg, image } from "gpui-kit";
import { h_flex } from "gpui-base";
import { spaces, panes, terminals, focused, hc, exec, run, openOverlay, theme, window, shared, layout, settings } from "herdr";

// The terminal the layout's jj-panel block shows
const JJ = "jj-panel";

function find(node, id) {
  if (node?.id === id) return node;
  for (const child of node?.children ?? []) {
    const found = find(child, id);
    if (found) return found;
  }
  return null;
}

// The folder jjui should follow: the focused pane's, or the active tab's when the jj panel has focus
function jjFolder() {
  const f = focused();
  if (f?.pane) return f.cwd;
  const space = spaces().find(s => s.active), tab = space?.tabs.find(c => c.active);
  const inTab = panes().filter(p => p.tab === tab?.id && p.cwd);
  return (inTab.find(p => p.focused) ?? inTab[0])?.cwd ?? space?.folder ?? null;
}

export default class Tabs extends View {
  init() {
    this.pressed = null;
    this.panels = JSON.parse(localStorage.getItem("panels") ?? "{}");
  }

  // The side panel is remembered per space: switching shows that space's choice
  // (closed if it never had one), and opening or closing it records it.
  syncPanel(space, panel, body, enabled) {
    if (!space || !panel) return;
    const now = panel.hidden ? null : body?.active ?? null;
    if (space.id !== this.space) {
      const first = this.space === undefined;
      this.space = space.id; this.pending = null;
      if (!(first && !(space.id in this.panels))) {
        const stored = this.panels[space.id] ?? null, want = enabled.includes(stored) ? stored : null;
        if (want !== now) {
          this.pending = { want, until: Date.now() + 1000 };
          if (want) { run("layout.select", { stack: "panel-body", child: want }); run("layout.show", { id: "panel" }); }
          else run("layout.hide", { id: "panel" });
          return;
        }
      }
    }
    // Until the restore lands (or something else won), the old state isn't a choice.
    if (this.pending) {
      if (this.pending.want !== now && Date.now() < this.pending.until) return;
      this.pending = null;
    }
    if (this.panels[space.id] === now) return;
    this.panels[space.id] = now;
    localStorage.setItem("panels", JSON.stringify(this.panels));
  }

  // Starts jjui at the folder's repo root unless it's already running there.
  // Answers false outside a jj repo, where jjui would quit right away.
  async startJj(cwd) {
    const repo = await exec("jj", ["root"], cwd ? { cwd } : {}).catch(() => null);
    if (repo?.code !== 0) return false;
    const root = repo.stdout.trim();
    if (terminals().some(x => x.name === JJ && x.state === "live" && x.cwd === root)) return true;
    this.jjStarting = Date.now() + 3000;
    await hc(["kill", JJ]);
    await hc(["rm", JJ]);
    const started = await hc(["run", "--bg", "--rm", "--no-notify", "--name", JJ, "--cwd", root, "jjui"]);
    if (started.code !== 0) { this.jjStarting = 0; return false; }
    return true;
  }

  // Shows jjui beside the tab, starting it in the focused folder's repo when needed.
  // Hiding leaves it running; it's restarted when the repo changes.
  async toggleJj(shown) {
    this.jjWanted = !shown;
    if (shown) { run("layout.hide", { id: "jj-panel" }); return; }
    if (!(await this.startJj(jjFolder()))) return;
    run("layout.show", { id: "jj-panel" });
    // The block is found by the name in its content, not by the terminal's address
    run("pane.focus", { terminal: JJ });
  }

  // After a space switch, an open jj panel follows the new space's repo.
  // It hides in a space with no repo and comes back in the next one that has one.
  async refreshJj() {
    if (await this.startJj(jjFolder())) run("layout.show", { id: "jj-panel" });
    else run("layout.hide", { id: "jj-panel" });
  }

  render() {
    const t = theme();
    const space = spaces().find(p => p.active);
    const shown = space?.tabs ?? [];
    const stop = (_e, cx) => cx.stop_propagation();
    const button = (id, label, action) => div().id(id).size(26).flex_none().flex().items_center().justify_center().rounded(6).text_color(t.dim).hover(s => s.bg(t.hover).text_color(t.foreground))
      .on_mouse_down("left", stop).on_click(action).child(label);
    const item = (c, i) => {
      const program = panes().find(p => p.tab === c.id && p.program?.agent)?.program ?? panes().find(p => p.tab === c.id)?.program;
      const name = /^tb\d+$/.test(c.name) ? program?.name ?? "Terminal" : c.name;
      return h_flex().id(`tab-${c.id}`).h(29).px(10).gap(7).rounded(7).items_center().flex_none().text_size(12.8)
        .border(1).border_color(c.active ? t.border : t.chrome).bg(c.active ? t.raised : t.chrome).text_color(c.active ? t.foreground : t.muted)
        .hover(s => s.bg(t.hover))
        .on_mouse_down("left", (e, cx) => { cx.stop_propagation(); this.pressed = i; if (e.click_count === 2) run("tab.rename", { id: c.id }); })
        .on_mouse_up("left", () => {
          const from = this.pressed; this.pressed = null;
          if (from !== null && from !== i) run("tab.move", { id: shown[from].id, index: space.tabs.findIndex(x => x.id === c.id) + 1 });
          else run("tab.select", { id: c.id });
        })
        .on_mouse_down("right", (_e, cx) => { cx.stop_propagation(); openOverlay({ mod: "menu", kind: "popup", width: 200, props: { tab: "tab", target: { id: c.id, space: space.id } } }); })
        .when(Boolean(program?.icon), el => el.child(program.tint ? svg(program.icon).size(14).text_color(t.muted) : image(program.icon).size(14)))
        .child(div().max_w(170).truncate().child(c.zoomed ? `${name} Z` : name))
        .when(c.status === "working", el => el.child(svg("mods/workspace-chrome/spinner.svg").size(12).flex_none().text_color(t.working).spin(900)))
        .when(c.status === "blocked" || c.status === "done", el => el.child(div().size(6).rounded(3).bg(t[c.status])))
        .when(c.active, el => el.child(div().id(`close-${c.id}`).text_color(t.dim).on_mouse_down("left", stop).on_click((_e, cx) => { cx.stop_propagation(); run("tab.close", { id: c.id }); }).child(svg("mods/pane/close.svg").size(12))));
    };
    const root = layout(), sidebar = find(root, "sidebar"), w = window();
    // Old saved rails and a dragged-narrow sidebar can be smaller than the window buttons.
    const lightsPadding = w?.platform === "macos" && w.titlebar === "none" && !w.fullscreen && root?.traffic_lights
      ? Math.max(10, (root.traffic_lights[0] + 64) / settings().zoom - (sidebar?.hidden ? 0 : sidebar?.size?.px ?? 0))
      : 10;
    const panel = find(root, "panel"), body = find(root, "panel-body");
    const enabled = shared("workspace.panels") ?? ["files", "changes"];
    this.syncPanel(space, panel, body, enabled);
    const chip = (id, label, icon, on, action) => h_flex().id(id).h(26).px(8).gap(5).flex_none().items_center().rounded(6)
      .text_size(12).bg(on ? t.selected : t.chrome).text_color(on ? t.foreground : t.muted)
      .hover(s => s.bg(t.hover)).on_mouse_down("left", stop)
      .on_click(action).child(icon).child(label);
    const panelButton = (id, label, icon) => {
      const on = panel && !panel.hidden && body?.active === id;
      return chip(`panel-${id}`, label, svg(icon).size(14), on, () => {
        if (on) run("layout.hide", { id: "panel" });
        else { run("layout.select", { stack: "panel-body", child: id }); run("layout.show", { id: "panel" }); }
      });
    };
    const jj = find(root, "jj-panel"), jjShown = Boolean(jj && !jj.hidden);
    // Collapse the jj panel once jjui exits (its terminal is removed on exit)
    if (terminals().some(x => x.name === JJ && x.state === "live")) this.jjStarting = 0;
    else if (jjShown && !(Date.now() < this.jjStarting)) { this.jjWanted = false; run("layout.hide", { id: "jj-panel" }); }
    if (space && space.id !== this.jjSpace) {
      const first = this.jjSpace === undefined;
      this.jjSpace = space.id;
      if (!first && (jjShown || this.jjWanted)) { this.jjWanted = true; this.refreshJj(); }
    }
    return h_flex().size_full().min_w(0).px(10).pl(lightsPadding).gap(3).items_center().bg(t.chrome).border_b(1).border_color(t.border)
      .on_mouse_up("left", () => { this.pressed = null; })
      .on_scroll_wheel(e => { if (Math.abs(e.delta.y) >= 1) run(e.delta.y > 0 ? "tab.prev" : "tab.next"); })
      .child(h_flex().id("tab-scroll").flex_1().min_w(0).h_full().items_center().gap(3).overflow_x_scrollbar().children(shown.map(item)))
      .child(button("tab-new", "+", () => openOverlay({ mod: "my-new-menu", kind: "popup", width: 250, height: 600 })))
      .when(Boolean(jj), el => el.child(chip("panel-jj", "jj", image("my-icons/jj.svg").size(14), jjShown, () => this.toggleJj(jjShown))))
      .when(enabled.includes("files"), el => el.child(panelButton("files", "Files", "mods/files/file.svg")))
      .when(enabled.includes("changes"), el => el.child(panelButton("changes", "Changes", "mods/changes/changes.svg")))
      // Window icons come from the shipped tabs mod: herdr won't load images through this mod's symlink
      .when(w?.buttons, el => el.child(button("minimize", w.platform === "windows" ? svg("mods/tabs/win-min.svg").size(16) : "−", () => run("window.minimize")))
        .child(button("maximize", w.platform === "windows" ? svg(`mods/tabs/${w.maximized ? "win-restore" : "win-max"}.svg`).size(16) : "□", () => run("window.maximize")))
        .child(button("close-window", w.platform === "windows" ? svg("mods/tabs/win-close.svg").size(16) : svg("mods/pane/close.svg").size(13), () => run("window.close"))));
  }
}
