#! /bin/bash

set_clipboard () {
  powershell.exe -noprofile -command '$Input | Set-Clipboard'
}

get_clipboard() {
  powershell.exe -noprofile -command Get-Clipboard
}

clip () {
  if [ -t 0 ]; then
    get_clipboard
  else
    set_clipboard
  fi
}

