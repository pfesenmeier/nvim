$packages = $(
'Microsoft.DotNet.SDK.6'
'Microsoft.Azure.FunctionsCoreTools'
)

$packages | ForEach-Object { winget install $PSItem }
