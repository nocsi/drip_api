# Markdown Format Comparison: Standard Markdown vs Executable Notebooks

## What is Executable Markdown?

Executable markdown formats like LiveMD are used by applications like [Livebook](https://livebook.dev/) for interactive notebooks. They're essentially Markdown with embedded executable code cells and metadata.

## Livebook's Format

### Official Structure
```markdown
# Title

## Section

Some markdown content.

```elixir
# This is an executable code cell
IO.puts("Hello")
```

<!-- livebook:{"output":true} -->

```
Hello
```

<!-- livebook:{"branch_parent_index":0} -->

## Another Section

More content...
```

### Key Features of Livebook:
1. **Metadata in HTML comments**: `<!-- livebook:{"key": "value"} -->`
2. **Cell outputs**: Stored inline after code cells
3. **Branching**: Support for branched notebook sections
4. **Smart cells**: Special cells with UI components
5. **Persistence**: Complete notebook state saved in the file

### Livebook Metadata Examples:
```markdown
<!-- livebook:{"persist_outputs":true} -->
<!-- livebook:{"autosave_interval_s":30} -->
<!-- livebook:{"branch_parent_index":0} -->
<!-- livebook:{"continue_on_error":true} -->
<!-- livebook:{"reevaluate_automatically":true} -->
<!-- livebook:{"output":true} -->
```

## Kyozo's Markdown Format

### What We Actually Have:
```markdown
# Title

Some markdown content.

```elixir
# Code block (not necessarily executable)
IO.puts("Hello")
```

<!-- livebook:{"enlightenment": {"suggestions": "..."}} -->
```

### Key Differences:

1. **Standard Markdown**: We use regular `.md` files
2. **No Special Metadata**: Just standard markdown without notebook-specific metadata
3. **No Execution Model**: Plain documentation files
4. **Simple Storage**: Just markdown files
5. **VFS Integration**: Virtual files generated based on project context

## Our Implementation Details

### 1. No Parser Needed
- Standard markdown rendering only
- No cell parsing or execution
- Use existing markdown processors

### 2. No Execution
- Code blocks are for documentation only
- No runtime execution
- Use Polyglot system for infrastructure-as-code

### 3. Storage
- Files stored as regular `.md` files
- No execution state
- Simple file storage

## Decision Made

We decided to:

1. **Use standard `.md` extension** - Clear that it's just markdown
2. **Remove notebook functionality** - Keep it simple, use plain markdown
3. **VFS for dynamic docs** - Generate helpful documentation based on project context
4. **Polyglot for executable markdown** - When you need infrastructure-as-code
3. **Implement notebook compatibility** - Support various notebook formats

## Recommendation

We decided to:

1. **Use standard markdown** - All files are `.md` or `.markdown`
2. **Treat any markdown as a notebook** - When code execution is needed
3. **Support metadata via HTML comments** - For richer documents:
   ```markdown
   <!-- {"@context": "https://schema.org", "@type": "Dataset"} -->
   ```

## Working with Different Formats

If you have different notebook formats:

```elixir
# Import from various formats
def import_notebook(content, source_format) do
  case source_format do
    :livebook -> extract_from_livebook(content)
    :jupyter -> extract_from_jupyter(content) 
    :rmarkdown -> extract_from_rmarkdown(content)
    _ -> content  # Already plain markdown
  end
end

# All get converted to plain markdown
# Code execution is a separate layer
```