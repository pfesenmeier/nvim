#! /bin/bash

set_clipboard () {
  pwsh.exe -noprofile -command '$Input |  Set-Clipboard'
}

get_clipboard() {
  pwsh.exe -noprofile -command 'Get-Clipboard' | sed s/\\r//
}

clip () {
  if [ -t 0 ]; then
    get_clipboard
  else
    set_clipboard
  fi
}

