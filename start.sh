#! /usr/bin/env bash

set -o errexit
set -o xtrace
set -o nounset
set -o pipefail

# installs brew, nushell, node, and neovim, and this repository

# curl -s https://raw.githubusercontent.com/pfesenmeier/nvim/main/start.sh | bash

if command -v brew &> /dev/null; then
    echo "brew already installed."
else
  echo "This script needs administrator priviledges to install brew prerequisites:"
  packages="build-essential procps curl file git"
  echo "$packages"
  sudo apt update && sudo apt install -y $packages

  echo "Running homebrew install script"
  curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh
fi

brew install neovim nushell fnm
fnm use --install-if-missing --log-level quiet lts-latest 

if [ -d "$HOME/nvim" ]; then
    echo "~/nvim folder already exists"
else
    cd "$HOME"
    git clone https://github.com/pfesenmeier/nvim
fi

nu -n ~/nvim/setup.nu
nu -c 'nvim --headless  "+Lazy! sync"  +qa'
nu -c 'nvim --headless  +TSUpdateSync  +qa'
nu -c "nvim --headless  +ToolsInstall! +qa"
