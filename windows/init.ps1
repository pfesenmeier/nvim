# run once to setup expected symlinks

$null = New-Item -ItemType SymbolicLink -Path $PROFILE -Value $home\nvim\windows\profile.ps1 -Force
$null = New-Item -Type Directory -Force $home\AppData\Local\nvim
$null = New-Item -ItemType SymbolicLink -Path $home\AppData\Local\nvim\init.lua -Value $home\nvim\init.lua -Force
$null = New-Item -ItemType SymbolicLink -Path $home\a\Local\nvim\lua -Value $home\nvim\lua -Force
$null = New-Item -ItemType SymbolicLink -Path $home\.rgignore -Value $home\nvim\windows\.rgignore -Force
