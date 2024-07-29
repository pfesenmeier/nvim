if $nu.os-info.family == 'windows' {
  winget install sharkdp.fd
} else if $nu.os-info.name == 'linux' {
  sudo apt install fd-find
  let fd = which fdfind | first | get path
  ln -s $fd ~/.local/bin/fd
}
