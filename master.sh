# master script to install fish, terminal profile, nvim
# inside an Ubuntu WSL2 Environment

# does not include
# - installing language servers

chmod -R u+rx ~/nvim/install/

cd ~

# configure git
./nvim/ubuntu/git.sh

# install wsl utilities (nice to be able to launch web browser when authenticating with gh)
./nvim/ubuntu/wsl.sh

INSTALL=./nvim/install

# github utility. preferred git auth method (gh auth login)
$INSTALL/gh.sh

# install things to be aliased in init.fish
$INSTALL/exa.sh # ls
$INSTALL/bat.sh # cat
$INSTALL/neovim.sh # e

# install prompt invoked in init.fish
$INSTALL/starship.sh

# install fish
$INSTALL/fish.sh

# create symlinks, install neovim packages
./nvim/start.sh

echo "Done. Few more steps..."
echo "1. Copy terminal.json into Windows Terminal's JSON config"
echo "2. Install a nerder font that handles starship prompt's ligatures"

