# Help Set-PSReadLineOption
Import-Module PSReadLine
Import-Module CompletionPredictor

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
Set-PSReadLineKeyHandler -Key Tab -Function Complete
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

Set-Alias e nvim
Set-Alias i ls

function clip {
    if ($MyInvocation.ExpectingInput) {
        $input | Set-Clipboard
    } else {
        Get-Clipboard
    }
}
