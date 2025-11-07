use util.nu run
#
# def join [...paths] {
#   $paths | path join
# }
#
let cabo = $env.home | path join Code cabo

# let lang = $stew | path join "lang"
# let pata = $stew | path join "pata"
#
def 'test' [] {}

def 'test frontend' [...args: string] {
  run  $cabo $'yarn test:frontend -- ($args | str join " ")'
}

def 'test backend' [...args: string] {
  run  $cabo $'yarn test:backend -- ($args | str join " ")'  
}

def 'app' [] {
  run $cabo 'yarn dev'
}

def 'regen' [] {
  run $cabo 'yarn db:regenerate'
}

def gql [] {
  run $cabo 'yarn generate:graphql'
}

def typecheck [] {
  run $cabo 'yarn typecheck'
}
