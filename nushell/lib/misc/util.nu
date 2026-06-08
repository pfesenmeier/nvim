 use std log
 
 export def dump [] {
   let result = $in;
   $result | print
   $result
 }
 
def --env cd-sibling [previous?: bool = false] {
  let current = pwd | path basename

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
 
 # Copy zoxide entries from one jj workspace to every sibling jj workspace.
 # Paths are rewritten (source prefix -> sibling prefix); scores are preserved.
 # Re-running accumulates scores (`zoxide import --merge`).
 export def zoxide-init-jj-workspace [
   source?: string # source workspace path; defaults to current `jj workspace root`
 ] {
   let source = if ($source | is-empty) {
     jj workspace root | str trim
   } else {
     $source | path expand
   }

   if not ($source | path exists) {
     error make { msg: $"source workspace does not exist: ($source)" }
   }

   let parent = $source | path dirname
   let self_name = $source | path basename

   let siblings = (
     ls $parent
     | where type == dir
     | where ($it.name | path basename) != $self_name
     | where (($it.name | path join '.jj') | path exists)
     | get name
   )

   if ($siblings | is-empty) {
     print "no sibling jj workspaces found"
     return
   }

   let raw = (zoxide query -l -s --base-dir $source | complete)
   if $raw.exit_code != 0 {
     error make { msg: $"zoxide query failed: ($raw.stderr)" }
   }

   let entries = (
     $raw.stdout
     | lines
     | parse --regex '^\s*(?<score>\S+)\s+(?<path>.+)$'
   )

   if ($entries | is-empty) {
     print $"no zoxide entries under ($source)"
     return
   }

   let now = (date now | format date '%s')
   let src_len = ($source | str length)

   for sibling in $siblings {
     let lines = (
       $entries
       | each {|e|
           let rel = ($e.path | str substring $src_len..)
           $"($sibling)($rel)|($e.score)|($now)"
         }
       | str join "\n"
     )
     let tmp = (mktemp)
     $lines | save -f $tmp
     let r = (zoxide import --merge --from z $tmp | complete)
     rm -f $tmp
     if $r.exit_code != 0 {
       print $"seed failed for ($sibling): ($r.stderr)"
     } else {
       print $"seeded ($entries | length) entries -> ($sibling)"
     }
   }
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
 
export def clip [] {
  let stdin = $in
  let is_wsl = ($nu.os-info.family != 'windows') and ('WSL_DISTRO_NAME' in $env)
  let use_win32yank = ($nu.os-info.family == 'windows') or $is_wsl

  if ($stdin | is-empty) {
    if $use_win32yank { win32yank.exe -o --lf } else { wl-paste }
  } else {
    if $use_win32yank { $stdin | win32yank.exe -i --crlf } else { $stdin | wl-copy }
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
