export def run [
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

