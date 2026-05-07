# scoop "install multiple" is bugged
export def main [] {
  [
    [name   install_cmd                                                    add_container_cmd upgrade_all_cmd     install_multiple windows_exe];
    [npm    "install --global"                                             null              "update -g"         true             null]
    [dotnet "tool install {} --global"                                     null              "tool update --all" false            null]
    [scoop  install                                                        "bucket add"      "update -a"         false            scoop]
    [brew   "install"                                                      "tap"             "upgrade"           true             null]
    [winget "install --no-upgrade --accept-package-agreements"             null              "upgrade --all"     true             winget.exe]
  ]
}
