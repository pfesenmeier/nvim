
def run [
  dir: string
  cmd: string
] {
  let cwd = pwd

  try {
    cd $dir
    nu -c $cmd
    cd $cwd
  } catch {
    cd $cwd
  }
}

def 'run test' [] {
  run ([$env.home Code StewLang lang tests] | path join) 'deno test --watch *'
}

