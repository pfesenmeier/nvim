use std log

export def dump [] {
  let result = $in;
  $result | print
  $result
}

export def clip [] {
     let stdin = $in;
     if ($stdin | is-empty) {
         run-external --redirect-stdout "pwsh" "-noprofile" "-c" "Get-Clipboard"
     } else {
        run-external "pwsh" "-noprofile" "-c" $"Set-Clipboard ($stdin)"
     }
}
