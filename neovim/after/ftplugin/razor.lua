-- Razor (.razor/.cshtml) has no dedicated tree-sitter parser, so reuse the
-- 'html' parser (installed in 'plugin/40_plugins.lua') for markup highlighting.
-- roslyn_ls semantic tokens (priority 125) still repaint the C# regions on top
-- of the html parse (priority 100); the '@' directives/code blocks are the only
-- rough spots.
vim.treesitter.start(0, 'html')
