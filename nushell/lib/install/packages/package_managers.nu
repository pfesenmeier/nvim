# scoop "install multiple" is bugged
# apt has no upgrade_all_cmd because "install upgrades" runs apt update/upgrade itself
export def main [] {
  [
    [name   install_cmd                                                    add_container_cmd upgrade_all_cmd              install_multiple windows_exe sudo];
    [dotnet "tool install {} --global"                                     null              "tool update --all --global" false            null        false]
    [scoop  install                                                        "bucket add"      "update -a"                  false            scoop       false]
    [brew   "install"                                                      "tap"             "upgrade"                    true             null        false]
    [winget "install --no-upgrade --accept-package-agreements"             null              "upgrade --all"              true             winget.exe  false]
    [pnpm   "add --global"                                                 null              "update --global"   true             null        false]
    [apt    "install -y"                                                   null              null                         true             null        true]
  ]
}
