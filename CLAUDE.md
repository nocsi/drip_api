<!-- usage-rules-start -->
<!-- usage-rules-header -->

# Usage Rules

**IMPORTANT**: Consult these usage rules early and often when working with the packages listed below.
Before attempting to use any of these packages or to discover if you should use them, review their
usage rules to understand the correct patterns, conventions, and best practices.

<!-- usage-rules-header-end -->

<!-- igniter-start -->

## igniter usage

_A code generation and project patching framework_

[igniter usage rules](deps/igniter/usage-rules.md)

<!-- igniter-end -->
<!-- ash_json_api-start -->

## ash_json_api usage

_The JSON:API extension for the Ash Framework._

[ash_json_api usage rules](deps/ash_json_api/usage-rules.md)

<!-- ash_json_api-end -->
<!-- claude-start -->

## claude usage

_Batteries-included Claude Code integration for Elixir projects_

[claude usage rules](deps/claude/usage-rules.md)

<!-- claude-end -->
<!-- claude:subagents-start -->

## claude:subagents usage

# Subagents Usage Rules

## Overview

Subagents in Claude projects should be configured via `.claude.exs` and installed using `mix claude.install`. This ensures consistent setup and proper integration with your project.

## Key Concepts

### Clean Slate Limitation

Subagents start with a clean slate on every invocation - they have no memory of previous interactions or context. This means:

- Context gathering operations (file reads, searches) are repeated each time
- Previous decisions or analysis must be rediscovered
- Consider embedding critical context directly in the prompt if repeatedly needed

### Tool Inheritance Behavior

When `tools` is omitted, subagents inherit ALL tools including dynamically loaded MCP tools. When specified:

- The list becomes static - new MCP tools won't be available
- Subagents without `:task` tool cannot delegate to other subagents
- Tool restrictions are enforced at invocation time, not definition time

## Configuration in .claude.exs

### Basic Structure

```elixir
%{
  subagents: [
    %{
      name: "Your Agent Name",
      description: "Clear description of when to use this agent",
      prompt: "Detailed system prompt for the agent",
      tools: [:read, :write, :edit],  # Optional - defaults to all tools
      usage_rules: ["package:rule"]    # Optional - includes specific usage rules
    }
  ]
}
```

### Required Fields

- **name**: Human-readable name (will be converted to kebab-case for filename)
- **description**: Clear trigger description for automatic delegation
- **prompt**: The system prompt that defines the agent's expertise

### Optional Fields

- **tools**: List of tool atoms to restrict access (defaults to all tools if omitted)
- **usage_rules**: List of usage rules to include in the agent's prompt

## References

