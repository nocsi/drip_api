defmodule Dirup.Storage.VFS.Generators.NodeProject do
  @behaviour Dirup.Storage.VFS.Generator

  @impl true
  def generate(%{files: files, path: path} = context) do
    if has_package_json?(files) do
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
      generator: :node_guide,
      icon: "📦",
      content_generator: fn -> generate_guide_content(context) end
    }
  end

  defp deploy_file(path, context) do
    if deployable?(context) do
      %{
        name: "deploy.md",
        path: Path.join(path, "deploy.md"),
        generator: :node_deploy,
        icon: "🚀",
        content_generator: fn -> generate_deploy_content(context) end
      }
    end
  end

  defp generate_guide_content(context) do
    """
    # Node.js Project Guide

    <!-- livebook:{"kyozo":{"type":"documentation","generated_at":"#{DateTime.utc_now()}"}} -->

    Welcome to your Node.js project! This guide will help you get started.

    ## Quick Start

    ```bash
    # Install dependencies
    #{package_manager(context)} install

    # Run development server
    #{dev_command(context)}

    # Run tests
    #{test_command(context)}
    ```

    ## Project Type

    #{detect_project_type(context)}

    ## Available Scripts

    #{list_npm_scripts(context)}

    ## Dependencies

    #{analyze_dependencies(context)}
    """
  end

  defp generate_deploy_content(context) do
    """
    # Node.js Deployment Guide

    <!-- livebook:{"kyozo":{"type":"deployment","generated_at":"#{DateTime.utc_now()}"}} -->

    ## Build Process

    ```bash
    # Install production dependencies
    #{package_manager(context)} install --production

    # Build the application
    #{build_command(context)}
    ```

    ## Deployment Options

    ### 1. Docker Deployment

    ```dockerfile
    FROM node:18-alpine

    WORKDIR /app

    # Copy package files
    COPY package*.json ./
    #{if has_yarn?(context.files), do: "COPY yarn.lock ./", else: ""}

    # Install dependencies
    RUN #{package_manager(context)} install --production

    # Copy application
    COPY . .

    # Build if needed
    #{if has_build_script?(context), do: "RUN #{package_manager(context)} run build", else: ""}

    EXPOSE #{detect_port(context)}

    CMD ["#{package_manager(context)}", "start"]
    ```

    ### 2. Kyozo Deployment

    ```elixir
    # Deploy this Node.js app
    {:ok, service} = Dirup.Services.deploy_folder(".",
      name: "#{app_name(context)}",
      type: :node_app,
      port: #{detect_port(context)}
    )
    ```

    ## Environment Variables

    #{detect_env_vars(context)}
    """
  end

  defp has_package_json?(files) do
    Enum.any?(files, &(&1.name == "package.json"))
  end

  defp deployable?(context) do
    has_package_json?(context.files)
  end

  defp package_manager(context) do
    cond do
      has_yarn?(context.files) -> "yarn"
      has_pnpm?(context.files) -> "pnpm"
      true -> "npm"
    end
  end

  defp has_yarn?(files), do: Enum.any?(files, &(&1.name == "yarn.lock"))
  defp has_pnpm?(files), do: Enum.any?(files, &(&1.name == "pnpm-lock.yaml"))

  defp dev_command(context) do
    pm = package_manager(context)

    if has_script?(context, "dev") do
      "#{pm} run dev"
    else
      "#{pm} start"
    end
  end

  defp test_command(context) do
    pm = package_manager(context)

    if has_script?(context, "test") do
      "#{pm} test"
    else
      "# No test script defined"
    end
  end

  defp build_command(context) do
    pm = package_manager(context)

    if has_script?(context, "build") do
      "#{pm} run build"
    else
      "# No build required"
    end
  end

  defp has_script?(_context, _script) do
    # In real implementation, parse package.json
    true
  end

  defp has_build_script?(context), do: has_script?(context, "build")

  defp detect_project_type(context) do
    files = context.files

    cond do
      Enum.any?(files, &(&1.name == "next.config.js")) ->
        "This is a **Next.js** application."

      Enum.any?(files, &(&1.name in ["gatsby-config.js", "gatsby-node.js"])) ->
        "This is a **Gatsby** site."

      Enum.any?(files, &(&1.name == "nuxt.config.js")) ->
        "This is a **Nuxt.js** application."

      Enum.any?(files, &(&1.name == "vite.config.js")) ->
        "This is a **Vite** application."

      Enum.any?(files, &(&1.name in ["webpack.config.js", "react-scripts"])) ->
        "This is a **React** application."

      Enum.any?(files, &(&1.name == "angular.json")) ->
        "This is an **Angular** application."

      Enum.any?(files, &(&1.name == "vue.config.js")) ->
        "This is a **Vue.js** application."

      true ->
        "This is a Node.js application."
    end
  end

  defp list_npm_scripts(_context) do
    # In real implementation, parse package.json
    """
    ```json
    {
      "scripts": {
        "dev": "next dev",
        "build": "next build",
        "start": "next start",
        "test": "jest",
        "lint": "eslint ."
      }
    }
    ```
    """
  end

  defp analyze_dependencies(_context) do
    # In real implementation, parse package.json
    """
    Key dependencies detected:
    - React framework
    - Express server
    - TypeScript support
    - Testing with Jest
    """
  end

  defp app_name(context) do
    # In real implementation, parse package.json for name
    Path.basename(context.path)
  end

  defp detect_port(_context) do
    # In real implementation, check common port configurations
    "3000"
  end

  defp detect_env_vars(context) do
    env_files =
      context.files
      |> Enum.filter(&(&1.name in [".env.example", ".env.sample", ".env.local.example"]))
      |> Enum.map(& &1.name)
      |> Enum.join(", ")

    if env_files != "" do
      """
      Environment configuration files found: #{env_files}

      ```bash
      # Common Node.js environment variables
      NODE_ENV=production
      PORT=3000
      DATABASE_URL=your_database_url
      API_KEY=your_api_key
      ```
      """
    else
      "No environment configuration files found."
    end
  end
end
