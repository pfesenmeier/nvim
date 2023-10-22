#! /usr/bin/env bash

PWD=$(pwd)

LSP_FOLDER=~/.local/bin/omnisharp
mkdir -p $LSP_FOLDER
cd $LSP_FOLDER

curl -L https://github.com/OmniSharp/omnisharp-roslyn/releases/latest/download/omnisharp-linux-musl-x64-net6.0.tar.gz | tar -xzf -

cd -
