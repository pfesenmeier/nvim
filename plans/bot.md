# bot.nvim

- I imagine how I'll work is moving around the codebase, gathering data on what I want to do (refactor)
- I'll leave some comments on functions, areas I want to clean up
- Then, when I'm ready, I'll dump the agent content into the chat window, and have claude code plan out some changes

## Commands
- shortcut for adding up context to prompt the bot (gb)
- the message in waiting will be a
- each time shortcut is executed over a selection:
  - the filename line numbers, and contents will be saved in the scratch buffer
  - the user will be prompted for a comment
- gbb - queue current line
- gbd - diagnostic
- gb<textobject> - queue textobject
- gb? - just add text without additional context

- commands to interact with buffer
- gbe - open + edit buffer
- gbx - send to TUI, and clear buffer (with confirmation)
- gbp - dump (paste) contents of saved (no draining)

## Additonal Work

I'd like to add a status to my statusline on what state claude is in (i think idle, waiting input, working?)
that would be a hint that it's ready for my gbx command
