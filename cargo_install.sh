TOOLS="bat mdcat ripgrep exa cargo-outdated cargo-edit fd-find cargo-tarpaulin cargo-expand"

cargo install $TOOLS

cargo install jless --version "0.7.0"
cargo install starship --locked
# todo - look at cli tool
# cargo install navi --locked

# for rust analyzer
# https://rust-analyzer.github.io/manual.html#installation
rustup component add rust-src
