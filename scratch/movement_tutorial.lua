-- ============================================================
-- Movement & Text-Object Tutorial
-- ============================================================
--
-- Goal: practice STRUCTURAL motion — text objects, jumps,
-- brackets, operators — and stop reaching for hjkl/wWb.
--
-- How to use:
--   1. Read each `-- Task:` line.
--   2. Position cursor as it says, then ATTEMPT the motion
--      without looking at `-- Hint:`.
--   3. If stuck >10s, peek the hint and retry.
--   4. `u` to undo destructive edits between attempts.
--
-- Rule of the game: never press h, j, k, l, w, W, b, B (motion).
-- (Visual-mode `<M-h/j/k/l>` from mini.move is fine — that's
-- a STRUCTURAL move, not a character step.)
--
-- Reference: :h mini.ai, :h mini.surround, :h mini.jump,
--            :h mini.jump2d, :h mini.bracketed, :h mini.indentscope,
--            :h mini.operators, :h mini.align, :h mini.splitjoin,
--            :h mini.move, :h text-objects, :h motion.txt
-- ============================================================

local M = {}

-- ============================================================
-- 1. mini.ai — a/i basics
-- :h MiniAi-textobject-builtin
-- ============================================================
--
-- Targets: parens, brackets, braces, quotes, `b` (any bracket),
-- `q` (any quote), `?` (prompt), `t` (tag-ish).
--
-- Task 1a: change the contents of `print(...)` below to `"hi"`.
-- Hint:    ci)   then type   "hi"
--
-- Task 1b: from the same line, yank the string "Alice" (with quotes).
-- Hint:    ya"
--
-- Task 1c: visually select the OUTER table (including braces).
-- Hint:    va{    (or `vab` if cursor is between any bracket pair)
--
-- Task 1d: visually select INSIDE any quote pair on the line, regardless
--          of whether it's ", ', or `.
-- Hint:    viq

function M.s1_basics()
  local user = { name = "Alice", roles = { 'admin', 'editor' }, age = 30 }
  print("Hello, " .. user.name .. " (age: " .. tostring(user.age) .. ")")
  return user
end

-- ============================================================
-- 2. mini.ai — "next" and "last" variants + `a` (argument)
-- :h MiniAi.config   (search_method = 'cover')
-- ============================================================
--
-- With search_method='cover', plain `cia` only acts on a textobject
-- COVERING the cursor. To reach the NEXT or LAST one explicitly:
--   in  +  n/l  +  textobject     e.g.  cina, dila, vinb, yalq
--
-- Task 2a: from the start of `function M.s2_nextlast(...)` line,
--          replace the 2nd argument (`port`) with `nil`.
-- Hint:    place cursor on `host`, then  cina   (change inside NEXT arg)
--          and type  nil  <Esc>. Cursor advances past it, so another
--          cina would now grab `timeout`.
--
-- Task 2b: from the END of the function signature line, delete the
--          LAST string in the `urls` table ("http://d.com").
-- Hint:    dilq   (delete inside last quote pair — searches backward)
--
-- Task 2c: visually select the argument BEFORE the cursor.
-- Hint:    vila

function M.s2_nextlast(host, port, timeout, retries)
  local urls = { "http://a.com", "http://b.com", "http://c.com", "http://d.com" }
  return host, port, timeout, retries, urls
end

-- ============================================================
-- 3. mini.ai — function call (`f`) vs function definition (`F`, custom)
--              and the whole buffer (`B`, custom)
-- :h MiniAi.gen_spec.treesitter
-- ============================================================
--
-- `f` / `F` distinction:
--   f  = function CALL                    e.g. `string.format(...)`
--   F  = function DEFINITION (treesitter) e.g. `function foo() ... end`
--
-- Task 3a: visually select the WHOLE `inner` function definition.
-- Hint:    on the word `inner`, type    vaF
--
-- Task 3b: visually select just the BODY of `inner` (no signature/end).
-- Hint:    viF
--
-- Task 3c: visually select the contents of the `table.concat(...)` call.
-- Hint:    vif    (cursor anywhere inside the call)
--
-- Task 3d: visually select the ENTIRE buffer.
-- Hint:    vaB    (custom — `:h MiniExtra.gen_ai_spec.buffer`)

function M.s3_func_buffer()
  local function inner(x)
    return string.format("value=%d", x * 2)
  end
  return inner(table.concat({ "a", "b", "c" }, ","))
end

-- ============================================================
-- 4. mini.surround — add / delete / replace / find / highlight
-- :h MiniSurround-builtin-surroundings
-- ============================================================
--
-- Mnemonic: s + {a|d|r|f|h} + (target / replacement)
--
-- Task 4a: surround the identifier `target` (left of the `=`) with parens.
--          i.e.  local target =  -->  local (target) =
-- Hint:    on `target`,    saiw)
--
-- Task 4a': surround the WHOLE string "hello world" (quotes included)
--           with parens.       i.e.  "hello world"  -->  ("hello world")
-- Hint:    cursor inside the string, then    saa")
--          Reads as: surround-ADD, region = AROUND double quote, output = ).
--
-- Task 4b: replace the double quotes on "hello world" with single quotes.
-- Hint:    sr"'
--
-- Task 4c: delete the parens around `(1 + 2)`.
-- Hint:    sd(
--
-- Task 4d: highlight the whole function call `M.s4_surround` definition
--          area (briefly flashes).
-- Hint:    shf     (cursor inside the function body)
--
-- Task 4e: replace the NEXT pair of curly braces (anywhere in the buffer)
--          with padded curly braces.
-- Hint:    srn{{

function M.s4_surround()
  local target = "hello world"
  local list = (1 + 2)
  local greet = 'foo bar baz'
  return target, list, greet
end

-- ============================================================
-- 5. mini.jump — smart f/F/t/T across multiple lines
-- :h MiniJump
-- ============================================================
--
-- Unlike built-in f, this works ACROSS lines and keeps highlighting
-- until you press something unrelated. `;` and `,` repeat.
--
-- Task 5a: from the start of `local data = ...`, land on the FIRST `,`
--          in the string, then hop to the next 3 commas.
-- Hint:    f,    then ; ; ;
--
-- Task 5b: from the start of `"apple, banana, cherry, ...`, delete
--          UP TO (not including) the second comma.
-- Hint:    2dt,    (delete TILL comma, count = 2 commas)
--
-- Task 5c: from `cherry`, jump backward to the closest `,`.
-- Hint:    F,

function M.s5_jump()
  local data = "apple, banana, cherry, date, elderberry, fig, grape, honeydew"
  return data
end

-- ============================================================
-- 6. mini.jump2d — label-based jump anywhere on screen
-- :h MiniJump2d
-- ============================================================
--
-- Stop counting lines. Lock eyes on the target, press <CR>, then type
-- the labels that appear over your target until it's unique.
--
-- Task 6a: from this section's header, jump to the word `ASTEROID` below
--          (in section 8) using ONLY <CR> + labels.
-- Hint:    <CR> then keep typing the labels that appear over `ASTEROID`
--
-- Task 6b: jump to the `return` keyword of `M.s11_splitjoin`.
-- Hint:    <CR> then label
--
-- (No code to operate on here — this section is pure jumping practice.)

-- ============================================================
-- 7. mini.bracketed — [/]-prefixed motion across many target kinds
-- :h MiniBracketed
-- ============================================================
--
-- Sampler:
--   ]b / [b   buffer (next/prev listed buffer)
--   ]j / [j   jump (forward/back in this buffer's jumplist)
--   ]d / [d   diagnostic
--   ]q / [q   quickfix entry
--   ]x / [x   conflict marker
--   ]o / [o   old/jumps-style file
--   ]c / [c   comment block
--
-- Task 7a: the local below WILL produce a `lua_ls` "unused" diagnostic
--          once attached. From the top of this file, jump to it.
-- Hint:    ]d
--
-- Task 7b: there is a fake merge conflict in the string below. Jump
--          between its markers.
-- Hint:    ]x   and   [x
--
-- Task 7c: from anywhere, jump to the next COMMENT block.
-- Hint:    ]c

