use std log

export def dump [] {
  let result = $in;
  $result | print
  $result
}

export def azurite-tmp [] {
  job spawn { azurite --inMemoryPersistence } -t azurite
}

# TODO helper to either start a process or resume previous process
# how to handle two? alwoys resume last?

export def jobs [] {
  let jobs = job list | sort-by id --reverse

  # TODO pattern matching
  let num_jobs = $jobs | length
  if $num_jobs == 1 {
    job unfreeze $jobs.0.id
  } else if $num_jobs > 1 {
    job list | input list | job unfreeze $in.id
  } 
}

def job-resume [name: string] {
  let existing = job list | where { $in.tag == $name } | first

  match $existing {
    null => { ^$name },
    _ => { job unfreeze $existing.id }
  }
}

export def jn [] {
  job-resume nvim
}

export def jc [] {
  job-resume claude
}

# TODO 
# "z within"
# jj workspace - away z [] {}
# jj workspace root
# zoxide query ---base-dir <path>
export def zw [word: string] {
  try {
    let root = jj workspace root
    let dir = zoxide query --base-dir $root $word
    z $dir
    pwd
  } catch {
    z $word
  }
}

# "z change" -> switches to other if two, or asks for input
export def zc [word: string] {
  try {
    let root = jj workspace root
    let dir = zoxide query --base-dir $root $word
    z $dir
  } catch {
    z $word
  }
  
}

# TODO use /mnt/c/Windows/System32/clip.exe

# was broken due to stop adding windows PATH to WSL
const powershell = "/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe"

export def clip [] {
     let stdin = $in;
     if ($stdin | is-empty) {
         if $nu.os-info.family == 'windows' {
             run-external $powershell "-noprofile" "-c" "Get-Clipboard"
         } else {
             wl-paste
         }
     } else {
        if $nu.os-info.family == 'windows' {
            let quoted = $stdin | str replace --all "'" "''"
            run-external $powershell "-noprofile" "-c" $"Set-Clipboard '($quoted)'"
        } else {
            $stdin | wl-copy
        }
     }
}

# pastes windows clipboard contents to compressed png inside wsl
export def png-paste [name: string, --force (-f)] {
  let data = clip
  let name = $name + .png

  if ($data | is-empty) {
    print "no data found"
    exit 1
  }

  if $force {
    $data | save -f $name
  } else {
    $data | save $name
  }

  optipng -o5 $name
  let success = (ls $name | get size | first) < 256kb

  if not $success {
    print "warning: compressed image is still too large for claude"
  }

}

export alias ip = image-paste

export def prs [] {
  gh pr list --author "@me" --json number,title,url,reviewDecision --template '{{range .}}{{printf "#%v" .number}} {{.title}}{{"\n"}}  URL: {{.url}}{{"\n"}}  Status: {{if .reviewDecision}}{{.reviewDecision}}{{else}}PENDING{{end}}{{"\n\n"}}{{end}}'
}
