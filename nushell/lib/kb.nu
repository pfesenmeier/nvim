# komorebic helpers

# (re)start komorebic, bar, hotkey daemon
export def start [] {
  match $nu.os-info.name {
    "macos" => {
      # skipping bar... conflicts 
      komorebic stop
      komorebic start

      if (ps | where name =~ skhd | is-not-empty) {
        skhd --stop-service
      }

      skhd --start-service
    },
    # windows or wsl with PATH interop
    _ => {
      komorebic.exe start --whkd --bar
    }
  }
}
