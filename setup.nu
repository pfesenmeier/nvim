let config_path = [$nu.home-path nvim] | path join;

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

def create_parent_dirs [target: string] {
  let dir = $target | path dirname;
  mkdir $dir;
}

([config.nu env.nu lib] | each {|x|
  let source = [$config_path nu $x] | path join;
  let dest = $nu.default-config-dir;
  create_parent_dirs $dest;
  symlink $source $dest;
});


let omni_dest = [$nu.home-path .omnisharp omnisharp.json] | path join;
let omni_src = [$config_path omnisharp.json] | path join;
create_parent_dirs $omni_dest;
symlink $omni_src $omni_dest;

([init.lua ginit.vim lua] | each {|x|
  let source = [$config_path $x] | path join;

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

let zellij_dest = [$nu.home-path .config zellij config.kdl] | path join;
let zellij_src = [$config_path zellij.kdl] | path join;
create_parent_dirs $zellij_dest;
symlink $zellij_src $zellij_dest;

