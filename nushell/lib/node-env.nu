if (which fnm | is-not-empty) {
  use std "path add"
  fnm env --json | from json | load-env

  let path_suffix = if $nu.os-info.family == 'windows' { '' } else { 'bin' }

  path add ($env.FNM_MULTISHELL_PATH | path join $path_suffix)

  # https://github.com/Schniz/fnm/issues/463#issuecomment-2989288244
  $env.config.hooks.env_change.PWD = (
      $env.config.hooks.env_change.PWD? | append {
          condition: {|| ['.nvmrc' '.node-version', 'package.json'] | any {|el| $el | path exists}}
          code: {|| ^fnm use}
      }
  )

  fnm use lts-latest --log-level quiet
}
