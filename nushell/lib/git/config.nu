git config --global core.editor "nvim"
git config --global user.name "Paul Fesenmeier"
# git config --global user.email pbfesenmeier@sep.com
git config --global user.email pfesenmeier@gmail.com
git config --global diff.external difft
git config --global push.autoSetupRemote true

# register git-credential-manager as the credential helper (github and azure devops)
git-credential-manager configure
# also set in env.nu, but git launched outside nushell needs it here
git config --global credential.credentialStore gpg
# azure devops sign in under wsl: gcm 3 tries the linux sign in broker, which isn't installed,
# and exits silently
if $nu.os-info.name == 'linux' {
  git config --global credential.msauthUseBroker false
}

git config --global commit.gpgsign false
git config --global gpg.program gpg

# user.signingkey is set by scripts/gpg_setup.nu

git config --global alias.chcekout checkout
git config --global alias.checkoud checkout
git config --global alias.comit commit
git config --global alias.committ commit

git config --global diff.external difft
git config --global push.autoSetupRemote true
