#! /home/linuxbrew/.linuxbrew/bin/nu

def bin [name: string] {
  $env.HOMEBREW_PREFIX | path join bin $name
}

def tab_config [] {
  {
    neovim: {
      cmd: (bin nvim)
    }
    jj: {
      cmd: jj
      default: true
    }
    claude: {
      cmd: (bin claude)
    }
  }
}

export const script_path = path self

export def main [session?: string, dir?: string] {
  let session = $session | default (pwd | path parse | get stem)
  let dir = $dir | default (pwd)

  tmux kill-session -t $session e>| ignore
  let tabs = tab_config | items {|tab_name, tab_value| { name: $tab_name, ...$tab_value } }
  let first = $tabs | first
  let rest = $tabs | skip 1

  tmux new-session -d -s $session -c $dir -n $first.name
  tmux send-keys -t $"($session):($first.name)" $first.cmd Enter

  for tab in $rest {
    tmux new-window -t $session -n $tab.name -c $dir
    tmux send-keys -t $"($session):($tab.name)" $tab.cmd Enter
  }

  let default = tab_config | items {|key, value|
    if ($value.default? | default false) { $key }
  } | where $in != null | first

  if ($default | is-not-empty) {
    tmux select-window -t $"($session):($default)"
  }

  tmux attach -t $session
}
