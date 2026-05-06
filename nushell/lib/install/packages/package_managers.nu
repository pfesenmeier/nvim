export def main [] {
  [
    [name   install_cmd                                        add_container_cmd install_multiple windows_exe];
    [npm    "install --global"                                 null              true             null]
    [dotnet "tool install {} --global"                         null              false            null]
    [scoop  install                                            "bucket add"      true             scoop]
    [brew   "install"                                          "tap"             true             null]
    [winget "install --accept-package-agreements"              null              true             winget.exe]
  ]
}
