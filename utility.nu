export def is-not-empty [] {
  ($in | is-empty) == false
}

export def is-false [] {
  $in == false
}

export def is-true [] {
  $in == true
}

# returns table with col key value
# of first non-empty 
export def coalesce [
  ...cols: string # list of columns
] {
  let result = (
    select $cols 
    | transpose key value 
    | where {|it| $it.value | is-empty | is-false } 
  )
  if ($result | is-empty) {
    $result
  } else {
    $result | first
  }
}

# export def filter-reject-warn-if-empty [
#  col: string 
#  msg: closure
# ] {
#   
# }

export def dump [] {
  let result = $in;
  $result | print
  $result
}

