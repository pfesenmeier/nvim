#! /usr/bin/env bash

wget https://dystroy.org/broot/download/x86_64-linux/broot
sudo mv -f broot /usr/local/bin/
chmod u+x /usr/local/bin/broot

# TODO download completions
wget https://dystroy.org/broot/download/completion/br.fish
mv -f br.fish ~/.config/fish/completions/

