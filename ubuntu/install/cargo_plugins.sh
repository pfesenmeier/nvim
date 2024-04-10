#! /usr/bin/env bash

TOOLS="cargo-outdated cargo-edit cargo-tarpaulin cargo-expand"

cargo install $TOOLS
rustup target add wasm32-unknown-unknown
