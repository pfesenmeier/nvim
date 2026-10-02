local fs = vim.fs

-- Overrides roslyn.nvim's config (lsp/roslyn.lua). A list like `cmd` replaces
-- the plugin's rather than merging, so start from the plugin's own cmd to keep
-- its flags (e.g. --daemon-mode) and only append the Roslynator extensions.
local plugin_lsp = vim.iter(vim.api.nvim_get_runtime_file('lsp/roslyn.lua', true)):find(function(path)
  return path:find('roslyn.nvim', 1, true) ~= nil
end)
local cmd = vim.deepcopy(dofile(plugin_lsp).cmd)

-- Load Roslynator's analyzers/refactorings as roslyn analyzer extensions.
-- ROSLYNATOR_DIR is exported by the nushell installer (install/cmds/roslynator.nu),
-- which copies only the extracted .dll files into it.
local roslynator_dir = vim.env.ROSLYNATOR_DIR
if roslynator_dir and vim.fn.isdirectory(roslynator_dir) == 1 then
  for name in fs.dir(roslynator_dir) do
    if vim.endswith(name, '.dll') then
      table.insert(cmd, '--extension')
      table.insert(cmd, fs.joinpath(roslynator_dir, name))
    end
  end
end

return {
  cmd = cmd,
  settings = {
    -- Only analyze open files rather than the whole solution. Big perf win on
    -- large solutions; trade-off is diagnostics for unopened files won't show
    -- until opened (a full build still catches everything).
    ['csharp|background_analysis'] = {
      dotnet_analyzer_diagnostics_scope = 'openFiles',
      dotnet_compiler_diagnostics_scope = 'openFiles',
    },
  },
}
