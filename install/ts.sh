#! /usr/bin/env bash

# https://github.com/typescript-language-server/typescript-language-server
npm install -g typescript-language-server typescript vscode-langservers-extracted @tailwindcss/language-server yarn

# requires node 16.1 or above
# https://yarnpkg.com/getting-started/install
corepack enable
yarn global add yaml-language-server


