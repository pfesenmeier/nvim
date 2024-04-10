if ($nu.os-info.family == 'windows') {
  winget install fzf
} else {
   brew install fzf
   ^$"(brew --prefix)/opt/fzf/install"
}
