#! /home/linuxbrew/.linuxbrew/bin/nu

def bin [name: string] {
  let prefix = $env.HOMEBREW_PREFIX? | default /home/linuxbrew/.linuxbrew/
  $prefix | path join bin $name
}

def tab_config [] {
  {
    neovim: {
      cmd: (bin nvim)
    }
    jj: {
      cmd: (bin jjui)
      default: true
    }
    claude: {
      cmd: (bin claude)
    }
    shell: {}  # plain shell — no cmd, tmux's default-shell (nu) opens
  }
}

export const script_path = path self

export def main [
  session?: string,
  dir?: string,
  --no-attach,  # skip the trailing `tmux attach` (used when sesh handles attach)
  --populate,   # operate on the *current* session: rename window 1, add the
                # other windows from tab_config. No kill, no new-session, no
                # attach. Used as sesh's default_session.startup_command.
] {
  let tabs = tab_config | items {|tab_name, tab_value| { name: $tab_name, ...$tab_value } }
  let first = $tabs | first
  let rest = $tabs | skip 1
  let default = tab_config | items {|key, value|
    if ($value.default? | default false) { $key }
  } | where $in != null | first

  # Tabs without a cmd just open a plain shell — tmux's default-shell takes
  # over, so we skip the send-keys for those windows.
  let send_cmd = {|target, tab|
    if ($tab.cmd? | is-not-empty) {
      tmux send-keys -t $target $tab.cmd Enter
    }
  }

  if $populate {
    let session = (tmux display-message -p "#S" | str trim)
    tmux rename-window -t $"($session):" $first.name
    do $send_cmd $"($session):($first.name)" $first
    for tab in $rest {
      tmux new-window -t $session -n $tab.name
      do $send_cmd $"($session):($tab.name)" $tab
    }
    if ($default | is-not-empty) {
      tmux select-window -t $"($session):($default)"
    }
    return
  }

  let session = $session | default (pwd | path parse | get stem)
  let dir = $dir | default (pwd)

  let exists = ((tmux has-session -t $session | complete).exit_code == 0)

  if not $exists {
    tmux new-session -d -s $session -c $dir -n $first.name
    do $send_cmd $"($session):($first.name)" $first

    for tab in $rest {
      tmux new-window -t $session -n $tab.name -c $dir
      do $send_cmd $"($session):($tab.name)" $tab
    }

    if ($default | is-not-empty) {
      tmux select-window -t $"($session):($default)"
    }
  }

  if not $no_attach {
    tmux attach -t $session
  }
}
