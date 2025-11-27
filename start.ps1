# Invoke-RestMethod -Uri https://raw.githubusercontent.com/pfesenmeier/nvim/main/start.ps1 \ Invoke-Expression

if (Get-Command scoop -ErrorAction SilentlyContinue) {
  Write-Host "scoop already installed."
} else {
  Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
  Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
}

scoop install git neovim nu fnm gsudo

if (Test-Path -Path (Join-Path ~ nvim) -PathType Container) {
  Write-Host "~/nvim folder already exists"
} else {
  git clone https://github.com/pfesenmeier/nvim
}

gsudo nu -n ~/nvim/setup.nu
nu -c 'nvim --headless  "+Lazy! sync"  +qa'
nu -c 'nvim --headless  +TSUpdateSync  +qa'
nu -c "nvim --headless  +ToolsInstall! +qa"
