if $nu.os-info.family == 'windows' {
  scoop bucket add extras
  scoop install extras/carapace-bin
} else {
  brew tap rsteube/homebrew-tap
  brew install rsteube/tap/carapace
} 



