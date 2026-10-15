#!/usr/bin/env bash

set -o errexit
set -o xtrace
set -o nounset
set -o pipefail

# installs brew, nushell, node, and neovim, and this repository

BREW=/home/linuxbrew/.linuxbrew/bin/brew

if command -v brew &> /dev/null; then
  echo "brew already installed."
  BREW="$(command -v brew)"
elif [ -x "$BREW" ]; then
  echo "brew installed but not on PATH; loading it."
else
  echo "This script needs administrator privileges to install brew prerequisites:"
  packages=(build-essential procps curl file git)
  echo "${packages[@]}"
  sudo apt update && sudo apt install -y "${packages[@]}"
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Make brew usable for the rest of this script
eval "$("$BREW" shellenv)"
# Persist brew on PATH for future bash shells
BREW_LINE='eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"'
if ! grep -qF "$BREW_LINE" "$HOME/.bashrc"; then
  echo "$BREW_LINE" >> "$HOME/.bashrc"
fi
brew --version

brew install neovim nushell pnpm

# pnpm global installs need PNPM_HOME/bin on PATH
export PNPM_HOME="${PNPM_HOME:-$HOME/.local/share/pnpm}"
export PATH="$PNPM_HOME/bin:$PATH"
mkdir -p "$PNPM_HOME/bin"

pnpm runtime set node lts -g

if [ -d "$HOME/nvim" ]; then
  echo "$HOME/nvim folder already exists"
else
  git clone https://github.com/pfesenmeier/nvim "$HOME/nvim"
fi

echo "if running in wsl, add this to your startup command:  --shell-type standard --exec /home/linuxbrew/.linuxbrew/bin/nu"
