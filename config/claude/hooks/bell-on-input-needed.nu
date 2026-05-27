# Ring terminal bell when Claude needs user input or finishes working.
# Registered on: Notification (permission_prompt), Stop

def main [] {
    let input = $in | from json
    let event = $input | get -o hook_event_name | default "unknown"

    let should_ring = match $event {
        "Notification" => true,
        "Stop" => true,
        _ => false,
    }

    if $should_ring {
        # The hook subprocess may be detached from /dev/tty (macOS spawns it
        # in a new session). When running under tmux, $TMUX_PANE is still
        # inherited — resolve it to the pane's PTY path and write BEL there
        # so tmux registers the bell event (shows `(!)` in the status line).
        let tty = if "TMUX_PANE" in $env {
            ^tmux display-message -p -t $env.TMUX_PANE "#{pane_tty}" | str trim
        } else {
            "/dev/tty"
        }
        (char bel) | save --raw --force $tty
    }
}
