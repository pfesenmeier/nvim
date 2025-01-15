let remote = "https://raw.githubusercontent.com/nushell/tree-sitter-nu/main/queries/nu/"
let local = (
    $env.XDG_DATA_HOME?
    | default ($env.HOME | path join ".local" "share")
    | path join "nvim" "lazy" "nvim-treesitter" "queries" "nu"
)

let files = ["highlights.scm" "indents.scm" "injections.scm" "textobjects.scm"]

mkdir $local
$files | par-each {|file| http get ([$remote $file] | str join "/") | save --force ($local | path join $file) }
