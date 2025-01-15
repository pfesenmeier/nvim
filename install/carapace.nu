if $nu.os-info.family == 'windows' {
  scoop bucket add extras
  scoop install extras/carapace-bin
} else {
  brew install carapace
} 



