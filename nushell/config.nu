# Nushell Config File
#
# version = "0.115.1"
#
# Nushell keeps all defaults in Rust (`Config::default()`); the shipped
# default config.nu is just `$env.config = {}`. So this file holds only
# intentional overrides -- anything omitted takes the current default and
# stays current across upgrades. Inspect defaults with `nu -n -c '$env.config'`,
# `keybindings default`, or `config nu --doc`.

# Follow the OS light/dark setting, like herdr does. Neovim gets there on its
# own by asking the terminal for its background color.
def system-is-light [] {
    match $nu.os-info.name {
        windows => {
            (registry query --hkcu 'Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' AppsUseLightTheme
            | get value?) == 1
        }
        # `defaults` fails when the key is missing, which means light mode
        macos => { (do { ^defaults read -g AppleInterfaceStyle } | complete).exit_code != 0 }
        _ => false
    }
}

# Everforest hard, the same palettes the everforest colorscheme uses in Neovim.
# `grey` is for dim text like hints; `search_bg` is behind search matches.
let p = if (system-is-light) {
    {
        red: '#F85552' orange: '#F57D26' yellow: '#DFA000' green: '#8DA101'
        aqua: '#35A77C' blue: '#3A94C5' purple: '#DF69BA'
        fg: '#5C6A72' grey: '#A6B0A0' search_bg: '#FFE7DE'
    }
} else {
    {
        red: '#E67E80' orange: '#E69875' yellow: '#DBBC7F' green: '#A7C080'
        aqua: '#83C092' blue: '#7FBBB3' purple: '#D699B6'
        fg: '#D3C6AA' grey: '#414B50' search_bg: '#D3C6AA'
    }
}

# Colors nushell does not recognize are silently ignored, so keys must match
# `nu -n -c '$env.config.color_config | columns'`.
let everforest = {
        binary: $p.purple
        block: $p.blue
        bool: $p.purple
        cell-path: $p.fg
        closure: $p.aqua
        duration: $p.yellow
        float: $p.purple
        glob: $p.fg
        int: $p.purple
        list: $p.aqua
        nothing: $p.red
        range: $p.orange
        record: $p.aqua
        semver: $p.blue
        semver-range: $p.blue
        string: $p.green

        binary_printable: $p.blue
        binary_whitespace: $p.aqua
        binary_non_ascii: $p.yellow
        binary_null_char: $p.grey
        binary_ascii_other: $p.purple

        # was `date`, which nushell stopped reading -- this closure was dead
        datetime: {|| (date now) - $in |
            if $in < 1hr {
                { fg: $p.red attr: 'b' }
            } else if $in < 6hr {
                $p.red
            } else if $in < 1day {
                $p.yellow
            } else if $in < 3day {
                $p.green
            } else if $in < 1wk {
                { fg: $p.green attr: 'b' }
            } else if $in < 6wk {
                $p.aqua
            } else if $in < 52wk {
                $p.blue
            } else { 'dark_gray' }
        }

        filesize: {|e|
            if $e == 0b {
                $p.fg
            } else if $e < 1mb {
                $p.aqua
            } else {{ fg: $p.blue }}
        }

        shape_binary: { fg: $p.purple attr: 'b' }
        shape_block: { fg: $p.blue attr: 'b' }
        shape_bool: $p.purple
        shape_closure: { fg: $p.aqua attr: 'b' }
        shape_custom: $p.green
        shape_datetime: { fg: $p.aqua attr: 'b' }
        shape_directory: $p.green
        shape_external: $p.green
        shape_external_resolved: $p.green
        shape_externalarg: { fg: $p.green attr: 'b' }
        shape_filepath: $p.green
        shape_flag: { fg: $p.blue attr: 'b' }
        shape_float: { fg: $p.purple attr: 'b' }
        shape_garbage: { fg: '#FFFFFF' bg: '#FF0000' attr: 'b' }
        shape_glob_interpolation: { fg: $p.aqua attr: 'b' }
        shape_globpattern: { fg: $p.aqua attr: 'b' }
        shape_int: { fg: $p.purple attr: 'b' }
        shape_internalcall: { fg: $p.green attr: 'b' }
        shape_keyword: { fg: $p.red attr: 'b' }
        shape_list: { fg: $p.aqua attr: 'b' }
        shape_literal: $p.blue
        shape_match_pattern: $p.green
        shape_matching_brackets: { attr: 'u' }
        shape_nothing: $p.red
        shape_operator: $p.orange
        shape_pipe: { fg: $p.orange attr: 'b' }
        shape_range: { fg: $p.orange attr: 'b' }
        shape_raw_string: { fg: $p.green attr: 'b' }
        shape_record: { fg: $p.aqua attr: 'b' }
        shape_redirection: { fg: $p.orange attr: 'b' }
        shape_signature: { fg: $p.green attr: 'b' }
        shape_string: $p.green
        shape_string_interpolation: { fg: $p.aqua attr: 'b' }
        shape_table: { fg: $p.blue attr: 'b' }
        shape_vardecl: { fg: $p.blue attr: 'u' }
        shape_variable: $p.blue

        empty: $p.blue
        header: { fg: $p.green attr: 'b' }
        hints: $p.grey
        leading_trailing_space_bg: { attr: 'n' }
        row_index: { fg: $p.green attr: 'b' }
        search_result: { fg: $p.red bg: $p.search_bg }
        separator: $p.fg
}

