#! /usr/bin/env bash

PWD=$(pwd)

NVIM=$HOME/nvim

LUA_LSP_FOLDER=$NVIM/lua-language-server

mkdir -p $LUA_LSP_FOLDER
cd $LUA_LSP_FOLDER

curl -L "https://github.com/LuaLS/lua-language-server/releases/download/3.6.11/lua-language-server-3.6.11-linux-x64.tar.gz" | tar -xzf -

BINARY=~/.local/bin/lua-language-server
ln -sf $NVIM/lua_lsp_wrapper $BINARY

sudo chmod u+x $BINARY

cd $PWD
