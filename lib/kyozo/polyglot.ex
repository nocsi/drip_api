defmodule Kyozo.Polyglot do
  @moduledoc """
  Polyglot: Markdown that speaks many languages.

  A parser and transpiler that makes markdown do things it was never meant to do.
  Because markdown has no syntax errors (markdown ::= .*), we can hide anything in it.

  ## Examples

      # This markdown is actually a Dockerfile
      "# My App\\n```dockerfile\\nFROM elixir:1.14\\n```"
      |> Polyglot.parse()
      |> Polyglot.transpile(:docker)
      |> Docker.build()

      # This markdown is actually a git repository
      "# Dotfiles\\n```file:.zshrc\\nexport EDITOR=vim\\n```"
      |> Polyglot.parse()
      |> Polyglot.transpile(:git)
      |> Git.init()

      # This markdown is actually executable
      "# Deploy\\n<!-- polyglot:executable -->\\n```bash\\nkubectl apply -f k8s/\\n```"
      |> Polyglot.parse()
      |> Polyglot.execute()
  """

  defstruct [
    # Original markdown
    :source,
    # What this markdown really is
    :language,
    # Parsed AST
    :ast,
    # Hidden metadata
    :metadata,
    # Extracted executable parts
    :artifacts,
    # Transpilation target
    :target
  ]

  @type language ::
          :dockerfile | :terraform | :kubernetes | :sql | :git | :config | :executable | :document
  @type t :: %__MODULE__{
          source: String.t(),
          language: language(),
          ast: list(),
          metadata: map(),
          artifacts: list(),
          target: atom() | nil
        }

  # ---- Core API ----

  @doc """
  Parse markdown and detect what it really is.
  """
  def parse(markdown) when is_binary(markdown) do
    %__MODULE__{
      source: markdown,
      language: detect_language(markdown),
      ast: build_ast(markdown),
      metadata: extract_metadata(markdown),
      artifacts: extract_artifacts(markdown),
      target: nil
    }
  end

  @doc """
  Transpile markdown to another format.
  """
  def transpile(%__MODULE__{} = polyglot, target) do
    transpiler = get_transpiler(target)

    %{polyglot | target: target}
    |> transpiler.transpile()
  end

  @doc """
  Execute the markdown based on what it is.
  """
  def execute(%__MODULE__{language: language} = polyglot) do
    executor = get_executor(language)
    executor.execute(polyglot)
  end

  # ---- Language Detection ----

  defp detect_language(markdown) do
    cond do
      # Explicit declaration
      declares_type?(markdown, "Dockerfile") -> :dockerfile
      declares_type?(markdown, "Terraform") -> :terraform
      declares_type?(markdown, "Kubernetes") -> :kubernetes
      declares_type?(markdown, "Repository") -> :git
      declares_type?(markdown, "Database") -> :sql
      declares_type?(markdown, "Configuration") -> :config
      declares_type?(markdown, "Executable") -> :executable
      # Implicit detection - more specific first
      has_kubernetes?(markdown) -> :kubernetes
      has_terraform?(markdown) -> :terraform
      has_sql_schema?(markdown) -> :sql
      has_file_blocks?(markdown) -> :git
      has_shebang?(markdown) -> :executable
      has_dockerfile?(markdown) -> :dockerfile
      # Default
      true -> :document
    end
  end

  defp declares_type?(markdown, type) do
    markdown =~ ~r/@type.*?#{type}|polyglot:.*?#{String.downcase(type)}/
  end

  # ---- Language Detection Helpers ----

  defp has_dockerfile?(markdown) do
    markdown =~ ~r/```dockerfile/i or
      (markdown =~ ~r/FROM\s+[\w:\.-]+/m and
         (markdown =~ ~r/RUN\s+/ or markdown =~ ~r/COPY\s+/ or markdown =~ ~r/WORKDIR\s+/ or
            markdown =~ ~r/EXPOSE\s+\d+/ or markdown =~ ~r/CMD\s+/))
  end

  defp has_terraform?(markdown) do
    markdown =~ ~r/```terraform/i or
      markdown =~ ~r/```hcl/i or
      markdown =~ ~r/resource\s+"[\w_]+"/ or
      markdown =~ ~r/provider\s+"[\w_]+"/ or
      markdown =~ ~r/variable\s+"[\w_]+"/
  end

  defp has_kubernetes?(markdown) do
    markdown =~ ~r/```yaml/i and
      (markdown =~ ~r/apiVersion:/ or
         markdown =~ ~r/kind:\s*(Deployment|Service|Pod|ConfigMap)/ or
         markdown =~ ~r/metadata:/ or
         markdown =~ ~r/spec:/)
  end

  defp has_sql_schema?(markdown) do
    markdown =~ ~r/```sql/i or
      markdown =~ ~r/CREATE\s+TABLE/i or
      markdown =~ ~r/CREATE\s+DATABASE/i or
      markdown =~ ~r/ALTER\s+TABLE/i or
      markdown =~ ~r/DROP\s+TABLE/i or
      markdown =~ ~r/INSERT\s+INTO/i or
      markdown =~ ~r/SELECT\s+.+\s+FROM/i or
      markdown =~ ~r/CREATE\s+INDEX/i
  end

  defp has_file_blocks?(markdown) do
    markdown =~ ~r/```file:/ or
      markdown =~ ~r/```[^`]*\.(py|js|rb|go|rs|java|php|c|cpp|h)/
  end

  defp has_shebang?(markdown) do
    markdown =~ ~r/#!/ or
      markdown =~ ~r/```bash/ or
      markdown =~ ~r/```shell/ or
      markdown =~ ~r/```sh/
  end

  # ---- AST Building ----

  defp build_ast(markdown) do
    markdown
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.reduce([], fn {line, num}, acc ->
      cond do
        String.starts_with?(line, "# ") ->
          [%{type: :header, level: 1, text: String.slice(line, 2..-1//1), line: num} | acc]

        String.starts_with?(line, "## ") ->
          [%{type: :header, level: 2, text: String.slice(line, 3..-1//1), line: num} | acc]

        String.starts_with?(line, "### ") ->
          [%{type: :header, level: 3, text: String.slice(line, 4..-1//1), line: num} | acc]

        String.starts_with?(line, "```") ->
          [%{type: :code_fence, language: extract_language_from_fence(line), line: num} | acc]

        String.starts_with?(line, "<!--") ->
          [%{type: :comment, content: line, line: num} | acc]

        String.trim(line) == "" ->
          [%{type: :blank, line: num} | acc]

        true ->
          [%{type: :text, content: line, line: num} | acc]
      end
    end)
    |> Enum.reverse()
  end

  defp extract_language_from_fence(line) do
    case Regex.run(~r/```(\w+)/, line) do
      [_, lang] -> String.to_atom(lang)
      _ -> nil
    end
  end

  # ---- Metadata Extraction ----

  defp extract_metadata(markdown) do
    extractors = [
      &extract_html_comments/1,
      &extract_link_hashes/1,
      &extract_zero_width/1,
      &extract_whitespace_patterns/1,
      &extract_code_attributes/1
    ]

    extractors
    |> Enum.flat_map(& &1.(markdown))
    |> merge_metadata()
  end

  defp extract_html_comments(markdown) do
    ~r/<!-- (.*?) -->/s
    |> Regex.scan(markdown)
    |> Enum.flat_map(fn [_, content] ->
      cond do
        content =~ ~r/polyglot:/ -> parse_polyglot_comment(content)
        content =~ ~r/kyozo:/ -> parse_kyozo_comment(content)
        content =~ ~r/@\w+:/ -> parse_linked_data(content)
        true -> []
      end
    end)
  end

  defp extract_link_hashes(markdown) do
    # Content-addressed links
    ~r/\[([^\]]+)\]\(([a-f0-9]{64})\)/
    |> Regex.scan(markdown)
    |> Enum.map(fn [_, text, hash] ->
      %{
        type: :content_link,
        text: text,
        hash: hash,
        content: retrieve_content(hash)
      }
    end)
  end

  defp extract_zero_width(markdown) do
    # Data hidden in zero-width Unicode
    markdown
    |> String.graphemes()
    |> Enum.chunk_by(&zero_width?/1)
    |> Enum.filter(fn chars -> Enum.all?(chars, &zero_width?/1) end)
    |> Enum.map(&decode_zero_width/1)
  end

  defp extract_whitespace_patterns(_markdown) do
    # Placeholder for whitespace pattern extraction
    []
  end

  defp extract_code_attributes(_markdown) do
    # Placeholder for code attribute extraction
    []
  end

  # ---- Comment Parsers ----

  defp parse_polyglot_comment(content) do
    case Regex.run(~r/polyglot:(\w+)(?:\s+(.+))?/, content) do
      [_, type] ->
        [%{type: :polyglot_directive, directive: type}]

      [_, type, params] ->
        parsed_params = parse_comment_params(params)
        [%{type: :polyglot_directive, directive: type, params: parsed_params}]

      _ ->
        []
    end
  end

  defp parse_kyozo_comment(content) do
    case Regex.run(~r/kyozo:(\w+)(?:\s+(.+))?/, content) do
      [_, type] ->
        [%{type: :kyozo_directive, directive: type}]

      [_, type, params] ->
        parsed_params = parse_comment_params(params)
        [%{type: :kyozo_directive, directive: type, params: parsed_params}]

      _ ->
        []
    end
  end

  defp parse_linked_data(content) do
    try do
      case Jason.decode(content) do
        {:ok, data} when is_map(data) ->
          [%{type: :linked_data, data: data}]

        _ ->
          []
      end
    rescue
      _ -> []
    end
  end

  defp parse_comment_params(params_string) do
    params_string
    |> String.split()
    |> Enum.reduce(%{}, fn param, acc ->
      case String.split(param, "=", parts: 2) do
        [key, value] -> Map.put(acc, key, value)
        [key] -> Map.put(acc, key, true)
      end
    end)
  end

  # ---- Zero-width Character Handling ----

  defp zero_width?(char) do
    char in ["\u200B", "\u200C", "\u200D", "\u2060", "\uFEFF"]
  end

  defp decode_zero_width(chars) do
    # Convert zero-width chars to binary, then decode as data
    binary =
      chars
      |> Enum.map(&zero_width_to_bit/1)
      |> Enum.join()
      |> String.to_integer(2)
      |> :binary.encode_unsigned()

    case String.valid?(binary) do
      true -> %{type: :hidden_data, content: binary}
      false -> %{type: :hidden_binary, data: binary}
    end
  rescue
    _ -> %{type: :invalid_zero_width, chars: chars}
  end

  defp zero_width_to_bit(char) do
    case char do
      # Zero Width Space
      "\u200B" -> "0"
      # Zero Width Non-Joiner
      "\u200C" -> "1"
      # Zero Width Joiner
      "\u200D" -> "01"
      # Word Joiner
      "\u2060" -> "10"
      # Zero Width No-Break Space
      "\uFEFF" -> "11"
      _ -> "0"
    end
  end

  # ---- Artifact Extraction ----

  defp extract_artifacts(markdown) do
    # Extract all possible artifact types, not just the primary language
    [
      extract_dockerfile_artifacts(markdown),
      extract_terraform_artifacts(markdown),
      extract_kubernetes_artifacts(markdown),
      extract_sql_artifacts(markdown),
      extract_git_artifacts(markdown),
      extract_executable_artifacts(markdown)
    ]
    |> List.flatten()
    |> Enum.reject(&is_nil/1)
  end

  defp extract_dockerfile_artifacts(markdown) do
    ~r/```dockerfile\n(.*?)```/s
    |> Regex.scan(markdown)
    |> Enum.map(fn [_, content] ->
      %{
        type: :dockerfile,
        content: content,
        buildable: true
      }
    end)
  end

  defp extract_terraform_artifacts(markdown) do
    terraform_blocks = Regex.scan(~r/```(?:terraform|hcl)\n(.*?)```/s, markdown)

    terraform_blocks
    |> Enum.map(fn [_, content] ->
      %{
        type: :terraform,
        content: String.trim(content),
        plannable: true
      }
    end)
    |> Kernel.++(extract_terraform_inline(markdown))
  end

  defp extract_terraform_inline(markdown) do
    # Extract terraform blocks that might not be in code fences
    patterns = [
      ~r/resource\s+"([^"]+)"\s+"([^"]+)"\s*{([^}]*)}/m,
      ~r/provider\s+"([^"]+)"\s*{([^}]*)}/m,
      ~r/variable\s+"([^"]+)"\s*{([^}]*)}/m
    ]

    patterns
    |> Enum.flat_map(&Regex.scan(&1, markdown))
    |> Enum.map(fn matches ->
      %{
        type: :terraform_resource,
        content: List.first(matches),
        extracted: true
      }
    end)
  end

  defp extract_kubernetes_artifacts(markdown) do
    yaml_blocks = Regex.scan(~r/```yaml\n(.*?)```/s, markdown)

    yaml_blocks
    |> Enum.filter(fn [_, content] ->
      content =~ ~r/apiVersion:|kind:|metadata:|spec:/
    end)
    |> Enum.map(fn [_, content] ->
      %{
        type: :kubernetes,
        content: String.trim(content),
        deployable: true,
        manifest_type: extract_k8s_kind(content)
      }
    end)
  end

  defp extract_k8s_kind(content) do
    case Regex.run(~r/kind:\s*(\w+)/, content) do
      [_, kind] -> String.downcase(kind)
      _ -> "unknown"
    end
  end

  defp extract_sql_artifacts(markdown) do
    sql_blocks = Regex.scan(~r/```sql\n(.*?)```/s, markdown)

    sql_blocks
    |> Enum.map(fn [_, content] ->
      trimmed = String.trim(content)

      %{
        type: :sql,
        content: trimmed,
        executable: true,
        operation: detect_sql_operation(trimmed)
      }
    end)
  end

  defp detect_sql_operation(sql) do
    cond do
      sql =~ ~r/^CREATE/i -> :create
      sql =~ ~r/^ALTER/i -> :alter
      sql =~ ~r/^DROP/i -> :drop
      sql =~ ~r/^INSERT/i -> :insert
      sql =~ ~r/^UPDATE/i -> :update
      sql =~ ~r/^DELETE/i -> :delete
      sql =~ ~r/^SELECT/i -> :select
      true -> :unknown
    end
  end

  defp extract_git_artifacts(markdown) do
    ~r/```file:([^\n]+)\n(.*?)```/s
    |> Regex.scan(markdown)
    |> Enum.map(fn [_, path, content] ->
      %{
        type: :file,
        path: path,
        content: content
      }
    end)
  end

  defp extract_executable_artifacts(markdown) do
    executable_blocks = [
      {~r/```bash\n(.*?)```/s, :bash},
      {~r/```shell\n(.*?)```/s, :shell},
      {~r/```sh\n(.*?)```/s, :sh}
    ]

    executable_blocks
    |> Enum.flat_map(fn {regex, type} ->
      Regex.scan(regex, markdown)
      |> Enum.map(fn [_, content] ->
        %{
          type: type,
          content: String.trim(content),
          executable: true,
          has_shebang: String.starts_with?(content, "#!")
        }
      end)
    end)
  end

  # ---- Transpilation ----

  def get_transpiler(:docker), do: Kyozo.Polyglot.Transpilers.Docker
  def get_transpiler(:terraform), do: Kyozo.Polyglot.Transpilers.Terraform
  def get_transpiler(:kubernetes), do: Kyozo.Polyglot.Transpilers.Kubernetes
  def get_transpiler(:git), do: Kyozo.Polyglot.Transpilers.Git
  def get_transpiler(:bash), do: Kyozo.Polyglot.Transpilers.Bash
  def get_transpiler(_), do: Kyozo.Polyglot.Transpilers.Identity

  # ---- Execution ----

  def get_executor(:dockerfile), do: Kyozo.Polyglot.Executors.Docker
  def get_executor(:terraform), do: Kyozo.Polyglot.Executors.Terraform
  def get_executor(:kubernetes), do: Kyozo.Polyglot.Executors.Kubernetes
  def get_executor(:sql), do: Kyozo.Polyglot.Executors.SQL
  def get_executor(:git), do: Kyozo.Polyglot.Executors.Git
  def get_executor(:executable), do: Kyozo.Polyglot.Executors.Shell
  def get_executor(_), do: Kyozo.Polyglot.Executors.Noop

  # ---- Sanitization Functions ----

  defp remove_zero_width_chars(markdown) do
    zero_width_chars = ["\u200B", "\u200C", "\u200D", "\u2060", "\uFEFF"]

    Enum.reduce(zero_width_chars, markdown, fn char, acc ->
      String.replace(acc, char, "")
    end)
  end

  defp remove_polyglot_comments(markdown) do
    markdown
    |> String.replace(~r/<!-- polyglot:.*? -->/s, "")
    |> String.replace(~r/<!-- kyozo:.*? -->/s, "")
  end

  defp normalize_whitespace(markdown) do
    markdown
    # Windows line endings
    |> String.replace(~r/\r\n/, "\n")
    # Mac line endings
    |> String.replace(~r/\r/, "\n")
    # Tabs to spaces
    |> String.replace(~r/\t/, "    ")
    # Trailing whitespace
    |> String.replace(~r/ +\n/, "\n")
    # Multiple blank lines
    |> String.replace(~r/\n{3,}/, "\n\n")
  end

  defp remove_content_links(markdown) do
    # Remove content-addressed links [text](hash)
    String.replace(markdown, ~r/\[([^\]]+)\]\(([a-f0-9]{64})\)/, "\\1")
  end

  # ---- Utilities ----

  @doc """
  Check if markdown is polyglot (contains hidden functionality).
  """
  def polyglot?(markdown) do
    parsed = parse(markdown)

    parsed.language != :document or
      parsed.metadata != %{} or
      parsed.artifacts != []
  end

  @doc """
  Strip all polyglot features, returning plain markdown.
  """
  def sanitize(markdown) do
    markdown
    |> remove_zero_width_chars()
    |> remove_polyglot_comments()
    |> normalize_whitespace()
    |> remove_content_links()
  end

  defp merge_metadata(items) do
    Enum.reduce(items, %{}, &Map.merge(&2, &1))
  end

  defp retrieve_content(hash) do
    # Would retrieve from content-addressed storage
    nil
  end
end
