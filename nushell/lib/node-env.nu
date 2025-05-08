if $nu.os-info.family == 'windows' {
  return
}

if ($env.FNM_MULTISHELL_PATH? | is-not-empty) {
  $env.PATH = ($env.PATH
      | split row (char esep)
      | prepend $"($env.FNM_MULTISHELL_PATH)/bin"
  )
}

if (which fnm | is-not-empty) {
  load-env (fnm env --shell bash
      | lines
      | str replace 'export ' ''
      | str replace -a '"' ''
      | split column "=" 
      | rename name value
      | where name != "FNM_ARCH" and name != "PATH"
      | reduce -f {} {|it, acc| $acc | upsert $it.name $it.value }
  )

  fnm use lts-latest --log-level quiet
}

