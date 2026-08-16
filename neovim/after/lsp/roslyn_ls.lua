local uv = vim.uv
local fs = vim.fs

-- Prefer 'roslyn-language-server', falling back to the nuget binary name.
-- (The base config probes these in the opposite order.)
local exe = vim.fn.executable('roslyn-language-server') == 1 and 'roslyn-language-server'
  or 'Microsoft.CodeAnalysis.LanguageServer'
local cmd = {
  exe,
  '--logLevel',
  'Information',
  '--extensionLogDirectory',
  fs.joinpath(uv.os_tmpdir(), 'roslyn_ls/logs'),
  '--stdio',
}

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
