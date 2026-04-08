# Jo - Job Runner

## Problem

At different times, I have long-running jobs I want to run and re-run.
`dotnet test`, `claude -p "/pr-review` , `dotnet build`, etc..
These are dependent on the working directory and the workspace.
These are invoked within a shell tab, a neovim session, etc..

## Solution

I'd like to build a pair of commands, one for a server, and one to send messages to it (client).
There will also be some sort of UI around the server.

The client will send messages to (re)start or kill jobs, with details like
- the command
- the working dir
- the jj workspace
- the command "key"
- whether or not to kill other jobs with same key (e.g., I am starting the api in a workspace and I want to stop all other instances)

- it will also be able to query the jobs, e.g.:
    - get all jobs, get all by key
    - status (running, stopped, failed)

## Client Spec

api supports
 - jo start <job> (restart)
 - jo stop  <job>
 - jo request {parameters} # jo start/stop will call this under the hood. useful for debugging as well
 - jo info <job> [--log] [--json]
TODO: not MVP
 - jo attach <job> - is this also an http endpoint, socket?

## Client Config Spec

To ease typing, there should be a global config file, ~/jo.config.json (TODO: location)

config:

```json
{
  "key": "test",
  "command": "dotnet test",
  "folder": "$JJ_ROOT/Foo.Tests/"
}
# returns <id>
```

not MVP: parameterized commands, e.g. test filters, dynamic folder names

## Server Spec

- jo serve
- jo serve --json
  
- server outputs logs
[default|test-api] <log line>
[second|api] <log line>

- saves job history to ~/.config/jo/history/<repo>/<workspace>/<key>/<timestamp>
  OR... timestamp_key_workspace_repo
- saves client history to ~/.config/jo/client-history.txt

main loop ->
  -> process for messages from api job (stop / stop jobs)
  -> check for messages from jobs themselves
  -> bell character if exited

**could run an API server on a background thread, queue up jobs. good for validating input**
localhost:1234/request
which sends a "job" to the main thread

## Server UI Spec

- my initial idea is to build a nvim plugin that can be run in a dedicated terminal to display / manage the server.
- e.g., nvim +JoStart
- it will run a server in one hidden terminal.
- button that reads history and offers jobs to re-run
- lua parses log output and splits the logs into separate tabs
- options for viewing (grouped by workspace, key, etc..)
- tabs separate key presses for restarting, stopping jobs, which calls the jo client

**instead of job recv ->use lua to manage the jobs via buffers?**

## TODO

- how to resume claude sessions, if desired?

- if I need to branch out of nushell's std lib (say for api request handling, would I be better off using, say, C# and spectre.console?

