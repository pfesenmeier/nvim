# Nushell Environment Config File
#
# version = "0.85.0"

# Disable XON/XOFF flow control so Ctrl+S reaches applications (e.g. Neovim)
stty -ixon

def jj-prompt-info [] {
    let result = try {
        jj log --no-pager -r "@ | @-" -T 'change_id.shortest() ++ "\t" ++ description.first_line() ++ "\t" ++ bookmarks.join(",") ++ "\t" ++ if(empty, "true", "false") ++ "\t" ++ working_copies ++ "\n"' --no-graph e> /dev/null
    } catch {
        return null
    }

    let lines = $result | str trim | split row "\n" | where { |l| $l | is-not-empty }
    if ($lines | is-empty) { return null }

    $lines | each { |line|
        let parts = $line | split row "\t"
        {
            change_id: ($parts | get 0)
            description: ($parts | get -o 1 | default "")
            bookmarks: ($parts | get -o 2 | default "")
            empty: (($parts | get -o 3 | default "false") == "true")
            working_copies: ($parts | get -o 4 | default "")
        }
    }
}

def create_left_prompt [] {
    let dir = $env.PWD | str replace $nu.home-dir "~" | path split | last 3 | path join
    let reset = ansi reset
    let dir_color = ansi -e { fg: "#DBBC7F" }
    let at_color = ansi -e { fg: "#83C092" }
    let par_color = ansi -e { fg: "#7FBBB3" }
    let dim = ansi -e { fg: "#859289" }

    let dir_segment = $"($dir_color) \u{f07c} ($dir)($reset)"

    let revs = jj-prompt-info
    if ($revs == null) {
        return $"($dir_segment)\n"
    }

    let at_rev = $revs | get 0
    let workspace = $at_rev.working_copies | str replace -r '@$' '' | str trim
    let workspace_segment = if ($workspace | is-empty) or $workspace == "default" {
        ""
    } else {
        let ws_color = ansi -e { fg: "#D699B6" }
        $"($ws_color) \u{f0b1} ($workspace)($reset)"
    }
    let at_desc = if ($at_rev.description | is-empty) { "(no description)" } else {
        $at_rev.description | str substring 0..40
    }
    let at_bookmarks = if ($at_rev.bookmarks | is-empty) { "" } else {
        $" ($dim)[($at_rev.bookmarks)]"
    }
    let at_id = $at_rev.change_id | fill -a left -w 3 -c ' '
    let empty_indicator = if $at_rev.empty { $" ($dim)\(empty\)" } else { "" }
    let at_line = $"($at_color) \u{e728} ($at_id) ($dim)\"($at_desc)\"($at_bookmarks)($empty_indicator)($reset)"

    let par_line = if ($revs | length) >= 2 {
        let par_rev = $revs | get 1
        let par_desc = if ($par_rev.description | is-empty) { "(no description)" } else {
            $par_rev.description | str substring 0..40
        }
        let par_bookmarks = if ($par_rev.bookmarks | is-empty) { "" } else {
            $" ($dim)[($par_rev.bookmarks)]"
        }
        let par_id = $par_rev.change_id | fill -a left -w 3 -c ' '
        $"\n($par_color) \u{e727} ($par_id) ($dim)\"($par_desc)\"($par_bookmarks)($reset)"
    } else {
        ""
    }

    $"($dir_segment)($workspace_segment)\n($at_line)($par_line)\n"
}

# def create_left_prompt [] {
#     let home =  $nu.home-dir
#
#     let dir = ([
#         ($env.PWD | str substring 0..($home | str length) | str replace $home "~"),
#         ($env.PWD | str substring ($home | str length)..)
#     ] | str join)
#
#     let path_color = (if (is-admin) { ansi red_bold } else { ansi green_bold })
#     let separator_color = (if (is-admin) { ansi light_red_bold } else { ansi light_green_bold })
#     let path_segment = $"($path_color)($dir)"
#
#     $path_segment | str replace --all (char path_sep) $"($separator_color)/($path_color)"
# }

