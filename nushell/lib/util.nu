use std log

export def dump [] {
  let result = $in;
  $result | print
  $result
}

def --env cd-sibling [previous?: bool = false] {
  let current = pwd | path parse | get stem

  let options = (
    ls .. -s 
    | where type == dir 
    | get name 
    | enumerate 
    | rename index name
  )

  let current = $options | where name == $current | first

  let new = if $previous {
    $current.index - 1
  } else {
    $current.index + 1
  }

  let new = $options | where index == $new | first
  let new = pwd | path dirname | path join $new.name

  cd $new
}

export def --env cdp [] {
  cd-sibling
}

export def --env cdn [] {
  cd-sibling true
}

export def azurite-tmp [] {
  job spawn { azurite --inMemoryPersistence } -d azurite
}

export def zoxide-init-jj-workspace [
  workspace: string # path to workspace
] {
  # move all queries from <workspace> to <other-workspace>
  
}

export def job-select [] {
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
export def --env zw [word: string] {
  let root = jj workspace root
  let result = zoxide query --base-dir $root $word | complete
  let dir = if $result.exit_code == 0 {
    $result.stdout | str trim
  } else {
    if not ($word | path exists) {
      error make { msg: $"not found: ($word)" }
    }
    $word
  }
  zoxide add $dir
  cd $dir
}

# "z change" -> switches to other if two, or asks for input
export def --env zc [word: string] {
  try {
    let root = jj workspace root
    let dir = zoxide query --base-dir $root $word
    zoxide add $dir
    cd $dir
  } catch {|err|
    print $err.msg
    cd $word
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
