# komorebic helpers

# (re)start komorebic, bar, hotkey daemon
export def start [] {
  match $nu.os-info.name {
    "macos" => {
      komorebic stop  --bar
      komorebic start --bar

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