def create_right_prompt [] {
    # create a right prompt in magenta with green separators and am/pm underlined
    let time_segment = ([
        (ansi reset)
        (ansi magenta)
        (date now | format date '%x %X %p') # try to respect user's locale
    ] | str join | str replace --regex --all "([/:])" $"(ansi green)${1}(ansi magenta)" |
        str replace --regex --all "([AP]M)" $"(ansi magenta_underline)${1}")

    let last_exit_code = if ($env.LAST_EXIT_CODE != 0) {([
        (ansi rb)
        ($env.LAST_EXIT_CODE)
    ] | str join)
    } else { "" }

    ([$last_exit_code, (char space), $time_segment] | str join)
}

def concat-paths [...path] {
    let current = if ($in | is-not-empty) {
      $in | split row (char esep)
    } else {
      []
    }

    (
      $current  
      | prepend $path
      | uniq
      | str join (char esep)
    )
}

if ($nu.os-info.family != windows) {
  let prefix = if $nu.os-info.name == "macos" {
      "/opt/homebrew"
  } else {
      "/home/linuxbrew/.linuxbrew"
  }

  $env.HOMEBREW_PREFIX = $prefix
  $env.HOMEBREW_CELLAR = $prefix | path join Cellar
  $env.HOMEBREW_REPOSITORY = $prefix | path join Homebrew
  let brew_paths = [
      bin
      sbin
  ] | each { |dir| $prefix | path join $dir }
  $env.PATH = (
    $env.PATH
    | prepend $brew_paths
    | prepend ($nu.home-dir | path join ".local" "bin")
    | uniq
  )

  $env.MANPATH = (
    $env.MANPATH? 
    | concat-paths ($prefix | path join share man)
  )
  $env.INFOPATH = (
    $env.INFOPATH?
    | concat-paths  ($prefix | path join share info)
  )
}

# Use nushell functions to define your right and left prompt
$env.PROMPT_COMMAND = {|| create_left_prompt }
# FIXME: This default is not implemented in rust code as of 2023-09-08.
$env.PROMPT_COMMAND_RIGHT = {||}

# The prompt indicators are environmental variables that represent
# the state of the prompt
$env.PROMPT_INDICATOR = {|| "> " }
$env.PROMPT_INDICATOR_VI_INSERT = {|| ": " }
$env.PROMPT_INDICATOR_VI_NORMAL = {|| "> " }
$env.PROMPT_MULTILINE_INDICATOR = {|| "::: " }

# Specifies how environment variables are:
# - converted from a string to a value on Nushell startup (from_string)
# - converted from a value back to a string when running external commands (to_string)
# Note: The conversions happen *after* config.nu is loaded
$env.ENV_CONVERSIONS = {
    "PATH": {
        from_string: { |s| $s | split row (char esep) | path expand --no-symlink }
        to_string: { |v| $v | path expand --no-symlink | str join (char esep) }
    }
    "Path": {
        from_string: { |s| $s | split row (char esep) | path expand --no-symlink }
        to_string: { |v| $v | path expand --no-symlink | str join (char esep) }
    }
}

# Directories to search for scripts when calling source or use
$env.NU_LIB_DIRS = [
    # FIXME: This default is not implemented in rust code as of 2023-09-06.
    ($nu.default-config-dir | path join 'scripts') # add <nushell-config-dir>/scripts
    ($nu.default-config-dir | path join 'lib')
]

# Directories to search for plugin binaries when calling register
$env.NU_PLUGIN_DIRS = [
    # FIXME: This default is not implemented in rust code as of 2023-09-06.
    ($nu.default-config-dir | path join 'plugins') # add <nushell-config-dir>/plugins
]

# To add entries to PATH (on Windows you might use Path), you can use the following pattern:
# $env.PATH = ($env.PATH | split row (char esep) | prepend '/some/path')

$env.lib-path = ($nu.config-path | path dirname | path join 'lib')

# pnpm
$env.PNPM_HOME = $nu.home-dir | path join .local share pnpm
let orbBin = $nu.home-dir | path join .orbstack bin

$env.PATH = ($env.PATH | split row (char esep) | prepend [$env.PNPM_HOME $orbBin] )

# for linux credential manager
# OR git config --global credential.credentialStore gpg
# https://github.com/git-ecosystem/git-credential-manager/blob/main/docs/credstores.md#gpgpass-compatible-files
$env.GCM_CREDENTIAL_STORE = "gpg"
let tty = tty
$env.GPG_TTY = $tty
