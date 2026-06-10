# bot.nvim

## Commands

- shortcut for queueing up context to prompt the bot (err, ai agent) (gb)
- multiple commands to record a piece of context as an extmark
- gbb - queue current line
- gb<textobject> - queue textobject
- gb? - add miscellanous text

- commands to send queued messages into chat
- gbx - send to TUI, draining the messages
- gbp - dump (paste) contents of saved (no draining)

## Sending To TUI

- internal FIFO of messages
- wait until TUI is ready
- use techniques not to overload the TUI (delay)
- use techniques to prevent sending text if requesting for input

## UI

## Having the bot talk back

- currently - edits on disk, text in the editor feed
- future - status in the statusbar
- 
