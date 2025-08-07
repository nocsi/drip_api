defmodule Kyozo.Projects.Services.ProjectLoader do
  @moduledoc """
  Service module for loading and parsing projects from directories or files.
  Handles directory walking, gitignore patterns, markdown parsing, and task extraction.
  """

  require Logger

  @markdown_extensions [".md", ".markdown", ".mdown", ".mkd", ".mkdn"]
  @default_ignore_patterns [
    "node_modules/",
    ".git/",
    ".DS_Store",
    "*.tmp",
    "*.log",
    ".env*",
    "dist/",
    "build/",
    "target/",
    "*.pyc",
    "__pycache__/",
    ".pytest_cache/",
    ".coverage",
    "coverage/",
    ".nyc_output/",
    "*.min.js",
    "*.min.css"
  ]

  @doc """
  Walks a directory and returns a list of files and directories found.
  Respects gitignore patterns and custom ignore patterns.
  """
  def walk_directory(path, opts \\ []) do
    skip_gitignore = Keyword.get(opts, :skip_gitignore, false)
    ignore_patterns = Keyword.get(opts, :ignore_patterns, [])
    skip_repo_lookup = Keyword.get(opts, :skip_repo_lookup, false)

    # Load gitignore patterns if not skipped
    gitignore_patterns = if skip_gitignore do
      []
    else
      load_gitignore_patterns(path, skip_repo_lookup)
    end

    # Combine all ignore patterns
    all_patterns = @default_ignore_patterns ++ gitignore_patterns ++ ignore_patterns

    # Walk the directory
    do_walk_directory(path, path, all_patterns, [])
  end

  @doc """
  Checks if a file is a markdown file based on its extension.
  """
  def is_markdown_file?(file_path) do
    extension = Path.extname(file_path) |> String.downcase()
    extension in @markdown_extensions
  end

  @doc """
  Parses markdown content and returns a structured representation.
  """
  def parse_markdown_content(content) do
    try do
      # Simple markdown parsing - in a real implementation you might use a proper markdown parser
      lines = String.split(content, "\n")
      
      blocks = parse_markdown_blocks(lines, [])
      
      %{
        type: "markdown",
        blocks: blocks,
        line_count: length(lines),
        word_count: count_words(content)
      }
    rescue
      error ->
        Logger.error("Failed to parse markdown content: #{Exception.message(error)}")
        %{type: "error", error: Exception.message(error)}
    end
  end

  @doc """
  Extracts executable tasks (code blocks) from markdown content.
  """
  def extract_tasks_from_markdown(content, identity_mode \\ :unspecified) do
    try do
      lines = String.split(content, "\n")
      extract_code_blocks(lines, identity_mode, [])
    rescue
      error ->
        Logger.error("Failed to extract tasks from markdown: #{Exception.message(error)}")
        []
    end
  end

  # Private functions

  defp do_walk_directory(current_path, root_path, ignore_patterns, acc) do
    case File.ls(current_path) do
      {:ok, entries} ->
        Enum.reduce(entries, acc, fn entry, acc ->
          entry_path = Path.join(current_path, entry)
          relative_path = Path.relative_to(entry_path, root_path)

          # Check if this path should be ignored
          if should_ignore?(relative_path, ignore_patterns) do
            acc
          else
            case File.stat(entry_path) do
              {:ok, %File.Stat{type: :directory}} ->
                new_acc = [{:dir, entry_path} | acc]
                do_walk_directory(entry_path, root_path, ignore_patterns, new_acc)

              {:ok, %File.Stat{type: :regular}} ->
                [{:file, entry_path} | acc]

              _ ->
                acc
            end
          end
        end)

      {:error, reason} ->
        Logger.warning("Failed to read directory #{current_path}: #{reason}")
        acc
    end
  end

  defp should_ignore?(relative_path, ignore_patterns) do
    Enum.any?(ignore_patterns, fn pattern ->
      matches_pattern?(relative_path, pattern)
    end)
  end

  defp matches_pattern?(path, pattern) do
    # Simple pattern matching - supports basic wildcards and directory patterns
    cond do
      String.ends_with?(pattern, "/") ->
        # Directory pattern
        dir_pattern = String.trim_trailing(pattern, "/")
        String.starts_with?(path, dir_pattern <> "/") or path == dir_pattern

      String.contains?(pattern, "*") ->
        # Wildcard pattern
        regex_pattern = 
          pattern
          |> String.replace(".", "\\.")
          |> String.replace("*", ".*")
          |> then(&("^" <> &1 <> "$"))
        
        case Regex.compile(regex_pattern) do
          {:ok, regex} -> Regex.match?(regex, path)
          _ -> false
        end

      true ->
        # Exact match or substring
        String.contains?(path, pattern)
    end
  end

  defp load_gitignore_patterns(path, skip_repo_lookup) do
    patterns = []

    # Load .gitignore from current directory
    gitignore_path = Path.join(path, ".gitignore")
    patterns = if File.exists?(gitignore_path) do
      case File.read(gitignore_path) do
        {:ok, content} -> patterns ++ parse_gitignore_content(content)
        _ -> patterns
      end
    else
      patterns
    end

    # Load .git/info/exclude if not skipping repo lookup
    if not skip_repo_lookup do
      git_exclude_path = find_git_exclude(path)
      if git_exclude_path && File.exists?(git_exclude_path) do
        case File.read(git_exclude_path) do
          {:ok, content} -> patterns ++ parse_gitignore_content(content)
          _ -> patterns
        end
      else
        patterns
      end
    else
      patterns
    end
  end

  defp find_git_exclude(path) do
    git_dir = find_git_directory(path)
    if git_dir do
      Path.join([git_dir, "info", "exclude"])
    end
  end

  defp find_git_directory(path) do
    git_path = Path.join(path, ".git")
    
    cond do
      File.dir?(git_path) ->
        git_path

      File.exists?(git_path) ->
        # .git might be a file pointing to the real .git directory
        case File.read(git_path) do
          {:ok, content} ->
            if String.starts_with?(content, "gitdir: ") do
              String.trim(content)
              |> String.replace_prefix("gitdir: ", "")
              |> Path.expand(path)
            end
          _ -> nil
        end

      path != "/" and path != Path.dirname(path) ->
        find_git_directory(Path.dirname(path))

      true ->
        nil
    end
  end

  defp parse_gitignore_content(content) do
    content
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(fn line ->
      line == "" or String.starts_with?(line, "#")
    end)
    |> Enum.map(fn line ->
      # Remove leading slash
      if String.starts_with?(line, "/") do
        String.slice(line, 1..-1//-1)
      else
        line
      end
    end)
  end

  defp parse_markdown_blocks([], acc), do: Enum.reverse(acc)

  defp parse_markdown_blocks([line | rest], acc) do
    cond do
      # Heading
      String.starts_with?(line, "#") ->
        level = count_leading_chars(line, "#")
        title = String.trim(String.slice(line, level..-1//-1))
        block = %{type: "heading", level: level, title: title}
        parse_markdown_blocks(rest, [block | acc])

      # Code block start
      String.starts_with?(line, "```") ->
        language = String.trim(String.slice(line, 3..-1))
        {code_lines, remaining_lines} = extract_code_block(rest, [])
        code = Enum.join(code_lines, "\n")
        block = %{
          type: "code_block",
          language: if(language != "", do: language, else: nil),
          code: code
        }
        parse_markdown_blocks(remaining_lines, [block | acc])

      # Regular paragraph
      line != "" ->
        block = %{type: "paragraph", content: line}
        parse_markdown_blocks(rest, [block | acc])

      # Empty line
      true ->
        parse_markdown_blocks(rest, acc)
    end
  end

  defp extract_code_block([], acc), do: {Enum.reverse(acc), []}

  defp extract_code_block([line | rest], acc) do
    if String.starts_with?(line, "```") do
      {Enum.reverse(acc), rest}
    else
      extract_code_block(rest, [line | acc])
    end
  end

  defp extract_code_blocks([], _identity_mode, acc), do: Enum.reverse(acc)

  defp extract_code_blocks([line | rest], identity_mode, acc) do
    if String.starts_with?(line, "```") do
      language = String.trim(String.slice(line, 3..-1//-1))
      {code_lines, remaining_lines, line_start} = extract_code_block_with_position(rest, [], length(acc) + 2)
      
      if code_lines != [] do
        code = Enum.join(code_lines, "\n")
        line_end = line_start + length(code_lines) - 1
        
        task = %{
          runme_id: generate_runme_id(identity_mode, code, length(acc)),
          name: generate_task_name(language, length(acc) + 1),
          is_name_generated: true,
          language: if(language != "", do: language, else: nil),
          code: code,
          line_start: line_start,
          line_end: line_end,
          is_executable: is_executable_language?(language),
          timeout_seconds: get_default_timeout(language)
        }
        
        extract_code_blocks(remaining_lines, identity_mode, [task | acc])
      else
        extract_code_blocks(remaining_lines, identity_mode, acc)
      end
    else
      extract_code_blocks(rest, identity_mode, acc)
    end
  end

  defp extract_code_block_with_position([], acc, line_start), do: {Enum.reverse(acc), [], line_start}

  defp extract_code_block_with_position([line | rest], acc, line_start) do
    if String.starts_with?(line, "```") do
      {Enum.reverse(acc), rest, line_start}
    else
      extract_code_block_with_position(rest, [line | acc], line_start)
    end
  end

  defp generate_runme_id(identity_mode, code, index) do
    case identity_mode do
      :unspecified -> nil
      :all -> generate_id_from_content(code, index)
      :cell -> generate_id_from_content(code, index)
      :document -> nil
      _ -> nil
    end
  end

  defp generate_id_from_content(code, index) do
    # Generate a deterministic ID based on code content and position
    hash = :crypto.hash(:sha256, "#{code}#{index}")
    Base.encode16(hash, case: :lower) |> String.slice(0, 16)
  end

  defp generate_task_name(language, index) do
    language_name = case String.downcase(language || "code") do
      "py" -> "Python"
      "python" -> "Python"
      "js" -> "JavaScript"
      "javascript" -> "JavaScript"
      "ts" -> "TypeScript"
      "typescript" -> "TypeScript"
      "rb" -> "Ruby"
      "ruby" -> "Ruby"
      "go" -> "Go"
      "rust" -> "Rust"
      "rs" -> "Rust"
      "java" -> "Java"
      "c" -> "C"
      "cpp" -> "C++"
      "cxx" -> "C++"
      "sh" -> "Shell"
      "bash" -> "Shell"
      "zsh" -> "Shell"
      "fish" -> "Shell"
      "powershell" -> "PowerShell"
      "ps1" -> "PowerShell"
      "sql" -> "SQL"
      "r" -> "R"
      "scala" -> "Scala"
      "kotlin" -> "Kotlin"
      "swift" -> "Swift"
      "php" -> "PHP"
      "html" -> "HTML"
      "css" -> "CSS"
      "scss" -> "SCSS"
      "sass" -> "Sass"
      "yaml" -> "YAML"
      "yml" -> "YAML"
      "json" -> "JSON"
      "xml" -> "XML"
      "dockerfile" -> "Docker"
      other -> String.capitalize(other)
    end

    "#{language_name} Task #{index}"
  end

  defp is_executable_language?(language) do
    executable_languages = [
      "python", "py", "javascript", "js", "typescript", "ts",
      "ruby", "rb", "go", "rust", "rs", "java", "c", "cpp", "cxx",
      "sh", "bash", "zsh", "fish", "powershell", "ps1", "sql", "r",
      "scala", "kotlin", "swift", "php"
    ]
    
    String.downcase(language || "") in executable_languages
  end

  defp get_default_timeout(language) do
    case String.downcase(language || "") do
      lang when lang in ["python", "py"] -> 60
      lang when lang in ["javascript", "js", "typescript", "ts"] -> 30
      lang when lang in ["sh", "bash", "zsh", "fish"] -> 30
      lang when lang in ["sql"] -> 120
      lang when lang in ["r"] -> 90
      lang when lang in ["java", "scala", "kotlin"] -> 120
      lang when lang in ["go", "rust", "rs", "c", "cpp", "cxx"] -> 60
      _ -> 30
    end
  end

  defp count_leading_chars(string, char) do
    string
    |> String.graphemes()
    |> Enum.take_while(&(&1 == char))
    |> length()
  end

  defp count_words(content) do
    content
    |> String.split(~r/\s+/)
    |> Enum.reject(&(&1 == ""))
    |> length()
  end
end