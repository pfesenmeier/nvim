$packages = $(
# 'Axosoft.GitKraken'
'BurntSushi.ripgrep.MSVC'
'CoreyButler.NVMforWindows'
'Docker.DockerDesktop'
'eza-community.eza'
'GitHub.cli'
'Hashicorp.Terraform'
'JetBrains.Toolbox'
'Neovim.Neovim'
'Microsoft.AzureCLI'
'Microsoft.PowerShell'
'Microsoft.VisualStudioCode'
'Microsoft.Teams'
'Microsoft.WindowsTerminal'
'Obsidian.Obsidian'
'Orange-OpenSource.Hurl'
# 'Pulumi.Pulumi'
'Python.Python.3.11'
'SlackTechnologies.Slack'
'Starship.Starship'
'Zoom.Zoom'
'devtoys'
'jqlang.jq'
'junegunn.fzf'
'gerardog.gsudo'
'rsteube.Carapace'
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

# run wsl --update to install it for docker
