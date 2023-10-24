export def is-non-empty [] {
  ($in | is-empty) == false
}

export def dump [] {
  let result = $in;
  $result | print
  $result
}

