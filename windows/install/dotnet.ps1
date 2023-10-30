$packages = $(
'Microsoft.Azure.FunctionsCoreTools'
)

$packages | ForEach-Object { winget install $PSItem }
