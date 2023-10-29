$packages = $(
'Microsoft.PowerShell'
'Microsoft.Teams'
'Microsoft.WindowsTerminal'
'SlackTechnologies.Slack'
'devtoys'
'gerardog.gsudo'
)

$packages | ForEach-Object { 
  Write-Host $PSItem -ForegroundColor Green
  winget install --no-upgrade $PSItem
  Write-Host
}

Get-Command sed || winget install git.git --interactive --force

# run wsl --update to install it for docker
