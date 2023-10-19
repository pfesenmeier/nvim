#! /usr/bin/env bash

$PWD=$(pwd)

$LSP_FOLDER='\Program Files\omnisharp\bin'
$ZIP = "$LSP_FOLDER\omni.zip"
mkdir -p $LSP_FOLDER

curl -L https://github.com/OmniSharp/omnisharp-roslyn/releases/latest/download/omnisharp-win-x64-net6.0.zip --output $ZIP

unzip $ZIP -d $LSP_FOLDER
rm $ZIP

