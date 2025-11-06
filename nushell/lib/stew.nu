let main = $nu.home-path | path join Code StewLang cli main.ts

def stew [...args] {
  deno run --allow-env --allow-read $main ...$args
}
