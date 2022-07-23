#! /usr/bin/env bash

PWD=$(pwd)

NVIM=$HOME/nvim

LUA_LSP_FOLDER=$NVIM/lua-language-server

mkdir -p $LUA_LSP_FOLDER
cd $LUA_LSP_FOLDER

curl -L https://github.com/sumneko/lua-language-server/releases/latest/download/lua-language-server-3.5.0-linux-x64.tar.gz | tar -xzf -

BINARY=~/.local/bin/lua-language-server
ln -sf $NVIM/lua_lsp_wrapper $BINARY

sudo chmod u+x $BINARY

cd $PWD
