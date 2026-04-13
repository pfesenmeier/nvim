use constants.nu wsl_distro_home

# jj helpers
# export def jjj [] {}

# clone a git repository in WSL from Windows
# export def "jjj wsl-clone" [
#   path: string         # path to repo in WSL, relative to WSL home directory
# ] {
#   let path = $wsl_distro_home | path join $path
#
#   git config --global --add safe.directory ($path | path join .git)
#
#   jj git clone $path --remote wsl
# }

# set and track a bookmark
# export def "jj-bst" [branch: string] {
#     jj bookmark set $branch
#     jj bookmark track $branch
# }

# format all C# files changed since trunk
export def fmt-changed [] {
    let files = (jj diff --summary --from "trunk()"
        | lines
        | parse "{status} {file}"
        | where file ends-with ".cs"
        | get file)

    if ($files | is-not-empty) {
      csharpier format ...$files
    }
}