let default_keybindings = $env.config.keybindings

$env.config = {
    show_banner: false
    edit_mode: vi
    buffer_editor: "nvim"
    color_config: $everforest

    footer_mode: "auto"          # default is now 25 (rows)
    render_right_prompt_on_last_line: true
    highlight_resolved_externals: true
    display_errors: {
        exit_code: true          # show the exit code when an external fails
    }

    completions: {
        partial: false
        algorithm: "fuzzy"
        sort: "smart"
    }

    cursor_shape: {
        emacs: blink_block
        vi_insert: line
        vi_normal: block
    }

    shell_integration: {
        # ConEmu/Windows Terminal cwd reporting, for "duplicate tab" in the same
        # directory. Replaces the hand-rolled hooks.env_change.PWD escape this
        # config used to carry. Everything else here defaults to true already.
        osc9_9: true
    }

    # Lets reedline distinguish ctrl+i from tab, ctrl+backspace, shift+enter,
    # etc. Ghostty and WezTerm support it; Windows Terminal does not, and there
    # is no auto-detection, so this is opt-in per terminal.
    # use_kitty_protocol: true

    # sqlite history adds per-session isolation and richer metadata, but starts
    # empty -- run `history import` once to carry over history.txt.
    # history: { file_format: "sqlite", isolation: true }

    # Only bindings that are NOT already reedline/nushell defaults. The block
    # after this record merges them with the defaults by `name`: a matching name
    # replaces that default, a new name is appended.
    keybindings: [
        {
            name: neovim
            modifier: control
            keycode: char_6
            mode: [vi_normal vi_insert]
            event: {
              send: executehostcommand,
              cmd: "jn"
            }
        }
        {
            name: claude
            modifier: control
            keycode: char_7
            mode: [vi_normal vi_insert]
            event: {
              send: executehostcommand,
              cmd: "jc"
            }
        }
        {
            name: jj_log
            modifier: control
            keycode: char_9
            mode: [vi_normal vi_insert]
            event: {
              send: executehostcommand,
              cmd: "jj log"
            }
        }
        {
          name: yank_last_command
          modifier: control
          keycode: char_y
          mode: [vi_normal vi_insert]
          event: {
            send: executehostcommand,
            # `clip` is ours (lib/misc/util.nu). Nushell ships a built-in `clip`
            # (hence $env.config.clip.*) but it is behind a cargo feature that is
            # off in this build, and ours handles WSL via win32yank anyway.
            cmd: "history | skip 1 | last | get command | clip"
          }
        }
        {
          # replaces the default history_menu on ctrl-r, which this frees up
          name: run_last_command
          modifier: control
          keycode: char_r
          mode: [vi_normal vi_insert]
          event: {
            send: executehostcommand,
            cmd: "history | skip 1 | last | get command | nu -c $in"
          }
        }
        {
          name: history_menu
          modifier: control_alt
          keycode: char_r
          mode: [emacs, vi_insert, vi_normal]
          event: { send: menu name: history_menu }
        }
        {
          name: change_dir_with_fzf
          modifier: control
          keycode: char_g
          mode: [vi_normal vi_insert]
          event: {
            send: executehostcommand,
            cmd: "cd (fd -t d | fzf | decode utf-8 | str trim)"
          }
        }
        {
          name: open_neovim_with_fzf
          modifier: control
          keycode: char_t
          mode: [vi_normal vi_insert]
          event: {
            send: executehostcommand,
            cmd: "fd -t f | fzf | decode utf-8 | str trim | if ($in != '') { nvim $in }"
          }
        }
        {
          name: job_unfreeze
          modifier: control
          keycode: char_f
          mode: [vi_normal vi_insert]
          event: {
            send: executehostcommand,
            cmd: "job-select"
          }
        }
        {
          name: open_neovim_with_fzf_from_home_dir
          modifier: control
          keycode: char_v
          mode: [vi_normal vi_insert]
          event: {
            send: executehostcommand,
            cmd: "fd -t f | fzf | decode utf-8 | str trim | if ($in != '') { nvim $in }"
          }
        }
    ]
}

# Setting `keybindings` above replaces the default list outright, which drops
# completion_menu and leaves Tab doing nothing. Put the defaults back, minus
# any we redefine by name.
$env.config.keybindings = (
    $default_keybindings
    | where name not-in ($env.config.keybindings | get name)
    | append $env.config.keybindings
)

alias e = nvim
alias s = git status
alias a = git add
alias c = git commit
alias b = git branch
alias l = git log --oneline
alias z = zoxide
alias helf = help
alias jobs = job list

source secrets.nu
source misc/util.nu
source install/install-packages.nu
source paths.nu
source dotnet/jb-clean.nu
source dotnet/env.nu
source git/cmds.nu
source ~/.zoxide.nu

# any source script can include an install subcommand
export def install [] {}

source install/cmds/roslyn_lsp.nu
source install/cmds/netcoredbg.nu
source install/cmds/roslynator.nu
use jj/cmds.nu *
use jj/completions.nu *
use misc/wt-layout.nu *
use kb.nu
