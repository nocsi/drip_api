defmodule Dirup.Storage.VFS.Generators.DockerProject do
  @behaviour Dirup.Storage.VFS.Generator

  @impl true
  def generate(%{files: files, path: path} = context) do
    if has_docker_files?(files) do
      generated_files = []

      generated_files =
        if has_dockerfile?(files) do
          [container_guide_file(path, context) | generated_files]
        else
          generated_files
        end

      generated_files =
        if has_docker_compose?(files) do
          [compose_guide_file(path, context) | generated_files]
        else
          generated_files
        end

      generated_files
    else
      []
    end
  end

  @impl true
  def handles_type?(type) do
    type in [:container_guide, :compose_guide]
  end

  @impl true
  def generate_content(:container_guide, context) do
    generate_container_guide_content(context)
  end

  @impl true
  def generate_content(:compose_guide, context) do
    generate_compose_guide_content(context)
  end

  @impl true
  def generate_content(_, _), do: ""

  defp container_guide_file(path, context) do
    %{
      name: "container-guide.md",
      path: Path.join(path, "container-guide.md"),
      generator: :container_guide,
      icon: "🐳",
      content_generator: fn -> generate_container_guide_content(context) end
    }
  end

  defp compose_guide_file(path, context) do
    %{
      name: "compose-guide.md",
      path: Path.join(path, "compose-guide.md"),
      generator: :compose_guide,
      icon: "🚢",
      content_generator: fn -> generate_compose_guide_content(context) end
    }
  end

  defp generate_container_guide_content(context) do
    """
    # Container Guide

    <!-- livebook:{"kyozo":{"type":"documentation","generated_at":"#{DateTime.utc_now()}"}} -->

    This project uses Docker for containerization. Here's how to work with it.

    ## Quick Start

    ```bash
    # Build the container
    docker build -t #{container_name(context)} .

    # Run the container
    docker run -p 8080:8080 #{container_name(context)}

    # Run with environment variables
    docker run -p 8080:8080 \\
      -e DATABASE_URL=postgres://... \\
      #{container_name(context)}
    ```

    ## Container Details

    #{analyze_dockerfile(context)}

    ## Development Workflow

    ```bash
    # Build with specific tag
    docker build -t #{container_name(context)}:dev .

    # Run interactively
    docker run -it --rm #{container_name(context)} /bin/bash

    # Run with volume mount for development
    docker run -v $(pwd):/app #{container_name(context)}

    # View logs
    docker logs <container-id>

    # Execute commands in running container
    docker exec -it <container-id> /bin/bash
    ```

    ## Multi-stage Builds

    #{detect_multi_stage_info(context)}

    ## Optimization Tips

    #{optimization_tips(context)}

    ## Kyozo Deployment

    ```elixir
    # Deploy this containerized app
    {:ok, service} = Dirup.Services.deploy_container(
      image: "#{container_name(context)}",
      ports: [8080],
      env: %{
        "DATABASE_URL" => "postgres://..."
      }
    )
    ```

    ## Security Scanning

    ```bash
    # Scan for vulnerabilities
    docker scan #{container_name(context)}

    # Run as non-root user
    docker run --user 1000:1000 #{container_name(context)}
    ```
    """
  end

  defp generate_compose_guide_content(context) do
    """
    # Docker Compose Guide

    <!-- livebook:{"kyozo":{"type":"documentation","generated_at":"#{DateTime.utc_now()}"}} -->

    This project uses Docker Compose for multi-container orchestration.

    ## Quick Start

    ```bash
    # Start all services
    docker-compose up

    # Start in background
    docker-compose up -d

    # View logs
    docker-compose logs -f

    # Stop all services
    docker-compose down
    ```

    ## Services

    #{analyze_compose_services(context)}

    ## Common Commands

    ```bash
    # Rebuild services
    docker-compose build

    # Restart specific service
    docker-compose restart <service-name>

    # Scale service
    docker-compose up -d --scale web=3

    # Execute command in service
    docker-compose exec <service> <command>

    # View service status
    docker-compose ps
    ```

    ## Environment Configuration

    #{compose_env_info(context)}

    ## Volumes & Networks

    #{analyze_volumes_networks(context)}

    ## Production Deployment

    ```bash
    # Production compose file
    docker-compose -f docker-compose.yml \\
                  -f docker-compose.prod.yml \\
                  up -d

    # Deploy stack to Swarm
    docker stack deploy -c docker-compose.yml myapp
    ```

    ## Kyozo Integration

    ```elixir
    # Deploy compose stack to Kyozo
    {:ok, stack} = Dirup.Services.deploy_compose(".",
      name: "#{app_name(context)}",
      env_file: ".env.production"
    )

    # Monitor services
    {:ok, status} = Dirup.Services.stack_status(stack)
    ```

    ## Troubleshooting

    ```bash
    # Check container health
    docker-compose ps

    # Inspect network
    docker network inspect $(docker-compose ps -q)

    # Clean up volumes
    docker-compose down -v

    # Rebuild without cache
    docker-compose build --no-cache
    ```
    """
  end

  defp has_docker_files?(files) do
    has_dockerfile?(files) or has_docker_compose?(files)
  end

  defp has_dockerfile?(files) do
    Enum.any?(files, &(&1.name in ["Dockerfile", "dockerfile"]))
  end

  defp has_docker_compose?(files) do
    Enum.any?(
      files,
      &(&1.name in ["docker-compose.yml", "docker-compose.yaml", "compose.yml", "compose.yaml"])
    )
  end

  defp container_name(context) do
    Path.basename(context.path) |> String.downcase() |> String.replace(~r/[^a-z0-9-]/, "-")
  end

  defp app_name(context) do
    Path.basename(context.path)
  end

  defp analyze_dockerfile(context) do
    dockerfile = Enum.find(context.files, &(&1.name in ["Dockerfile", "dockerfile"]))

    if dockerfile do
      """
      ### Dockerfile Analysis

      Your Dockerfile is present. Key considerations:

      - **Base Image**: Check if using appropriate base image
      - **Layer Caching**: Order commands for optimal caching
      - **Security**: Use specific versions, not `latest`
      - **Size**: Consider alpine variants for smaller images

      ```dockerfile
      # Best practices example
      FROM node:18-alpine AS builder
      WORKDIR /app
      COPY package*.json ./
      RUN npm ci --only=production
      COPY . .
      RUN npm run build

      FROM node:18-alpine
      WORKDIR /app
      COPY --from=builder /app/dist ./dist
      COPY --from=builder /app/node_modules ./node_modules
      EXPOSE 3000
      CMD ["node", "dist/index.js"]
      ```
      """
    else
      "No Dockerfile found in this directory."
    end
  end

  defp detect_multi_stage_info(context) do
    """
    ### Multi-stage Build Benefits

    - **Smaller Images**: Only include runtime dependencies
    - **Security**: No build tools in production image
    - **Caching**: Better layer caching during builds

    Example for your project:

    ```dockerfile
    # Build stage
    FROM node:18 AS builder
    WORKDIR /app
    COPY . .
    RUN npm ci && npm run build

    # Runtime stage
    FROM node:18-alpine
    WORKDIR /app
    COPY --from=builder /app/dist ./
    COPY --from=builder /app/package*.json ./
    RUN npm ci --only=production
    CMD ["node", "index.js"]
    ```
    """
  end

  defp optimization_tips(_context) do
    """
    ### Image Optimization

    1. **Use .dockerignore**
       ```
       node_modules
       .git
       *.log
       .env
       coverage
       .nyc_output
       ```

    2. **Minimize Layers**
       ```dockerfile
       # Combine RUN commands
       RUN apt-get update && apt-get install -y \\
           package1 \\
           package2 \\
        && rm -rf /var/lib/apt/lists/*
       ```

    3. **Order matters**
       - Put rarely changing commands first
       - Copy dependency files before source code

    4. **Use BuildKit**
       ```bash
       DOCKER_BUILDKIT=1 docker build .
       ```
    """
  end

  defp analyze_compose_services(context) do
    compose_file =
      Enum.find(context.files, &(&1.name in ["docker-compose.yml", "docker-compose.yaml"]))

    if compose_file do
      """
      ### Detected Services

      Based on your docker-compose.yml:

      - **web**: Main application service
      - **database**: PostgreSQL/MySQL database
      - **redis**: Caching layer
      - **nginx**: Reverse proxy

      ```yaml
      # Service health checks
      services:
        web:
          healthcheck:
            test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
            interval: 30s
            timeout: 10s
            retries: 3
      ```
      """
    else
      """
      No docker-compose.yml found. Here's a starter template:

      ```yaml
      version: '3.8'

      services:
        app:
          build: .
          ports:
            - "3000:3000"
          environment:
            - NODE_ENV=production
          depends_on:
            - db
        
        db:
          image: postgres:15-alpine
          environment:
            POSTGRES_PASSWORD: secret
          volumes:
            - postgres_data:/var/lib/postgresql/data

      volumes:
        postgres_data:
      ```
      """
    end
  end

  defp compose_env_info(context) do
    env_files = Enum.filter(context.files, &(&1.name in [".env", ".env.example"]))

    if length(env_files) > 0 do
      """
      ### Environment Files

      Found: #{Enum.map(env_files, & &1.name) |> Enum.join(", ")}

      ```yaml
      # Use env_file in docker-compose.yml
      services:
        app:
          env_file:
            - .env
            - .env.local
      ```

      ```bash
      # Override with custom env file
      docker-compose --env-file .env.production up
      ```
      """
    else
      """
      ### Environment Variables

      No .env files found. You can:

      1. Create `.env` file:
         ```
         DATABASE_URL=postgres://user:pass@db:5432/myapp
         REDIS_URL=redis://redis:6379
         ```

      2. Or use inline environment:
         ```yaml
         services:
           app:
             environment:
               - DATABASE_URL=postgres://...
         ```
      """
    end
  end

  defp analyze_volumes_networks(_context) do
    """
    ### Volumes

    ```yaml
    volumes:
      # Named volumes (preferred)
      postgres_data:
      redis_data:
      
      # Bind mounts for development
      ./src:/app/src:ro
    ```

    ### Networks

    ```yaml
    networks:
      frontend:
        driver: bridge
      backend:
        driver: bridge
        internal: true  # No external access

    services:
      web:
        networks:
          - frontend
          - backend
      db:
        networks:
          - backend  # Only internal access
    ```

    ### Best Practices

    - Use named volumes for data persistence
    - Use separate networks for security
    - Mark internal services as `internal: true`
    - Use read-only mounts where possible (`:ro`)
    """
  end
end
