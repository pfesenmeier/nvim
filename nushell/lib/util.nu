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
             run-external "pwsh" "-noprofile" "-c" "Get-Clipboard"
         } else {
             wl-paste
         }
     } else {
        if $nu.os-info.family == 'windows' {
            run-external "pwsh" "-noprofile" "-c" $"Set-Clipboard ($stdin)"
        } else {
            $stdin | wl-copy
        }
     }
}
