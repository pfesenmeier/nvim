export def main [] {
  [
    [name   install_cmd add_container_cmd install_multiple                                 ];
    [npm    "install    --global"         null                         true                ]
    [dotnet "tool       install           {}                           --global" null false]
    [scoop  install     "bucket           add"                         true                ]
    [brew   "install"          "tap"      true      ]
    [winget "install    --no-upgrade      --accept-package-agreements" null      true      ]
  ]
}
