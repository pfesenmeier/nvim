let main = $nu.home-path | path join Code StewLang cli main.ts

def stew [] {
  deno run --allow-env --allow-read $main
}
