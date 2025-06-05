return {
  { name = "deno",                       src = { "brew", "scoop" } },
  { name = "difftastic",                 src = { "brew", "scoop" } },
  { name = "fd",                         src = { "brew", "scoop" } },
  { name = "fnm",                        src = { "brew", "scoop" } }, -- see node-env.nu
  { name = "fzf",                        src = { "brew", "scoop" } },
  { name = "gcc",                        src = { "brew", "scoop" } },
  { name = "gh",                         src = { "brew", "scoop" } },
  { name = "lua-language-server",        src = { "brew", "scoop" } },
  { name = "marksman",                   src = { "brew", "scoop" } },
  { name = "neovim",                     src = { "brew", "scoop" } },
  { name = "nushell",                    src = { "brew", scoop = "nu" } }, -- not nu!
  { name = "ripgrep",                    src = { "brew", "scoop" } },
  { name = "starship",                   src = { "brew", "scoop" } },
  { name = "vcredist2022",               src = { "scoop" } }, --needed for neovim
  -- TODO update vue.lua to use fnm
  { name = "nvm",                        src = { "scoop" } }, -- try use fnm
  -- { name = "zig",                 src = { "scoop" }}, -- trying to use gcc for treesitter
  { name = "nerd-fonts/0xProto-NF-Mono", src = { "scoop" } },
  { name = "gsudo",                      src = { "scoop" } },
  { name = "make",                       src = { "scoop" } },
  { name = "komorebi",                   src = { "scoop" } },
  { name = "whkd",                       src = { "scoop" } },
  { name = "gpg4win",                    src = { "scoop" } },
  { name = "discord",                    src = { winget = "discord.discord" } },
  { name = "chrome",                     src = { winget = "google.chrome" } },
  { name = "visualstudiocode",           src = { winget = "microsoft.visualstudiocode" } },
  { name = "dockerdesktop",              src = { winget = "docker.dockerdesktop" } },
  { name = "dbeaver",                    src = { winget = "dbeaver.dbeaver" } },
  { name = "gpg4win",                    src = { winget = "GnuPG.Gpg4win" } },
  { name = "devtoys",                    src = { winget = "DevToys-app.DevToys" } },
}
