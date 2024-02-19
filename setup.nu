let config_path = [$nu.home-path nvim]

# https://www.nushell.sh/blog/2023-08-23-happy-birthday-nushell-4.html
def symlink [
    existing: path   # The existing file
    link_name: path  # The name of the symlink
] {
    let existing = ($existing | path expand -s)
    let link_name = ($link_name | path expand)

    if $nu.os-info.family == 'windows' {
        if ($existing | path type) == 'dir' {
            mklink /D $link_name $existing
        } else {
            mklink $link_name $existing
        }
    } else {
        ln -sfv $existing $link_name | ignore
    }
}

([config.nu env.nu lib] | each {|x|
  let source = $config_path | append [nu $x] | path join;
  let dest = $nu.default-config-dir;

  symlink $source $dest;
});


let omnifolder = [$nu.home-path .omnisharp] | path join;
mkdir $omnifolder;
(symlink omnisharp.json ([$omnifolder omnisharp.json] | path join))

([init.lua ginit.vim lua] | each {|x|
  let source = $config_path | append $x | path join;

  let dest_folder = (
    $nu.home-path 
    | append (if ($nu.os-info.family == 'windows') {  [AppData Local] } else { [.config] })
    | append nvim
  )

  mkdir ($dest_folder | path join)

  let dest = (
    $nu.home-path 
    | append $dest_folder 
    | append $x 
    | path join
  );

  symlink $source $dest;
})

