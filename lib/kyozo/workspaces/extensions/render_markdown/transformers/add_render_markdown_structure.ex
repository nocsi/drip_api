defmodule Kyozo.Workspaces.Extensions.RenderMarkdown.Transformers.AddRenderMarkdownStructure do
  @moduledoc """
  Adds the resource structure required for the render markdown extension.

  This transformer:
  1. Adds the relevant change to automatically render markdown to HTML
  2. Adds destination attributes to the `allow_nil_input` of each action
  3. Ensures proper attribute types are set for HTML content
  4. Adds task extraction functionality if enabled
  """

  use Spark.Dsl.Transformer
  alias Spark.Dsl.Transformer

  def transform(dsl) do
    render_attributes = Transformer.get_option(dsl, [:render_markdown], :render_attributes, [])
    extract_tasks? = Transformer.get_option(dsl, [:render_markdown], :extract_tasks?, false)

    # Transform each render attribute pair
    result = 
      Enum.reduce_while(render_attributes, {:ok, dsl}, fn {source, destination}, {:ok, current_dsl} ->
        case transform_render_attribute(current_dsl, source, destination, extract_tasks?) do
          {:ok, transformed_dsl} ->
            {:cont, {:ok, transformed_dsl}}
          
          {:error, reason} ->
            {:halt, {:error, reason}}
        end
      end)

    case result do
      {:ok, final_dsl} ->
        # Add any additional setup needed for the extension
        {:ok, setup_extension_attributes(final_dsl, render_attributes)}
      
      error ->
        error
    end
  end

  defp transform_render_attribute(dsl, source, destination, extract_tasks?) do
    try do
      transformed_dsl = 
        dsl
        |> allow_nil_input_for_destination(destination)
        |> add_render_markdown_change(source, destination, extract_tasks?)
        |> ensure_html_attribute_exists(destination)

      {:ok, transformed_dsl}
    rescue
      error ->
        {:error, "Failed to transform render attribute #{source} -> #{destination}: #{inspect(error)}"}
    end
  end

  defp allow_nil_input_for_destination(dsl, destination) do
    dsl
    |> Transformer.get_entities([:actions])
    |> Enum.filter(&(&1.type in [:create, :update]))
    |> Enum.reduce(dsl, fn action, current_dsl ->
      updated_action = %{
        action | 
        allow_nil_input: (action.allow_nil_input || []) ++ [destination] |> Enum.uniq()
      }

      Transformer.replace_entity(
        current_dsl,
        [:actions],
        updated_action,
        &(&1.name == action.name)
      )
    end)
  end

  defp add_render_markdown_change(dsl, source, destination, extract_tasks?) do
    change_entity = 
      Transformer.build_entity!(
        Ash.Resource.Dsl, 
        [:changes], 
        :change,
        change: {
          Kyozo.Workspaces.Extensions.RenderMarkdown.Changes.RenderMarkdown,
          source: source, 
          destination: destination,
          extract_tasks?: extract_tasks?
        }
      )

    Transformer.add_entity(dsl, [:changes], change_entity)
  end

  defp ensure_html_attribute_exists(dsl, destination) do
    # Check if the destination attribute already exists
    existing_attributes = Transformer.get_entities(dsl, [:attributes])
    
    if Enum.any?(existing_attributes, &(&1.name == destination)) do
      dsl
    else
      # Add the HTML attribute if it doesn't exist
      html_attribute = 
        Transformer.build_entity!(
          Ash.Resource.Dsl,
          [:attributes],
          :attribute,
          name: destination,
          type: :string,
          allow_nil?: true,
          public?: true,
          description: "HTML rendered from markdown content"
        )

      Transformer.add_entity(dsl, [:attributes], html_attribute)
    end
  end

  defp setup_extension_attributes(dsl, render_attributes) do
    # Add any computed attributes or additional setup needed
    if Enum.any?(render_attributes) do
      add_markdown_metadata_attributes(dsl)
    else
      dsl
    end
  end

  defp add_markdown_metadata_attributes(dsl) do
    # Add calculation for markdown statistics if it doesn't exist
    existing_calculations = Transformer.get_entities(dsl, [:calculations])
    
    if Enum.any?(existing_calculations, &(&1.name == :markdown_stats)) do
      dsl
    else
      stats_calculation = 
        Transformer.build_entity!(
          Ash.Resource.Dsl,
          [:calculations],
          :calculate,
          name: :markdown_stats,
          type: :map,
          public?: true,
          description: "Statistics about markdown content (word count, reading time, etc.)",
          calculation: {
            Kyozo.Workspaces.Extensions.RenderMarkdown.Calculations.MarkdownStats,
            []
          }
        )

      Transformer.add_entity(dsl, [:calculations], stats_calculation)
    end
  end

  # Ensure this transformer runs after the basic resource structure is set up
  def after?(_), do: true

  # But before the final validations
  def before?(Ash.Resource.Transformers.ValidateRelationshipAttributes), do: true
  def before?(_), do: false
end