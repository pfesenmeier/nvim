#!/usr/bin/env nu

use ./utils.nu

if $nu.os-info.family == 'windows' {
  (
    utils github install
    artempyanykh/marksman
    marksman.exe
    marksman.exe
  )
} else {
  brew install marksman
}
