defmodule Dirup.Storage.VFS.Generators.ElixirProject do
  @behaviour Dirup.Storage.VFS.Generator

  @impl true
  def generate(%{files: files, path: path} = context) do
    if has_mix_file?(files) do
      [
        guide_file(path, context),
        deploy_file(path, context)
      ]
      |> Enum.reject(&is_nil/1)
    else
      []
    end
  end

  @impl true
  def handles_type?(type) do
    type in [:guide, :deploy]
  end

  @impl true
  def generate_content(:guide, context) do
    generate_guide_content(context)
  end

  @impl true
  def generate_content(:deploy, context) do
    generate_deploy_content(context)
  end

  @impl true
  def generate_content(_, _), do: ""

  defp guide_file(path, context) do
    %{
      name: "guide.md",
      path: Path.join(path, "guide.md"),
      generator: :elixir_guide,
      icon: "📚",
      content_generator: fn -> generate_guide_content(context) end
    }
  end

  defp deploy_file(path, context) do
    if deployable?(context) do
      %{
        name: "deploy.md",
        path: Path.join(path, "deploy.md"),
        generator: :elixir_deploy,
        icon: "🚀",
        content_generator: fn -> generate_deploy_content(context) end
      }
    end
  end

  defp generate_guide_content(context) do
    """
    # Elixir Project Guide

    <!-- livebook:{"kyozo":{"type":"documentation","generated_at":"#{DateTime.utc_now()}"}} -->

    Welcome to your Elixir project! This guide will help you get started.

    ## Quick Start

    ```bash
    # Install dependencies
    mix deps.get

    # Run tests
    mix test

    # Start interactive shell
    iex -S mix
    ```

    ## Project Structure

    #{analyze_project_structure(context)}

    ## Available Commands

    #{list_mix_tasks(context)}

    ## Configuration

    #{analyze_config(context)}

    #{if has_phoenix?(context.files), do: phoenix_specific_content(), else: ""}
    #{if has_nerves?(context.files), do: nerves_specific_content(), else: ""}
    #{if has_markdown?(context.files), do: markdown_specific_content(), else: ""}
    """
  end

  defp generate_deploy_content(context) do
    """
    # Deployment Guide

    <!-- livebook:{"kyozo":{"type":"deployment","generated_at":"#{DateTime.utc_now()}"}} -->

    ## Deployment Options

    This Elixir project can be deployed using various methods:

    ### 1. Release Build

    ```bash
    # Build a release
    MIX_ENV=prod mix release

    # Run the release
    _build/prod/rel/#{app_name(context)}/bin/#{app_name(context)} start
    ```

    ### 2. Docker Deployment

    ```dockerfile
    # Dockerfile
    FROM elixir:1.14-alpine AS build

    WORKDIR /app

    # Install dependencies
    COPY mix.exs mix.lock ./
    RUN mix deps.get --only prod

    # Copy source
    COPY . .

    # Build release
    RUN MIX_ENV=prod mix release

    # Runtime stage
    FROM alpine:3.18

    RUN apk add --no-cache libncurses

    WORKDIR /app

    COPY --from=build /app/_build/prod/rel/#{app_name(context)} ./

    CMD ["/app/bin/#{app_name(context)}", "start"]
    ```

    ### 3. Kyozo Deployment

    Deploy directly to Kyozo:

    ```elixir
    # Deploy this folder as a service
    {:ok, service} = Dirup.Services.deploy_folder(".", 
      name: "#{app_name(context)}",
      type: :elixir_app
    )
    ```

    ## Environment Variables

    #{detect_env_vars(context)}

    ## Health Checks

    #{generate_health_check_info(context)}
    """
  end

  defp has_mix_file?(files) do
    Enum.any?(files, &(&1.name == "mix.exs"))
  end

  defp deployable?(context) do
    context.files
    |> Enum.any?(
      &(&1.name in [
          "Dockerfile",
          "docker-compose.yml",
          "fly.toml",
          ".github/workflows/deploy.yml"
        ])
    )
  end

  defp has_phoenix?(files) do
    Enum.any?(files, &(&1.name == "mix.exs" and String.contains?(&1.content || "", ":phoenix")))
  end

  defp has_nerves?(files) do
    Enum.any?(files, &(&1.name == "mix.exs" and String.contains?(&1.content || "", ":nerves")))
  end

  defp has_markdown?(files) do
    Enum.any?(files, &String.ends_with?(&1.name, ".md"))
  end

  defp analyze_project_structure(context) do
    dirs =
      context.files
      |> Enum.filter(&(&1.type == "directory"))
      |> Enum.map(&"- `#{&1.name}/` - #{describe_directory(&1.name)}")
      |> Enum.join("\n")

    if dirs == "" do
      "No subdirectories found."
    else
      dirs
    end
  end

  defp describe_directory("lib"), do: "Application source code"
  defp describe_directory("test"), do: "Test files"
  defp describe_directory("config"), do: "Configuration files"
  defp describe_directory("priv"), do: "Private application files"
  defp describe_directory("assets"), do: "Frontend assets (Phoenix)"
  defp describe_directory("deps"), do: "Dependencies (git ignored)"
  defp describe_directory(_), do: "Project directory"

  defp list_mix_tasks(_context) do
    """
    ```bash
    # Common mix tasks
    mix compile         # Compile the project
    mix test           # Run tests
    mix format         # Format code
    mix deps.get       # Get dependencies
    mix deps.update    # Update dependencies
    mix credo          # Run code analysis (if installed)
    mix dialyzer       # Run type checking (if installed)
    ```
    """
  end

  defp analyze_config(context) do
    config_files =
      context.files
      |> Enum.filter(&(&1.type == "file" and String.starts_with?(&1.name, "config")))
      |> Enum.map(&"- `#{&1.name}`")
      |> Enum.join("\n")

    if config_files == "" do
      "No configuration files found."
    else
      "Configuration files found:\n#{config_files}"
    end
  end

  defp phoenix_specific_content do
    """

    ## Phoenix Framework Detected

    ### Development Server

    ```bash
    # Start Phoenix server
    mix phx.server

    # Or start with interactive shell
    iex -S mix phx.server
    ```

    ### Phoenix Commands

    ```bash
    mix phx.routes         # List all routes
    mix phx.gen.html      # Generate HTML resources
    mix phx.gen.json      # Generate JSON resources
    mix phx.gen.live      # Generate LiveView resources
    mix ecto.create       # Create database
    mix ecto.migrate      # Run migrations
    ```

    Access your application at: http://localhost:4000
    """
  end

  defp nerves_specific_content do
    """

    ## Nerves Framework Detected

    ### Firmware Build

    ```bash
    # Set target hardware
    export MIX_TARGET=rpi0

    # Get dependencies for target
    mix deps.get

    # Build firmware
    mix firmware

    # Burn to SD card
    mix firmware.burn
    ```
    """
  end

  defp markdown_specific_content do
    """

    ## Markdown Files Detected

    You have Markdown files in your project! You can:

    1. View them as documentation
    2. Edit them in your favorite editor
    3. Render them with markdown processors

    ```bash
    # View markdown files
    cat *.md
    ```
    """
  end

  defp app_name(context) do
    # Try to extract app name from mix.exs or fallback to directory name
    mix_file = Enum.find(context.files, &(&1.name == "mix.exs"))

    if mix_file && mix_file.content do
      case Regex.run(~r/app:\s*:(\w+)/, mix_file.content) do
        [_, name] -> name
        _ -> Path.basename(context.path)
      end
    else
      Path.basename(context.path)
    end
  end

  defp detect_env_vars(context) do
    env_example = Enum.find(context.files, &(&1.name in [".env.example", ".env.sample"]))

    if env_example do
      """
      Found environment configuration in `#{env_example.name}`.

      Required environment variables:
      ```bash
      #{parse_env_example(env_example)}
      ```
      """
    else
      "No environment configuration file found. Check your application configuration."
    end
  end

  defp parse_env_example(_file) do
    # In a real implementation, we'd parse the file content
    """
    DATABASE_URL=postgres://user:pass@localhost/dbname
    SECRET_KEY_BASE=generate_with_mix_phx.gen.secret
    PORT=4000
    """
  end

  defp generate_health_check_info(context) do
    if has_phoenix?(context.files) do
      """
      ```elixir
      # Add a health check endpoint
      get "/health", HealthController, :index

      # Simple health controller
      defmodule MyAppWeb.HealthController do
        use MyAppWeb, :controller
        
        def index(conn, _params) do
          json(conn, %{status: "ok", timestamp: DateTime.utc_now()})
        end
      end
      ```
      """
    else
      """
      ```elixir
      # Add health check to your application
      def health_check do
        %{
          status: "ok",
          app: :#{app_name(context)},
          timestamp: DateTime.utc_now()
        }
      end
      ```
      """
    end
  end
end
