#!/usr/bin/env nu
use ./utils.nu

def main [] {
  if $nu.os-info.family == 'windows' {
    (
      utils github install
      OmniSharp/omnisharp-roslyn 
      omnisharp-win-x64.zip
      OmniSharp.exe
    )
  } else {
    (
      utils github install
      OmniSharp/omnisharp-roslyn 
      omnisharp-linux-x64-net6.0.zip
      OmniSharp
    )
  }
}
