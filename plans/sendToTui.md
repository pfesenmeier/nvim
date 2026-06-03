# Send To Tui

Currently, we have the ability to have a tui (jjui, claude) within a terminal in neovim control the editor by sending commands to the neovim remote server ($NVIM).

The question now is how to best approach how to push data back. For example,

- open all revisions that touch this file in jjui
- prompt a running claude with current buffer diagnostics and a message

## References

- Oli Morris's CodeCompanion has a recent `cli` feature meant to send messages to a tui
- I've not read it, but perhaps sidekick.nvim also has a similar feature

## Exploration Goals

- How hacky are these solutions? what's a reasonable expectation of these techniques? would I be better off sticking to current pattern of invoking actions within the tui to get data from the client?
- For example, a keybind to open jjui, change query to get all that touch current buffer (get by using current cli tool we are building)
