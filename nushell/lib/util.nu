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
            let quoted = $stdin | str replace --all "'" "''"
            run-external "powershell" "-noprofile" "-c" $"Set-Clipboard '($quoted)'"
        } else {
            $stdin | wl-copy
        }
     }
}

export def prs [] {
  gh pr list --author "@me" --json number,title,url,reviewDecision --template '{{range .}}{{printf "#%v" .number}} {{.title}}{{"\n"}}  URL: {{.url}}{{"\n"}}  Status: {{if .reviewDecision}}{{.reviewDecision}}{{else}}PENDING{{end}}{{"\n\n"}}{{end}}'
}
