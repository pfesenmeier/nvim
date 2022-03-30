TOOLS="bat mdcat ripgrep exa cargo-outdated cargo-edit fd-find"

cargo install $TOOLS

cargo install jless --version "0.7.0"
cargo install starship --locked

# for rust analyzer
# https://rust-analyzer.github.io/manual.html#installation
rustup component add rust-src
