if $nu.os-info.family == 'windows' {
  winget install sharkdp.fd
} else {
  sudo apt install fd-find
}
