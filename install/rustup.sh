# https://stackoverflow.com/questions/52445961/how-do-i-fix-the-rust-error-linker-cc-not-found-for-debian-on-windows-10
sudo apt install build-essential
# not sure why these are here, given above link
# sudo apt install lld
# sudo apt install pkg-config
# sudo apt install libssl-dev

# https://www.rust-lang.org/learn/get-started
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# this is in original cargo instructions, but I am using mold linker.
# see cargo_config.toml
#
# mkdir -p ~/.cargo
# echo '[target.x86_64-unknown-linux-gnu]
# rustflags = [
#    "-C", "link-arg=-fuse-ld=lld",
# ]' > ~/.cargo/config

