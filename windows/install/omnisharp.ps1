#! /usr/bin/env bash

$PWD=$(pwd)

$LSP_FOLDER='\Program Files\omnisharp\bin'
mkdir -p $LSP_FOLDER
cd $LSP_FOLDER

curl -L https://github.com/OmniSharp/omnisharp-roslyn/releases/latest/download/omnisharp-win-x64-net6.0.zip --output omni.zip

unzip omni.zip
rm omni.zip

cd -
