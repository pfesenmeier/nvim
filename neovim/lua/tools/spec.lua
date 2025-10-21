return {
  { name = "deno",                              src = { "brew", "scoop" } },
  { name = "difftastic",                        src = { "brew", "scoop" } },
  { name = "fd",                                src = { "brew", "scoop" } },
  { name = "fnm",                               src = { "brew", "scoop" } }, -- see node-env.nu
  { name = "fzf",                               src = { "brew", "scoop" } },
  { name = "gcc",                               src = { "brew", "scoop" } },
  { name = "gh",                                src = { "brew", "scoop" } },
  { name = "lua-language-server",               src = { "brew", "scoop" } },
  { name = "marksman",                          src = { "brew", "scoop" } },
  { name = "neovim",                            src = { "brew", "scoop" } },
  { name = "nushell",                           src = { "brew", scoop = "nu" } }, -- not nu!
  { name = "ripgrep",                           src = { "brew", "scoop" } },
  { name = "starship",                          src = { "brew", "scoop" } },
  { name = "vcredist2022",                      src = { "scoop" } }, --needed for neovim on Windows
  { name = "nerd-fonts/0xProto-NF-Mono",        src = { "scoop" } },
  { name = "gsudo",                             src = { "scoop" } },
  { name = "make",                              src = { "scoop" } },
  { name = "komorebi",                          src = { "scoop" } },
  { name = "whkd",                              src = { "scoop" } },
  { name = "gpg4win",                           src = { "scoop" } },
  { name = "discord",                           src = { winget = "discord.discord" } },
  { name = "chrome",                            src = { winget = "google.chrome" } },
  { name = "visualstudiocode",                  src = { winget = "microsoft.visualstudiocode" } },
  { name = "dockerdesktop",                     src = { winget = "docker.dockerdesktop" } },
  { name = "dbeaver",                           src = { winget = "dbeaver.dbeaver" } },
  { name = "gpg4win",                           src = { winget = "GnuPG.Gpg4win" } },
  { name = "devtoys",                           src = { winget = "DevToys-app.DevToys" } },
  { name = "opencode",                          src = { brew = "sst/tap/opencode" } },
  { name = "neovim-remote",                     src = { "brew" } },
  { name = "zoxide",                            src = { "brew" } },
  { name = "jj",                                src = { "brew" } },
  { name = "dockerfile-language-server-nodejs", src = { "npm" } },
  { name = "graphql-language-service-cli",      src = { "npm" } },
  { name = "typescript",                        src = { "npm" } },
  { name = "typescript-language-server",        src = { "npm" } },
  { name = "@vue/language-server",              src = { "npm" } },
  { name = "@vtsls/language-server",            src = { "npm" } },
  { name = "@prisma/language-server",           src = { "npm" } },
  { name = "prettier",                          src = { "npm" } }, -- install globally
  { name = "vscode-langservers-extracted",      src = { "npm" } }, -- css, eslint, html
  { name = "@tailwindcss/language-server",      src = { "npm" } },
  { name = "@anthropic-ai/claude-code",         src = { "npm" } },
  { name = "@zed-industries/claude-code-acp",   src = { "npm" } }
  -- { name = "lazygit",                    src = { "brew" } }
}
