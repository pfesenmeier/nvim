# Ring terminal bell when Claude needs user input or finishes working.
# Registered on: Notification (permission_prompt), Stop

def main [] {
    let input = $in | from json
    let event = $input | get -o hook_event_name | default "unknown"

    let should_ring = match $event {
        "Notification" => true,
        "Stop" => {
            $input
            | get -o last_assistant_message
            | default ""
            | str trim
            | str ends-with "?"
        },
        _ => false,
    }

    if $should_ring {
        (char bel) | save --raw --force /dev/tty
    }
}
