export def main [] {
  [
    [name                                  srcWindows                                srcUnix                                             srcMac ];
    [stylua                                scoop                                  brew                                                brew]
    # pdfs. apt on linux: brew's poppler pulls in a second gnupg that clashes with apt's gpg-agent
    [poppler                               scoop                                  apt=poppler-utils                                   brew]
    [fd                                    scoop                                     brew                                                brew]
    [pnpm                                  scoop                                     brew                                                brew]
    [fzf                                   scoop                                     brew                                                brew]
    [gcc                                   scoop                                     brew                                                brew]
    [gh                                    scoop                                     brew                                                brew]
    [lua-language-server                   scoop                                     brew                                                brew]
    [marksman                              scoop                                     brew                                                brew]
    [neovim                                scoop                                     brew                                                brew]
    # gui for neovim. wsl uses the windows install with `neovide --wsl`
    [neovide                               scoop                                     null                                                brew]
    [nushell                               scoop=nu                                  brew                                                brew]
    [ripgrep                               scoop                                     brew                                                brew]
    [bat                                   scoop                                     brew                                                brew]
    # neovim
    [vcredist2022                          scoop                                     null                                                null]
    ['nerd-fonts/0xProto-NF-Mono'          scoop                                     null                                                brew=font-0xproto-nerd-font]
    [gsudo                                 scoop                                     null                                                null]
    [make                                  scoop                                     null                                                null]
    [komorebi                              scoop                                     null                                                'brew=lgug2z/tap;komorebi-for-mac']
    [whkd                                  scoop                                     null                                                'brew=asmvik/formulae/skhd']
    [difftastic                            scoop                                  brew                                                brew]
    # [discord                               winget=discord.discord                    null                                                null]
    # linux: the .deb adds google's apt repo, so apt upgrade keeps it current after this
    [google-chrome-stable                  winget=google.chrome                      'apt=https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb' null]
    [visualstudiocode                      winget=microsoft.visualstudiocode         null                                                null]
    [dockerdesktop                         winget=docker.dockerdesktop               null                                                null]
    [orbstack                              null                                      null                                                brew]
    # [postgres                              null                                      null                                                'brew=postgresql@18']
    [dbeaver                               winget=DBeaver.DBeaver.Community          null                                                null]
    [gpg4win                               winget=GnuPG.Gpg4win                      null                                                null]
    [devtoys                               winget=DevToys-app.DevToys                null                                                null]
    [zoxide                                scoop                                     brew                                                brew]
    [jj                                    scoop                                     brew                                                brew]
    [jjui                                  scoop                                  brew                                                brew]
    [npm                                   pnpm                                      pnpm                                                pnpm]
    [dockerfile-language-server-nodejs     pnpm                                      pnpm                                                pnpm]
    [graphql-language-service-cli          pnpm                                  pnpm                                                pnpm]
    [typescript                            pnpm                                      pnpm                                                pnpm]
    [@vue/language-server                  null                                      null                                                null]
    [@prisma/language-server               null                                      null                                                null]
    [@vtsls/language-server                pnpm                                      pnpm                                                pnpm]
    [prettier                              pnpm                                  pnpm                                                pnpm]
    [tree-sitter-cli                       pnpm                                      pnpm                                                pnpm]
    [vscode-langservers-extracted          pnpm                                  pnpm                                                pnpm]
    [@tailwindcss/language-server          null                                      null                                                null]
    [claude-code                           scoop            'brew=claude-code@latest'                           'brew=claude-code@latest']
    # word files
    [pandoc                                scoop                                  brew                                                brew]
    [yq                                    scoop                                     brew                                                brew]
    [jq                                    scoop                                     brew                                                brew]
    [git-credential-manager                null                                      dotnet                                              dotnet]
    [dotnet-ef                             dotnet                                    dotnet                                              dotnet]
    [csharpier                             dotnet                                    dotnet                                              dotnet]
    # auth for azure devops nuget feeds
    [Microsoft.Artifacts.CredentialProvider.NuGet.Tool dotnet                    dotnet                                             dotnet]
    # TODO: wait until out of prerelease https://www.nuget.org/packages/roslyn-language-server/
    # [roslyn-language-server                null                                      dotnet                                              dotnet]
    [func                                  scoop=azure-functions-core-tools          'brew=azure/functions;azure-functions-core-tools@4' 'brew=azure/functions;azure-functions-core-tools@4']
    [azure-cli                             scoop                                     brew                                                brew]
    [sqlcmd                                winget=Microsoft.Sqlcmd                   brew                                                brew]
    [azure-storage-explorer               winget=Microsoft.Azure.StorageExplorer    null                                                null]
    [win32yank                             scoop             null                                                null]
    [Logitech.OptionsPlus                  winget                                    null                                                brew=logi-options+]
    # gpg passphrase prompt for git signing and the credential manager store
    [pinentry-gnome3                       null                                      apt                                                 null]
    # dbus-launch, so pinentry-gnome3 can open under wsl
    [dbus-x11                              null                                      apt                                                 null]
    # backs the git-credential-manager gpg store
    [pass                                  null                                      apt                                                 null]
    # secure store for gcm's azure devops token cache, otherwise it falls back to plain text
    [gnome-keyring                         null                                      apt                                                 null]
  ]
}
