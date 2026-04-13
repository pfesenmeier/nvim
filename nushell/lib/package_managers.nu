export def main [] {
  [
    [name   install_cmd                                       ];
    [npm    "install --global"                                      ]
    [dotnet "tool    install      --global"                   ]
    [scoop  install                                           ]
    [brew   install                                           ]
    [winget "install --no-upgrade --accept-package-agreements"]
  ]
}
