# Ra - personal dev config

### big wins
- add nvim-gui niceities
    - integrate pasteing into telescope from system clipboard
    - shortcut for call FullScreen()
    - enhance terminal to all nushell terminal by default (fix PATH / Path problem)

- shortcut for copying filename (let @+ = expand("%:t")) (or for creating class file, a la
- add saving buffer to test running command
- shortcut for vim.diagnostic.setqflist({ severity = ERROR }) (project-level errors)
- async dotnet build (plenary?), esp for tests
- https://github.com/mfussenegger/nvim-dap/wiki/Cookbook#making-debugging-net-easier
- find dotnet process https://github.com/mfussenegger/nvim-dap/issues/356#issuecomment-975825270
- dotnet build output

### small things
- filter autocompletion by type
  jetbrains?)
- get snippets working?
- obsidian.nvim https://github.com/epwalsh/obsidian.nvim
- closing buffers from renamed files
- command to generate namespace based on File location
- sessions management (open up last tabs used on startup
- use text objects treesitter?
- nu lsp setup
- dap integrations (fzf, telescope)
- close buffers through telescope?
- telescope git buffer preview fitting in preview window
- telescope view marks
- cleanup tab and signs bg
- associate tab width per filetype

### tips
- <C-o>, <c-w>, <c-h> in insert mode
- =, S for indent
the `W` motion (contiguous text)
what is vim wiki
dadbod


## Ra Steps
- run setup.nu to symlink config, env, lib
- add 'lib' dir to NU_LIB_DIRS in env.nu
- add 'source ra.nu' etc.. to bottom of config.nu

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


## closed
not sure how global .editorconfig is being setup...
either symlink an .editorconfig to the solution folder
or setting an empty .editorconfig at solution level and symlinking one at ~\\.editorconfig

- fix all of occurences in buffer... yeah, I think this has to be providerd by the server. not sure though. 
- Does "Run Test" work with parameterized test? <- yes, just put cursor on theory
