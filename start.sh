#! /usr/bin/env bash

# curl -s https://raw.githubusercontent.com/pfesenmeier/nvim/main/start.sh | bash

# install brew if not installed - see docs
# https://docs.brew.sh/Homebrew-on-Linux#install
if command -v brew &> /dev/null; then
    echo "brew already installed."
else
  echo "This script needs administrator priviledges to install brew prerequisites:"
  packages="build-essential procps curl file git"
  echo "$packages"
  sudo apt update && sudo apt install -y $packages
  test -d ~/.linuxbrew && eval "$(~/.linuxbrew/bin/brew shellenv)"
  test -d /home/linuxbrew/.linuxbrew && eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
  echo "eval \"\$($(brew --prefix)/bin/brew shellenv)\"" >> ~/.bashrc
fi

if [ -d "$HOME/nvim" ]; then
    echo "~/nvim folder already exists"
else
    cd "$HOME"
    git clone https://github.com/pfesenmeier/nvim
fi