function M.s7_bracketed()
  local unused_diagnostic_target = 1  -- intentionally unused

  local fake_conflict = [[
<<<<<<< HEAD
this side of the conflict
=======
the other side of the conflict
>>>>>>> feature-branch
]]
  return fake_conflict
end

-- ============================================================
-- 8. mini.indentscope — operate by indent level
-- :h MiniIndentscope
-- ============================================================
--
-- `ii` / `ai` = inside / around the indent scope at cursor.
-- `[i` / `]i` jump to the top/bottom of the current scope.
--
-- Task 8a: position cursor on the line `print("ASTEROID")` below.
--          Visually select the surrounding `if` scope.
-- Hint:    Vai
--
-- Task 8b: from the same line, jump to the TOP of the enclosing scope.
-- Hint:    [i
--
-- Task 8c: change everything INSIDE the innermost scope (the `while`).
-- Hint:    cii

function M.s8_indent()
  if true then
    for i = 1, 10 do
      while i > 0 do
        if i % 2 == 0 then
          print("ASTEROID")
        end
        i = i - 1
      end
    end
  end
end

-- ============================================================
-- 9. mini.operators — gr / gm / gs / gx / g=
-- :h MiniOperators
-- ============================================================
--
-- gr = replace with register      gm = multiply (duplicate)
-- gs = sort                       gx = exchange
-- g= = evaluate (lua/vim)
--
-- Task 9a: yank the word `cherry` (e.g. with `yiw`). Then REPLACE the
--          word `apple` with the contents of the unnamed register.
-- Hint:    on `cherry`, yiw — then on `apple`, griw
--
-- Task 9b: duplicate the entire `local words = {...}` line.
-- Hint:    gmm
--
-- Task 9c: sort the items in the `words` table (one item per line — first
--          run mini.splitjoin's `gS` on the table to expand it).
-- Hint:    gS on `{`, then  vi{gs   (sort visual selection)
--
-- Task 9d: swap `"first"` and `"second"`.
-- Hint:    on `"first"`,  gxi"    then on `"second"`,  gxi"   (mini.exchange
--          completes the swap when invoked twice)
--
-- Task 9e: replace the bare `vim.fn.getcwd()` line with its evaluated value.
-- Hint:    g==    (on that exact line — replaces it with the function result)

function M.s9_operators()
  local words = { "banana", "apple", "cherry", "date", "elderberry" }
  vim.fn.getcwd()
  local a, b = "first", "second"
  return words, a, b
end

-- ============================================================
-- 10. mini.align — align by separator
-- :h MiniAlign
-- ============================================================
--
-- Operator form:    ga  +  textobject  +  split-char
-- Interactive:      gA  +  textobject   (then choose split/justify)
--
-- Task 10a: align the assignments below by `=`.
-- Hint:     gaip=     (cursor inside the paragraph)
--
-- Task 10b: alternatively, do it interactively.
-- Hint:     gAip      then press `s` and type `=`, then `<CR>`

function M.s10_align()
  local name = "Bob"
  local longerName = "Alice"
  local age = 42
  local occupation = "Engineer"
  local x = 1
  return name, longerName, age, occupation, x
end

-- ============================================================
-- 11. mini.splitjoin — gS to toggle single-line ↔ multi-line
-- :h MiniSplitjoin
-- ============================================================
--
-- Task 11a: expand the `cfg` table to one key per line.
-- Hint:     cursor on `{` (or anywhere on the line), then  gS
--
-- Task 11b: collapse it back.
-- Hint:     cursor anywhere inside the expanded table, then  gS
--          (Bonus: `.` after the first `gS` dot-repeats.)

function M.s11_splitjoin()
  local cfg = { host = "localhost", port = 8080, timeout = 30, retries = 3, debug = false }
  return cfg
end

-- ============================================================
-- 12. mini.move — <M-hjkl> to reorder/indent (structural, not character)
-- :h MiniMove
-- ============================================================
--
-- Normal mode:  <M-j>/<M-k> move current line down/up.
--               <M-h>/<M-l> de-indent / indent current line.
-- Visual mode:  <M-h/j/k/l> move the whole selection.
--
-- Task 12a: reorder the list below so items are 1, 2, 3, 4 in order.
--           Use ONLY <M-j>/<M-k> (no dd/p, no cut/paste).
-- Hint:     on each out-of-place line, press <M-k> or <M-j> until it lands.
--
-- Task 12b: select the whole `items` table (try  vi{ ) then indent it
--           one level deeper.
-- Hint:     vi{  then  <M-l>

function M.s12_move()
  local items = {
    "3. third",
    "1. first",
    "4. fourth",
    "2. second",
  }
  return items
end

-- ============================================================
-- 13. Built-in structural motion — no plugin required
-- :h motion.txt   :h mark-motions   :h jump-motions
-- ============================================================
--
-- %        jump to matching bracket
-- * / #    search next/prev occurrence of word under cursor
-- ( / )    sentence backward / forward (works in prose & comments)
-- { / }    paragraph backward / forward (blank-line-delimited)
-- H/M/L    top / middle / bottom of visible screen
-- ma       set mark `a` here;  'a  jump to its line;  `a  jump to col
-- <C-o>    older position in jumplist;  <C-i>  newer
-- g; / g,  older / newer position in CHANGE list
--
-- Task 13a: on any `{` below, jump to its matching `}`.
-- Hint:     %
--
-- Task 13b: on the word `RAVEN` (first occurrence), jump to next RAVEN.
-- Hint:     *    (then n / N)
--
-- Task 13c: jump forward by paragraph through the prose block below.
-- Hint:     }    (then `{` to go back)
--
-- Task 13d: set mark `a` here:  -- MARK_A_DROP_HERE
--           Then jump to the very last line of the buffer (G), then back.
-- Hint:     ma  ...  G  ...  `a
--
-- Task 13e: make a small edit, then another small edit elsewhere,
--           then walk backward through the changelist.
-- Hint:     g;  g;  g,
--
-- Task 13f: from this line, hop to the bottom of the visible screen,
--           then back to the top.
-- Hint:     L    then    H

function M.s13_builtin()
  local function nest_a()
    return { { { { "deep" } } } }
  end

  -- The RAVEN flew over the wall. A second RAVEN watched. A third RAVEN
  -- joined them. The fourth RAVEN was suspicious. The fifth RAVEN left.

  -- This is the first sentence. Here is a second one. And a third!
  -- A new paragraph starts after a blank line.

  -- Another paragraph here.

  -- Yet another. Sentences end with periods. Or question marks?
  return nest_a()
end

-- ============================================================
-- CHALLENGE — composite tasks, no hints.
-- ============================================================
--
-- C1. Duplicate `M.s4_surround`, then in the copy change every `"..."`
--     to `'...'`, then move the duplicate ABOVE `M.s4_surround`.
--
-- C2. In `M.s2_nextlast`, swap the order of `host` and `port` in the
--     function signature AND in the return statement.
--
-- C3. In `M.s11_splitjoin`, expand the table, sort its keys
--     alphabetically, then collapse it back.
--
-- C4. From the top of this file, reach the word `ASTEROID` (in section 8)
--     in exactly THREE keystrokes total.

return M
