$packages = $(
'Axosoft.GitKraken'
'BurntSushi.ripgrep.MSVC'
'CoreyButler.NVMforWindows'
'GitHub.cli'
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
  winget install --no-upgrade $PSItem
  Write-Host
}

Get-Command sed || winget install git.git --interactive --force

if (Get-Command choco) {
  Write-Host "Run from Elevated Prompt:"
  Write-Host
  Write-Host "choco install difftastic" 
} else {
  Start-Process "https://chocolatey.org/install#individual"
}