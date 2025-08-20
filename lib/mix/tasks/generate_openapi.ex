defmodule Mix.Tasks.GenerateFromOpenapi do
  use Mix.Task

  @shortdoc "Generates Ash domain/resources from an OpenAPI file if missing, using Ash generators"

  def run([openapi_path]) do
    # Ensure deps and tasks are loaded
    Mix.Task.run("deps.loadpaths")
    Mix.Task.run("loadpaths")

    # Get app details
    app = Atom.to_string(Mix.Project.config()[:app])
    app_module = Macro.camelize(app)

    # Parse and cast the OpenAPI file (assume YAML; adjust for JSON)
    {:ok, spec_map} = YamlElixir.read_from_file(openapi_path)
    openapi_spec = spec_map

    # Extract domain info from title (e.g., "kyozo.workspace.v1" -> Workspace)
    {domain_name, domain_module} = extract_domain_info(openapi_spec, app_module)

    # Extract schemas and paths
    schemas = get_in(openapi_spec, ["components", "schemas"]) || %{}
    paths = openapi_spec["paths"] || %{}

    # Filter and deduplicate schemas
    filtered_schemas = filter_schemas(schemas)

    Mix.shell().info("Generating domain #{domain_name} with #{map_size(filtered_schemas)} resources...")

    # Generate domain if it doesn't exist
    generate_domain_if_missing(domain_module, domain_name, app)

    # Generate resources for each schema

    Enum.each(filtered_schemas, fn {resource_name, schema_struct} ->
      if should_generate_resource?(schema_struct) do
        case generate_resource(resource_name, schema_struct, domain_module,
                              openapi_spec, paths, app_module) do
          {:ok, resource_module} ->
            add_resource_to_domain(domain_module, resource_module)
            Mix.shell().info("  Generated resource #{inspect(resource_module)}")

          {:error, reason} ->
            Mix.shell().error("  Failed to generate resource #{resource_name}: #{reason}")
        end
      else
        Mix.shell().info("  Skipping #{resource_name} (not suitable for resource generation)")
      end
    end)

    Mix.shell().info("Generation complete from #{openapi_path}. Domain: #{domain_name}")
    Mix.shell().info("Next steps:")
    Mix.shell().info("  1. Review generated resources in lib/#{Macro.underscore(app)}/#{Macro.underscore(domain_name)}/")
    Mix.shell().info("  2. Run `mix ash.codegen #{Macro.underscore(domain_name)}_generated`")
    Mix.shell().info("  3. Run `mix ash.migrate` to apply database changes")
    Mix.shell().info("  4. Validate with your OpenAPI spec")
  end

  def run(_) do
    Mix.shell().error("Usage: mix generate_from_openapi <path_to_openapi_file>")
    Mix.shell().info("Example: mix generate_from_openapi priv/openapi/kyozo/workspace/v1/workspace.openapi.yaml")
  end

  # Extract domain information from OpenAPI spec
  defp extract_domain_info(openapi_spec, app_module) do
    title = get_in(openapi_spec, ["info", "title"]) || "Api"

    # Handle dotted titles like "kyozo.workspace.v1"
    domain_parts = title
    |> String.split(".")
    |> Enum.take(2) # Take first two parts: "kyozo.workspace"
    |> Enum.map(&Macro.camelize/1)

    domain_name = case domain_parts do
      [_app, domain] -> domain
      [domain] -> domain
      [] -> "Api"
      _ -> Enum.join(domain_parts, "")
    end

    domain_module = Module.concat([app_module, domain_name])
    {domain_name, domain_module}
  end

  # Filter out utility schemas and keep only meaningful ones
  defp filter_schemas(schemas) do
    schemas
    |> Enum.filter(&should_include_schema?/1)
    |> Enum.into(%{})
  end

  # Determine if schema should be included in generation
  defp should_include_schema?({schema_name, _schema_struct}) do
    name_str = to_string(schema_name)

    # Skip utility schemas
    not (String.starts_with?(name_str, "connect") or
         String.contains?(name_str, "google.protobuf") or
         String.contains?(name_str, "Connect") or
         String.ends_with?(name_str, "Entry") or # Skip metadata entries
         name_str in ["connect-protocol-version", "connect-timeout-header"])
  end

  # Check if schema should generate a resource
  defp should_generate_resource?(schema_struct) do
    case schema_struct do
      # Skip primitive enums and constants
      %{"type" => "string", "enum" => _} -> false
      %{"type" => type, "const" => _} when type in ["string", "number", "integer", "boolean"] -> false

      # Skip primitives without properties
      %{"type" => type} when type in ["string", "number", "integer", "boolean"] ->
        Map.has_key?(schema_struct, "properties") and map_size(Map.get(schema_struct, "properties", %{})) > 0

      # Include objects with properties
      %{"type" => "object", "properties" => properties} when map_size(properties) > 0 -> true
      %{"properties" => properties} when map_size(properties) > 0 -> true

      # Include union types
      %{"oneOf" => _} -> true
      %{"anyOf" => _} -> true
      %{"allOf" => _} -> true

      # Skip everything else
      _ -> false
    end
  end

  # Generate a single resource
  defp generate_resource(resource_name, schema_struct, domain_module, openapi_spec, paths, app_module) do
    # Clean resource name for module creation
    clean_name = resource_name
    |> to_string()
    |> String.split(".")
    |> List.last()
    |> String.replace(~r/[^a-zA-Z0-9_]/, "_")
    |> Macro.camelize()

    resource_module = Module.concat([domain_module, clean_name])

    # Check if resource already exists
    if resource_already_exists?(resource_module) do
      {:error, "Resource already exists"}
    else
      # Collect attribute and relationship args from properties
      {attr_args, rel_args} = process_schema_properties(schema_struct, openapi_spec, app_module)

      # Infer actions from paths
      actions = infer_actions_from_paths(paths, clean_name, resource_name)

      # Build args for ash.gen.resource
      gen_args = [
        inspect(resource_module),
        "--domain", inspect(domain_module),
        "--extend", "json_api,postgres",
        "--timestamps",
        "--yes"
      ] ++ attr_args ++ rel_args ++ actions

      # Run the generator
      try do
        result = Mix.Task.run("ash.gen.resource", gen_args)
        case result do
          :ok -> {:ok, resource_module}
          _ -> {:ok, resource_module} # ash.gen.resource doesn't always return :ok
        end
      rescue
        error ->
          {:error, Exception.message(error)}
      end
    end
  end

  # Check if resource file already exists
  defp resource_already_exists?(resource_module) do
    resource_file = resource_module_to_path(resource_module)
    File.exists?(resource_file)
  end

  # Convert resource module to file path
  defp resource_module_to_path(resource_module) do
    path_parts = resource_module
    |> Module.split()
    |> Enum.map(&Macro.underscore/1)

    "lib/" <> Enum.join(path_parts, "/") <> ".ex"
  end

  # Generate domain module if it doesn't exist
  defp generate_domain_if_missing(domain_module, domain_name, app) do
    domain_file = domain_module_to_path(domain_module)

    unless File.exists?(domain_file) do
      Mix.shell().info("Creating domain #{domain_name}...")

      domain_content = """
      defmodule #{inspect(domain_module)} do
        use Ash.Domain,
          otp_app: :#{app},
          extensions: [AshJsonApi.Domain]

        json_api do
          authorize? false
        end

        resources do
          # Resources will be added by the generator
        end
      end
      """

      File.mkdir_p!(Path.dirname(domain_file))
      File.write!(domain_file, domain_content)
    end
  end

  # Add resource to domain file if not already present
  defp add_resource_to_domain(domain_module, resource_module) do
    domain_file = domain_module_to_path(domain_module)

    if File.exists?(domain_file) do
      content = File.read!(domain_file)

      # Use inspect to avoid Elixir. prefix
      resource_name = inspect(resource_module)
      unless String.contains?(content, "resource #{resource_name}") do
        # Simple string replacement - find "resources do" and add after it
        if String.contains?(content, "resources do") do
          new_content = String.replace(content,
            "resources do\n    # Resources will be added by the generator",
            "resources do\n    # Resources will be added by the generator\n    resource #{resource_name}"
          )

          # If that didn't work, try a more general replacement
          new_content = if new_content == content do
            String.replace(content, "resources do", "resources do\n    resource #{resource_name}")
          else
            new_content
          end

          if new_content != content do
            File.write!(domain_file, new_content)
          end
        end
      end
    end
  end

  # Convert domain module to file path
  defp domain_module_to_path(domain_module) do
    path_parts = domain_module
    |> Module.split()
    |> Enum.map(&Macro.underscore/1)

    "lib/" <> Enum.join(path_parts, "/") <> ".ex"
  end

  # Process schema properties to extract attributes and relationships
  defp process_schema_properties(schema_struct, openapi_spec, app_module) do
    properties = Map.get(schema_struct, "properties", %{})
    required_fields = Map.get(schema_struct, "required", [])

    Enum.reduce(properties, {[], []}, fn {attr_name, attr_schema}, {attrs, rels} ->
      attr_name_str = to_string(attr_name)
      required? = Enum.member?(required_fields, attr_name_str)

      case resolve_property_type(attr_schema, openapi_spec, app_module) do
        {:attribute, type} ->
          modifiers = build_attribute_modifiers(required?, attr_schema)
          # Convert camelCase/snake_case to snake_case for Ash
          clean_attr_name = Macro.underscore(attr_name_str)
          attr = "#{clean_attr_name}:#{type}#{modifiers}"
          {["--attribute", attr | attrs], rels}

        {:relationship, rel_type, dest_module} ->
          modifiers = if required?, do: ":required", else: ""
          clean_attr_name = Macro.underscore(attr_name_str)
          rel = "#{rel_type}:#{clean_attr_name}:#{dest_module}#{modifiers}"
          {attrs, ["--relationship", rel | rels]}
      end
    end)
  end

  # Resolve property type to either attribute or relationship
  defp resolve_property_type(attr_schema, openapi_spec, app_module) do
    cond do
      # Direct $ref - belongs_to relationship
      Map.has_key?(attr_schema, "$ref") ->
        ref_name = extract_ref_name(attr_schema["$ref"])
        dest_module = Module.concat([app_module, Macro.camelize(ref_name)])
        {:relationship, "belongs_to", dest_module}

      # Array with $ref items - has_many relationship
      attr_schema["type"] == "array" &&
      attr_schema["items"] &&
      Map.has_key?(attr_schema["items"], "$ref") ->
        ref_name = extract_ref_name(attr_schema["items"]["$ref"])
        dest_module = Module.concat([app_module, Macro.camelize(ref_name)])
        {:relationship, "has_many", dest_module}

      # Regular attribute
      true ->
        resolved_schema = resolve_schema(attr_schema, openapi_spec)
        type = map_openapi_type_to_ash(resolved_schema)
        {:attribute, type}
    end
  end

  # Extract reference name from $ref path
  defp extract_ref_name(ref_path) do
    ref_path
    |> String.split("/")
    |> List.last()
    |> String.split(".")
    |> List.last()
  end

  # Resolve schema references
  defp resolve_schema(%{"$ref" => ref_path}, openapi_spec) do
    ref_parts = String.split(ref_path, "/") |> Enum.drop(1) # Remove leading "#"
    get_in(openapi_spec, ref_parts) || %{}
  end
  defp resolve_schema(schema, _openapi_spec), do: schema

  # Build attribute modifiers string
  defp build_attribute_modifiers(required?, attr_schema) do
    modifiers = ["public"] # Always make public for API
    modifiers = if required?, do: ["required" | modifiers], else: modifiers

    # Add format constraints
    modifiers = case attr_schema["format"] do
      "email" -> ["email" | modifiers]
      "uri" -> ["url" | modifiers]
      "date-time" -> modifiers # datetime type handles this
      _ -> modifiers
    end

    if length(modifiers) > 0 do
      ":" <> Enum.join(modifiers, ":")
    else
      ""
    end
  end

  # Map OpenAPI types to Ash types
  defp map_openapi_type_to_ash(%{"type" => "string", "format" => "date-time"}), do: "utc_datetime_usec"
  defp map_openapi_type_to_ash(%{"type" => "string", "format" => "date"}), do: "date"
  defp map_openapi_type_to_ash(%{"type" => "string", "format" => "email"}), do: "ci_string"
  defp map_openapi_type_to_ash(%{"type" => "string", "format" => "uuid"}), do: "uuid"
  defp map_openapi_type_to_ash(%{"type" => "string", "format" => "binary"}), do: "binary"
  defp map_openapi_type_to_ash(%{"type" => "string", "enum" => _}), do: "atom"
  defp map_openapi_type_to_ash(%{"type" => "string"}), do: "string"
  defp map_openapi_type_to_ash(%{"type" => "integer", "format" => "int64"}), do: "integer"
  defp map_openapi_type_to_ash(%{"type" => "integer"}), do: "integer"
  defp map_openapi_type_to_ash(%{"type" => "number"}), do: "decimal"
  defp map_openapi_type_to_ash(%{"type" => "boolean"}), do: "boolean"
  defp map_openapi_type_to_ash(%{"type" => "object"}), do: "map"
  defp map_openapi_type_to_ash(%{"type" => "array", "items" => _items}) do
    # For command line compatibility, use string type for arrays
    # TODO: Manually change to {:array, :string} in generated resource files
    "string"
  end
  defp map_openapi_type_to_ash(%{"oneOf" => _}), do: "union"
  defp map_openapi_type_to_ash(%{"anyOf" => _}), do: "union"
  defp map_openapi_type_to_ash(_), do: "string" # Fallback

  # Infer Ash actions from OpenAPI paths
  defp infer_actions_from_paths(paths, clean_name, full_resource_name) do
    # Try different path patterns based on the service structure
    service_patterns = [
      "/#{full_resource_name}/",
      "/#{clean_name}/",
      "/#{Macro.underscore(clean_name)}/",
    ]

    # Also try REST-style patterns
    rest_patterns = [
      "/#{Macro.underscore(clean_name)}s", # Plural
      "/#{Macro.underscore(clean_name)}", # Singular
      "/#{String.downcase(clean_name)}s", # Lowercase plural
      "/#{String.downcase(clean_name)}" # Lowercase singular
    ]

    all_patterns = service_patterns ++ rest_patterns

    # Find matching paths
    matching_paths = Enum.filter(paths, fn {path, _ops} ->
      Enum.any?(all_patterns, &String.contains?(path, &1))
    end)

    # Extract operations from matching paths
    all_ops = Enum.flat_map(matching_paths, fn {_path, ops} -> Map.keys(ops) end)

    # Determine actions based on HTTP methods found
    actions = []
    actions = if Enum.any?(all_ops, &(&1 in ["post"])), do: ["create" | actions], else: actions
    actions = if Enum.any?(all_ops, &(&1 in ["get"])), do: ["read" | actions], else: actions
    actions = if Enum.any?(all_ops, &(&1 in ["patch", "put"])), do: ["update" | actions], else: actions
    actions = if Enum.any?(all_ops, &(&1 in ["delete"])), do: ["destroy" | actions], else: actions

    case actions do
      [] -> ["--default-actions", "create,read,update,destroy"]
      _ -> ["--default-actions", Enum.reverse(actions) |> Enum.join(",")]
    end
  end
end
