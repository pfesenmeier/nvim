use std log

export def dump [] {
  let result = $in;
  $result | print
  $result
}

export def clip [] {
     let stdin = $in;
     if ($stdin | is-empty) {
         if $nu.os-info.family == 'windows' {
             run-external "powershell" "-noprofile" "-c" "Get-Clipboard"
         } else {
             wl-paste
         }
     } else {
        if $nu.os-info.family == 'windows' {
            run-external "powershell" "-noprofile" "-c" $"Set-Clipboard ($stdin)"
        } else {
            $stdin | wl-copy
        }
     }
}
