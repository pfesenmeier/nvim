param (
  [Parameter(Mandatory=$true)]
  # Name of the environment variable
  [string] $Variable,
  # Value of the environment variable
  [string] $Value,
  # Target. Accepted values: "User", "Machine", "Process"
  [string] $Target = "user"
)

[Environment]::SetEnvironmentVariable($Variable, $Value, $Target);
