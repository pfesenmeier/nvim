#! /usr/bin/env bash

set -o errexit

wget https://github.com/ryankurte/cargo-binstall/releases/latest/download/cargo-binstall-x86_64-unknown-linux-musl.tgz

tar -xvzf cargo-binstall-x86_64-unknown-linux-musl.tgz

mkdir -p $HOME/.cargo/bin/
mv cargo-binstall $HOME/.cargo/bin/
rm cargo-binstall-x86_64-unknown-linux-musl.tgz

