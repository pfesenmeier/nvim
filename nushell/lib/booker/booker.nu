module helpers {
  export def empty [] {
    { paths: [] }
  }

  export def save_file [] {
    if $nu.os-info.family == 'windows' {
       $env.TEMP | default $env.TMP
    } else {
       '/var/tmp'
    } | path join 'booker' 'booker.json' 
  }
  # get or create save file
  export def open_save_file [] {
    if (save_file | path exists | $in == false) {
       mkdir (save_file | path dirname)
       empty | to json | save (save_file) 
    }

    open (save_file)
  }

  export def save_save_file [] {
    $in | collect | save -f (save_file)
  }
}

use helpers *



# tool to save bookmarks
def bkr [] {  
  [
    $"(help bkr)"
    $"Saved bookmarks stored in: (save_file)"
  ] | str join (char newline)
}

# list bookmarks
def 'bkr ls' [] {
  open_save_file | get paths
}

# add bookmark to list
def 'bkr add' [path: string, name: string] {
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

  (
    open_save_file 
    | update paths { append { path: $path, name: $name } | sort-by name } 
    | save_save_file
  )
}

# change directory to a bookmark
def --env 'bkr cd' [name: string] {
   let path = open_save_file | get paths | where name == $name

   if ($path | is-empty) {
      bkr ls
   } else {
     cd ($path | first | $in.path)
     ls
   }
}

# remove a bookmark
def 'bkr remove' [name: string] {
  open_save_file | update paths {$in | where {|path| $path.name != $name }} | save_save_file
}

# remove all bookmarks
def 'bkr clear' [] {
  empty | to json | save_save_file
}
