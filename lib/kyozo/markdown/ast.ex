defmodule Kyozo.Markdown.AST do
  @moduledoc """
  AST definitions for Kyozo-enhanced Markdown.
  Compatible with mdast (Markdown Abstract Syntax Tree) spec.
  """

  # Standard mdast node types
  defmodule Node do
    @type t :: %{
            type: atom(),
            children: list(t()) | nil,
            value: String.t() | nil,
            position: Position.t() | nil,
            data: map() | nil
          }
  end

  defmodule Position do
    @type t :: %{
            start: Point.t(),
            end: Point.t()
          }
  end

  defmodule Point do
    @type t :: %{
            line: integer(),
            column: integer(),
            offset: integer()
          }
  end

  # Root node
  defmodule Root do
    defstruct type: :root,
              children: [],
              position: nil,
              data: nil
  end

  # Block nodes
  defmodule Paragraph do
    defstruct type: :paragraph,
              children: [],
              position: nil,
              data: nil
  end

  defmodule Heading do
    defstruct type: :heading,
              depth: 1,
              children: [],
              position: nil,
              data: nil
  end

  defmodule Code do
    defstruct type: :code,
              lang: nil,
              meta: nil,
              value: "",
              position: nil,
              data: nil

    @type t :: %__MODULE__{
            type: :code,
            lang: String.t() | nil,
            meta: String.t() | nil,
            value: String.t(),
            position: Position.t() | nil,
            data: map() | nil
          }
  end

  defmodule BlockQuote do
    defstruct type: :blockquote,
              children: [],
              position: nil,
              data: nil
  end

  defmodule List do
    defstruct type: :list,
              ordered: false,
              start: nil,
              spread: false,
              children: [],
              position: nil,
              data: nil
  end

  defmodule ListItem do
    defstruct type: :listItem,
              checked: nil,
              spread: false,
              children: [],
              position: nil,
              data: nil
  end

  # Inline nodes
  defmodule Text do
    defstruct type: :text,
              value: "",
              position: nil,
              data: nil
  end

  defmodule Emphasis do
    defstruct type: :emphasis,
              children: [],
              position: nil,
              data: nil
  end

  defmodule Strong do
    defstruct type: :strong,
              children: [],
              position: nil,
              data: nil
  end

  defmodule Link do
    defstruct type: :link,
              url: "",
              title: nil,
              children: [],
              position: nil,
              data: nil
  end

  defmodule Image do
    defstruct type: :image,
              url: "",
              title: nil,
              alt: nil,
              position: nil,
              data: nil
  end

  defmodule InlineCode do
    defstruct type: :inlineCode,
              value: "",
              position: nil,
              data: nil
  end

  # Kyozo-enhanced nodes (stored in standard nodes' data field)
  defmodule KyozoData do
    @moduledoc """
    Kyozo metadata stored in standard mdast nodes' data field.
    This keeps us mdast-compatible while adding superpowers.
    """

    defstruct kyozo: %{
                executable: false,
                enlightened: false,
                metadata: %{},
                dependencies: [],
                executor: nil,
                hidden: false
              }
  end

  defmodule HTML do
    @moduledoc "HTML comments containing our Kyozo metadata"
    defstruct type: :html,
              value: "",
              position: nil,
              data: nil
  end
end
