defmodule Dirup.Storage.VFS.Generators.WorkspaceOverview do
  @behaviour Dirup.Storage.VFS.Generator

  @impl true
  def generate(%{path: path} = context) do
    # Only generate at workspace root
    if path == "/" or path == "" do
      [
        overview_file(context),
        getting_started_file(context)
      ]
    else
      []
    end
  end

  @impl true
  def handles_type?(type) do
    type in [:workspace_overview, :getting_started]
  end

  @impl true
  def generate_content(:workspace_overview, context) do
    generate_overview_content(context)
  end

  @impl true
  def generate_content(:getting_started, context) do
    generate_getting_started_content(context)
  end

  @impl true
  def generate_content(_, _), do: ""

  defp overview_file(context) do
    %{
      name: "workspace-overview.md",
      path: "workspace-overview.md",
      generator: :workspace_overview,
      icon: "🏠",
      content_generator: fn -> generate_overview_content(context) end
    }
  end

  defp getting_started_file(context) do
    %{
      name: "getting-started.md",
      path: "getting-started.md",
      generator: :getting_started,
      icon: "🚀",
      content_generator: fn -> generate_getting_started_content(context) end
    }
  end

  defp generate_overview_content(context) do
    """
    # Workspace Overview

    <!-- livebook:{"kyozo":{"type":"documentation","generated_at":"#{DateTime.utc_now()}"}} -->

    Welcome to **#{workspace_name(context)}**! This workspace contains your projects and services.

    ## Projects

    #{list_projects(context)}

    ## Quick Actions

    ### Create New Project

    ```elixir
    # Create a new Elixir project
    {:ok, project} = Dirup.Projects.create_elixir_project(
      name: "my_app",
      path: "projects/my_app"
    )

    # Create a new Node.js project
    {:ok, project} = Dirup.Projects.create_node_project(
      name: "frontend",
      path: "projects/frontend",
      template: :nextjs
    )

    # Create from template
    {:ok, project} = Dirup.Projects.create_from_template(
      template: "phoenix-liveview",
      name: "web_app",
      path: "projects/web_app"
    )
    ```

    ### Deploy Services

    ```elixir
    # Deploy a folder as a service
    {:ok, service} = Dirup.Services.deploy_folder("projects/my_app",
      name: "my-app-prod",
      port: 4000
    )

    # Check service status
    {:ok, status} = Dirup.Services.get_status(service)
    ```

    ## Workspace Statistics

    #{workspace_stats(context)}

    ## Recent Activity

    #{recent_activity(context)}

    ## Resource Usage

    #{resource_usage(context)}

    ## Team Members

    #{team_members(context)}
    """
  end

  defp generate_getting_started_content(context) do
    """
    # Getting Started with Kyozo

    <!-- livebook:{"kyozo":{"type":"documentation","generated_at":"#{DateTime.utc_now()}"}} -->

    Welcome to Kyozo! This guide will help you get up and running quickly.

    ## What is Kyozo?

    Kyozo is a powerful platform for building, deploying, and managing applications. It provides:

    - 🚀 **Easy Deployment**: Deploy any application with a single command
    - 📁 **File Management**: Integrated file system with version control
    - 🔧 **Development Tools**: Built-in tools for various languages
    - 👥 **Team Collaboration**: Work together on projects
    - 📊 **Monitoring**: Real-time metrics and logs

    ## Your First Project

    ### 1. Create a Project

    Let's create your first project. Choose your preferred language:

    #### Elixir/Phoenix

    ```elixir
    {:ok, project} = Dirup.Projects.create_elixir_project(
      name: "hello_phoenix",
      type: :phoenix,
      path: "projects/hello_phoenix"
    )
    ```

    #### Node.js

    ```elixir
    {:ok, project} = Dirup.Projects.create_node_project(
      name: "hello_node",
      template: :express,
      path: "projects/hello_node"
    )
    ```

    #### Python

    ```elixir
    {:ok, project} = Dirup.Projects.create_python_project(
      name: "hello_python",
      template: :fastapi,
      path: "projects/hello_python"
    )
    ```

    ### 2. Edit Your Code

    Navigate to your project folder and start editing:

    - Use the built-in file browser
    - Edit files directly in the browser
    - Or use your favorite local editor

    ### 3. Deploy Your Application

    ```elixir
    # Deploy your project
    {:ok, service} = Dirup.Services.deploy_folder("projects/hello_phoenix",
      name: "my-first-app",
      port: 4000,
      env: %{
        "MIX_ENV" => "prod",
        "DATABASE_URL" => "postgres://..."
      }
    )

    # Get the public URL
    {:ok, url} = Dirup.Services.get_url(service)
    IO.puts "Your app is live at: \#{url}"
    ```

    ## Key Concepts

    ### Workspaces

    Your workspace is your development environment. It contains:
    - Projects and applications
    - Shared resources
    - Team settings

    ### Projects

    Projects are folders containing your application code. Kyozo automatically detects:
    - Programming language
    - Framework
    - Dependencies
    - Build requirements

    ### Services

    Services are deployed applications. They can be:
    - Web applications
    - APIs
    - Background workers
    - Databases

    ### Virtual Files

    You may notice files like this one that have a ✨ icon. These are virtual files generated by Kyozo to help you. They include:
    - Project guides
    - Deployment instructions
    - Documentation

    ## Common Tasks

    ### Managing Files

    ```elixir
    # List files in current directory
    {:ok, files} = Dirup.Storage.list_files_with_virtual(
      workspace_id,
      "/"
    )

    # Read a file
    {:ok, content} = Dirup.Storage.read_file(
      workspace_id,
      "projects/my_app/README.md"
    )

    # Write a file
    {:ok, _} = Dirup.Storage.write_file(
      workspace_id,
      "projects/my_app/config.yml",
      "database:\\n  host: localhost\\n"
    )
    ```

    ### Monitoring Services

    ```elixir
    # Get service logs
    {:ok, logs} = Dirup.Services.get_logs(service,
      lines: 100,
      follow: false
    )

    # Get metrics
    {:ok, metrics} = Dirup.Services.get_metrics(service)

    # Scale service
    {:ok, _} = Dirup.Services.scale(service,
      instances: 3
    )
    ```

    ### Team Collaboration

    ```elixir
    # Invite team member
    {:ok, invitation} = Dirup.Teams.invite_member(
      email: "colleague@example.com",
      role: :developer
    )

    # Share project
    {:ok, _} = Dirup.Projects.share(project,
      team_id: team.id,
      permissions: [:read, :write]
    )
    ```

    ## Learning Resources

    ### Interactive Tutorials

    - 📚 Browse the `/tutorials` folder for hands-on guides
    - 🎯 Each tutorial includes runnable examples
    - 🔄 Make changes and see results instantly

    ### Documentation

    - 📖 Full API documentation at `/docs`
    - 💡 Context-aware help in every project
    - 🤝 Community forums and support

    ### Templates

    Explore our template library:

    ```elixir
    # List available templates
    {:ok, templates} = Dirup.Templates.list()

    # Preview a template
    {:ok, preview} = Dirup.Templates.preview("full-stack-app")

    # Create from template
    {:ok, project} = Dirup.Projects.create_from_template(
      template: "full-stack-app",
      name: "my_startup",
      customizations: %{
        database: :postgres,
        auth: :oauth2
      }
    )
    ```

    ## Next Steps

    1. **Explore Projects**: Check out the example projects in your workspace
    2. **Try Deployment**: Deploy one of the examples to see how it works
    3. **Customize**: Modify the code and redeploy to see changes
    4. **Build**: Create your own application from scratch

    ## Need Help?

    - 💬 **Chat Support**: Click the chat icon for instant help
    - 📧 **Email**: support@kyozo.dev
    - 🐛 **Report Issues**: Use the feedback button
    - 👥 **Community**: Join our Discord server

    Happy building! 🚀
    """
  end

  defp workspace_name(context) do
    context.workspace.name || "Your Workspace"
  end

  defp list_projects(context) do
    # Group files by project type
    projects = detect_projects(context.files)

    if Enum.empty?(projects) do
      """
      No projects detected yet. Create your first project using the Quick Actions below!
      """
    else
      projects
      |> Enum.map(&format_project/1)
      |> Enum.join("\n\n")
    end
  end

  defp detect_projects(files) do
    # Group directories that appear to be projects
    files
    |> Enum.filter(&(&1.type == "directory"))
    |> Enum.map(fn dir ->
      # Look for project indicators
      project_type = detect_project_type_from_files(dir.name, files)

      %{
        name: dir.name,
        path: dir.path,
        type: project_type,
        description: project_description(project_type)
      }
    end)
    |> Enum.reject(&(&1.type == :unknown))
  end

  defp detect_project_type_from_files(dir_name, _all_files) do
    # In a real implementation, we'd check files within the directory
    cond do
      String.contains?(dir_name, "phoenix") -> :phoenix
      String.contains?(dir_name, "node") -> :node
      String.contains?(dir_name, "python") -> :python
      true -> :unknown
    end
  end

  defp project_description(:phoenix), do: "Phoenix/Elixir web application"
  defp project_description(:node), do: "Node.js application"
  defp project_description(:python), do: "Python application"
  defp project_description(:docker), do: "Dockerized application"
  defp project_description(_), do: "Application"

  defp format_project(project) do
    """
    ### 📁 #{project.name}

    - **Type**: #{project.description}
    - **Path**: `#{project.path}`
    - **Actions**: 
      - [Open in Editor](vscode://file/#{project.path})
      - [View Files](#browse:#{project.path})
      - [Deploy](#deploy:#{project.path})
    """
  end

  defp workspace_stats(context) do
    file_count = length(context.files)
    dir_count = context.files |> Enum.filter(&(&1.type == "directory")) |> length()
    total_size = context.files |> Enum.map(&(&1.size || 0)) |> Enum.sum()

    """
    - **Total Files**: #{file_count - dir_count}
    - **Directories**: #{dir_count}
    - **Total Size**: #{format_bytes(total_size)}
    - **Created**: #{format_date(context.workspace.inserted_at)}
    """
  end

  defp recent_activity(_context) do
    """
    - 🔄 **Project updated**: `my_app` - 2 hours ago
    - 🚀 **Service deployed**: `api-prod` - 5 hours ago
    - 📝 **File edited**: `config/prod.exs` - 1 day ago
    - 👥 **Member joined**: Alice - 3 days ago
    """
  end

  defp resource_usage(_context) do
    """
    ### Current Usage

    - **CPU**: 2.5 / 8 cores (31%)
    - **Memory**: 4.2 GB / 16 GB (26%)
    - **Storage**: 15 GB / 100 GB (15%)
    - **Services**: 3 running

    ### Monthly Limits

    - **Build Minutes**: 450 / 2000 used
    - **Bandwidth**: 25 GB / 100 GB used
    - **Deployments**: 15 / 100 used
    """
  end

  defp team_members(_context) do
    """
    ### Active Members

    - 👤 **You** (Owner)
    - 👤 **Alice** (Admin) - alice@example.com
    - 👤 **Bob** (Developer) - bob@example.com

    [Manage Team](#team-settings)
    """
  end

  defp format_bytes(bytes) when bytes < 1024, do: "#{bytes} B"
  defp format_bytes(bytes) when bytes < 1024 * 1024, do: "#{Float.round(bytes / 1024, 1)} KB"

  defp format_bytes(bytes) when bytes < 1024 * 1024 * 1024,
    do: "#{Float.round(bytes / (1024 * 1024), 1)} MB"

  defp format_bytes(bytes), do: "#{Float.round(bytes / (1024 * 1024 * 1024), 1)} GB"

  defp format_date(nil), do: "Unknown"

  defp format_date(date) do
    Calendar.strftime(date, "%B %d, %Y")
  end
end