- [Subagents](https://docs.anthropic.com/en/docs/claude-code/sub-agents.md)
- [Claude Code Settings](https://docs.anthropic.com/en/docs/claude-code/settings.md)
- [Claude Code Hooks](https://docs.anthropic.com/en/docs/claude-code/hooks.md)

<!-- claude:subagents-end -->
<!-- ash_authentication-start -->

## ash_authentication usage

_Authentication extension for the Ash Framework._

[ash_authentication usage rules](deps/ash_authentication/usage-rules.md)

<!-- ash_authentication-end -->
<!-- ash_phoenix-start -->

## ash_phoenix usage

_Utilities for integrating Ash and Phoenix_

[ash_phoenix usage rules](deps/ash_phoenix/usage-rules.md)

<!-- ash_phoenix-end -->
<!-- usage_rules-start -->

## usage_rules usage

_A dev tool for Elixir projects to gather LLM usage rules from dependencies_

## Using Usage Rules

Many packages have usage rules, which you should _thoroughly_ consult before taking any
action. These usage rules contain guidelines and rules _directly from the package authors_.
They are your best source of knowledge for making decisions.

## Modules & functions in the current app and dependencies

When looking for docs for modules & functions that are dependencies of the current project,
or for Elixir itself, use `mix usage_rules.docs`

```
# Search a whole module
mix usage_rules.docs Enum

# Search a specific function
mix usage_rules.docs Enum.zip

# Search a specific function & arity
mix usage_rules.docs Enum.zip/1
```

## Searching Documentation

You should also consult the documentation of any tools you are using, early and often. The best
way to accomplish this is to use the `usage_rules.search_docs` mix task. Once you have
found what you are looking for, use the links in the search results to get more detail. For example:

```
# Search docs for all packages in the current application, including Elixir
mix usage_rules.search_docs Enum.zip

# Search docs for specific packages
mix usage_rules.search_docs Req.get -p req

# Search docs for multi-word queries
mix usage_rules.search_docs "making requests" -p req

# Search only in titles (useful for finding specific functions/modules)
mix usage_rules.search_docs "Enum.zip" --query-by title
```

<!-- usage_rules-end -->
<!-- usage_rules:elixir-start -->

## usage_rules:elixir usage

# Elixir Core Usage Rules

## Pattern Matching

- Use pattern matching over conditional logic when possible
- Prefer to match on function heads instead of using `if`/`else` or `case` in function bodies

## Error Handling

- Use `{:ok, result}` and `{:error, reason}` tuples for operations that can fail
- Avoid raising exceptions for control flow
- Use `with` for chaining operations that return `{:ok, _}` or `{:error, _}`

## Common Mistakes to Avoid

- Elixir has no `return` statement, nor early returns. The last expression in a block is always returned.
- Don't use `Enum` functions on large collections when `Stream` is more appropriate
- Avoid nested `case` statements - refactor to a single `case`, `with` or separate functions
- Don't use `String.to_atom/1` on user input (memory leak risk)
- Lists and enumerables cannot be indexed with brackets. Use pattern matching or `Enum` functions
- Prefer `Enum` functions like `Enum.reduce` over recursion
- When recursion is necessary, prefer to use pattern matching in function heads for base case detection
- Using the process dictionary is typically a sign of unidiomatic code
- Only use macros if explicitly requested
- There are many useful standard library functions, prefer to use them where possible

## Function Design

- Use guard clauses: `when is_binary(name) and byte_size(name) > 0`
- Prefer multiple function clauses over complex conditional logic
- Name functions descriptively: `calculate_total_price/2` not `calc/2`
- Predicate function names should not start with `is` and should end in a question mark.
- Names like `is_thing` should be reserved for guards

## Data Structures

- Use structs over maps when the shape is known: `defstruct [:name, :age]`
- Prefer keyword lists for options: `[timeout: 5000, retries: 3]`
- Use maps for dynamic key-value data
- Prefer to prepend to lists `[new | list]` not `list ++ [new]`

## Mix Tasks

- Use `mix help` to list available mix tasks
- Use `mix help task_name` to get docs for an individual task
- Read the docs and options fully before using tasks

## Testing

- Run tests in a specific file with `mix test test/my_test.exs` and a specific test with the line number `mix test path/to/test.exs:123`
- Limit the number of failed tests with `mix test --max-failures n`
- Use `@tag` to tag specific tests, and `mix test --only tag` to run only those tests
- Use `assert_raise` for testing expected exceptions: `assert_raise ArgumentError, fn -> invalid_function() end`
- Use `mix help test` to for full documentation on running tests

## Debugging

- Use `dbg/1` to print values while debugging. This will display the formatted value and other relevant information in the console.

<!-- usage_rules:elixir-end -->
<!-- usage_rules:otp-start -->

## usage_rules:otp usage

# OTP Usage Rules

## GenServer Best Practices

- Keep state simple and serializable
- Handle all expected messages explicitly
- Use `handle_continue/2` for post-init work
- Implement proper cleanup in `terminate/2` when necessary

## Process Communication

- Use `GenServer.call/3` for synchronous requests expecting replies
- Use `GenServer.cast/2` for fire-and-forget messages.
- When in doubt, us `call` over `cast`, to ensure back-pressure
- Set appropriate timeouts for `call/3` operations

## Fault Tolerance

- Set up processes such that they can handle crashing and being restarted by supervisors
- Use `:max_restarts` and `:max_seconds` to prevent restart loops

## Task and Async

- Use `Task.Supervisor` for better fault tolerance
- Handle task failures with `Task.yield/2` or `Task.shutdown/2`
- Set appropriate task timeouts
- Use `Task.async_stream/3` for concurrent enumeration with back-pressure

<!-- usage_rules:otp-end -->
<!-- ash-start -->

## ash usage

_A declarative, extensible framework for building Elixir applications._

[ash usage rules](deps/ash/usage-rules.md)

<!-- ash-end -->
<!-- ash_graphql-start -->

## ash_graphql usage

_The extension for building GraphQL APIs with Ash_

[ash_graphql usage rules](deps/ash_graphql/usage-rules.md)

<!-- ash_graphql-end -->
<!-- ash_postgres-start -->

## ash_postgres usage

_The PostgreSQL data layer for Ash Framework_

[ash_postgres usage rules](deps/ash_postgres/usage-rules.md)

<!-- ash_postgres-end -->
<!-- kyozo_project-start -->

## kyozo_project usage

_Project-specific rules for the Kyozo application_

# Kyozo Project Usage Rules

## Editor Components

**CRITICAL**: Do NOT reimplement TipTapEditor or TipTapToolbar components.

### Use the Existing Editor

- ALWAYS use `Editor.svelte` located at `/assets/svelte/Editor.svelte`
- This component uses the `elim` package components: `ShadcnEditor`, `ShadcnToolBar`, `ShadcnBubbleMenu`, `ShadcnDragHandle`
- The existing Editor.svelte is properly integrated with LiveView hooks and the elim package

### Do NOT Create New Editor Components

- Do NOT create new files like `TipTapEditor.svelte` or `TipTapToolbar.svelte`
- Do NOT reimplement editor functionality from scratch
- If editor functionality needs modification, edit the existing `Editor.svelte` component

## Icon Imports

**CRITICAL**: Always use the correct Lucide import path.

### Correct Import Syntax

```typescript
// CORRECT - Use @lucide/svelte
import { Users, Plus, Mail, Settings } from "@lucide/svelte";

// WRONG - Do not use lucide-svelte
import { Users, Plus, Mail, Settings } from "lucide-svelte";
```

### Import Path Rules

- ALWAYS use `@lucide/svelte` for Lucide icon imports
- NEVER use `lucide-svelte` (without the @) as this causes build failures
- Check existing files for reference if unsure about import paths

## Svelte 5 Compatibility

### Use Modern Svelte 5 Syntax

- Use `$props()` instead of `export let`
- Use `onclick` instead of `on:click`
- Use `onchange` instead of `on:change`
- Use `$state()` for reactive variables
- Use `$derived()` for computed values
- Avoid `<svelte:component>` in runes mode - use conditional rendering instead

### Event Handler Pattern

```typescript
// CORRECT - Svelte 5 syntax
<button onclick={() => handleClick()}>Click me</button>

// DEPRECATED - Svelte 4 syntax (generates warnings)
<button on:click={() => handleClick()}>Click me</button>
```

## File Organization

### Component Locations

- UI components are in `/assets/svelte/ui/`
- App-specific components are in `/assets/svelte/[domain]/`
- The main Editor component is at `/assets/svelte/Editor.svelte`

### Import Paths

- Use relative imports for project components: `import Component from '../ui/component'`
- Use `@lucide/svelte` for icons
- Use proper paths for UI components from the established UI library structure
<!-- kyozo_project-end -->

<!-- usage-rules-end -->
