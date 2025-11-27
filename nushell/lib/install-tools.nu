use lua-run.nu 

# install tools defined in tools/spec.lua
export def main [] {
  let tools = lua-run get_tools | transpose manager cmd

  $tools | each {
    print "Found tool: " $in.manager 
  }

  $tools | each {
    print "Running: " $in.cmd
    run-external ...$in.cmd
  }

}

export def list [] {
  let tools = lua-run get_tools | transpose manager cmd
}
