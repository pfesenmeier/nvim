#! /bin/bash

function set_clipboard 
  pwsh.exe -noprofile -command '$Input |  Set-Clipboard'
end

function get_clipboard 
  pwsh.exe -noprofile -command 'Get-Clipboard' | sed s/\\r//
end

function clip
  if isatty stdin
    get_clipboard
  else
    set_clipboard
  end
end

