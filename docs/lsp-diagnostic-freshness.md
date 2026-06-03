# LSP Diagnostic Freshness in Neovim

Research notes on keeping LSP diagnostics fresh — the problem where diagnostics
go stale until you save, switch modes, or move the cursor.

## Current state of this config

- `neovim/plugin/10_options.lua:173` sets `update_in_insert = false` (standard default).
- No refresh-on-mode-change autocmd anywhere.
- Active LSP servers: `deno`, `lua_ls`, `roslyn`, `vtsls`, `vue_ls`.
  - vtsls / lua_ls / vue_ls push diagnostics on every `didChange` and rarely go stale.
  - `roslyn` is the likely culprit when staleness bites.

## What popular distros actually do

**None of LazyVim, NvChad, AstroNvim, LunarVim, or kickstart.nvim set up a
refresh-on-InsertLeave autocmd for diagnostics.** What looks like that pattern in
their code is always for **codelens**, not diagnostics:

| Distro      | File                                                  | What it refreshes      |
| ----------- | ----------------------------------------------------- | ---------------------- |
| LazyVim     | `lua/lazyvim/plugins/lsp/init.lua:205`                | codelens               |
| AstroNvim   | `lua/astronvim/plugins/_astrolsp_autocmds.lua`        | codelens               |
| LunarVim    | `lua/lvim/lsp/utils.lua:136` (`setup_codelens_refresh`) | codelens             |
| NvChad      | —                                                     | no refresh hook        |
| kickstart   | `init.lua:184` (config only)                          | no refresh hook        |

They all rely on:
1. Server-pushed diagnostics over `didChange`
2. Neovim's built-in behavior of queueing push diagnostics during insert and
   replaying them on `InsertLeave` when `update_in_insert = false`

## Mechanisms in Neovim 0.10 / 0.11

### Push (default)

Server sends `textDocument/publishDiagnostics`. With `update_in_insert = false`,
core buffers them and replays on `InsertLeave`. Staleness here means the
**server** hasn't republished.

### Pull (LSP 3.17)

`vim.lsp.diagnostic._enable(bufnr)` — private but stable. Once enabled, core
hooks `LspNotify` and pulls on every change. There is **no** public
`vim.lsp.buf.document_diagnostic()` — call the underscore API or use
[`catlee/pull_diags.nvim`](https://github.com/catlee/pull_diags.nvim).

Related private APIs in `runtime/lua/vim/lsp/diagnostic.lua`:

- `vim.lsp.diagnostic._enable(bufnr)` — switch buffer to `pull_kind = 'document'`
- `vim.lsp.diagnostic._refresh(bufnr, client_id?, only_visible?)` — manual pull
- `vim.lsp.diagnostic.on_diagnostic(err, result, ctx)` — handler
- `vim.lsp.buf.workspace_diagnostics({client_id?})` — public, workspace-wide pull

### `DiagnosticChanged` autocmd

First-class. `ev.data.diagnostics` contains the new list. Useful for syncing
loclist / statusline.

## Server-specific knobs

- **roslyn** — diagnostics often lag in large solutions; check
  `RoslynBackgroundAnalysisScope` / `Roslyn.background_analysis_scope`.
- **vtsls** — push on every change; no on-save knob.
- **eslint-lsp** — `settings.eslint.run = "onType" | "onSave"`. Classic
  stale-until-save toggle.
- **rust-analyzer** — `checkOnSave` runs cargo check only on save;
  `diagnostics.enable` is the live analyzer.
- **lua_ls** — `Lua.diagnostics.workspaceDelay` / `workspaceRate` control
  workspace scan timing.

## Patterns worth stealing

### Opt into pull diagnostics for capable servers

The cleanest fix when staleness is real:

```lua
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if client and client:supports_method("textDocument/diagnostic") then
      vim.lsp.diagnostic._enable(args.buf)
    end
  end,
})
```

### Manual refresh on InsertLeave

Useful only if a server supports pull but you don't want it firing on every
change:

```lua
vim.api.nvim_create_autocmd({ "InsertLeave", "BufEnter" }, {
  callback = function(args)
    for _, c in ipairs(vim.lsp.get_clients({ bufnr = args.buf })) do
      if c:supports_method("textDocument/diagnostic") then
        vim.lsp.diagnostic._refresh(args.buf, c.id)
      end
    end
  end,
})
```

### Observe diagnostics changing

```lua
vim.api.nvim_create_autocmd("DiagnosticChanged", {
  callback = function(ev) vim.diagnostic.setloclist({ open = false }) end,
})
```

## Recommendation

Before adding autocmds, figure out **which** server is going stale. If it's
vtsls / lua_ls / vue_ls, an InsertLeave refresh won't help — the server already
pushed. If it's `roslyn`, opt into pull diagnostics for that client specifically
(it advertises `textDocument/diagnostic`).

## Sources

- [Neovim diagnostic docs](https://neovim.io/doc/user/diagnostic.html)
- [vim.lsp.diagnostic source](https://github.com/neovim/neovim/blob/master/runtime/lua/vim/lsp/diagnostic.lua)
- [LSP: Support textDocument/diagnostic (#22838)](https://github.com/neovim/neovim/issues/22838)
- [Pull Diagnostic Support for Neovim — Chris Atlee](https://atlee.ca/posts/pull-diagnostic-support-for-neovim/)
- [catlee/pull_diags.nvim](https://github.com/catlee/pull_diags.nvim)
- [What's New in Neovim 0.11 — gpanders](https://gpanders.com/blog/whats-new-in-neovim-0-11/)
- [DiagnosticChanged autocmd PR (#16098)](https://github.com/neovim/neovim/pull/16098)
- [Setting Up LSP Within Neovim (v0.11) — Stephen Van Tran](https://stephenvantran.com/posts/2025-10-29-setup-neovim-lsp-011/)
