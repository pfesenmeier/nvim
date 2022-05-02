#! /bin/fish

function set_clipboard 
  powershell.exe -noprofile -command '$Input |  Set-Clipboard'
end

function get_clipboard 
  powershell.exe -noprofile -command 'Get-Clipboard' | sed s/\\r//
end

function clip
  if isatty stdin
    get_clipboard
  else
    set_clipboard
  end
end

