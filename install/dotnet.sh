#! /usr/bin/env bash

# from https://learn.microsoft.com/en-us/dotnet/core/install/linux-ubuntu#2204-microsoft-package-feed
wget https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
sudo dpkg -i packages-microsoft-prod.deb
rm packages-microsoft-prod.deb

sudo apt-get update && \
  sudo apt-get install -y dotnet-sdk-7.0

sudo apt-get update && \
  sudo apt-get install -y aspnetcore-runtime-7.0
