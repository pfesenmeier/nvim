# Huey

- Huey is a collection of neovim plugins to help manage agents, workspaces, and neovim servers
- API is heavily inspired by herdr-core and rex
    - https://www.superlogical.com/rex/docs/installation
    - https://github.com/herdrdev/herdr-core, https://herdr.dev/core/

- out of scope:
  - persistence of agents outside the neovim server process. relying on claude /resume command

- term definition
  - workspace - a neovim server with `cwd` set to a jujutsu worktree.

- Features include
  - pickers to attach to a server or open an agent terminal
  - plugin to manage workspaces and their agents a-la mini.files
  - a commandline tool and skill for agents to interact with your editor
  - status bar and buffer bar helpers that work in mini


## Huey.Explorer

there are three panes:
- repositories
  - workspaces (jj workspace + huey.workspace)
    - agents

- each one has a status icon next to it

- <leader>eh -> open huey.explorer pane
  - if coming from an agent buffer, open at the agent pane
  - else, open on the workspace pane, with current workspace focused.

(does this mean each pane will be a different buffer type?)

- each will need to define how to sync with the current state
  - creating a line
  - deleting a line
  - changing the text

## Huey.Cli and SKILL.md

## Agent hub

- `huey/term.lua` reads agent status from OSC 7501 (`state=idle|working|done|blocked|error`,
  plus `kind`, `progress`, base64 `title` and `msg`). Claude Code only sends it after the
  terminal answers its `OSC 7501 ; ?` probe, so every terminal buffer answers.
- On Windows none of that arrives: nvim's terminal runs on ConPTY, which re-renders output
  from its own screen buffer and drops every OSC that isn't screen content, the probe
  included. So Claude Code hooks in `config/claude/settings.json` run `huey hook`, which maps
  the event to a status and calls `HueyTerm.report` over `$NVIM`. That finds the terminal by
  walking the hook's parent processes up to a terminal's `jobpid()`. Where OSC 7501 does
  arrive (Linux, macOS) it wins and hook reports for that terminal are ignored.
- The first nvim starts `huey serve` (`bin/huey`), a hub listening on `$HUEY_SOCK`, else
  `\\.\pipe\huey-<user>` on Windows or `$XDG_RUNTIME_DIR/huey.sock` (`$TMPDIR/huey-<user>.sock`).
  Every nvim streams its agent statuses there; an nvim that quits or crashes takes its agents
  with it. The hub exits 30s after the last connection closes.
- Inside nvim the explorer's agent panes (`<leader>ea`, see `lua/huey/projects/README.md`)
  list agents with their state, time in state, age, and title.
- `huey tui`: every agent across nvims for a terminal outside nvim.
- `huey list`: the same agents as JSON.
- Both lists lay out rows with `huey/hub/view.lua`.
- Protocol: one JSON object per line. Code lives in `neovim/lua/huey/hub/`.

## Implementation:

### State

- global .huey folder to keep track of persistent state

### Configuration Options

- where workspaces are saved on disk (sibling folder vs global folder)
- which harness to use (claude, codex, opencode, pi)
- custom pre-processor, e.g. to allow custom prefixes to commands

## Open Questions

1. Would like to include the prompt inline in the agents pane, but allow opening interactive (empty) claude instances
  a. solution - allow synchronizing empty lines (mini.files strips empty lines)
1. How to

