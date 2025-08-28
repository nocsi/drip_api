defmodule Dirup.MarkdownLD.StreamParser.Pipeline do
  @moduledoc """
  Pipeline system for composable markdown processing.

  Provides a flexible architecture for chaining parsers, transforms, and listeners
  to create custom processing workflows.

  ## Example

      pipeline = Pipeline.new()
        |> Pipeline.add_parser(SemanticExtractor)
        |> Pipeline.add_transform(AIEnhancer)
        |> Pipeline.add_listener(MetricsCollector)

  """

  alias Dirup.MarkdownLD.StreamParser.{Parser, Transform, Listener}

  @type plugin_type :: :parser | :transform | :listener
  @type plugin_module :: module()
  @type plugin_entry :: %{
          type: plugin_type(),
          module: plugin_module(),
          priority: integer(),
          enabled: boolean(),
          config: map()
        }

  @type t :: %__MODULE__{
          parsers: [plugin_entry()],
          transforms: [plugin_entry()],
          listeners: [plugin_entry()],
          config: map()
        }

  defstruct parsers: [],
            transforms: [],
            listeners: [],
            config: %{}

  @doc """
  Create a new empty pipeline.
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      config: Enum.into(opts, %{})
    }
  end

  @doc """
  Add a parser to the pipeline.

  Parsers extract data from markdown chunks.
  """
  @spec add_parser(t(), plugin_module(), keyword()) :: t()
  def add_parser(pipeline, parser_module, opts \\ []) do
    plugin_entry = create_plugin_entry(:parser, parser_module, opts)

    updated_parsers =
      pipeline.parsers
      |> add_plugin_sorted(plugin_entry)

    %{pipeline | parsers: updated_parsers}
  end

  @doc """
  Add a transform to the pipeline.

  Transforms modify or enhance parsed data.
  """
  @spec add_transform(t(), plugin_module(), keyword()) :: t()
  def add_transform(pipeline, transform_module, opts \\ []) do
    plugin_entry = create_plugin_entry(:transform, transform_module, opts)

    updated_transforms =
      pipeline.transforms
      |> add_plugin_sorted(plugin_entry)

    %{pipeline | transforms: updated_transforms}
  end

  @doc """
  Add a listener to the pipeline.

  Listeners receive events and data for monitoring or side effects.
  """
  @spec add_listener(t(), plugin_module(), keyword()) :: t()
  def add_listener(pipeline, listener_module, opts \\ []) do
    plugin_entry = create_plugin_entry(:listener, listener_module, opts)

    updated_listeners =
      pipeline.listeners
      |> add_plugin_sorted(plugin_entry)

    %{pipeline | listeners: updated_listeners}
  end

  @doc """
  Remove a plugin from the pipeline by module.
  """
  @spec remove_plugin(t(), plugin_module()) :: t()
  def remove_plugin(pipeline, plugin_module) do
    %{
      pipeline
      | parsers: Enum.reject(pipeline.parsers, &(&1.module == plugin_module)),
        transforms: Enum.reject(pipeline.transforms, &(&1.module == plugin_module)),
        listeners: Enum.reject(pipeline.listeners, &(&1.module == plugin_module))
    }
  end

  @doc """
  Enable or disable a plugin.
  """
  @spec toggle_plugin(t(), plugin_module(), boolean()) :: t()
  def toggle_plugin(pipeline, plugin_module, enabled) do
    %{
      pipeline
      | parsers: toggle_plugin_in_list(pipeline.parsers, plugin_module, enabled),
        transforms: toggle_plugin_in_list(pipeline.transforms, plugin_module, enabled),
        listeners: toggle_plugin_in_list(pipeline.listeners, plugin_module, enabled)
    }
  end

  @doc """
  Get all plugins of a specific type.
  """
  @spec get_plugins(t(), plugin_type()) :: [plugin_entry()]
  def get_plugins(pipeline, type) do
    case type do
      :parser -> pipeline.parsers
      :transform -> pipeline.transforms
      :listener -> pipeline.listeners
    end
    |> Enum.filter(& &1.enabled)
  end

  @doc """
  Get only the enabled plugin modules of a specific type.
  """
  @spec get_plugin_modules(t(), plugin_type()) :: [plugin_module()]
  def get_plugin_modules(pipeline, type) do
    get_plugins(pipeline, type)
    |> Enum.map(& &1.module)
  end

  @doc """
  Update pipeline configuration.
  """
  @spec configure(t(), map()) :: t()
  def configure(pipeline, config) do
    %{pipeline | config: Map.merge(pipeline.config, config)}
  end

  @doc """
  Validate that all plugins in the pipeline implement required behaviors.
  """
  @spec validate(t()) :: :ok | {:error, [term()]}
  def validate(pipeline) do
    errors = []

    parser_errors = validate_plugins(pipeline.parsers, Parser)
    transform_errors = validate_plugins(pipeline.transforms, Transform)
    listener_errors = validate_plugins(pipeline.listeners, Listener)

    all_errors = parser_errors ++ transform_errors ++ listener_errors

    case all_errors do
      [] -> :ok
      errors -> {:error, errors}
    end
  end

  @doc """
  Create a pipeline from a configuration map.

  ## Example Configuration

      config = %{
        parsers: [
          %{module: SemanticExtractor, priority: 10, config: %{depth: 3}},
          %{module: HeaderParser, priority: 5}
        ],
        transforms: [
          %{module: AIEnhancer, priority: 10, config: %{model: "gpt-4"}}
        ],
        listeners: [
          %{module: MetricsCollector, priority: 0}
        ]
      }

  """
  @spec from_config(map()) :: t()
  def from_config(config) do
    pipeline = new()

    pipeline =
      config
      |> Map.get(:parsers, [])
      |> Enum.reduce(pipeline, fn parser_config, acc ->
        add_parser(acc, parser_config.module, Map.to_list(parser_config))
      end)

    pipeline =
      config
      |> Map.get(:transforms, [])
      |> Enum.reduce(pipeline, fn transform_config, acc ->
        add_transform(acc, transform_config.module, Map.to_list(transform_config))
      end)

    pipeline =
      config
      |> Map.get(:listeners, [])
      |> Enum.reduce(pipeline, fn listener_config, acc ->
        add_listener(acc, listener_config.module, Map.to_list(listener_config))
      end)

    configure(pipeline, Map.get(config, :config, %{}))
  end

  @doc """
  Convert pipeline to configuration map for serialization.
  """
  @spec to_config(t()) :: map()
  def to_config(pipeline) do
    %{
      parsers: Enum.map(pipeline.parsers, &plugin_entry_to_config/1),
      transforms: Enum.map(pipeline.transforms, &plugin_entry_to_config/1),
      listeners: Enum.map(pipeline.listeners, &plugin_entry_to_config/1),
      config: pipeline.config
    }
  end

  @doc """
  Merge two pipelines together.
  """
  @spec merge(t(), t()) :: t()
  def merge(pipeline1, pipeline2) do
    %__MODULE__{
      parsers: merge_plugin_lists(pipeline1.parsers, pipeline2.parsers),
      transforms: merge_plugin_lists(pipeline1.transforms, pipeline2.transforms),
      listeners: merge_plugin_lists(pipeline1.listeners, pipeline2.listeners),
      config: Map.merge(pipeline1.config, pipeline2.config)
    }
  end

  @doc """
  Clone a pipeline with optional modifications.
  """
  @spec clone(t(), keyword()) :: t()
  def clone(pipeline, modifications \\ []) do
    base_pipeline = %__MODULE__{
      parsers: pipeline.parsers,
      transforms: pipeline.transforms,
      listeners: pipeline.listeners,
      config: pipeline.config
    }

    Enum.reduce(modifications, base_pipeline, fn
      {:add_parser, {module, opts}}, acc ->
        add_parser(acc, module, opts)

      {:add_transform, {module, opts}}, acc ->
        add_transform(acc, module, opts)

      {:add_listener, {module, opts}}, acc ->
        add_listener(acc, module, opts)

      {:remove_plugin, module}, acc ->
        remove_plugin(acc, module)

      {:configure, config}, acc ->
        configure(acc, config)

      _, acc ->
        acc
    end)
  end

  @doc """
  Get pipeline statistics and information.
  """
  @spec stats(t()) :: map()
  def stats(pipeline) do
    enabled_parsers = Enum.count(pipeline.parsers, & &1.enabled)
    enabled_transforms = Enum.count(pipeline.transforms, & &1.enabled)
    enabled_listeners = Enum.count(pipeline.listeners, & &1.enabled)

    %{
      total_plugins: enabled_parsers + enabled_transforms + enabled_listeners,
      parsers: %{
        total: length(pipeline.parsers),
        enabled: enabled_parsers,
        disabled: length(pipeline.parsers) - enabled_parsers
      },
      transforms: %{
        total: length(pipeline.transforms),
        enabled: enabled_transforms,
        disabled: length(pipeline.transforms) - enabled_transforms
      },
      listeners: %{
        total: length(pipeline.listeners),
        enabled: enabled_listeners,
        disabled: length(pipeline.listeners) - enabled_listeners
      },
      config_keys: Map.keys(pipeline.config)
    }
  end

  # Private helper functions

  defp create_plugin_entry(type, module, opts) do
    %{
      type: type,
      module: module,
      priority: Keyword.get(opts, :priority, 0),
      enabled: Keyword.get(opts, :enabled, true),
      config: Keyword.get(opts, :config, %{}) |> Enum.into(%{})
    }
  end

  defp add_plugin_sorted(plugin_list, new_plugin) do
    # Remove existing plugin with same module, then add new one
    plugin_list
    |> Enum.reject(&(&1.module == new_plugin.module))
    |> Kernel.++([new_plugin])
    |> Enum.sort_by(& &1.priority, :desc)
  end

  defp toggle_plugin_in_list(plugin_list, plugin_module, enabled) do
    Enum.map(plugin_list, fn plugin ->
      if plugin.module == plugin_module do
        %{plugin | enabled: enabled}
      else
        plugin
      end
    end)
  end

  defp validate_plugins(plugins, behavior) do
    plugins
    |> Enum.filter(& &1.enabled)
    |> Enum.flat_map(fn plugin ->
      case validate_plugin_behavior(plugin.module, behavior) do
        :ok -> []
        {:error, reason} -> [{plugin.module, reason}]
      end
    end)
  end

  defp validate_plugin_behavior(module, behavior) do
    required_functions = get_behavior_functions(behavior)

    missing_functions =
      required_functions
      |> Enum.reject(fn {name, arity} ->
        function_exported?(module, name, arity)
      end)

    case missing_functions do
      [] -> :ok
      missing -> {:error, {:missing_functions, missing}}
    end
  end

  defp get_behavior_functions(Parser), do: [{:parse, 3}]
  defp get_behavior_functions(Transform), do: [{:transform, 3}]
  defp get_behavior_functions(Listener), do: [{:handle_event, 3}]

  defp plugin_entry_to_config(plugin_entry) do
    %{
      module: plugin_entry.module,
      priority: plugin_entry.priority,
      enabled: plugin_entry.enabled,
      config: plugin_entry.config
    }
  end

  defp merge_plugin_lists(list1, list2) do
    # Create a map for deduplication by module
    combined =
      (list1 ++ list2)
      |> Enum.reduce(%{}, fn plugin, acc ->
        Map.put(acc, plugin.module, plugin)
      end)
      |> Map.values()

    # Sort by priority
    Enum.sort_by(combined, & &1.priority, :desc)
  end
end
