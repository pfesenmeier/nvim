let servers = [
    dockerfile-language-server-nodejs
    graphql-language-service-cli
    typescript
    typescript-language-server
    @vue/language-server
    @prisma/language-server
    vscode-langservers-extracted # css, eslint, html 
    @tailwindcss/language-server
]

npm install -g ...$servers
