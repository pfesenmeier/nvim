# Help Set-PSReadLineOption
Import-Module PSReadLine
Import-Module CompletionPredictor

# TODO -> auto-set $HOME environment variable for git bash

Remove-Alias rm
Remove-Alias mv
Set-Alias ls eza

$PSReadlineOptions = @{
  BellStyle = "None"
  EditMode = "Vi"
  HistoryNoDuplicates = $true
  HistorySearchCursorMovesToEnd = $true
  PredictionSource = "HistoryAndPlugin"
  PredictionViewStyle = "InlineView"
  ViModeIndicator = "Script"
  ViModeChangeHandler = function OnViModeChange {
        if ($args[0] -eq 'Command') {
            # Set the cursor to a blinking block.
            Write-Host -NoNewLine "$([char]0x1b)[1 q"
        } else {
            # Set the cursor to a blinking line.
            Write-Host -NoNewLine "$([char]0x1b)[5 q"
        }
    }
}
Set-PSReadLineOption @PSReadlineOptions
# this was making dir listing super slow
# Set-PSReadLineKeyHandler -Key Tab -Function Complete
Set-PSReadLineKeyHandler -Chord "Alt+f" -Function AcceptNextSuggestionWord
Set-PSReadLineKeyHandler -Chord "Ctrl+f" -Function AcceptSuggestion

# Searching for commands with up/down arrow is really handy.  The
# option "moves to end" is useful if you want the cursor at the end
# of the line while cycling through history like it does w/o searching,
# without that option, the cursor will remain at the position it was
# when you used up arrow, which can be useful if you forget the exact
# string you started the search on.
Set-PSReadLineOption -HistorySearchCursorMovesToEnd
Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward

$env:path += ";C:\Program Files\Neovim\bin"
$env:path += ";C:\Program Files\starship\bin"
$env:path += ";C:\ProgramData\chocolatey\bin"

Invoke-Expression (&starship init powershell)
# https://learn.microsoft.com/en-us/windows/terminal/tutorials/new-tab-same-directory
function Invoke-Starship-PreCommand {
  $loc = $executionContext.SessionState.Path.CurrentLocation;
  $prompt = "$([char]27)]9;12$([char]7)"
  if ($loc.Provider.Name -eq "FileSystem")
  {
    $prompt += "$([char]27)]9;9;`"$($loc.ProviderPath)`"$([char]27)\"
  }
  $host.ui.Write($prompt)
}

Set-Alias e nvim
Set-Alias cat bat
Set-Alias bash 'C:\Program Files\Git\bin\bash.exe'
function i {
  Get-ChildItem -Directory
}

function s { git status }
function a { git add $args }
function c { git commit $args }
function ll { eza -l }



function clip {
    if ($MyInvocation.ExpectingInput) {
        $input | Set-Clipboard
    } else {
        Get-Clipboard
    }
}

# Set-PSReadlineKeyHandler -Key Tab -Function Complete

# https://learn.microsoft.com/en-us/cli/azure/install-azure-cli-windows?tabs=azure-cli#enable-tab-completion-on-powershell
Register-ArgumentCompleter -Native -CommandName az -ScriptBlock {
    param($commandName, $wordToComplete, $cursorPosition)
    $completion_file = New-TemporaryFile
    $env:ARGCOMPLETE_USE_TEMPFILES = 1
    $env:_ARGCOMPLETE_STDOUT_FILENAME = $completion_file
    $env:COMP_LINE = $wordToComplete
    $env:COMP_POINT = $cursorPosition
    $env:_ARGCOMPLETE = 1
    $env:_ARGCOMPLETE_SUPPRESS_SPACE = 0
    $env:_ARGCOMPLETE_IFS = "`n"
    $env:_ARGCOMPLETE_SHELL = 'powershell'
    az 2>&1 | Out-Null
    Get-Content $completion_file | Sort-Object | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, "ParameterValue", $_)
    }
    Remove-Item $completion_file, Env:\_ARGCOMPLETE_STDOUT_FILENAME, Env:\ARGCOMPLETE_USE_TEMPFILES, Env:\COMP_LINE, Env:\COMP_POINT, Env:\_ARGCOMPLETE, Env:\_ARGCOMPLETE_SUPPRESS_SPACE, Env:\_ARGCOMPLETE_IFS, Env:\_ARGCOMPLETE_SHELL
}

# Import the Chocolatey Profile that contains the necessary code to enable
# tab-completions to function for `choco`.
# Be aware that if you are missing these lines from your profile, tab completion
# for `choco` will not function.
# See https://ch0.co/tab-completion for details.
$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
  Import-Module "$ChocolateyProfile"
}

. $home\nvim\windows\local.ps1
