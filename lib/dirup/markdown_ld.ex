defmodule Dirup.MarkdownLD do
  @moduledoc """
  Markdown-LD: Markdown with Linked Data

  A format that embeds structured, semantic data within markdown documents,
  making them both human-readable and machine-understandable.
  """

  alias Dirup.MarkdownLD.{Parser, Graph, Executor, Vocabulary}

  @context_url "https://kyozo.dev/schemas/markdown-ld/v1"

  defmodule Document do
    @moduledoc "A Markdown-LD document with its graph"

    defstruct [
      :id,
      :content,
      :graph,
      :blocks,
      :metadata,
      :context
    ]

    @type t :: %__MODULE__{
            id: String.t(),
            content: String.t(),
            graph: RDF.Graph.t(),
            blocks: list(Block.t()),
            metadata: map(),
            context: map()
          }
  end

  defmodule Block do
    @moduledoc "A semantic block within a document"

    defstruct [
      :id,
      :type,
      :content,
      :language,
      :properties,
      :position,
      :raw
    ]

    @type t :: %__MODULE__{
            id: String.t(),
            type: String.t(),
            content: String.t(),
            language: String.t() | nil,
            properties: map(),
            position: integer(),
            raw: String.t()
          }
  end

  @doc """
  Parse Markdown-LD content into a semantic document
  """
  def parse(content, opts \\ []) do
    with {:ok, blocks} <- Parser.parse_blocks(content),
         {:ok, graph} <- build_graph(blocks),
         {:ok, doc_metadata} <- extract_document_metadata(blocks) do
      document = %Document{
        id: doc_metadata["@id"] || generate_id(),
        content: content,
        graph: graph,
        blocks: blocks,
        metadata: doc_metadata,
        context: doc_metadata["@context"] || default_context()
      }

      {:ok, document}
    end
  end

  @doc """
  Execute a Markdown-LD document with semantic understanding
  """
  def execute(%Document{} = doc, context \\ %{}) do
    # Build execution plan from semantic graph
    with {:ok, execution_plan} <- build_execution_plan(doc),
         {:ok, results} <- Executor.execute_plan(execution_plan, context) do
      {:ok, results}
    end
  end

  @doc """
  Query the document's knowledge graph
  """
  def query(%Document{} = doc, sparql_query) do
    SPARQL.execute(sparql_query, doc.graph)
  end

  @doc """
  Convert document to RDF triples
  """
  def to_rdf(%Document{} = doc) do
    doc.graph
    |> RDF.Turtle.write_string!()
  end

  @doc """
  Create a new Markdown-LD document programmatically
  """
  def new(opts \\ []) do
    %Document{
      id: Keyword.get(opts, :id, generate_id()),
      content: "",
      graph: RDF.Graph.new(),
      blocks: [],
      metadata: %{
        "@context" => @context_url,
        "@type" => "kyozo:Document"
      },
      context: default_context()
    }
  end

  @doc """
  Add a semantic block to the document
  """
  def add_block(%Document{} = doc, type, content, properties \\ %{}) do
    block_id = generate_block_id()

    block = %Block{
      id: block_id,
      type: type,
      content: content,
      properties: Map.merge(%{"@id" => block_id, "@type" => type}, properties),
      position: length(doc.blocks)
    }

    # Update graph with block triples
    graph =
      doc.graph
      |> Graph.add_block(doc.id, block)

    %{doc | blocks: doc.blocks ++ [block], graph: graph}
  end

  @doc """
  Add a code block with semantic properties
  """
  def add_code(%Document{} = doc, language, content, opts \\ []) do
    properties = %{
      "kyozo:language" => language,
      "kyozo:executable" => Keyword.get(opts, :executable, true)
    }

    properties =
      if deps = Keyword.get(opts, :depends_on) do
        Map.put(properties, "kyozo:dependsOn", deps)
      else
        properties
      end

    add_block(doc, "kyozo:CodeBlock", content, properties)
  end

  @doc """
  Add a data block with semantic properties
  """
  def add_data(%Document{} = doc, format, content, opts \\ []) do
    properties = %{
      "kyozo:format" => format,
      "kyozo:parseable" => true
    }

    properties =
      if schema = Keyword.get(opts, :validates) do
        Map.put(properties, "kyozo:validatedBy", schema)
      else
        properties
      end

    add_block(doc, "kyozo:DataBlock", content, properties)
  end

  @doc """
  Render document back to Markdown-LD format
  """
  def render(%Document{} = doc) do
    # Add document-level metadata
    header = render_json_ld_comment(doc.metadata)

    # Render blocks
    blocks =
      doc.blocks
      |> Enum.map(&render_block/1)
      |> Enum.join("\n\n")

    header <> "\n\n" <> blocks
  end

  # Private functions

  defp build_graph(blocks) do
    graph = RDF.Graph.new()

    Enum.reduce(blocks, {:ok, graph}, fn
      block, {:ok, g} ->
        {:ok, Graph.add_block_triples(g, block)}

      _, error ->
        error
    end)
  end

  defp extract_document_metadata(blocks) do
    # Find document-level metadata block
    doc_block =
      Enum.find(blocks, fn b ->
        b.properties["@type"] in ["kyozo:Document", "kyozo:ExecutableDocument"]
      end)

    if doc_block do
      {:ok, doc_block.properties}
    else
      {:ok, %{}}
    end
  end

  defp build_execution_plan(%Document{} = doc) do
    # Query for executable blocks and their dependencies
    query = """
    PREFIX kyozo: <https://kyozo.dev/vocab/>

    SELECT ?block ?deps
    WHERE {
      ?block a kyozo:CodeBlock ;
             kyozo:executable true .
      OPTIONAL { ?block kyozo:dependsOn ?deps }
    }
    ORDER BY ?block
    """

    case SPARQL.execute(query, doc.graph) do
      {:ok, results} ->
        plan = build_dependency_order(results)
        {:ok, plan}

      error ->
        error
    end
  end

  defp render_block(%Block{} = block) do
    metadata = render_json_ld_comment(block.properties)

    case block.type do
      "kyozo:CodeBlock" ->
        metadata <> "\n```#{block.properties["kyozo:language"]}\n#{block.content}\n```"

      "kyozo:DataBlock" ->
        metadata <> "\n```#{block.properties["kyozo:format"]}\n#{block.content}\n```"

      _ ->
        metadata <> "\n" <> block.content
    end
  end

  defp render_json_ld_comment(properties) do
    json = Jason.encode!(properties, pretty: true)
    "<!--\n#{json}\n-->"
  end

  defp generate_id do
    "doc:" <> UUID.uuid4()
  end

  defp generate_block_id do
    "block:" <> UUID.uuid4()
  end

  defp default_context do
    %{
      "@vocab" => "https://kyozo.dev/vocab/",
      "schema" => "https://schema.org/",
      "dc" => "http://purl.org/dc/terms/",
      "foaf" => "http://xmlns.com/foaf/0.1/"
    }
  end

  defp build_dependency_order(results) do
    # Build topological sort of blocks based on dependencies
    # This is simplified - real implementation would handle cycles
    results
    |> Enum.sort_by(fn r ->
      length(r.deps || [])
    end)
  end
end
