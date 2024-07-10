let local_tools_path = if $nu.os-info.family == 'windows' {
  [$nu.home-path AppData Local] | path join
} else {
  [$nu.home-path .local bin] | path join
}

let local_tools = [
    [artempyanykh marksman]
] | each {|tool| $local_tools_path | append $tool | path join }
  | filter {|| $in | path exists } 


if $nu.os-info.family == 'windows' {
  $env.Path = (
    $local_tools | reduce -f ($env.Path | split row (char esep)) {|it, acc| $acc | prepend $it } 
  )
} else {
  $env.PATH = (
    $local_tools | reduce -f ($env.PATH | split row (char esep)) {|it, acc| $acc | prepend $it } 
  )
} 
