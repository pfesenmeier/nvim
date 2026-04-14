$env.DOTNET_ROOT = "/usr/bin"
$env.PATH = $env.PATH | prepend [
  /home/pfes/.dotnet/tools
  /home/pfes/.dotnet
]
