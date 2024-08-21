
let save_file = if $nu.os-info.family == 'windows' {
   $env.TEMP | default $env.TMP
} else {
   '/var/tmp'
} | path join 'booker' 'booker.txt' 

# tool to save bookmarks
def booker [] {  
  [
    $"(help booker)"
    $"Saved bookmarks stored in: ($save_file)"
  ] | str join (char newline)
}

# get or create save file
def open_save_file [] {
  if ($save_file | path exists | $in == false) {
     mkdir ($save_file | path dirname)
     touch $save_file
  }

  open $save_file | lines
}

def save_save_file [] {
  $in | collect | save -f $save_file
}

def 'booker list' [] {
  open_save_file | enumerate
}

def 'booker add' [path: string] {
  let span = (metadata $path).span

  let path = $path | path expand

  if ($path | path type | $in != 'dir') {
    let text = if ($path | path exists) {
      "this path is not a directory"
    } else {
      "this path does not exist"
    }

    error make {
      msg: "must pass in path to directory",
      label: {
        text: $text
        span: $span  
      }
    }
  }

  open_save_file | append $path | save_save_file
}

def 'booker clear' [] {
  "" | save_save_file
}
