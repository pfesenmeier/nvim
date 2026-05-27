let dotnet = $env.HOME | path join .dotnet
$env.DOTNET_ROOT = $dotnet

# something is setting this, and messing up Microsoft.CodeAnalysis.LanguageServer
# if ($env.DOTNET_ROOT? | is-not-empty) {
#   hide-env DOTNET_ROOT
# }

$env.PATH = $env.PATH | prepend [
  $dotnet
  ($dotnet | path join tools)
]
