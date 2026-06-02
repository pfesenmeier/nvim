# Registers Module

Alternative to shortcut for sending to claude code directly

<leader>rc change current register
rs <- set
ra <- append
rad <- diagnotics
rap <- path
rai <- interactive
rst

rai <- prompt something to add
rsa send to claude
rp <- preview contents in float
<reader>raa add
<reader>rA append


❯ is there a neovim shortcut for "append to buffer"? (as opposed to set buffer ("ayy)

● Yes — use the uppercase register name to append.

  - "ayy → set register a to the current line
  - "Ayy → append the current line to register a

  The same rule works for any register operation:
  - "Ay$ — append to end of line into a
  - "Ap is not a thing for pasting (paste always reads, capitalization only matters on write/yank/delete)

  So the mnemonic is: lowercase overwrites, uppercase appends.

✻ Cogitated for 5s

❯ wow. what's the shortcut then for, say, append buffer filename. append buffer contents

● Both build on the same uppercase-register trick, but via Ex commands since there's no single-key motion for "filename" or "whole buffer as a thing."

  Append whole buffer contents to register a:
  :%yank A
  (:%y A for short — % = all lines, A = append to a)

  Append current filename to register a:
  :let @A = expand('%')
  - expand('%') → relative path (e.g. lua/config/init.lua)
  - expand('%:p') → absolute path
  - expand('%:t') → just the tail (basename)

  The :let @A = ... form is the general pattern: assigning to an uppercase register name appends instead of overwrites, same rule as "Ayy. So :let @A = "\n---\n" would tack a separator onto
  register a, etc.
