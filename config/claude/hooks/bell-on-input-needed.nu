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
        # /dev/tty isn't reliable here: on macOS the hook is setsid'd so it
        # ENXIOs, and on either OS, if Claude is running inside nvim's
        # :terminal, /dev/tty resolves to nvim's PTY and the bell never
        # reaches the outer terminal. Walk up the process tree and write
        # the BEL to the *outermost* real TTY (the actual terminal app).
        mut pid = $nu.pid
        mut outer = ""
        for _ in 0..15 {
            let ppid_str = (^ps -o ppid= -p $pid | str trim)
            if ($ppid_str | is-empty) { break }
            let ppid = ($ppid_str | into int)
            if $ppid <= 1 { break }
            let name = (^ps -o tty= -p $ppid | str trim)
            if $name != "??" and $name != "?" and ($name | str length) > 0 {
                $outer = $name
            }
            $pid = $ppid
        }
        if ($outer | is-not-empty) {
            (char bel) | save --raw --force $"/dev/($outer)"
        }
    }

    # When running inside an nvim :terminal, surface the same signal in the
    # parent nvim's mini.notify pane via the `nv` bridge.
    let notify = match $event {
        "Notification" => { message: "Claude needs input", level: "warn" },
        "Stop"         => { message: "Claude stopped",     level: "info" },
        _              => null,
    }
    if $notify != null and not ($env.NVIM? | is-empty) {
        # Use the absolute path: Claude's hook may not inherit ~/.local/bin on PATH.
        let nv = ($env.HOME | path join ".local/bin/nv")
        try { ^$nv notify $notify.message --level $notify.level | ignore }
    }
}
