defmodule Dirup.Storage.VFS.Templates do
  @moduledoc """
  Customizable templates for virtual file generation
  """

  alias Dirup.Storage.VFS.Cache

  @doc """
  Register a custom template for a generator
  """
  def register_template(workspace_id, generator_type, template_name, template_content) do
    key = "vfs:template:#{workspace_id}:#{generator_type}:#{template_name}"

    template = %{
      content: template_content,
      variables: extract_variables(template_content),
      created_at: DateTime.utc_now(),
      workspace_id: workspace_id,
      generator_type: generator_type,
      name: template_name
    }

    Cache.put(key, template, ttl: :infinity)
    {:ok, template}
  end

  @doc """
  Get a custom template or fall back to default
  """
  def get_template(workspace_id, generator_type, template_name) do
    key = "vfs:template:#{workspace_id}:#{generator_type}:#{template_name}"

    case Cache.get(key) do
      {:ok, template} -> {:ok, template}
      :miss -> get_default_template(generator_type, template_name)
    end
  end

  @doc """
  Render a template with variables
  """
  def render_template(template_content, variables \\ %{}) do
    variables
    |> Enum.reduce(template_content, fn {key, value}, content ->
      String.replace(content, "{{#{key}}}", to_string(value))
    end)
  end

  @doc """
  List all custom templates for a workspace
  """
  def list_templates(workspace_id) do
    # In production, this would query from database
    {:ok, []}
  end

  @doc """
  Default templates that can be customized
  """
  def default_templates do
    %{
      elixir_guide: %{
        quick_start: """
        # {{project_name}} Quick Start

        Generated on {{date}} for {{workspace_name}}

        ## Getting Started

        ```bash
        # Install dependencies
        mix deps.get

        # Run tests
        mix test
        ```

        ## Custom Instructions

        {{custom_instructions}}
        """,
        deploy_guide: """
        # Deploying {{project_name}}

        ## Deployment Options

        {{#if has_docker}}
        ### Docker Deployment
        ```bash
        docker build -t {{project_name}} .
        docker run -p 4000:4000 {{project_name}}
        ```
        {{/if}}

        ## Environment Variables

        {{env_vars}}
        """
      }
    }
  end

  defp extract_variables(template_content) do
    ~r/\{\{(\w+)\}\}/
    |> Regex.scan(template_content)
    |> Enum.map(fn [_, var] -> var end)
    |> Enum.uniq()
  end

  defp get_default_template(generator_type, template_name) do
    case get_in(default_templates(), [generator_type, template_name]) do
      nil -> {:error, :template_not_found}
      template -> {:ok, %{content: template, variables: extract_variables(template)}}
    end
  end
end
