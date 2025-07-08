# https://aider.chat/docs/llms/github.html#where-do-i-get-the-token
let apps_path = if $nu.os-info.family == 'windows' {
  $env.LOCALAPPDATA | path join github-copilot apps.json
} else  {
  $env.HOME | path join .config github-copilot apps.json
}

let profile = open $apps_path | values | first

$env.OPENAI_API_BASE = 'https://api.githubcopilot.com'
$env.OPENAI_API_KEY = $profile.oauth_token
