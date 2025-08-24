# Kyozo Markdown & Notebook System

A unified approach where standard markdown files can be treated as notebooks when needed.

## Overview

Kyozo uses a simple but powerful approach:
- **All documents are markdown** (`.md` or `.markdown` files)
- **Any markdown can become a notebook** - just open it in notebook mode
- **Markdown-LD** (Markdown with Linked Data) works especially well for structured content
- **No special formats** - just standard markdown that works everywhere

## How It Works

### 1. Regular Markdown Files
Create and edit markdown files normally:

```markdown
# My Document

This is a regular markdown file.

```python
# Code blocks can be executed when viewed as a notebook
def hello():
    return "world"
```

## Data Analysis

```sql
SELECT * FROM users LIMIT 10;
```
```

### 2. Notebook Mode
When you need to execute code, open any markdown file as a notebook:
- Extracts code blocks as executable "tasks"
- Maintains execution state
- Shows outputs inline
- Supports multiple languages

### 3. Markdown-LD (Linked Data)
For richer documents, use JSON-LD in HTML comments:

```markdown
# Product Analysis

<!-- 
{
  "@context": "https://schema.org",
  "@type": "Dataset",
  "name": "Q4 Sales Data",
  "description": "Quarterly sales analysis"
}
-->

```python
import pandas as pd
df = pd.read_csv('sales.csv')
df.head()
```
```

## Architecture

```
Files (markdown documents)
    ↓
Notebooks (execution layer)
    ↓
Tasks (extracted code blocks)
```

## Benefits

1. **No Lock-in**: Your files are just markdown
2. **Flexibility**: Use as documents or notebooks
3. **Git-Friendly**: Clean diffs, easy merging
4. **Universal**: Works with any markdown editor
5. **Progressive**: Add execution when needed

## API Usage

### Create a Markdown File
```bash
curl -X POST /api/v1/teams/:team_id/workspaces/:workspace_id/files \
  -d '{"file": {"name": "analysis.md", "content": "# Analysis\\n```python\\nprint(\"Hello\")\\n```"}}'
```

### Open as Notebook
```bash
curl -X POST /api/v1/teams/:team_id/files/:file_id/notebooks
```

### Execute Code
```bash
curl -X POST /api/v1/teams/:team_id/notebooks/:notebook_id/execute
```

## File Types

- `.md` - Standard markdown files
- `.markdown` - Alternative markdown extension
- No special notebook format needed!

## Best Practices

1. **Write Clean Markdown**: Use standard markdown syntax
2. **Annotate Code Blocks**: Use language identifiers (```python, ```sql, etc.)
3. **Use Markdown-LD**: Add structured data when beneficial
4. **Keep It Simple**: Don't over-engineer, it's just markdown

## Migration

If you have existing notebook files:
- `.ipynb` → Convert to markdown
- `.livemd` → Already markdown, just rename to `.md` (or keep as-is)
- `.rmd` → Extract to plain markdown

## Summary

The Kyozo approach is simple: **everything is markdown**. When you need notebook functionality, we provide it as a layer on top of your existing markdown files. No special formats, no lock-in, just markdown that can do more when you need it to.