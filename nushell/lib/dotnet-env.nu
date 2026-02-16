$env.DOTNET_ROOT = "/home/pfes/.dotnet"
$env.PATH = $env.PATH | prepend [
  /home/pfes/.dotnet/tools
  /home/pfes/.dotnet
]
