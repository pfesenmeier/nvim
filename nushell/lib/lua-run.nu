use constants.nu lua_script_dir

# runs scripts from neovim configuration
# scripts must return json
export def main [
  name: string # name of script w/o ext, , e.g. get_tools, foo/nested
] {
  let script = $lua_script_dir | path join ($name + '.lua') | path expand

  nvim -l $script | complete | get stdout | from json
}

# list all available scripts
export def list [] {
  glob ($lua_script_dir + "/**/*.lua") | each {
    path relative-to $lua_script_dir 
    | path parse
    | upsert extension { "" }
    | path join
  }
}
