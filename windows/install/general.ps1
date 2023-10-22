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

if (Get-Command choco) {
  Write-Host "Run from Elevated Prompt:"
  Write-Host
  Write-Host "choco install difftastic" 
} else {
  Write-Host "Need Chocolatey to install difftastic"
  Start-Process "https://chocolatey.org/install#individual"
}

# run wsl --update to install it for docker
