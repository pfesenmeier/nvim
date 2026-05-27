# Picks an Everforest accent based on the current session name and applies
# it to the status bar. Invoked from tmux hooks (session-created and
# client-session-changed) so each session gets its own consistent color
# without leaving the Everforest palette.

const PALETTE = [
  "#A7C080"  # green
  "#83C092"  # aqua
  "#7FBBB3"  # blue
  "#DBBC7F"  # yellow
  "#E69875"  # orange
  "#E67E80"  # red
  "#D699B6"  # purple
]

export def main [] {
  let session = (^tmux display-message -p "#S" | str trim)
  let hex = ($session | hash sha256 | str substring 0..<2)
  let idx = (($hex | into int --radix 16) mod ($PALETTE | length))
  let color = ($PALETTE | get $idx)
  ^tmux set status-style $"fg=#2D353B,bg=($color)"
}
