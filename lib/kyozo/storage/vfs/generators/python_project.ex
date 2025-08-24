defmodule Kyozo.Storage.VFS.Generators.PythonProject do
  @behaviour Kyozo.Storage.VFS.Generator

  @impl true
  def generate(%{files: files, path: path} = context) do
    if has_python_project?(files) do
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
      generator: :python_guide,
      icon: "🐍",
      content_generator: fn -> generate_guide_content(context) end
    }
  end

  defp deploy_file(path, context) do
    if deployable?(context) do
      %{
        name: "deploy.md",
        path: Path.join(path, "deploy.md"),
        generator: :python_deploy,
        icon: "🚀",
        content_generator: fn -> generate_deploy_content(context) end
      }
    end
  end

  defp generate_guide_content(context) do
    """
    # Python Project Guide

    <!-- livebook:{"kyozo":{"type":"documentation","generated_at":"#{DateTime.utc_now()}"}} -->

    Welcome to your Python project! This guide will help you get started.

    ## Quick Start

    ```bash
    # Create virtual environment
    python -m venv venv

    # Activate virtual environment
    source venv/bin/activate  # On Windows: venv\\Scripts\\activate

    # Install dependencies
    #{install_command(context)}

    # Run the application
    #{run_command(context)}
    ```

    ## Project Type

    #{detect_project_type(context)}

    ## Project Structure

    #{analyze_project_structure(context)}

    ## Dependencies

    #{analyze_dependencies(context)}

    ## Development

    #{development_tasks(context)}
    """
  end

  defp generate_deploy_content(context) do
    """
    # Python Deployment Guide

    <!-- livebook:{"kyozo":{"type":"deployment","generated_at":"#{DateTime.utc_now()}"}} -->

    ## Deployment Options

    ### 1. Docker Deployment

    ```dockerfile
    FROM python:3.11-slim

    WORKDIR /app

    # Copy dependency files
    #{copy_dependency_files(context)}

    # Install dependencies
    RUN pip install --no-cache-dir #{install_args(context)}

    # Copy application
    COPY . .

    # Expose port
    EXPOSE #{detect_port(context)}

    # Run application
    CMD ["#{start_command(context)}"]
    ```

    ### 2. Kyozo Deployment

    ```elixir
    # Deploy this Python app
    {:ok, service} = Kyozo.Services.deploy_folder(".",
      name: "#{app_name(context)}",
      type: :python_app,
      port: #{detect_port(context)}
    )
    ```

    ### 3. Production Setup

    ```bash
    # Install production dependencies only
    pip install #{install_args(context)} --no-dev

    # Collect static files (Django/Flask)
    #{collect_static_command(context)}

    # Run migrations (if applicable)
    #{migration_command(context)}

    # Start with production server
    #{production_server_command(context)}
    ```

    ## Environment Variables

    #{detect_env_vars(context)}

    ## Health Checks

    #{generate_health_check_info(context)}
    """
  end

  defp has_python_project?(files) do
    Enum.any?(files, &(&1.name in ["requirements.txt", "setup.py", "pyproject.toml", "Pipfile"]))
  end

  defp deployable?(context) do
    has_python_project?(context.files) or
      Enum.any?(context.files, &(&1.name in ["Dockerfile", "Procfile", ".python-version"]))
  end

  defp install_command(context) do
    cond do
      has_file?(context, "requirements.txt") -> "pip install -r requirements.txt"
      has_file?(context, "setup.py") -> "pip install -e ."
      has_file?(context, "pyproject.toml") -> "pip install ."
      has_file?(context, "Pipfile") -> "pipenv install"
      true -> "# No dependency file found"
    end
  end

  defp run_command(context) do
    cond do
      has_django?(context) -> "python manage.py runserver"
      has_flask?(context) -> "flask run"
      has_fastapi?(context) -> "uvicorn main:app --reload"
      has_file?(context, "main.py") -> "python main.py"
      has_file?(context, "app.py") -> "python app.py"
      true -> "python your_script.py"
    end
  end

  defp detect_project_type(context) do
    cond do
      has_django?(context) ->
        "This is a **Django** web application."

      has_flask?(context) ->
        "This is a **Flask** web application."

      has_fastapi?(context) ->
        "This is a **FastAPI** application."

      has_file?(context, "setup.py") ->
        "This is a **Python package** with setup.py."

      has_file?(context, "pyproject.toml") ->
        "This is a **modern Python project** using pyproject.toml."

      has_jupyter?(context) ->
        "This project contains **Jupyter notebooks**."

      true ->
        "This is a Python project."
    end
  end

  defp analyze_project_structure(context) do
    dirs =
      context.files
      |> Enum.filter(&(&1.type == "directory"))
      |> Enum.map(&"- `#{&1.name}/` - #{describe_python_directory(&1.name)}")
      |> Enum.join("\n")

    files =
      context.files
      |> Enum.filter(&(&1.type == "file" and important_python_file?(&1.name)))
      |> Enum.map(&"- `#{&1.name}` - #{describe_python_file(&1.name)}")
      |> Enum.join("\n")

    """
    #{if dirs != "", do: "### Directories\n#{dirs}\n", else: ""}
    #{if files != "", do: "### Key Files\n#{files}", else: ""}
    """
  end

  defp describe_python_directory("tests"), do: "Test files"
  defp describe_python_directory("test"), do: "Test files"
  defp describe_python_directory("src"), do: "Source code"
  defp describe_python_directory("lib"), do: "Library code"
  defp describe_python_directory("docs"), do: "Documentation"
  defp describe_python_directory("scripts"), do: "Utility scripts"
  defp describe_python_directory("static"), do: "Static files (CSS, JS, images)"
  defp describe_python_directory("templates"), do: "HTML templates"
  defp describe_python_directory("migrations"), do: "Database migrations"
  defp describe_python_directory(_), do: "Project directory"

  defp important_python_file?(name) do
    name in [
      "setup.py",
      "pyproject.toml",
      "requirements.txt",
      "Pipfile",
      "manage.py",
      "app.py",
      "main.py",
      "wsgi.py",
      "asgi.py",
      "conftest.py",
      "tox.ini",
      "pytest.ini",
      ".flake8",
      ".pylintrc"
    ]
  end

  defp describe_python_file("setup.py"), do: "Package setup configuration"
  defp describe_python_file("pyproject.toml"), do: "Modern Python project configuration"
  defp describe_python_file("requirements.txt"), do: "Dependency list"
  defp describe_python_file("Pipfile"), do: "Pipenv dependency file"
  defp describe_python_file("manage.py"), do: "Django management script"
  defp describe_python_file("app.py"), do: "Application entry point"
  defp describe_python_file("main.py"), do: "Main application file"
  defp describe_python_file("wsgi.py"), do: "WSGI configuration"
  defp describe_python_file("asgi.py"), do: "ASGI configuration"
  defp describe_python_file(_), do: "Configuration file"

  defp analyze_dependencies(context) do
    cond do
      has_file?(context, "requirements.txt") ->
        """
        Dependencies are managed in `requirements.txt`.

        ```bash
        # View dependencies
        cat requirements.txt

        # Freeze current dependencies
        pip freeze > requirements.txt
        ```
        """

      has_file?(context, "Pipfile") ->
        """
        Dependencies are managed with Pipenv.

        ```bash
        # Install development dependencies
        pipenv install --dev

        # Add new dependency
        pipenv install package_name
        ```
        """

      has_file?(context, "pyproject.toml") ->
        """
        Dependencies are managed in `pyproject.toml`.

        ```bash
        # Install with pip
        pip install .

        # Install with poetry (if using)
        poetry install
        ```
        """

      true ->
        "No dependency management file found."
    end
  end

  defp development_tasks(context) do
    """
    ### Testing

    ```bash
    #{test_command(context)}
    ```

    ### Code Quality

    ```bash
    # Format code
    #{format_command(context)}

    # Lint code
    #{lint_command(context)}

    # Type checking
    #{type_check_command(context)}
    ```

    ### Development Server

    ```bash
    #{dev_server_command(context)}
    ```
    """
  end

  defp test_command(context) do
    cond do
      has_file?(context, "pytest.ini") or has_file?(context, "conftest.py") ->
        "pytest"

      has_file?(context, "manage.py") ->
        "python manage.py test"

      has_file?(context, "tox.ini") ->
        "tox"

      true ->
        "python -m unittest discover"
    end
  end

  defp format_command(context) do
    cond do
      has_in_requirements?(context, "black") -> "black ."
      has_in_requirements?(context, "autopep8") -> "autopep8 --in-place --recursive ."
      true -> "# Install black: pip install black"
    end
  end

  defp lint_command(context) do
    cond do
      has_file?(context, ".flake8") -> "flake8"
      has_file?(context, ".pylintrc") -> "pylint **/*.py"
      has_in_requirements?(context, "ruff") -> "ruff check ."
      true -> "# Install flake8: pip install flake8"
    end
  end

  defp type_check_command(context) do
    if has_in_requirements?(context, "mypy") do
      "mypy ."
    else
      "# Install mypy: pip install mypy"
    end
  end

  defp dev_server_command(context) do
    cond do
      has_django?(context) -> "python manage.py runserver"
      has_flask?(context) -> "flask run --debug"
      has_fastapi?(context) -> "uvicorn main:app --reload"
      true -> "python -m http.server 8000  # Simple HTTP server"
    end
  end

  defp copy_dependency_files(context) do
    files = []

    files =
      if has_file?(context, "requirements.txt"),
        do: ["COPY requirements.txt ." | files],
        else: files

    files = if has_file?(context, "setup.py"), do: ["COPY setup.py ." | files], else: files

    files =
      if has_file?(context, "pyproject.toml"), do: ["COPY pyproject.toml ." | files], else: files

    Enum.join(files, "\n")
  end

  defp install_args(context) do
    cond do
      has_file?(context, "requirements.txt") -> "-r requirements.txt"
      has_file?(context, "setup.py") -> "."
      has_file?(context, "pyproject.toml") -> "."
      true -> ""
    end
  end

  defp start_command(context) do
    cond do
      has_django?(context) -> "gunicorn project.wsgi:application"
      has_flask?(context) -> "gunicorn app:app"
      has_fastapi?(context) -> "uvicorn main:app --host 0.0.0.0"
      true -> "python app.py"
    end
  end

  defp detect_port(context) do
    cond do
      has_django?(context) or has_flask?(context) -> "8000"
      has_fastapi?(context) -> "8000"
      true -> "8080"
    end
  end

  defp app_name(context) do
    # Try to extract from setup.py or pyproject.toml, fallback to directory
    Path.basename(context.path)
  end

  defp collect_static_command(context) do
    if has_django?(context) do
      "python manage.py collectstatic --noinput"
    else
      "# No static collection needed"
    end
  end

  defp migration_command(context) do
    if has_django?(context) do
      "python manage.py migrate"
    else
      "# No migrations needed"
    end
  end

  defp production_server_command(context) do
    cond do
      has_django?(context) ->
        "gunicorn project.wsgi:application --bind 0.0.0.0:8000"

      has_flask?(context) ->
        "gunicorn app:app --bind 0.0.0.0:8000"

      has_fastapi?(context) ->
        "uvicorn main:app --host 0.0.0.0 --port 8000"

      true ->
        "python app.py"
    end
  end

  defp detect_env_vars(context) do
    env_files =
      context.files
      |> Enum.filter(&(&1.name in [".env.example", ".env.sample", ".env"]))
      |> Enum.map(& &1.name)
      |> Enum.join(", ")

    if env_files != "" do
      """
      Environment configuration files found: #{env_files}

      ```bash
      # Common Python environment variables
      PYTHONPATH=/app
      FLASK_ENV=production
      DJANGO_SETTINGS_MODULE=project.settings
      DATABASE_URL=postgresql://user:pass@localhost/db
      SECRET_KEY=your-secret-key
      DEBUG=False
      ```
      """
    else
      """
      No environment configuration files found.

      Common environment variables to consider:
      - `DATABASE_URL` - Database connection string
      - `SECRET_KEY` - Application secret key
      - `DEBUG` - Debug mode (set to False in production)
      - `ALLOWED_HOSTS` - Django allowed hosts
      """
    end
  end

  defp generate_health_check_info(context) do
    cond do
      has_django?(context) ->
        """
        ```python
        # Django health check view
        from django.http import JsonResponse

        def health_check(request):
            return JsonResponse({
                'status': 'healthy',
                'timestamp': datetime.now().isoformat()
            })

        # Add to urls.py
        path('health/', health_check, name='health_check'),
        ```
        """

      has_flask?(context) ->
        """
        ```python
        # Flask health check endpoint
        @app.route('/health')
        def health_check():
            return {
                'status': 'healthy',
                'timestamp': datetime.utcnow().isoformat()
            }
        ```
        """

      has_fastapi?(context) ->
        """
        ```python
        # FastAPI health check endpoint
        @app.get("/health")
        async def health_check():
            return {
                "status": "healthy",
                "timestamp": datetime.utcnow().isoformat()
            }
        ```
        """

      true ->
        """
        ```python
        # Simple health check endpoint
        def health_check():
            return {
                'status': 'healthy',
                'timestamp': datetime.utcnow().isoformat()
            }
        ```
        """
    end
  end

  # Helper functions
  defp has_file?(context, filename) do
    Enum.any?(context.files, &(&1.name == filename))
  end

  defp has_django?(context) do
    has_file?(context, "manage.py") or
      has_in_requirements?(context, "django")
  end

  defp has_flask?(context) do
    has_in_requirements?(context, "flask") or
      (has_file?(context, "app.py") and not has_django?(context))
  end

  defp has_fastapi?(context) do
    has_in_requirements?(context, "fastapi")
  end

  defp has_jupyter?(context) do
    Enum.any?(context.files, &String.ends_with?(&1.name, ".ipynb"))
  end

  defp has_in_requirements?(_context, _package) do
    # In real implementation, would parse requirements.txt
    false
  end
end
