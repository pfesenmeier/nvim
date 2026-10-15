# Sets up gpg on a fresh linux machine so git can sign commits and
# git-credential-manager can use its gpg credential store.
#
# Before running:
#   1. install packages (pinentry-gnome3, dbus-x11, pass come from apt)
#        install packages   (from a nushell session, config.nu loads it)
#   2. run setup.nu, which links config/gpg-agent.conf to ~/.gnupg/gpg-agent.conf
#   3. export your secret key on the old machine
#        gpg --export-secret-keys --armor <keyid> > key.asc
#      and copy key.asc over. delete it from both machines when done.
#
# Usage:
#   nu ~/nvim/scripts/gpg_setup.nu --import key.asc
#   nu ~/nvim/scripts/gpg_setup.nu             # key is already imported
use std/log

const pinentry = '/usr/bin/pinentry-gnome3'

def check-deps [] {
  let missing = [
    [path              package];
    [$pinentry         pinentry-gnome3]
    [/usr/bin/dbus-launch dbus-x11]
  ] | where not ($it.path | path exists) | get package

  if ($missing | is-not-empty) {
    error make { msg: $"missing packages. install with: sudo apt install ($missing | str join ' ')" }
  }

  let agent_conf = $nu.home-dir | path join .gnupg gpg-agent.conf
  if not ($agent_conf | path exists) {
    error make { msg: $"($agent_conf) not found. run setup.nu first" }
  }

  if not (open $agent_conf | str contains $pinentry) {
    log warning $"($agent_conf) does not use ($pinentry)"
  }
}

# lists secret keys as {fingerprint, uid}
def secret-keys [] {
  let rows = ^gpg --list-secret-keys --with-colons | lines | each { split row ':' }

  $rows | enumerate | where ($it.item | first) == 'sec' | each {|key|
    let rest = $rows | skip ($key.index + 1)
    {
      fingerprint: ($rest | where ($it | first) == 'fpr' | first | get 9)
      uid: ($rest | where ($it | first) == 'uid' | first | get 9)
    }
  }
}

def pick-key [] {
  let keys = secret-keys

  if ($keys | is-empty) {
    error make { msg: "no secret keys found. rerun with --import <file>" }
  }

  if ($keys | length) == 1 {
    $keys | first
  } else {
    $keys | input list --display uid "pick the key to use for git"
  }
}

def main [
  --import: path # armored secret key file to import first
] {
  if $nu.os-info.name != 'linux' {
    error make { msg: "this script is for linux. on windows use gpg4win, on mac see config/gpg-agent.conf.mac" }
  }

  check-deps

  # gpg refuses to use a home dir others can read
  let gnupg = $nu.home-dir | path join .gnupg
  ^chmod 700 $gnupg

  # pick up the current gpg-agent.conf
  ^gpgconf --kill gpg-agent

  if $import != null {
    log info $"importing ($import). pinentry will ask for the key's passphrase"
    ^gpg --import $import
  }

  let key = pick-key
  log info $"using ($key.uid) ($key.fingerprint)"

  # imported keys start untrusted, which makes pass refuse to encrypt to them
  $"($key.fingerprint):6:\n" | ^gpg --import-ownertrust

  ^git config --global user.signingkey $key.fingerprint
  log info "set git user.signingkey"

  let gpg_id = $nu.home-dir | path join .password-store .gpg-id
  if (which pass | is-empty) {
    log warning "pass is not installed. git-credential-manager's gpg store will not work"
  } else if ($gpg_id | path exists) {
    log info "password store already initialized"
  } else {
    ^pass init $key.fingerprint
  }

  log info "test signing. a passphrase window should open"
  "test" | ^gpg --clearsign | ignore
  log info "gpg is set up. commits are signed with: git commit -S (or set commit.gpgsign true)"
}
