# personal dev config

### AI

- TODO tommcdo/vim-lion
- https://github.com/banjo/contextfiles.nvim for importing copilot prompts / instruction files

### VSCode Extextension
- Github Pull Requests
- Better Comments
- Paste JSON as Code
- Comment Tag Template
- Biome
- Css Peek
- File Utils
- Error Lens
- Code Snap
- Pretty TS Errors
- Permute Lines
- TODO Tree

### install script
ps1
bash?

### komorebi
default app layout?
bubble tilebar?
gruvbox colors
square corners
borders false?
background img

### big wins
- get rid off nvm or fnm, but get fnm env stuff working
- "open test file" shortcut
- search fatigue
- close quickfix
- repeat <leader>gn go to next edit.
- go previous edit
- make go faster?
- windows_wsl setup (need for komorebi)
- soft link downloads, documents, desktop to wsl
- telescope: all buffers except terminal buffers
- telescope: only terminal buffers
- remove nushell highlight script, not needed?
- sort buffers alphabetically?
- import via autocomplete selection
- stop adding newlines to end of files
- add "rg this selection", "fd this selection"
- add save buffer to test commands
- pin netcoredbg, neotest
- connect formatters via lsp: 
    - https://github.com/creativenull/efmls-configs-nvim
    - https://github.com/creativenull/efmls-configs-nvim/
- add save buffer to test commands
- https://csharpier.com/ with neoformat
- install fd from github (winget breaks path on every upgrade)
- enhance cross-platform (PATH / Path), fzf plugin, omnisharp path
- add "let $FZF_DEFAULT_COMMAND = 'rg --files --hidden'"
- add nvim-gui niceities
    - enhance terminal to all nushell terminal by default (fix PATH / Path problem)
- project-level errors
    - dotnet build output
    - shortcut for vim.diagnostic.setqflist({ severity = ERROR }) (project-level errors)

- debugging
    - find dotnet process https://github.com/mfussenegger/nvim-dap/issues/356#issuecomment-975825270

- shortcut for copying filename (let @+ = expand("%:t")) (or for creating class file, a la
- understanding tmux sessions

### small things
- sessions management (open up last tabs used on startup

### tips
- <C-o>, <c-w>, <c-h> in insert mode
- =, S for indent
what is vim wiki

## Adding rosylnator
https://github.com/OmniSharp/omnisharp-vim/issues/451#issuecomment-473727111
https://marketplace.visualstudio.com/items?itemName=josefpihrt-vscode.roslynator
https://open-vsx.org/extension/josefpihrt-vscode/roslynator

## Dotnet 

- Dapr
- Prometheus
- [Visual Studio Aspire Tools](https://learn.microsoft.com/en-us/dotnet/aspire/setup-tooling?tabs=visual-studio#visual-studio-tooling)
- Open Telemetry
- Container Apps (aca)
- cli tools with AOT
- https://smartwindows.app/



## done
- go to next / last edit
- wsl_windows, wsl_linux environments
- enhance terminal to all nushell terminal by default (fix PATH / Path problem)
- install netcoredbg (cross platform)
- put all c# stuff into one file
- integrate pasteing into telescope from system clipboard
- shortcut for call FullScreen()
- integrate pasteing into telescope from system clipboard (nvim-gui, ubuntu)
