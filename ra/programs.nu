let programs = {
  rg: {
      winget: 'burntsushi'
      apt: true
  }
  nvim: {|name| print $name}
}
do $programs.nvim hello
