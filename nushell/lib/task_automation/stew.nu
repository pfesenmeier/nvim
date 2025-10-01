use util.nu run

def join [...paths] {
  $paths | path join
}

let stew = $env.home | path join Code StewLang
let lang = $stew | path join lang
let cli = $stew | path join cli main.ts

def 'test lang' [] {
  run  (join $lang tests) 'deno test --watch *'
}


def "stew" [] {
  deno run --allow-read --allow-env $cli

}

