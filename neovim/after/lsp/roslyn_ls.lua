return {
  filetypes = { "cs", "razor" },
  settings = {
    -- Only analyze open files rather than the whole solution. Big perf win on
    -- large solutions; trade-off is diagnostics for unopened files won't show
    -- until opened (a full build still catches everything).
    ["csharp|background_analysis"] = {
      dotnet_analyzer_diagnostics_scope = "openFiles",
      dotnet_compiler_diagnostics_scope = "openFiles",
    },
  },
}
