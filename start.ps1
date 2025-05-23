# Invoke-RestMethod -Uri https://raw.githubusercontent.com/pfesenmeier/nvim/main/start.ps1

if (Get-Command scoop -ErrorAction SilentlyContinue) {
  Write-Host "scoop already installed."
} else {
  Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
  Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
}

if (Get-Command git -ErrorAction SilentlyContinue) {
  Write-Host "git already installed."
} else {
  scoop install git
}

if (Test-Path -Path (Join-Path ~ nvim) -PathType Container) {
  Write-Host "config folder already exists"
} else {
  git clone https://github.com/pfesenmeier/nvim
}
