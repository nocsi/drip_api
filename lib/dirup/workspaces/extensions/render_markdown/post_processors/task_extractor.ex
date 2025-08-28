defmodule Dirup.Workspaces.Extensions.RenderMarkdown.PostProcessors.TaskExtractor do
  @moduledoc """
  Processes HTML content to extract and enhance executable code blocks as tasks.

  This processor:
  - Identifies code blocks that can be executed as tasks
  - Adds task metadata and execution controls to code blocks
  - Enhances code blocks with run buttons and status indicators
  - Processes task-specific comments and annotations
  - Handles task dependencies and execution order
  """

  @doc """
  Processes code blocks to extract and enhance tasks in the HTML AST.

  ## Parameters

  - `ast` - The HTML AST to process
  - `extract_tasks?` - Whether to extract and enhance tasks (default: false)

  ## Returns

  The processed HTML AST with enhanced task code blocks
  """
  def process(ast, extract_tasks? \\ false)

  def process(ast, false), do: ast

  def process(ast, true) do
    {processed_ast, _task_counter} =
      Floki.traverse_and_update(ast, 0, fn element, task_counter ->
        case element do
          # Process code blocks that might be tasks
          {"div", attrs, children} ->
            if is_code_block_container?(attrs) do
              process_code_block_container(element, task_counter)
            else
              {element, task_counter}
            end

          # Process pre blocks directly
          {"pre", attrs, [{"code", code_attrs, code_children}]} ->
            if is_executable_code_block?(code_attrs, code_children) do
              process_executable_code_block(
                {"pre", attrs, [{"code", code_attrs, code_children}]},
                task_counter
              )
            else
              {element, task_counter}
            end

          # Default case - don't modify
          other ->
            {other, task_counter}
        end
      end)

    processed_ast
  end

  defp is_code_block_container?(attrs) do
    case List.keyfind(attrs, "class", 0) do
      {"class", class_str} ->
        String.contains?(class_str, "code-block-container")

      nil ->
        false
    end
  end

  defp is_executable_code_block?(code_attrs, code_children) do
    language = extract_language_from_code_attrs(code_attrs)
    code_text = Floki.text(code_children) |> String.trim()

    is_executable_language?(language) and not String.empty?(code_text)
  end

  defp extract_language_from_code_attrs(code_attrs) do
    case List.keyfind(code_attrs, "class", 0) do
      {"class", class_str} ->
        class_str
        |> String.split(" ")
        |> Enum.find_value(fn class ->
          cond do
            String.starts_with?(class, "language-") ->
              String.replace_prefix(class, "language-", "")

            is_executable_language?(class) ->
              class

            true ->
              nil
          end
        end)

      nil ->
        nil
    end
  end

  defp process_code_block_container({"div", attrs, children}, task_counter) do
    # Extract code information from the container
    case extract_code_info_from_container(children) do
      {:ok, code_info} ->
        if is_executable_language?(code_info.language) do
          enhanced_container =
            enhance_task_container({"div", attrs, children}, code_info, task_counter)

          {enhanced_container, task_counter + 1}
        else
          {{"div", attrs, children}, task_counter}
        end

      {:error, _reason} ->
        {{"div", attrs, children}, task_counter}
    end
  end

  defp process_executable_code_block(
         {"pre", attrs, [{"code", code_attrs, code_children}]},
         task_counter
       ) do
    language = extract_language_from_code_attrs(code_attrs)
    code_text = Floki.text(code_children) |> String.trim()

    code_info = %{
      language: language,
      code: code_text,
      line_count: length(String.split(code_text, "\n"))
    }

    # Wrap in container and enhance
    container = {
      "div",
      [{"class", "code-block-container relative group mb-4"}],
      [{"pre", attrs, [{"code", code_attrs, code_children}]}]
    }

    enhanced_container = enhance_task_container(container, code_info, task_counter)
    {enhanced_container, task_counter + 1}
  end

  defp extract_code_info_from_container(children) do
    case find_code_element(children) do
      {:ok, {"code", code_attrs, code_children}} ->
        language = extract_language_from_code_attrs(code_attrs)
        code_text = Floki.text(code_children) |> String.trim()

        {:ok,
         %{
           language: language,
           code: code_text,
           line_count: length(String.split(code_text, "\n"))
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp find_code_element(children) do
    case Floki.find(children, "code") do
      [{"code", attrs, code_children}] ->
        {:ok, {"code", attrs, code_children}}

      [] ->
        {:error, :no_code_element}

      _ ->
        {:error, :multiple_code_elements}
    end
  end

  defp enhance_task_container({"div", container_attrs, children}, code_info, task_index) do
    task_id = "task-#{task_index}"

    # Add task-specific classes and attributes
    enhanced_attrs =
      container_attrs
      |> add_task_classes()
      |> add_task_attributes(task_id, code_info)

    # Create enhanced children with task controls
    enhanced_children =
      children
      |> add_task_toolbar(task_id, code_info)
      |> add_task_status_indicator(task_id)
      |> add_task_output_area(task_id)

    {"div", enhanced_attrs, enhanced_children}
  end

  defp add_task_classes(attrs) do
    additional_classes = "executable-task task-container"

    case List.keyfind(attrs, "class", 0) do
      {"class", existing_class} ->
        List.keyreplace(attrs, "class", 0, {"class", "#{existing_class} #{additional_classes}"})

      nil ->
        [{"class", additional_classes} | attrs]
    end
  end

  defp add_task_attributes(attrs, task_id, code_info) do
    task_attrs = [
      {"data-task-id", task_id},
      {"data-language", code_info.language},
      {"data-executable", "true"},
      {"data-line-count", Integer.to_string(code_info.line_count)},
      {"role", "region"},
      {"aria-label", "Executable #{code_info.language} task"}
    ]

    task_attrs ++ attrs
  end

  defp add_task_toolbar(children, task_id, code_info) do
    toolbar = create_task_toolbar(task_id, code_info)

    # Insert toolbar before the first child (usually the existing toolbar or pre block)
    case children do
      [first_child | rest] ->
        [toolbar, first_child | rest]

      [] ->
        [toolbar]
    end
  end

  defp create_task_toolbar(task_id, code_info) do
    {
      "div",
      [
        {"class",
         "task-toolbar flex items-center justify-between bg-gradient-to-r from-green-50 to-blue-50 border-b border-green-200 px-4 py-2 text-sm"},
        {"role", "toolbar"},
        {"aria-label", "Task execution controls"}
      ],
      [
        # Task info section
        {
          "div",
          [{"class", "flex items-center gap-3"}],
          [
            # Executable indicator
            {
              "span",
              [
                {"class", "flex items-center gap-1 text-green-700 font-medium"},
                {"title", "This code block can be executed"}
              ],
              [
                {
                  "svg",
                  [
                    {"xmlns", "http://www.w3.org/2000/svg"},
                    {"class", "h-4 w-4"},
                    {"fill", "none"},
                    {"viewBox", "0 0 24 24"},
                    {"stroke", "currentColor"},
                    {"stroke-width", "2"}
                  ],
                  [
                    {
                      "path",
                      [
                        {"stroke-linecap", "round"},
                        {"stroke-linejoin", "round"},
                        {"d", "M5 3l14 9-14 9V3z"}
                      ],
                      []
                    }
                  ]
                },
                "Executable #{String.capitalize(code_info.language)}"
              ]
            },
            # Line count
            {
              "span",
              [{"class", "text-gray-600 text-xs"}],
              ["#{code_info.line_count} lines"]
            }
          ]
        },
        # Action buttons section
        {
          "div",
          [{"class", "flex items-center gap-2"}],
          [
            # Run button
            {
              "button",
              [
                {"type", "button"},
                {"class",
                 "run-task-btn bg-green-600 hover:bg-green-700 text-white px-3 py-1 rounded text-xs font-medium flex items-center gap-1 transition-colors focus:outline-none focus:ring-2 focus:ring-green-500 focus:ring-offset-1"},
                {"onclick", "executeTask('#{task_id}')"},
                {"aria-label", "Execute this task"},
                {"title", "Run this code"}
              ],
              [
                {
                  "svg",
                  [
                    {"xmlns", "http://www.w3.org/2000/svg"},
                    {"class", "h-3 w-3"},
                    {"fill", "none"},
                    {"viewBox", "0 0 24 24"},
                    {"stroke", "currentColor"},
                    {"stroke-width", "2"}
                  ],
                  [
                    {
                      "path",
                      [
                        {"stroke-linecap", "round"},
                        {"stroke-linejoin", "round"},
                        {"d", "M5 3l14 9-14 9V3z"}
                      ],
                      []
                    }
                  ]
                },
                "Run"
              ]
            },
            # Stop button (initially hidden)
            {
              "button",
              [
                {"type", "button"},
                {"class",
                 "stop-task-btn hidden bg-red-600 hover:bg-red-700 text-white px-3 py-1 rounded text-xs font-medium flex items-center gap-1 transition-colors focus:outline-none focus:ring-2 focus:ring-red-500 focus:ring-offset-1"},
                {"onclick", "stopTask('#{task_id}')"},
                {"aria-label", "Stop task execution"},
                {"title", "Stop execution"}
              ],
              [
                {
                  "svg",
                  [
                    {"xmlns", "http://www.w3.org/2000/svg"},
                    {"class", "h-3 w-3"},
                    {"fill", "none"},
                    {"viewBox", "0 0 24 24"},
                    {"stroke", "currentColor"},
                    {"stroke-width", "2"}
                  ],
                  [
                    {
                      "rect",
                      [
                        {"x", "6"},
                        {"y", "6"},
                        {"width", "12"},
                        {"height", "12"},
                        {"rx", "2"}
                      ],
                      []
                    }
                  ]
                },
                "Stop"
              ]
            }
          ]
        }
      ]
    }
  end

  defp add_task_status_indicator(children, task_id) do
    status_indicator = {
      "div",
      [
        {"id", "#{task_id}-status"},
        {"class", "task-status hidden"},
        {"role", "status"},
        {"aria-live", "polite"}
      ],
      [
        {
          "div",
          [{"class", "flex items-center gap-2 px-4 py-2 text-sm border-b"}],
          [
            {
              "div",
              [{"class", "status-icon"}],
              []
            },
            {
              "span",
              [{"class", "status-text"}],
              ["Ready"]
            },
            {
              "span",
              [{"class", "status-time text-gray-500 text-xs ml-auto"}],
              []
            }
          ]
        }
      ]
    }

    children ++ [status_indicator]
  end

  defp add_task_output_area(children, task_id) do
    output_area = {
      "div",
      [
        {"id", "#{task_id}-output"},
        {"class", "task-output hidden"},
        {"role", "log"},
        {"aria-label", "Task execution output"}
      ],
      [
        {
          "div",
          [
            {"class",
             "output-header bg-gray-800 text-gray-200 px-4 py-2 text-xs font-medium flex items-center justify-between"}
          ],
          [
            {
              "span",
              [],
              ["Output"]
            },
            {
              "button",
              [
                {"type", "button"},
                {"class", "clear-output-btn text-gray-400 hover:text-gray-200 transition-colors"},
                {"onclick", "clearTaskOutput('#{task_id}')"},
                {"aria-label", "Clear output"},
                {"title", "Clear output"}
              ],
              [
                {
                  "svg",
                  [
                    {"xmlns", "http://www.w3.org/2000/svg"},
                    {"class", "h-4 w-4"},
                    {"fill", "none"},
                    {"viewBox", "0 0 24 24"},
                    {"stroke", "currentColor"},
                    {"stroke-width", "2"}
                  ],
                  [
                    {
                      "path",
                      [
                        {"stroke-linecap", "round"},
                        {"stroke-linejoin", "round"},
                        {"d",
                         "M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"}
                      ],
                      []
                    }
                  ]
                }
              ]
            }
          ]
        },
        {
          "pre",
          [
            {"class",
             "output-content bg-gray-900 text-gray-100 p-4 overflow-x-auto text-sm font-mono max-h-64 overflow-y-auto"},
            {"data-output-type", "stdout"}
          ],
          [
            {
              "code",
              [{"class", "output-text"}],
              []
            }
          ]
        }
      ]
    }

    children ++ [output_area]
  end

  defp is_executable_language?(nil), do: false

  defp is_executable_language?(language) when is_binary(language) do
    executable_languages = [
      "python",
      "py",
      "javascript",
      "js",
      "typescript",
      "ts",
      "bash",
      "sh",
      "shell",
      "elixir",
      "ex",
      "exs",
      "sql",
      "ruby",
      "rb",
      "go",
      "rust",
      "rs",
      "java",
      "kotlin",
      "kt",
      "scala",
      "php",
      "r",
      "julia",
      "jl",
      "perl",
      "pl",
      "lua",
      "powershell",
      "ps1"
    ]

    String.downcase(language) in executable_languages
  end

  defp is_executable_language?(_), do: false
end
