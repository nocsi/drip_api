# Markdown & Notebooks in Kyozo

## Unified Approach

In Kyozo, there's no separation between markdown files and notebooks:
- **All documents are markdown files** (`.md` or `.markdown`)
- **Any markdown file can be opened as a notebook** for code execution
- **No special notebook format** - just standard markdown

## How It Works

### File Operations (for all markdown files)

1. **create** - Create new markdown file
2. **read** - Read file content
3. **update** - Update file content
4. **delete** - Delete file
5. **list** - List files in workspace
6. **duplicate** - Copy a file
7. **rename** - Rename a file
8. **move** - Move to different folder

### Notebook Operations (for markdown files with code)

1. **create_from_file** - Open a markdown file as notebook
2. **execute** - Execute all code blocks
3. **execute_task** - Execute specific code block
4. **stop_execution** - Stop running code
5. **reset_execution** - Clear execution state
6. **tasks** - List executable code blocks
7. **duplicate** - Duplicate as new notebook
8. **collaborate** - Enable real-time collaboration

## Example Workflow

```bash
# 1. Create a markdown file
POST /api/v1/files
{
  "file": {
    "name": "analysis.md",
    "content": "# Data Analysis\n\n```python\nimport pandas as pd\nprint('Hello')\n```"
  }
}

# 2. Open it as a notebook (when you need execution)
POST /api/v1/files/:file_id/notebooks

# 3. Execute the code
POST /api/v1/notebooks/:notebook_id/execute

# 4. Or just keep editing it as a regular markdown file
PATCH /api/v1/files/:file_id
{
  "file": {
    "content": "# Updated Analysis\n\nNew content here..."
  }
}
```

## Key Benefits

1. **No Format Lock-in**: Your files are always just markdown
2. **Progressive Enhancement**: Add execution only when needed
3. **Universal Compatibility**: Works with any markdown editor
4. **Clean Version Control**: Simple diffs in git
5. **Flexible Workflow**: Document-first or code-first, your choice

## When to Use What

### Use File API when:
- Creating/editing documentation
- Managing file organization
- Working with non-executable content
- Collaborating via git

### Use Notebook API when:
- Need to execute code blocks
- Want to see outputs inline
- Doing data analysis
- Creating interactive reports

## Markdown-LD (Linked Data)

For richer documents, embed JSON-LD:

```markdown
# Sales Report

<!-- 
{
  "@context": "https://schema.org",
  "@type": "Report",
  "dateCreated": "2024-12-20",
  "author": "Data Team"
}
-->

## Analysis

```python
# This code can be executed in notebook mode
sales_total = sum(sales_data)
print(f"Total: ${sales_total}")
```
```

This approach gives you the best of both worlds: simple markdown files that can become powerful notebooks when needed.