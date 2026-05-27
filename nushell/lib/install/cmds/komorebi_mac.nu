# TODO support macos-only software
def "install komorebi-for-mac" [] {
  if $nu.os-info.name != 'macos' {
    print "requires macos"
    exit 1
  }
  brew tap lgug2z/tap
  brew install lgug2z/tap/komorebi-for-mac
  # https://github.com/asmvik/skhd
  brew install asmvik/formulae/skhd
}
