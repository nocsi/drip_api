defmodule Kyozo.Workspaces.Extensions.RenderMarkdown do
  @moduledoc """
  Sets up markdown text attributes to be transformed to html (in another column) using MDEx.
  
  This extension provides a declarative way to automatically convert markdown content
  to HTML with support for syntax highlighting, header IDs, table of contents, and
  code block processing for runnable tasks.
  """

  @render_markdown %Spark.Dsl.Section{
    name: :render_markdown,
    schema: [
      render_attributes: [
        type: :keyword_list,
        default: [],
        doc:
          "A keyword list of attributes that should have markdown rendered as html, and the attribute that should be written to."
      ],
      header_ids?: [
        type: :boolean,
        default: true,
        doc: "Set to false to disable setting an id for each header."
      ],
      table_of_contents?: [
        type: :boolean,
        default: false,
        doc: "Set to true to enable a table of contents to be generated."
      ],
      syntax_highlighting?: [
        type: :boolean,
        default: true,
        doc: "Set to false to disable syntax highlighting for code blocks."
      ],
      extract_tasks?: [
        type: :boolean,
        default: false,
        doc: "Set to true to extract executable code blocks as tasks."
      ],
      allowed_languages: [
        type: {:list, :string},
        default: ["elixir", "python", "javascript", "typescript", "bash", "shell", "sql", "json", "yaml", "markdown"],
        doc: "List of allowed programming languages for syntax highlighting."
      ],
      mdx_options: [
        type: :keyword_list,
        default: [
          extension: [
            strikethrough: true,
            tagfilter: true,
            table: true,
            autolink: true,
            tasklist: true,
            footnotes: true
          ],
          render: [
            github_pre_lang: true,
            escape: false,
            hardbreaks: false,
            unsafe_: true
          ],
          features: [
            syntax_highlight_theme: "github"
          ]
        ],
        doc: "MDEx parsing and rendering options."
      ]
    ]
  }

  use Spark.Dsl.Extension,
    sections: [@render_markdown],
    transformers: [Kyozo.Workspaces.Extensions.RenderMarkdown.Transformers.AddRenderMarkdownStructure]

  def render_attributes(resource) do
    Spark.Dsl.Extension.get_opt(resource, [:render_markdown], :render_attributes, [])
  end

  def header_ids?(resource) do
    Spark.Dsl.Extension.get_opt(resource, [:render_markdown], :header_ids?, true)
  end

  def table_of_contents?(resource) do
    Spark.Dsl.Extension.get_opt(resource, [:render_markdown], :table_of_contents?, false)
  end

  def syntax_highlighting?(resource) do
    Spark.Dsl.Extension.get_opt(resource, [:render_markdown], :syntax_highlighting?, true)
  end

  def extract_tasks?(resource) do
    Spark.Dsl.Extension.get_opt(resource, [:render_markdown], :extract_tasks?, false)
  end

  def allowed_languages(resource) do
    Spark.Dsl.Extension.get_opt(resource, [:render_markdown], :allowed_languages, [
      "elixir", "python", "javascript", "typescript", "bash", "shell", "sql", "json", "yaml", "markdown"
    ])
  end

  def mdx_options(resource) do
    Spark.Dsl.Extension.get_opt(resource, [:render_markdown], :mdx_options, [
      extension: [
        strikethrough: true,
        tagfilter: true,
        table: true,
        autolink: true,
        tasklist: true,
        footnotes: true
      ],
      render: [
        github_pre_lang: true,
        escape: false,
        hardbreaks: false,
        unsafe_: true
      ],
      features: [
        syntax_highlight_theme: "github"
      ]
    ])
  end

  @doc """
  Converts markdown text to HTML using MDEx with post-processing.
  
  ## Options
  
  - `add_ids?` - Whether to add IDs to headers for linking
  - `add_table_of_contents?` - Whether to generate a table of contents
  - `syntax_highlighting?` - Whether to enable syntax highlighting
  - `extract_tasks?` - Whether to extract code blocks as executable tasks
  - `allowed_languages` - List of allowed languages for highlighting
  - `mdx_options` - MDEx configuration options
  
  ## Returns
  
  - `{:ok, html_content, extracted_tasks}` on success
  - `{:error, reason}` on failure
  
  The `extracted_tasks` is a list of maps containing:
  - `language` - Programming language of the code block
  - `code` - The actual code content
  - `name` - Generated or specified name for the task
  - `line_start` - Starting line number (if available)
  - `line_end` - Ending line number (if available)
  """
  def as_html(text, opts \\ [])

  def as_html(text, opts) when is_list(text) do
    Enum.reduce_while(text, {:ok, [], []}, fn text_item, {:ok, html_list, task_list} ->
      case as_html(text_item, opts) do
        {:ok, html, tasks} ->
          {:cont, {:ok, [html | html_list], task_list ++ tasks}}
        
        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, html_list, task_list} ->
        {:ok, Enum.reverse(html_list), task_list}
      
      error ->
        error
    end
  end

  def as_html(nil, _opts) do
    {:ok, nil, []}
  end

  def as_html("", _opts) do
    {:ok, "", []}
  end

  def as_html(text, opts) when is_binary(text) do
    add_ids? = Keyword.get(opts, :add_ids?, true)
    add_table_of_contents? = Keyword.get(opts, :add_table_of_contents?, false)
    syntax_highlighting? = Keyword.get(opts, :syntax_highlighting?, true)
    extract_tasks? = Keyword.get(opts, :extract_tasks?, false)
    allowed_languages = Keyword.get(opts, :allowed_languages, [])
    mdx_options = Keyword.get(opts, :mdx_options, [])

    # Pre-process text to extract tasks if needed
    {processed_text, extracted_tasks} = 
      if extract_tasks? do
        extract_code_blocks(text, allowed_languages)
      else
        {text, []}
      end

    # Convert markdown to HTML using MDEx
    case MDEx.to_html(processed_text, mdx_options) do
      {:ok, html_content} ->
        # Post-process the HTML
        processed_html = 
          Kyozo.Workspaces.Extensions.RenderMarkdown.PostProcessor.run(
            html_content,
            add_ids?,
            add_table_of_contents?,
            syntax_highlighting?,
            allowed_languages
          )
        
        {:ok, processed_html, extracted_tasks}
      
      {:error, reason} ->
        {:error, reason}
    end
  rescue
    error ->
      {:error, "Failed to render markdown: #{inspect(error)}"}
  end

  @doc """
  Extracts code blocks from markdown text for task creation.
  
  Returns a tuple of {processed_text, extracted_tasks} where:
  - processed_text has runnable code blocks marked with special attributes
  - extracted_tasks is a list of task information extracted from code blocks
  """
  def extract_code_blocks(text, allowed_languages \\ [])

  def extract_code_blocks(nil, _), do: {nil, []}
  def extract_code_blocks("", _), do: {"", []}

  def extract_code_blocks(text, allowed_languages) when is_binary(text) do
    # Split text into lines for processing
    lines = String.split(text, "\n")
    
    {processed_lines, tasks, _} = 
      Enum.reduce(lines, {[], [], {nil, nil, nil, 0}}, fn line, {acc_lines, acc_tasks, state} ->
        process_line(line, acc_lines, acc_tasks, state, allowed_languages)
      end)
    
    processed_text = Enum.join(processed_lines, "\n")
    {processed_text, tasks}
  end

  # Private function to process each line for code block extraction
  defp process_line(line, acc_lines, acc_tasks, {current_lang, current_code, start_line, line_num}, allowed_languages) do
    line_num = line_num + 1
    
    cond do
      # Start of code block
      String.starts_with?(line, "```") and is_nil(current_lang) ->
        lang = 
          line
          |> String.trim_leading("```")
          |> String.trim()
          |> case do
            "" -> nil
            lang_str -> lang_str
          end
        
        {[line | acc_lines], acc_tasks, {lang, [], line_num, line_num}}
      
      # End of code block
      String.starts_with?(line, "```") and not is_nil(current_lang) ->
        # Check if this is an allowed/executable language
        if current_lang in allowed_languages or Enum.empty?(allowed_languages) do
          code_content = 
            current_code
            |> Enum.reverse()
            |> Enum.join("\n")
            |> String.trim()
          
          task = %{
            language: current_lang,
            code: code_content,
            name: generate_task_name(current_lang, length(acc_tasks) + 1),
            line_start: start_line + 1, # +1 because we don't include the ``` line
            line_end: line_num - 1,     # -1 because we don't include the closing ``` line
            is_executable: executable_language?(current_lang),
            metadata: %{
              extracted_from_markdown: true,
              original_fence: "```#{current_lang}"
            }
          }
          
          # Add special attributes to the closing fence for identification
          modified_line = "```<!-- kyozo-task-#{length(acc_tasks)} -->"
          {[modified_line | acc_lines], [task | acc_tasks], {nil, nil, nil, line_num}}
        else
          {[line | acc_lines], acc_tasks, {nil, nil, nil, line_num}}
        end
      
      # Inside code block
      not is_nil(current_lang) ->
        {acc_lines, acc_tasks, {current_lang, [line | current_code], start_line, line_num}}
      
      # Regular line
      true ->
        {[line | acc_lines], acc_tasks, {current_lang, current_code, start_line, line_num}}
    end
  end

  defp generate_task_name(language, index) do
    lang_name = 
      case language do
        "js" -> "JavaScript"
        "ts" -> "TypeScript"
        "py" -> "Python"
        "sh" -> "Shell"
        "bash" -> "Bash"
        nil -> "Code"
        lang -> String.capitalize(lang)
      end
    
    "#{lang_name} Task #{index}"
  end

  defp executable_language?(language) do
    executable_langs = [
      "python", "py", "javascript", "js", "typescript", "ts", 
      "bash", "sh", "shell", "elixir", "ex", "sql", "ruby", "rb"
    ]
    
    language in executable_langs
  end
end