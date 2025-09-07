#! /usr/bin/env bash

set -o errexit

# installs brew, nushell, and neovim, and this repository

# curl -s https://raw.githubusercontent.com/pfesenmeier/nvim/main/start.sh | bash

if command -v brew &> /dev/null; then
    echo "brew already installed."
else
  echo "This script needs administrator priviledges to install brew prerequisites:"
  packages="build-essential procps curl file git"
  echo "$packages"
  sudo apt update && sudo apt install -y $packages

  echo "Running homebrew install script"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  test -d ~/.linuxbrew && eval "$(~/.linuxbrew/bin/brew shellenv)"
  test -d /home/linuxbrew/.linuxbrew && eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
  echo "eval \"\$($(brew --prefix)/bin/brew shellenv)\"" >> ~/.bashrc
fi

brew install neovim nushell

if [ -d "$HOME/nvim" ]; then
    echo "~/nvim folder already exists"
else
    cd "$HOME"
    git clone https://github.com/pfesenmeier/nvim
fi

nu ~/nvim/setup.nu
nvim +ToolsInstall


