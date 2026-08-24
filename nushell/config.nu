# Nushell Config File
#
# version = "0.115.1"
#
# Nushell keeps all defaults in Rust (`Config::default()`); the shipped
# default config.nu is just `$env.config = {}`. So this file holds only
# intentional overrides -- anything omitted takes the current default and
# stays current across upgrades. Inspect defaults with `nu -n -c '$env.config'`,
# `keybindings default`, or `config nu --doc`.

# Everforest. Colors nushell does not recognize are silently ignored, so keys
# must match `nu -n -c '$env.config.color_config | columns'`.
#
#   red '#E67E80'   orange '#E69875'  yellow '#DBBC7F'  green '#A7C080'
#   aqua '#83C092'  blue '#7FBBB3'    purple '#D699B6'
#   fg '#D3C6AA'    grey '#414B50'
let everforest = {
        binary: '#D699B6'
        block: '#7FBBB3'
        bool: '#D699B6'
        cell-path: '#D3C6AA'
        closure: '#83C092'
        duration: '#DBBC7F'
        float: '#D699B6'
        glob: '#D3C6AA'
        int: '#D699B6'
        list: '#83C092'
        nothing: '#E67E80'
        range: '#E69875'
        record: '#83C092'
        semver: '#7FBBB3'
        semver-range: '#7FBBB3'
        string: '#A7C080'

        binary_printable: '#7FBBB3'
        binary_whitespace: '#83C092'
        binary_non_ascii: '#DBBC7F'
        binary_null_char: '#414B50'
        binary_ascii_other: '#D699B6'

        # was `date`, which nushell stopped reading -- this closure was dead
        datetime: {|| (date now) - $in |
            if $in < 1hr {
                { fg: '#E67E80' attr: 'b' }
            } else if $in < 6hr {
                '#E67E80'
            } else if $in < 1day {
                '#DBBC7F'
            } else if $in < 3day {
                '#A7C080'
            } else if $in < 1wk {
                { fg: '#A7C080' attr: 'b' }
            } else if $in < 6wk {
                '#83C092'
            } else if $in < 52wk {
                '#7FBBB3'
            } else { 'dark_gray' }
        }

        filesize: {|e|
            if $e == 0b {
                '#D3C6AA'
            } else if $e < 1mb {
                '#83C092'
            } else {{ fg: '#7FBBB3' }}
        }

        shape_binary: { fg: '#D699B6' attr: 'b' }
        shape_block: { fg: '#7FBBB3' attr: 'b' }
        shape_bool: '#D699B6'
        shape_closure: { fg: '#83C092' attr: 'b' }
        shape_custom: '#A7C080'
        shape_datetime: { fg: '#83C092' attr: 'b' }
        shape_directory: '#A7C080'
        shape_external: '#A7C080'
        shape_external_resolved: '#A7C080'
        shape_externalarg: { fg: '#A7C080' attr: 'b' }
        shape_filepath: '#A7C080'
        shape_flag: { fg: '#7FBBB3' attr: 'b' }
        shape_float: { fg: '#D699B6' attr: 'b' }
        shape_garbage: { fg: '#FFFFFF' bg: '#FF0000' attr: 'b' }
        shape_glob_interpolation: { fg: '#83C092' attr: 'b' }
        shape_globpattern: { fg: '#83C092' attr: 'b' }
        shape_int: { fg: '#D699B6' attr: 'b' }
        shape_internalcall: { fg: '#A7C080' attr: 'b' }
        shape_keyword: { fg: '#E67E80' attr: 'b' }
        shape_list: { fg: '#83C092' attr: 'b' }
        shape_literal: '#7FBBB3'
        shape_match_pattern: '#A7C080'
        shape_matching_brackets: { attr: 'u' }
        shape_nothing: '#E67E80'
        shape_operator: '#E69875'
        shape_pipe: { fg: '#E69875' attr: 'b' }
        shape_range: { fg: '#E69875' attr: 'b' }
        shape_raw_string: { fg: '#A7C080' attr: 'b' }
        shape_record: { fg: '#83C092' attr: 'b' }
        shape_redirection: { fg: '#E69875' attr: 'b' }
        shape_signature: { fg: '#A7C080' attr: 'b' }
        shape_string: '#A7C080'
        shape_string_interpolation: { fg: '#83C092' attr: 'b' }
        shape_table: { fg: '#7FBBB3' attr: 'b' }
        shape_vardecl: { fg: '#7FBBB3' attr: 'u' }
        shape_variable: '#7FBBB3'

        empty: '#7FBBB3'
        header: { fg: '#A7C080' attr: 'b' }
        hints: '#414B50'
        leading_trailing_space_bg: { attr: 'n' }
        row_index: { fg: '#A7C080' attr: 'b' }
        search_result: { fg: '#E67E80' bg: '#D3C6AA' }
        separator: '#D3C6AA'
}

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

    # Only bindings that are NOT already reedline/nushell defaults. Entries merge
    # with the defaults by `name`: a matching name replaces that default, a new
    # name is appended. Reusing one name twice warns (shared_keybindings_name).
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


alias e = nvim
alias nv = nvim --clean -l
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
source node-env.nu
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
