# scoop "install multiple" is bugged
# apt has no upgrade_all_cmd because "install upgrades" runs apt update/upgrade itself
# winget installs one at a time because a multi install folds every result into one generic failure code
# ok_exit_codes are non-zero codes that mean nothing went wrong
#   winget -1978335135 (0x8A150061): package already installed
export def main [] {
  [
    [name   install_cmd                                                    add_container_cmd upgrade_all_cmd              install_multiple windows_exe sudo  ok_exit_codes];
    [dotnet "tool install {} --global"                                     null              "tool update --all --global" false            null        false []]
    [scoop  install                                                        "bucket add"      "update -a"                  false            scoop       false []]
    [brew   "install"                                                      "tap"             "upgrade"                    true             null        false []]
    [winget "install --no-upgrade --accept-package-agreements"             null              "upgrade --all"              false            winget.exe  false [-1978335135]]
    [pnpm   "add --global"                                                 null              "update --global"   true             null        false []]
    [apt    "install -y"                                                   null              null                         true             null        true  []]
  ]
}
