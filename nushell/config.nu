# Nushell Config File
#
# version = "0.85.0"

# For more information on defining custom themes, see
# https://www.nushell.sh/book/coloring_and_theming.html
# And here is the theme collection
# https://github.com/nushell/nu_scripts/tree/main/themes
let everforest = {
        binary: '#D699B6'
        block: '#7FBBB3'
        cell-path: '#D3C6AA'
        closure: '#83C092'
        custom: '#D3C6AA'
        duration: '#DBBC7F'
        float: '#D699B6'
        glob: '#D3C6AA'
        int: '#D699B6'
        list: '#83C092'
        nothing: '#E67E80'
        range: '#E69875'
        record: '#83C092'
        string: '#A7C080'

        bool: {|| if $in { '#D699B6' } else { '#D699B6' } }

        date: {|| (date now) - $in |
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

        shape_and: { fg: '#E67E80' attr: 'b' }
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
        shape_or: { fg: '#E67E80' attr: 'b' }
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

        foreground: '#D3C6AA'
        background: '#272E33'
        cursor: '#D3C6AA'

        empty: '#7FBBB3'
        header: { fg: '#A7C080' attr: 'b' }
        hints: '#414B50'
        leading_trailing_space_bg: { attr: 'n' }
        row_index: { fg: '#A7C080' attr: 'b' }
        search_result: { fg: '#E67E80' bg: '#D3C6AA' }
        separator: '#D3C6AA'
}

# The default config record. This is where much of your global configuration is setup.
$env.config = {
    show_banner: false # true or false to enable or disable the welcome banner at startup

    ls: {
        use_ls_colors: true # use the LS_COLORS environment variable to colorize output
        clickable_links: true # enable or disable clickable links. Your terminal has to support links.
    }

    rm: {
        always_trash: false # always act as if -t was given. Can be overridden with -p
    }

    table: {
        mode: rounded # basic, compact, compact_double, light, thin, with_love, rounded, reinforced, heavy, none, other
        index_mode: always # "always" show indexes, "never" show indexes, "auto" = show indexes when a table has "index" column
        show_empty: true # show 'empty list' and 'empty record' placeholders for command output
        padding: { left: 1, right: 1 } # a left right padding of each column in a table
        trim: {
            methodology: wrapping # wrapping or truncating
            wrapping_try_keep_words: true # A strategy used by the 'wrapping' methodology
            truncating_suffix: "..." # A suffix used by the 'truncating' methodology
        }
        header_on_separator: false # show header text on separator/border line
    }

    error_style: "fancy" # "fancy" or "plain" for screen reader-friendly error messages

    # datetime_format determines what a datetime rendered in the shell would look like.
    # Behavior without this configuration point will be to "humanize" the datetime display,
    # showing something like "a day ago."
    datetime_format: {
        # normal: '%a, %d %b %Y %H:%M:%S %z'    # shows up in displays of variables or other datetime's outside of tables
        # table: '%m/%d/%y %I:%M:%S%p'          # generally shows up in tabular outputs such as ls. commenting this out will change it to the default human readable datetime format
    }

    explore: {
        status_bar_background: {fg: "#1E2326", bg: "#D3C6AA"},
        command_bar_text: {fg: "#D3C6AA"},
        highlight: {fg: "black", bg: "yellow"},
        status: {
            error: {fg: "white", bg: "red"},
            warn: {}
            info: {}
        },
        table: {
            split_line: {fg: "#374145"},
            selected_cell: {},
            selected_row: {},
            selected_column: {},
            show_cursor: true,
            line_head_top: true,
            line_head_bottom: true,
            line_shift: true,
            line_index: true,
        },
    }

    history: {
        max_size: 100_000 # Session has to be reloaded for this to take effect
        sync_on_enter: true # Enable to share history between multiple sessions, else you have to close the session to write history to file
        file_format: "plaintext" # "sqlite" or "plaintext"
        isolation: false # only available with sqlite file_format. true enables history isolation, false disables it. true will allow the history to be isolated to the current session using up/down arrows. false will allow the history to be shared across all sessions.
    }

    completions: {
        case_sensitive: false # set to true to enable case-sensitive completions
        quick: true    # set this to false to prevent auto-selecting completions when only one remains
        partial: false    # set this to false to prevent partial filling of the prompt
        algorithm: "prefix"    # prefix or fuzzy
    }

    filesize: {
        unit: metric
    }

    cursor_shape: {
        emacs: blink_block # block, underscore, line, blink_block, blink_underscore, blink_line, inherit to skip setting cursor shape (line is the default)
        vi_insert: line # block, underscore, line, blink_block, blink_underscore, blink_line, inherit to skip setting cursor shape (block is the default)
        vi_normal: block # block, underscore, line, blink_block, blink_underscore, blink_line, inherit to skip setting cursor shape (underscore is the default)
    }

    color_config: $everforest
    footer_mode: "auto" # always, never, number_of_rows, auto
    float_precision: 2 # the precision for displaying floats in tables
    buffer_editor: "nvim" # command that will be used to edit the current line buffer with ctrl+o, if unset fallback to $env.EDITOR and $env.VISUAL
    use_ansi_coloring: auto
    bracketed_paste: true # enable bracketed paste, currently useless on windows
    edit_mode: vi # emacs, vi
    shell_integration: {
        # osc2 abbreviates the path if in the home_dir, sets the tab/window title, shows the running command in the tab/window title
        osc2: true
        # osc7 is a way to communicate the path to the terminal, this is helpful for spawning new tabs in the same directory
        osc7: true
        # osc8 is also implemented as the deprecated setting ls.show_clickable_links, it shows clickable links in ls output if your terminal supports it. show_clickable_links is deprecated in favor of osc8
        osc8: true
        # osc9_9 is from ConEmu and is starting to get wider support. It's similar to osc7 in that it communicates the path to the terminal
        osc9_9: true
        # osc133 is several escapes invented by Final Term which include the supported ones below.
        # 133;A - Mark prompt start
        # 133;B - Mark prompt end
        # 133;C - Mark pre-execution
        # 133;D;exit - Mark execution finished with exit code
        # This is used to enable terminals to know where the prompt is, the command is, where the command finishes, and where the output of the command is
        osc133: true
        # osc633 is closely related to osc133 but only exists in visual studio code (vscode) and supports their shell integration features
        # 633;A - Mark prompt start
        # 633;B - Mark prompt end
        # 633;C - Mark pre-execution
        # 633;D;exit - Mark execution finished with exit code
        # 633;E - NOT IMPLEMENTED - Explicitly set the command line with an optional nonce
        # 633;P;Cwd=<path> - Mark the current working directory and communicate it to the terminal
        # and also helps with the run recent menu in vscode
        osc633: true
        # reset_application_mode is escape \x1b[?1l and was added to help ssh work better
        reset_application_mode: true
    }
    render_right_prompt_on_last_line: true # true or false to enable or disable right prompt to be rendered on last line of the prompt.

    hooks: {
        pre_prompt: [{ null }] # run before the prompt is shown
        pre_execution: [{ null }] # run before the repl input is run
        env_change: {
          # run if the PWD environment is different since the last repl input
          PWD: [
              # Enable Windows Terminal detect cwd to do "duplicate tab/pane"
              # https://github.com/nushell/nushell/issues/10166
              # {|before, after| print -n $"(ansi -o '9;9;')($after)(ansi "st")" }
            ] 
        }
        display_output: "if (term size).columns >= 100 { table -e } else { table }" # run to display the output of a pipeline
        command_not_found: { null } # return an error message when a command is not found
    }

    menus: [
        # Configuration for default nushell menus
        # Note the lack of source parameter
        {
            name: completion_menu
            only_buffer_difference: false
            marker: "| "
            type: {
                layout: columnar
                columns: 4
                col_width: 20     # Optional value. If missing all the screen width is used to calculate column width
                col_padding: 2
            }
            style: {
                text: green
                selected_text: green_reverse
                description_text: yellow
            }
        }
        {
            name: history_menu
            only_buffer_difference: true
            marker: "? "
            type: {
                layout: list
                page_size: 10
            }
            style: {
                text: green
                selected_text: green_reverse
                description_text: yellow
            }
        }
        {
            name: help_menu
            only_buffer_difference: true
            marker: "? "
            type: {
                layout: description
                columns: 4
                col_width: 20     # Optional value. If missing all the screen width is used to calculate column width
                col_padding: 2
                selection_rows: 4
                description_rows: 10
            }
            style: {
                text: green
                selected_text: green_reverse
                description_text: yellow
            }
        }
    ]

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
            name: claude
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
            cmd: "history | skip 1 | last | get command | clip"
          }
        }
        {
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
          name: change_dir_with_fzf_from_home_dir
          modifier: control
          keycode: char_g
          mode: [vi_normal vi_insert]
          event: {
            send: executehostcommand,
            cmd: "cd (fd -t d . ($env.HOME? | default $env.USERPROFILE?) | fzf | decode utf-8 | str trim)"
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
        {
            name: completion_menu
            modifier: none
            keycode: tab
            mode: [emacs vi_normal vi_insert]
            event: {
                until: [
                    { send: menu name: completion_menu }
                    { send: menunext }
                    { edit: complete }
                ]
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
            name: help_menu
            modifier: none
            keycode: f1
            mode: [emacs, vi_insert, vi_normal]
            event: { send: menu name: help_menu }
        }
        {
            name: completion_previous_menu
            modifier: shift
            keycode: backtab
            mode: [emacs, vi_normal, vi_insert]
            event: { send: menuprevious }
        }
        {
            name: next_page_menu
            modifier: control
            keycode: char_x
            mode: emacs
            event: { send: menupagenext }
        }
        {
            name: undo_or_previous_page_menu
            modifier: control
            keycode: char_z
            mode: emacs
            event: {
                until: [
                    { send: menupageprevious }
                    { edit: undo }
                ]
            }
        }
        {
            name: escape
            modifier: none
            keycode: escape
            mode: [emacs, vi_normal, vi_insert]
            event: { send: esc }    # NOTE: does not appear to work
        }
        {
            name: cancel_command
            modifier: control
            keycode: char_c
            mode: [emacs, vi_normal, vi_insert]
            event: { send: ctrlc }
        }
        {
            name: quit_shell
            modifier: control
            keycode: char_d
            mode: [emacs, vi_normal, vi_insert]
            event: { send: ctrld }
        }
        {
            name: clear_screen
            modifier: control
            keycode: char_l
            mode: [emacs, vi_normal, vi_insert]
            event: { send: clearscreen }
        }
        {
            name: search_history
            modifier: control
            keycode: char_q
            mode: [emacs, vi_normal, vi_insert]
            event: { send: searchhistory }
        }
        {
            name: open_command_editor
            modifier: control
            keycode: char_o
            mode: [emacs, vi_normal, vi_insert]
            event: { send: openeditor }
        }
        {
            name: move_up
            modifier: none
            keycode: up
            mode: [emacs, vi_normal, vi_insert]
            event: {
                until: [
                    {send: menuup}
                    {send: up}
                ]
            }
        }
        {
            name: move_down
            modifier: none
            keycode: down
            mode: [emacs, vi_normal, vi_insert]
            event: {
                until: [
                    {send: menudown}
                    {send: down}
                ]
            }
        }
        {
            name: move_left
            modifier: none
            keycode: left
            mode: [emacs, vi_normal, vi_insert]
            event: {
                until: [
                    {send: menuleft}
                    {send: left}
                ]
            }
        }
        {
            name: move_right_or_take_history_hint
            modifier: none
            keycode: right
            mode: [emacs, vi_normal, vi_insert]
            event: {
                until: [
                    {send: historyhintcomplete}
                    {send: menuright}
                    {send: right}
                ]
            }
        }
        {
            name: move_one_word_left
            modifier: control
            keycode: left
            mode: [emacs, vi_normal, vi_insert]
            event: {edit: movewordleft}
        }
        {
            name: move_one_word_right_or_take_history_hint
            modifier: control
            keycode: right
            mode: [emacs, vi_normal, vi_insert]
            event: {
                until: [
                    {send: historyhintwordcomplete}
                    {edit: movewordright}
                ]
            }
        }
        {
            name: move_to_line_start
            modifier: none
            keycode: home
            mode: [emacs, vi_normal, vi_insert]
            event: {edit: movetolinestart}
        }
        {
            name: move_to_line_start
            modifier: control
            keycode: char_a
            mode: [emacs, vi_normal, vi_insert]
            event: {edit: movetolinestart}
        }
        {
            name: move_to_line_end_or_take_history_hint
            modifier: none
            keycode: end
            mode: [emacs, vi_normal, vi_insert]
            event: {
                until: [
                    {send: historyhintcomplete}
                    {edit: movetolineend}
                ]
            }
        }
        {
            name: move_to_line_end_or_take_history_hint
            modifier: control
            keycode: char_e
            mode: [emacs, vi_normal, vi_insert]
            event: {
                until: [
                    {send: historyhintcomplete}
                    {edit: movetolineend}
                ]
            }
        }
        {
            name: move_to_line_start
            modifier: control
            keycode: home
            mode: [emacs, vi_normal, vi_insert]
            event: {edit: movetolinestart}
        }
        {
            name: move_to_line_end
            modifier: control
            keycode: end
            mode: [emacs, vi_normal, vi_insert]
            event: {edit: movetolineend}
        }
        {
            name: move_up
            modifier: control
            keycode: char_p
            mode: [emacs, vi_normal, vi_insert]
            event: {
                until: [
                    {send: menuup}
                    {send: up}
                ]
            }
        }
        # {
        #     name: move_down
        #     modifier: control
        #     keycode: char_t
        #     mode: [emacs, vi_normal, vi_insert]
        #     event: {
        #         until: [
        #             {send: menudown}
        #             {send: down}
        #         ]
        #     }
        # }
        {
            name: delete_one_character_backward
            modifier: none
            keycode: backspace
            mode: [emacs, vi_insert]
            event: {edit: backspace}
        }
        {
            name: delete_one_word_backward
            modifier: control
            keycode: backspace
            mode: [emacs, vi_insert]
            event: {edit: backspaceword}
        }
        {
            name: delete_one_character_forward
            modifier: none
            keycode: delete
            mode: [emacs, vi_insert]
            event: {edit: delete}
        }
        {
            name: delete_one_character_forward
            modifier: control
            keycode: delete
            mode: [emacs, vi_insert]
            event: {edit: delete}
        }
        {
            name: delete_one_character_forward
            modifier: control
            keycode: char_h
            mode: [emacs, vi_insert]
            event: {edit: backspace}
        }
        {
            name: delete_one_word_backward
            modifier: control
            keycode: char_w
            mode: [emacs, vi_insert]
            event: {edit: backspaceword}
        }
        {
            name: move_left
            modifier: none
            keycode: backspace
            mode: vi_normal
            event: {edit: moveleft}
        }
        {
            name: newline_or_run_command
            modifier: none
            keycode: enter
            mode: emacs
            event: {send: enter}
        }
        {
            name: move_left
            modifier: control
            keycode: char_b
            mode: emacs
            event: {
                until: [
                    {send: menuleft}
                    {send: left}
                ]
            }
        }
        {
            name: move_right_or_take_history_hint
            modifier: control
            keycode: char_f
            mode: emacs
            event: {
                until: [
                    {send: historyhintcomplete}
                    {send: menuright}
                    {send: right}
                ]
            }
        }
        {
            name: redo_change
            modifier: control
            keycode: char_g
            mode: emacs
            event: {edit: redo}
        }
        {
            name: undo_change
            modifier: control
            keycode: char_z
            mode: emacs
            event: {edit: undo}
        }
        {
            name: paste_before
            modifier: control
            keycode: char_y
            mode: emacs
            event: {edit: pastecutbufferbefore}
        }
        {
            name: cut_word_left
            modifier: control
            keycode: char_w
            mode: emacs
            event: {edit: cutwordleft}
        }
        {
            name: cut_line_to_end
            modifier: control
            keycode: char_k
            mode: emacs
            event: {edit: cuttoend}
        }
        {
            name: cut_line_from_start
            modifier: control
            keycode: char_u
            mode: emacs
            event: {edit: cutfromstart}
        }
        # {
        #     name: swap_graphemes
        #     modifier: control
        #     keycode: char_t
        #     mode: emacs
        #     event: {edit: swapgraphemes}
        # }
        {
            name: move_one_word_left
            modifier: alt
            keycode: left
            mode: emacs
            event: {edit: movewordleft}
        }
        {
            name: move_one_word_right_or_take_history_hint
            modifier: alt
            keycode: right
            mode: emacs
            event: {
                until: [
                    {send: historyhintwordcomplete}
                    {edit: movewordright}
                ]
            }
        }
        {
            name: move_one_word_left
            modifier: alt
            keycode: char_b
            mode: emacs
            event: {edit: movewordleft}
        }
        {
            name: move_one_word_right_or_take_history_hint
            modifier: alt
            keycode: char_f
            mode: emacs
            event: {
                until: [
                    {send: historyhintwordcomplete}
                    {edit: movewordright}
                ]
            }
        }
        {
            name: delete_one_word_forward
            modifier: alt
            keycode: delete
            mode: emacs
            event: {edit: deleteword}
        }
        {
            name: delete_one_word_backward
            modifier: alt
            keycode: backspace
            mode: emacs
            event: {edit: backspaceword}
        }
        {
            name: delete_one_word_backward
            modifier: alt
            keycode: char_m
            mode: emacs
            event: {edit: backspaceword}
        }
        {
            name: cut_word_to_right
            modifier: alt
            keycode: char_d
            mode: emacs
            event: {edit: cutwordright}
        }
        {
            name: upper_case_word
            modifier: alt
            keycode: char_u
            mode: emacs
            event: {edit: uppercaseword}
        }
        {
            name: lower_case_word
            modifier: alt
            keycode: char_l
            mode: emacs
            event: {edit: lowercaseword}
        }
        {
            name: capitalize_char
            modifier: alt
            keycode: char_c
            mode: emacs
            event: {edit: capitalizechar}
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
source install/cmds/komorebi_mac.nu
use jj/cmds.nu *
use jj/completions.nu *
use misc/wt-layout.nu *
use misc/tmux-start.nu
