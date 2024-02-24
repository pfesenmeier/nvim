# Ra - personal dev config

### big wins
- install netcoredbg (cross platform)
- put all c# stuff into one file
- add "let $FZF_DEFAULT_COMMAND = 'rg --files --hidden'"
- add nvim-gui niceities
    - integrate pasteing into telescope from system clipboard
    - shortcut for call FullScreen()
    - enhance terminal to all nushell terminal by default (fix PATH / Path problem)
- integrate pasteing into telescope from system clipboard (nvim-gui, ubuntu)

- be smarter about rebuilding before running tests
    - Omnisharp-vim... just for runnig tests?
    - add saving buffer to test running command
    - https://github.com/mfussenegger/nvim-dap/wiki/Cookbook#making-debugging-net-easier
    - async dotnet build (plenary?), esp for tests

- project-level errors
    - dotnet build output
    - shortcut for vim.diagnostic.setqflist({ severity = ERROR }) (project-level errors)

- debugging
    - find dotnet process https://github.com/mfussenegger/nvim-dap/issues/356#issuecomment-975825270

- shortcut for copying filename (let @+ = expand("%:t")) (or for creating class file, a la

### small things
- sessions management (open up last tabs used on startup

### tips
- <C-o>, <c-w>, <c-h> in insert mode
- =, S for indent
what is vim wiki

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


## done
- enhance terminal to all nushell terminal by default (fix PATH / Path problem)
