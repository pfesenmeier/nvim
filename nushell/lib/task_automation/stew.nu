use util.nu run

def join [...paths] {
  $paths | path join
}

let stew = $env.home | path join Code StewLang
let lang = $stew | path join "lang"
let pata = $stew | path join "pata"

def 'test lang' [] {
  run  (join $lang tests) 'deno test --watch *'
}

def 'pata' [] {
  run $pata  'npm run tauri dev'
}
use util.nu run

def join [...paths] {
  $paths | path join
}

let stew = $env.home | path join Code StewLang

def "stew" [] {
  deno task run 
}
