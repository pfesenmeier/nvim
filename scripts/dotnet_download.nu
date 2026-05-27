if $nu.os-info.name != 'macos' {
  print "macos not detected"
  exit 1
}

# https://learn.microsoft.com/en-us/dotnet/core/install/macos#install-net-with-a-script
cd ~/Downloads
brew install wget
wget https://dot.net/v1/dotnet-install.sh
chmod +x dotnet-install.sh
./dotnet-install.sh
