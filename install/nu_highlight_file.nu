let remote = "https://raw.githubusercontent.com/nushell/tree-sitter-nu/main/queries/nu/"

let local = if $nu.os-info.family == 'windows' {
    [$env.HOME AppData Local nvim-data]
} else {
    [$env.HOME .local share nvim]
} | append [
  site
  pack
  paqs
  start
  nvim-treesitter
  queries
  nu
] | path join

let file = "highlights.scm"

mkdir $local
http get ([$remote $file] | str join "/") | save --force ($local | path join $file)
