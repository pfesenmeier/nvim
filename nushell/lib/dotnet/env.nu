# something is setting this, and messing up Microsoft.CodeAnalysis.LanguageServer
if ($env.DOTNET_ROOT? | is-not-empty) {
  hide-env DOTNET_ROOT
}
$env.PATH = $env.PATH | prepend [
  /home/pfes/.dotnet/tools
  /home/pfes/.dotnet
]
