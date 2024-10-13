use utils.nu;

if $nu.os-info.family == 'windows' {
  } else {
   (
     utils github install
     microsoft/vscode-js-debug 
     js-debug-dap-v1.94.0.tar.gz
     dapDebugServer.js
     v1.94.0
   )
}
