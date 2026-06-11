# bot.nvim


## First case - Sending stuff to claude
- I imagine how I'll work is moving around the codebase, gathering data on what I want to do (refactor)
- I'll leave some comments on functions, areas I want to clean up
- Then, when I'm ready, I'll dump the agent content into the chat window, and have claude code plan out some changes

- shortcut for adding up context to prompt the bot (gb)
- the message in waiting will be a
- each time shortcut is executed over a selection:
  - the filename line numbers, and contents will be saved in the scratch buffer
  - the user will be prompted for a comment
- normal mode - gbb - queue current line
- visual mode - gb - queue selection


- gb? - just add text without additional context

- commands to interact with buffer
- gbe - open + edit buffer
- gbx - send to TUI, and clear buffer (with confirmation)
- gbp - dump (paste) contents of saved (no draining)

## Second Case - Claude Sending Data to me

- [ ] derive claude status from its lifecycle / hook firing, put it in status bar
  - [ ] basically: idle, needs input, working
