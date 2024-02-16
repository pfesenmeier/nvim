# run once to setup expected symlinks

$null = New-Item -ItemType SymbolicLink -Path $PROFILE -Value $home\nvim\windows\profile.ps1 -Force
$null = New-Item -Type Directory -Force $home\AppData\Local\nvim
$null = New-Item -ItemType SymbolicLink -Path $home\AppData\Local\nvim\init.lua -Value $home\nvim\init.lua -Force
$null = New-Item -ItemType SymbolicLink -Path $home\AppData\Local\nvim\ginit.vim -Value $home\nvim\ginit.vim -Force
$null = New-Item -ItemType SymbolicLink -Path $home\AppData\Local\nvim\lua -Value $home\nvim\lua -Force
$null = New-Item -ItemType SymbolicLink -Path $home\.ideavimrc -Value $home\nvim\windows\dotideavimrc -Force
# $null = New-Item -ItemType SymbolicLink -Path $home\.rgignore -Value $home\nvim\windows\.rgignore -Force

if (!(Test-Path $home\.config)) {
  New-Item -Path $home\.config -ItemType Directory
}
$null = New-Item -ItemType SymbolicLink -Path $home\.config\starship.toml -Value $home\nvim\starship.toml

# add .SH extension to PATHEXT system environment variable
# associate .sh files with \Program Files\Git\bin\sh.exe

Install-Module CompletionPredictor
