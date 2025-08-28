defmodule Dirup.Markdown.Types do
  @moduledoc """
  Single-purpose markdown types. Each file can only be ONE thing.

  This is our internal spec - not advertised, just discovered.
  """

  @doc """
  Detect the singular purpose of a markdown file from its metadata.
  """
  def detect_type(content) do
    case extract_type_declaration(content) do
      {:ok, %{"@type" => "kyozo:Dockerfile"}} ->
        {:dockerfile, %{executor: "docker", action: "build"}}

      {:ok, %{"@type" => "kyozo:Configuration"}} ->
        {:config, %{parser: "yaml", mountable: true}}

      {:ok, %{"@type" => "kyozo:Repository"}} ->
        {:git_repo, %{vcs: "git", bare: false}}

      {:ok, %{"@type" => "kyozo:Executable"}} ->
        {:executable, %{interpreter: detect_interpreter(content)}}

      {:ok, %{"@type" => "kyozo:Database"}} ->
        {:database, %{engine: "sqlite", embedded: true}}

      {:ok, %{"@type" => "kyozo:Service"}} ->
        {:service, %{runtime: "systemd", autostart: true}}

      _ ->
        # Default - just a doc
        {:documentation, %{}}
    end
  end

  defp extract_type_declaration(content) do
    case Regex.run(~r/<!-- ({[^}]*"@type"[^}]*}) -->/, content) do
      [_, json] -> Jason.decode(json)
      _ -> {:error, :no_type}
    end
  end

  @doc """
  Each type has specific capabilities and constraints
  """
  def capabilities(type) do
    case type do
      :dockerfile ->
        %{
          can_build: true,
          can_execute: false,
          can_mount: false,
          produces: "docker_image"
        }

      :config ->
        %{
          can_build: false,
          can_execute: false,
          can_mount: true,
          produces: "mounted_config"
        }

      :git_repo ->
        %{
          can_build: false,
          # git commands
          can_execute: true,
          # as a git repo
          can_mount: true,
          produces: "git_repository"
        }

      :executable ->
        %{
          can_build: false,
          can_execute: true,
          can_mount: false,
          produces: "process"
        }

      :database ->
        %{
          # schema
          can_build: true,
          # queries
          can_execute: true,
          # as a db file
          can_mount: true,
          produces: "sqlite_db"
        }
    end
  end

  defp detect_interpreter(content) do
    cond do
      String.contains?(content, "#!/usr/bin/env python") -> "python"
      String.contains?(content, "#!/usr/bin/env ruby") -> "ruby"
      String.contains?(content, "#!/usr/bin/env node") -> "node"
      String.contains?(content, "#!/bin/bash") -> "bash"
      String.contains?(content, "#!/bin/sh") -> "sh"
      String.contains?(content, "```elixir") -> "elixir"
      String.contains?(content, "```python") -> "python"
      String.contains?(content, "```javascript") -> "javascript"
      String.contains?(content, "```bash") -> "bash"
      true -> "unknown"
    end
  end
end

# Example: Dockerfile that builds
"""
<!-- {"@type": "kyozo:Dockerfile", "@id": "app:builder"} -->
# My App

```dockerfile
FROM elixir:1.14
WORKDIR /app
COPY . .
RUN mix deps.get
```

This file can ONLY build Docker images. Nothing else.
"""

# Example: Config that mounts
"""
<!-- {"@type": "kyozo:Configuration", "@id": "config:app"} -->
# App Configuration

```yaml
database:
  host: localhost
  port: 5432
```

This file can ONLY be mounted as config. Can't execute.
"""

# Example: Git repo in a markdown file!
"""
<!-- {"@type": "kyozo:Repository", "@id": "repo:dotfiles"} -->
# My Dotfiles

```gitignore
.DS_Store
*.swp
```

```file:.zshrc
export EDITOR=vim
alias ll='ls -la'
```

```file:.vimrc
set number
set expandtab
```

This IS a git repository. You can clone it, commit to it, push it.
"""

# Example: Executable script
"""
<!-- {"@type": "kyozo:Executable", "@id": "script:deploy"} -->
# Deploy Script

```bash
#!/bin/bash
set -e
echo "Deploying..."
docker build -t app .
docker push app
kubectl apply -f k8s/
```

This file can ONLY execute. It's not config, not a builder.
"""

# Example: Embedded SQLite database!
"""
<!-- {"@type": "kyozo:Database", "@id": "db:users"} -->
# Users Database

```sql
CREATE TABLE users (
  id INTEGER PRIMARY KEY,
  email TEXT UNIQUE NOT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO users (email) VALUES ('admin@example.com');
```

This markdown file IS a SQLite database. Query it directly!
"""
