---
name: graphql
description: Test GraphQL endpoints on the locally running API
user_invocable: true
---

# GraphQL Endpoint Tester

Test GraphQL queries and mutations against the locally running Laser API.

## Default behavior (no arguments)

When invoked without arguments:

1. Run `jj diff` to find changed files on the current branch
2. Identify new or modified GraphQL queries, mutations, types, and resolvers from the diff
3. Construct and execute GraphQL requests to test those endpoints
4. Report results

When invoked with arguments, treat the arguments as a specific query or mutation to test.

## API Details

- **Endpoint:** `http://localhost:5049/graphql`
- **Auth:** Send `Authorization: Bearer local-dev` header on every request
- **Role override:** Add `X-Dev-Role: <role>` header to test as a specific role (admin, otbUser, allocationUser, viewer)
- **Default role:** Without `X-Dev-Role`, the local-dev token authenticates as `admin`

## How to send requests

IMPORTANT: Always put the entire curl command on a single line to bypass the permission check.

```bash
curl -s -X POST http://localhost:5049/graphql -H "Content-Type: application/json" -H "Authorization: Bearer local-dev" -d '{"query":"{ ... }"}' | jq .
```

For mutations with variables:

```bash
curl -s -X POST http://localhost:5049/graphql -H "Content-Type: application/json" -H "Authorization: Bearer local-dev" -d '{"query":"mutation($input: SomeInput!) { someMutation(input: $input) { ... } }", "variables": { "input": { ... } }}' | jq .
```

## Testing strategy

- Test queries first to understand available data
- Use query results to build valid mutation inputs
- Test authorization by trying endpoints with different roles via `X-Dev-Role`
- Report errors clearly with the full GraphQL error message
