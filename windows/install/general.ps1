$packages = $(
'Axosoft.GitKraken'
'BurntSushi.ripgrep.MSVC'
'CoreyButler.NVMforWindows'
'Neovim.Neovim'
'Microsoft.PowerShell'
'Microsoft.VisualStudioCode'
'Microsoft.Teams'
'Microsoft.WindowsTerminal'
'Obsidian.Obsidian'
'Orange-OpenSource.Hurl'
'Python.Python.3.11'
'SlackTechnologies.Slack'
'Starship.Starship'
'Zoom.Zoom'
'devtoys'
'jqlang.jq'
'sharkdp.bat'
'sharkdp.fd'
'zig.zig'
)

$packages | ForEach-Object { 
  Write-Host $PSItem -ForegroundColor Green
  winget install $PSItem 
  Write-Host
}

Get-Command sed || winget install git.git --interactive --force
