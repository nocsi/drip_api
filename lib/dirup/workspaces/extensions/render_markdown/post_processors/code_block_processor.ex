defmodule Dirup.Workspaces.Extensions.RenderMarkdown.PostProcessors.CodeBlockProcessor do
  @moduledoc """
  Processes code blocks in HTML content for syntax highlighting and enhancement.

  This processor:
  - Adds syntax highlighting classes to code blocks
  - Enhances code blocks with copy buttons and language labels
  - Processes inline code elements
  - Adds line numbers for better readability
  - Handles executable code blocks with special styling
  """

  @doc """
  Processes code blocks and inline code in the HTML AST.

  ## Parameters

  - `ast` - The HTML AST to process
  - `syntax_highlighting?` - Whether to enable syntax highlighting (default: true)
  - `allowed_languages` - List of allowed programming languages for highlighting

  ## Returns

  The processed HTML AST with enhanced code blocks
  """
  def process(ast, syntax_highlighting? \\ true, allowed_languages \\ [])

  def process(ast, false, _allowed_languages), do: ast

  def process(ast, true, allowed_languages) do
    Floki.traverse_and_update(ast, fn
      # Process pre > code blocks (syntax highlighted code blocks)
      {"pre", pre_attrs, [{"code", code_attrs, code_children} = code_element]} ->
        process_code_block(
          {"pre", pre_attrs, [code_element]},
          code_attrs,
          code_children,
          allowed_languages
        )

      # Process standalone pre blocks
      {"pre", attrs, children} ->
        enhance_pre_block({"pre", attrs, children})

      # Process inline code elements
      {"code", attrs, children} ->
        process_inline_code({"code", attrs, children})

      # Default case - don't modify
      element ->
        element
    end)
  end

  defp process_code_block(
         {"pre", pre_attrs, [{"code", code_attrs, code_children}]},
         code_attrs,
         code_children,
         allowed_languages
       ) do
    language = extract_language_from_attrs(code_attrs)
    code_text = extract_code_text(code_children)

    # Check if language is allowed (if restrictions are in place)
    language_allowed? =
      Enum.empty?(allowed_languages) or language in allowed_languages

    if language_allowed? and not is_nil(language) do
      create_enhanced_code_block(pre_attrs, code_attrs, code_text, language)
    else
      create_plain_code_block(pre_attrs, code_attrs, code_children)
    end
  end

  defp extract_language_from_attrs(code_attrs) do
    case List.keyfind(code_attrs, "class", 0) do
      {"class", class_str} ->
        # Look for language- prefix (common in markdown parsers)
        case String.split(class_str, " ") |> Enum.find(&String.starts_with?(&1, "language-")) do
          "language-" <> lang ->
            lang

          nil ->
            # Try without language- prefix
            case String.split(class_str, " ") |> Enum.find(&is_programming_language?/1) do
              nil -> nil
              lang -> lang
            end
        end

      nil ->
        nil
    end
  end

  defp extract_code_text(code_children) do
    code_children
    |> Floki.text()
    |> String.trim()
  end

  defp create_enhanced_code_block(pre_attrs, code_attrs, code_text, language) do
    block_id = "code-block-#{System.unique_integer([:positive])}"

    # Enhanced pre element with toolbar
    {
      "div",
      [{"class", "code-block-container relative group mb-4"}],
      [
        # Toolbar with language label and copy button
        create_code_toolbar(language, block_id),
        # The actual code block
        {
          "pre",
          enhance_pre_attrs(pre_attrs, language),
          [
            {
              "code",
              enhance_code_attrs(code_attrs, language),
              [
                {
                  "span",
                  [
                    {"id", block_id},
                    {"class", "code-content"},
                    {"data-language", language},
                    {"data-code", code_text}
                  ],
                  [code_text]
                }
              ]
            }
          ]
        }
      ]
    }
  end

  defp create_plain_code_block(pre_attrs, code_attrs, code_children) do
    {
      "pre",
      add_plain_code_classes(pre_attrs),
      [
        {
          "code",
          add_plain_code_classes(code_attrs),
          code_children
        }
      ]
    }
  end

  defp create_code_toolbar(language, block_id) do
    {
      "div",
      [
        {"class",
         "code-toolbar flex items-center justify-between bg-gray-100 border-b border-gray-200 px-4 py-2 text-sm"},
        {"role", "toolbar"},
        {"aria-label", "Code block controls"}
      ],
      [
        # Language label
        {
          "span",
          [
            {"class", "language-label font-medium text-gray-700 flex items-center gap-2"},
            {"aria-label", "Programming language: #{language}"}
          ],
          [
            create_language_icon(language),
            String.capitalize(language)
          ]
        },
        # Copy button
        {
          "button",
          [
            {"type", "button"},
            {"class",
             "copy-btn opacity-0 group-hover:opacity-100 transition-opacity px-3 py-1 text-xs bg-blue-600 text-white rounded hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-1"},
            {"onclick", "copyCodeBlock('#{block_id}')"},
            {"aria-label", "Copy code to clipboard"},
            {"title", "Copy code"}
          ],
          [
            {
              "svg",
              [
                {"xmlns", "http://www.w3.org/2000/svg"},
                {"class", "h-4 w-4 inline mr-1"},
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
                     "M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"}
                  ],
                  []
                }
              ]
            },
            "Copy"
          ]
        }
      ]
    }
  end

  defp create_language_icon(language) do
    icon_class = "h-4 w-4 text-gray-500"

    case language do
      lang when lang in ["javascript", "js"] ->
        {
          "svg",
          [
            {"class", icon_class},
            {"viewBox", "0 0 24 24"},
            {"fill", "currentColor"}
          ],
          [
            {
              "path",
              [
                {"d",
                 "M0 0h24v24H0V0zm22.034 18.276c-.175-1.095-.888-2.015-3.003-2.873-.736-.345-1.554-.585-1.797-1.14-.091-.33-.105-.51-.046-.705.15-.646.915-.84 1.515-.66.39.12.75.42.976.9 1.034-.676 1.034-.676 1.755-1.125-.27-.42-.404-.601-.586-.78-.63-.705-1.469-1.065-2.834-1.034l-.705.089c-.676.165-1.32.525-1.71 1.005-1.14 1.291-.811 3.541.569 4.471 1.365 1.02 3.361 1.244 3.616 2.205.24 1.17-.87 1.545-1.966 1.41-.811-.18-1.26-.586-1.755-1.336l-1.83 1.051c.21.48.45.689.81 1.109 1.74 1.756 6.09 1.666 6.871-1.004.029-.09.24-.705.074-1.65l.046.067zm-8.983-7.245h-2.248c0 1.938-.009 3.864-.009 5.805 0 1.232.063 2.363-.138 2.711-.33.689-1.18.601-1.566.48-.396-.196-.597-.466-.83-.855-.063-.105-.11-.196-.127-.196l-1.825 1.125c.305.63.75 1.172 1.324 1.517.855.51 2.004.675 3.207.405.783-.226 1.458-.691 1.811-1.411.51-.93.402-2.07.397-3.346.012-2.054 0-4.109 0-6.179l.004-.056z"}
              ],
              []
            }
          ]
        }

      lang when lang in ["python", "py"] ->
        {
          "svg",
          [
            {"class", icon_class},
            {"viewBox", "0 0 24 24"},
            {"fill", "currentColor"}
          ],
          [
            {
              "path",
              [
                {"d",
                 "M14.25.18l.9.2.73.26.59.3.45.32.34.34.25.34.16.33.1.3.04.26.02.2-.01.13V8.5l-.05.63-.13.55-.21.46-.26.38-.3.31-.33.25-.35.19-.35.14-.33.1-.3.07-.26.04-.21.02H8.77l-.69.05-.59.14-.5.22-.41.27-.33.32-.27.35-.2.36-.15.37-.1.35-.07.32-.04.27-.02.21v3.06H3.17l-.21-.03-.28-.07-.32-.12-.35-.18-.36-.26-.36-.36-.35-.46-.32-.59-.28-.73-.21-.88-.14-1.05-.05-1.23.06-1.22.16-1.04.24-.87.32-.71.36-.57.4-.44.42-.33.42-.24.4-.16.36-.1.32-.05.24-.01h.16l.06.01h8.16v-.83H6.18l-.01-2.75-.02-.37.05-.34.11-.31.17-.28.25-.26.31-.23.38-.2.44-.18.51-.15.58-.12.64-.1.71-.06.77-.04.84-.02 1.27.05zm-6.3 1.98l-.23.33-.08.41.08.41.23.34.33.22.41.09.41-.09.33-.22.23-.34.08-.41-.08-.41-.23-.33-.33-.22-.41-.09-.41.09zm13.09 3.95l.28.06.32.12.35.18.36.27.36.35.35.47.32.59.28.73.21.88.14 1.04.05 1.23-.06 1.23-.16 1.04-.24.86-.32.71-.36.57-.4.45-.42.33-.42.24-.4.16-.36.09-.32.05-.24.02-.16-.01h-8.22v.82h5.84l.01 2.76.02.36-.05.34-.11.31-.17.29-.25.25-.31.24-.38.2-.44.17-.51.15-.58.13-.64.09-.71.07-.77.04-.84.01-1.27-.04-1.07-.14-.9-.2-.73-.25-.59-.3-.45-.33-.34-.34-.25-.34-.16-.33-.1-.3-.04-.25-.02-.2.01-.13v-5.34l.05-.64.13-.54.21-.46.26-.38.3-.32.33-.24.35-.2.35-.14.33-.1.3-.06.26-.04.21-.02.13-.01h5.84l.69-.05.59-.14.5-.21.41-.28.33-.32.27-.35.2-.36.15-.36.1-.35.07-.32.04-.28.02-.21V6.07h2.09l.14.01zm-6.47 14.25l-.23.33-.08.41.08.41.23.33.33.23.41.08.41-.08.33-.23.23-.33.08-.41-.08-.41-.23-.33-.33-.23-.41-.08-.41.08z"}
              ],
              []
            }
          ]
        }

      _ ->
        {
          "svg",
          [
            {"class", icon_class},
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
                {"d", "M10 20l4-16m4 4l4 4-4 4M6 16l-4-4 4-4"}
              ],
              []
            }
          ]
        }
    end
  end

  defp enhance_pre_attrs(attrs, language) do
    base_classes =
      "bg-gray-900 text-gray-100 overflow-x-auto text-sm leading-relaxed rounded-b-lg"

    language_class = "language-#{language}"

    case List.keyfind(attrs, "class", 0) do
      {"class", existing_class} ->
        combined = "#{existing_class} #{base_classes} #{language_class}"
        List.keyreplace(attrs, "class", 0, {"class", combined})

      nil ->
        [{"class", "#{base_classes} #{language_class}"} | attrs]
    end
    |> add_code_block_attrs(language)
  end

  defp enhance_code_attrs(attrs, language) do
    base_classes = "block p-4"
    language_class = "language-#{language}"

    case List.keyfind(attrs, "class", 0) do
      {"class", existing_class} ->
        combined = "#{existing_class} #{base_classes} #{language_class}"
        List.keyreplace(attrs, "class", 0, {"class", combined})

      nil ->
        [{"class", "#{base_classes} #{language_class}"} | attrs]
    end
  end

  defp add_code_block_attrs(attrs, language) do
    [
      {"data-language", language},
      {"role", "region"},
      {"aria-label", "Code block in #{language}"}
      | attrs
    ]
  end

  defp add_plain_code_classes(attrs) do
    base_classes = "bg-gray-50 border border-gray-200 rounded text-sm"

    case List.keyfind(attrs, "class", 0) do
      {"class", existing_class} ->
        List.keyreplace(attrs, "class", 0, {"class", "#{existing_class} #{base_classes}"})

      nil ->
        [{"class", base_classes} | attrs]
    end
  end

  defp enhance_pre_block({"pre", attrs, children}) do
    enhanced_classes =
      "bg-gray-50 border border-gray-200 rounded-lg p-4 overflow-x-auto text-sm font-mono"

    new_attrs =
      case List.keyfind(attrs, "class", 0) do
        {"class", existing_class} ->
          List.keyreplace(attrs, "class", 0, {"class", "#{existing_class} #{enhanced_classes}"})

        nil ->
          [{"class", enhanced_classes} | attrs]
      end

    {"pre", new_attrs, children}
  end

  defp process_inline_code({"code", attrs, children}) do
    # Check if this is already inside a pre block by looking at classes
    case List.keyfind(attrs, "class", 0) do
      {"class", class_str} when is_binary(class_str) ->
        if String.contains?(class_str, "language-") do
          # This is syntax-highlighted code, don't modify
          {"code", attrs, children}
        else
          # This is inline code
          enhance_inline_code(attrs, children)
        end

      nil ->
        # This is inline code
        enhance_inline_code(attrs, children)
    end
  end

  defp enhance_inline_code(attrs, children) do
    inline_classes = "bg-gray-100 text-red-600 px-1.5 py-0.5 rounded text-sm font-mono"

    new_attrs =
      case List.keyfind(attrs, "class", 0) do
        {"class", existing_class} ->
          List.keyreplace(attrs, "class", 0, {"class", "#{existing_class} #{inline_classes}"})

        nil ->
          [{"class", inline_classes} | attrs]
      end

    {"code", new_attrs, children}
  end

  defp is_programming_language?(lang) do
    programming_languages = [
      "javascript",
      "js",
      "typescript",
      "ts",
      "python",
      "py",
      "java",
      "c",
      "cpp",
      "csharp",
      "cs",
      "php",
      "ruby",
      "rb",
      "go",
      "rust",
      "kotlin",
      "swift",
      "scala",
      "perl",
      "r",
      "matlab",
      "html",
      "css",
      "scss",
      "sass",
      "less",
      "xml",
      "json",
      "yaml",
      "yml",
      "toml",
      "ini",
      "bash",
      "shell",
      "sh",
      "zsh",
      "fish",
      "powershell",
      "cmd",
      "batch",
      "sql",
      "graphql",
      "dockerfile",
      "docker",
      "makefile",
      "cmake",
      "elixir",
      "ex",
      "exs",
      "erlang",
      "erl",
      "haskell",
      "hs",
      "ocaml",
      "ml",
      "fsharp",
      "fs",
      "clojure",
      "clj",
      "lisp",
      "scheme",
      "lua",
      "dart",
      "vim",
      "latex",
      "tex",
      "markdown",
      "md",
      "diff",
      "patch"
    ]

    String.downcase(lang) in programming_languages
  end
end
