# Ra - personal dev config

## TODO
- symlink config dictory with nu.config-path
- download latest curl (for json flag)
- move apt, winget scripts to ra
- Fish alt-f, ctrl-f bindings
- new install location on windows: ~/AppData/Local
- let setup of ra-env file be less painful
- library for symlinking, unzipping, putting in bin folder
- support script installs
- support profiles (dotnet, js, etc..)
- common lib for neovim, ra to use (LSP_LUA_ENABLED, etc..)
- universal git config
- script to source everything in lib dir in config.nu

## Ra Steps
- run setup.nu to symlink config, env, lib
- add 'lib' dir to NU_LIB_DIRS in env.nu
- add 'source ra.nu' etc.. to bottom of config.nu
