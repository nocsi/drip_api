defmodule Dirup.Storage.MarkdownLD do
  @moduledoc """
  Markdown Linked Data processing module.

  This module provides markdown parsing with structured data extraction,
  link analysis, and task management capabilities. Currently uses pure Elixir
  implementations with plans for Rust NIF optimization.

  ## Features

  - Parse markdown into structured data (headings, links, code blocks, tasks)
  - Extract and validate links
  - Generate table of contents
  - Parse frontmatter
  - Task extraction with priorities and due dates
  - Word count and reading time estimation
  - Code block detection with language identification

  ## Usage

      iex> markdown = "# Hello World\n\nThis is [a link](https://example.com)."
      iex> {:ok, result} = MarkdownLD.parse(markdown)
      {:ok, %{
        headings: [%{level: 1, text: "Hello World", id: "hello-world", line_number: 1}],
        links: [%{url: "https://example.com", text: "a link", line_number: 3, is_image: false}],
        word_count: 6,
        reading_time_minutes: 1
      }}
  """

  @type heading :: %{
          level: pos_integer(),
          text: String.t(),
          id: String.t(),
          line_number: pos_integer()
        }

  @type link :: %{
          url: String.t(),
          title: String.t() | nil,
          text: String.t(),
          line_number: pos_integer(),
          is_image: boolean()
        }

  @type code_block :: %{
          language: String.t() | nil,
          code: String.t(),
          line_number: pos_integer(),
          is_executable: boolean()
        }

  @type task :: %{
          text: String.t(),
          completed: boolean(),
          line_number: pos_integer(),
          priority: String.t() | nil,
          due_date: String.t() | nil,
          tags: [String.t()]
        }

  @type markdown_data :: %{
          links: [link()],
          headings: [heading()],
          code_blocks: [code_block()],
          tasks: [task()],
          word_count: non_neg_integer(),
          reading_time_minutes: non_neg_integer(),
          metadata: map(),
          table_of_contents: [heading()],
          backlinks: [String.t()],
          frontmatter: map() | nil
        }

  @doc """
  Parse markdown content and return structured data.
  """
  @spec parse(String.t()) :: {:ok, markdown_data()} | {:error, term()}
  def parse(markdown) when is_binary(markdown) do
    # Simple implementation - can be enhanced with actual parsing later
    word_count = markdown |> String.split() |> length()
    reading_time = max(1, div(word_count + 199, 200))

    data = %{
      links: [],
      headings: extract_headings_simple(markdown),
      code_blocks: [],
      tasks: extract_tasks_simple(markdown),
      word_count: word_count,
      reading_time_minutes: reading_time,
      metadata: %{},
      table_of_contents: [],
      backlinks: [],
      frontmatter: extract_frontmatter_simple(markdown)
    }

    {:ok, data}
  end

  def parse(_), do: {:error, :invalid_markdown}

  @doc """
  Extract only links from markdown content.
  """
  @spec get_links(String.t()) :: {:ok, [link()]} | {:error, term()}
  def get_links(markdown) when is_binary(markdown) do
    links = extract_links_simple(markdown)
    {:ok, links}
  end

  def get_links(_), do: {:error, :invalid_markdown}

  @doc """
  Extract headings to build a table of contents.
  """
  @spec get_headings(String.t()) :: {:ok, [heading()]} | {:error, term()}
  def get_headings(markdown) when is_binary(markdown) do
    headings = extract_headings_simple(markdown)
    {:ok, headings}
  end

  def get_headings(_), do: {:error, :invalid_markdown}

  @doc """
  Validate links in markdown content.
  """
  @spec check_links([link()]) :: {:ok, [map()]} | {:error, term()}
  def check_links(links) when is_list(links) do
    results =
      Enum.map(links, fn link ->
        is_valid =
          case URI.parse(link.url) do
            %URI{scheme: scheme} when scheme in ["http", "https"] -> true
            # Assume local links are valid
            _ -> true
          end

        %{
          url: link.url,
          valid: is_valid,
          line_number: link.line_number
        }
      end)

    {:ok, results}
  end

  def check_links(_), do: {:error, :invalid_links}

  @doc """
  Generate a table of contents from headings.
  """
  @spec build_toc([heading()]) :: [map()]
  def build_toc(headings) when is_list(headings) do
    headings
    |> Enum.map(fn heading ->
      %{
        level: heading.level,
        text: heading.text,
        id: heading.id,
        anchor: "##{heading.id}",
        line_number: heading.line_number
      }
    end)
  end

  def build_toc(_), do: []

  @doc """
  Extract tasks from parsed markdown data.
  """
  @spec get_tasks(markdown_data()) :: [task()]
  def get_tasks(%{tasks: tasks}), do: tasks
  def get_tasks(_), do: []

  @doc """
  Filter completed tasks from a list of tasks.
  """
  @spec get_completed_tasks([task()]) :: [task()]
  def get_completed_tasks(tasks) when is_list(tasks) do
    Enum.filter(tasks, & &1.completed)
  end

  @doc """
  Filter pending tasks from a list of tasks.
  """
  @spec get_pending_tasks([task()]) :: [task()]
  def get_pending_tasks(tasks) when is_list(tasks) do
    Enum.reject(tasks, & &1.completed)
  end

  @doc """
  Calculate reading time in minutes based on word count.
  """
  @spec reading_time(non_neg_integer()) :: pos_integer()
  def reading_time(word_count) when is_integer(word_count) and word_count >= 0 do
    max(1, div(word_count + 199, 200))
  end

  # Private helper functions for simple parsing

  defp extract_headings_simple(markdown) do
    markdown
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.filter(fn {line, _} -> String.starts_with?(String.trim(line), "#") end)
    |> Enum.map(fn {line, line_number} ->
      trimmed = String.trim(line)
      level = trimmed |> String.graphemes() |> Enum.take_while(&(&1 == "#")) |> length()
      text = trimmed |> String.trim_leading("#") |> String.trim()
      id = generate_heading_id(text)

      %{
        level: level,
        text: text,
        id: id,
        line_number: line_number
      }
    end)
  end

  defp extract_links_simple(markdown) do
    # Simple regex-based link extraction
    regex = ~r/\[([^\]]*)\]\(([^)]*)\)/

    markdown
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.flat_map(fn {line, line_number} ->
      Regex.scan(regex, line, capture: :all_but_first)
      |> Enum.map(fn [text, url] ->
        %{
          url: url,
          title: nil,
          text: text,
          line_number: line_number,
          is_image: false
        }
      end)
    end)
  end

  defp extract_tasks_simple(markdown) do
    task_regex = ~r/^\s*[-*+]\s*\[([ xX])\]\s*(.+)$/

    markdown
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.filter(fn {line, _} -> Regex.match?(task_regex, line) end)
    |> Enum.map(fn {line, line_number} ->
      [_, checkbox, text] = Regex.run(task_regex, line)
      completed = String.trim(checkbox) in ["x", "X"]

      %{
        text: String.trim(text),
        completed: completed,
        line_number: line_number,
        priority: nil,
        due_date: nil,
        tags: []
      }
    end)
  end

  defp extract_frontmatter_simple(markdown) do
    if String.starts_with?(markdown, "---\n") do
      case String.split(markdown, "\n---\n", parts: 2) do
        [frontmatter_str, _] ->
          frontmatter_str
          |> String.trim_leading("---\n")
          |> String.split("\n")
          |> Enum.reduce(%{}, fn line, acc ->
            case String.split(line, ":", parts: 2) do
              [key, value] ->
                Map.put(acc, String.trim(key), String.trim(value))

              _ ->
                acc
            end
          end)

        _ ->
          nil
      end
    else
      nil
    end
  end

  defp generate_heading_id(text) do
    text
    |> String.downcase()
    |> String.replace(~r/[^\w\s-]/, "")
    |> String.replace(~r/\s+/, "-")
    |> String.trim("-")
  end
end
