## Bot Review

- [ ] derive claude status from its lifecycle / hook firing, put it in status bar
  - [ ] basically: idle, needs input, working

- [ ] a pr review skill that puts its file-level feedback into vim diagnostics
- [ ] <leader>fp - puts pull-request feedback into the mini picker
- [ ] each diagnostic has a code action available to select
  - [ ] last two options are always 'chat about this' - opens the claude terminal and pastes the contents (does not fire it off)
  - [ ] second - dismiss, which always removes the diagnostic

### Implementation Options

look how 'nv' tool is used to trigger neovim from claude
look how none-ls configures a fake lsp server
