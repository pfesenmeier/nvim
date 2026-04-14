export def main [] {
  [
    [name   install_cmd                                        add_container_cmd       ];
    [npm    "install --global"                                 null                    ]
    [dotnet "tool install --global"                            null                    ]
    [scoop  install                                            "bucket add"            ]
    [brew   "install --quiet"                                            "tap add"               ]
    [winget "install --no-upgrade --accept-package-agreements" null                    ]
  ]
}
