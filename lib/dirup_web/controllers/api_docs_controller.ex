defmodule DirupWeb.ApiDocsController do
  @moduledoc """
  Controller for serving OpenAPI specification with JSON-LD context support.

  Provides endpoints for:
  - OpenAPI specification with JSON-LD headers
  - Standalone JSON-LD context
  - API documentation viewer
  """

  use DirupWeb, :controller

  @doc """
  Serves the OpenAPI specification with proper JSON-LD headers.
  """
  def openapi(conn, _params) do
    # Generate OpenAPI spec dynamically from Ash resources
    spec = generate_openapi_spec()

    conn
    |> put_resp_content_type("application/ld+json")
    |> put_resp_header(
      "link",
      ~s(<https://schema.kyozo.store/container#>; rel="http://www.w3.org/ns/json-ld#context"; type="application/ld+json")
    )
    |> put_resp_header("access-control-allow-origin", "*")
    |> put_resp_header("cache-control", "public, max-age=300")
    |> json(spec)
  end

  @doc """
  Serves the standalone JSON-LD context.
  """
  def json_ld_context(conn, _params) do
    context = %{
      "@context" => %{
        "@base" => "https://kyozo.store/api/v2/",
        "@vocab" => "https://schema.kyozo.store/vocabulary#",
        "kyozo" => "https://schema.kyozo.store/container#",
        "schema" => "https://schema.org/",
        "rdf" => "http://www.w3.org/1999/02/22-rdf-syntax-ns#",
        "rdfs" => "http://www.w3.org/2000/01/rdf-schema#",
        "owl" => "http://www.w3.org/2002/07/owl#",
        "xsd" => "http://www.w3.org/2001/XMLSchema#",

        # Core Resources
        "Workspace" => %{
          "@id" => "kyozo:Workspace",
          "@type" => "@id"
        },
        "Team" => %{
          "@id" => "kyozo:Team",
          "@type" => "@id"
        },
        "User" => %{
          "@id" => "kyozo:User",
          "@type" => "@id"
        },
        "File" => %{
          "@id" => "kyozo:File",
          "@type" => "@id"
        },
        "Notebook" => %{
          "@id" => "kyozo:Notebook",
          "@type" => "@id"
        },

        # Container Services
        "ServiceInstance" => %{
          "@id" => "kyozo:ServiceInstance",
          "@type" => "@id"
        },
        "TopologyDetection" => %{
          "@id" => "kyozo:TopologyDetection",
          "@type" => "@id"
        },
        "DeploymentEvent" => %{
          "@id" => "kyozo:DeploymentEvent",
          "@type" => "@id"
        },
        "ServiceDependency" => %{
          "@id" => "kyozo:ServiceDependency",
          "@type" => "@id"
        },
        "ContainerImage" => %{
          "@id" => "kyozo:ContainerImage",
          "@type" => "@id"
        },
        "ServiceMetrics" => %{
          "@id" => "kyozo:ServiceMetrics",
          "@type" => "@id"
        },

        # Service Types
        "WebApplicationService" => "kyozo:WebApplicationService",
        "DatabaseService" => "kyozo:DatabaseService",
        "CacheService" => "kyozo:CacheService",
        "MessageQueueService" => "kyozo:MessageQueueService",
        "LoadBalancerService" => "kyozo:LoadBalancerService",
        "StaticFileService" => "kyozo:StaticFileService",
        "WorkerService" => "kyozo:WorkerService",
        "CronService" => "kyozo:CronService",
        "ProxyService" => "kyozo:ProxyService",
        "MonitoringService" => "kyozo:MonitoringService",

        # Properties
        "belongsTo" => "kyozo:belongsTo",
        "hasFiles" => "kyozo:hasFiles",
        "hasNotebooks" => "kyozo:hasNotebooks",
        "createdBy" => "kyozo:createdBy",
        "storageBackend" => "kyozo:storageBackend",
        "status" => "kyozo:status",
        "serviceType" => "kyozo:serviceType",
        "deploymentStatus" => "kyozo:deploymentStatus",
        "containerImage" => "kyozo:containerImage",
        "portMappings" => "kyozo:portMappings",
        "environmentVariables" => "kyozo:environmentVariables",
        "resourceLimits" => "kyozo:resourceLimits",
        "healthCheck" => "kyozo:healthCheck",
        "dependsOn" => "kyozo:dependsOn",
        "exposedPorts" => "kyozo:exposedPorts",
        "volumes" => "kyozo:volumes",
        "networks" => "kyozo:networks",
        "scalingConfig" => "kyozo:scalingConfig",
        "detectionConfidence" => %{
          "@id" => "kyozo:detectionConfidence",
          "@type" => "xsd:decimal"
        },
        "cpuUsage" => %{
          "@id" => "kyozo:cpuUsage",
          "@type" => "xsd:decimal"
        },
        "memoryUsage" => %{
          "@id" => "kyozo:memoryUsage",
          "@type" => "xsd:decimal"
        },
        "networkIO" => %{
          "@id" => "kyozo:networkIO",
          "@type" => "xsd:decimal"
        },
        "diskIO" => %{
          "@id" => "kyozo:diskIO",
          "@type" => "xsd:decimal"
        },

        # Timestamps
        "createdAt" => %{
          "@id" => "schema:dateCreated",
          "@type" => "xsd:dateTime"
        },
        "updatedAt" => %{
          "@id" => "schema:dateModified",
          "@type" => "xsd:dateTime"
        },
        "deployedAt" => %{
          "@id" => "kyozo:deployedAt",
          "@type" => "xsd:dateTime"
        },
        "detectionTimestamp" => %{
          "@id" => "kyozo:detectionTimestamp",
          "@type" => "xsd:dateTime"
        },
        "lastHealthCheckAt" => %{
          "@id" => "kyozo:lastHealthCheckAt",
          "@type" => "xsd:dateTime"
        },
        "occurredAt" => %{
          "@id" => "kyozo:occurredAt",
          "@type" => "xsd:dateTime"
        }
      }
    }

    conn
    |> put_resp_content_type("application/ld+json")
    |> put_resp_header("access-control-allow-origin", "*")
    |> put_resp_header("cache-control", "public, max-age=3600")
    |> json(context)
  end

  @doc """
  Serves an interactive API documentation viewer (Swagger UI or ReDoc).
  """
  def docs_viewer(conn, _params) do
    html_content = """
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Kyozo Store API Documentation</title>
      <link rel="stylesheet" type="text/css" href="https://unpkg.com/swagger-ui-dist@5.9.0/swagger-ui.css" />
      <style>
        html {
          box-sizing: border-box;
          overflow: -moz-scrollbars-vertical;
          overflow-y: scroll;
        }
        *, *:before, *:after {
          box-sizing: inherit;
        }
        body {
          margin: 0;
          background: #fafafa;
        }
      </style>
    </head>
    <body>
      <div id="swagger-ui"></div>
      
      <script src="https://unpkg.com/swagger-ui-dist@5.9.0/swagger-ui-bundle.js"></script>
      <script src="https://unpkg.com/swagger-ui-dist@5.9.0/swagger-ui-standalone-preset.js"></script>
      
      <script>
        window.onload = function() {
          const ui = SwaggerUIBundle({
            url: '/api/v2/openapi.json',
            dom_id: '#swagger-ui',
            deepLinking: true,
            presets: [
              SwaggerUIBundle.presets.apis,
              SwaggerUIStandalonePreset
            ],
            plugins: [
              SwaggerUIBundle.plugins.DownloadUrl
            ],
            layout: "StandaloneLayout",
            validatorUrl: null,
            tryItOutEnabled: true
          })
        }
      </script>
    </body>
    </html>
    """

    conn
    |> put_resp_content_type("text/html")
    |> put_resp_header("cache-control", "public, max-age=3600")
    |> send_resp(200, html_content)
  end

  # Private helper functions

  defp generate_openapi_spec do
    base_spec = %{
      "openapi" => "3.0.3",
      "info" => %{
        "title" => "Kyozo Store API",
        "version" => "1.0.0",
        "description" => """
        Kyozo Store API - Folder-as-a-Service platform with collaborative workspace management.

        This API provides JSON:API compliant endpoints with JSON-LD context for semantic web integration.
        All responses include semantic metadata for enhanced discoverability and integration capabilities.
        """,
        "contact" => %{
          "name" => "Kyozo API Support",
          "url" => "https://kyozo.store/support"
        },
        "license" => %{
          "name" => "Proprietary",
          "url" => "https://kyozo.store/license"
        }
      },
      "servers" => [
        %{
          "url" => "https://api.kyozo.store",
          "description" => "Production server"
        },
        %{
          "url" => "http://localhost:4000",
          "description" => "Development server"
        }
      ],
      "@context" => %{
        "@base" => "https://kyozo.store/api/v2/",
        "@vocab" => "https://schema.kyozo.store/vocabulary#",
        "kyozo" => "https://schema.kyozo.store/container#",
        "schema" => "https://schema.org/",
        "Workspace" => "kyozo:Workspace",
        "Team" => "kyozo:Team",
        "User" => "kyozo:User",
        "File" => "kyozo:File",
        "Notebook" => "kyozo:Notebook",
        "ServiceInstance" => "kyozo:ServiceInstance",
        "TopologyDetection" => "kyozo:TopologyDetection",
        "DeploymentEvent" => "kyozo:DeploymentEvent",
        "ServiceDependency" => "kyozo:ServiceDependency"
      },
      "components" => %{
        "securitySchemes" => %{
          "bearerAuth" => %{
            "type" => "http",
            "scheme" => "bearer",
            "bearerFormat" => "JWT"
          },
          "apiKeyAuth" => %{
            "type" => "apiKey",
            "in" => "header",
            "name" => "Authorization"
          }
        },
        "schemas" => generate_schemas()
      },
      "security" => [
        %{"bearerAuth" => []},
        %{"apiKeyAuth" => []}
      ],
      "tags" => [
        %{
          "name" => "workspaces",
          "description" => "Workspace management operations",
          "externalDocs" => %{
            "description" => "Workspace documentation",
            "url" => "https://docs.kyozo.store/workspaces"
          }
        },
        %{
          "name" => "teams",
          "description" => "Team and user management operations"
        },
        %{
          "name" => "files",
          "description" => "File and document management operations"
        },
        %{
          "name" => "notebooks",
          "description" => "Notebook and execution management operations"
        }
      ]
    }

    # Note: In a real implementation, you would use AshJsonApi to generate
    # the full OpenAPI spec from your resources. For now, we provide the base structure.
    base_spec
  end

  defp generate_schemas do
    %{
      "Workspace" => %{
        "type" => "object",
        "@context" => "https://kyozo.store/api/v1/vocab#Workspace",
        "properties" => %{
          "id" => %{
            "type" => "string",
            "format" => "uuid",
            "description" => "Unique workspace identifier"
          },
          "name" => %{"type" => "string", "description" => "Human-readable workspace name"},
          "description" => %{"type" => "string", "description" => "Workspace description"},
          "status" => %{"type" => "string", "enum" => ["active", "archived", "deleted"]},
          "storage_backend" => %{"type" => "string", "enum" => ["git", "s3", "hybrid"]},
          "settings" => %{"type" => "object", "description" => "Workspace configuration settings"},
          "tags" => %{"type" => "array", "items" => %{"type" => "string"}},
          "created_at" => %{"type" => "string", "format" => "date-time"},
          "updated_at" => %{"type" => "string", "format" => "date-time"}
        },
        "required" => ["id", "name", "status", "storage_backend"],
        "additionalProperties" => false
      },
      "ServiceInstance" => %{
        "type" => "object",
        "@context" => "https://kyozo.store/api/v1/vocab#ServiceInstance",
        "properties" => %{
          "id" => %{
            "type" => "string",
            "format" => "uuid",
            "description" => "Unique service identifier"
          },
          "name" => %{"type" => "string", "description" => "Service name"},
          "folder_path" => %{"type" => "string", "description" => "Path to service folder"},
          "service_type" => %{
            "type" => "string",
            "enum" => [
              "nodejs",
              "python",
              "ruby",
              "java",
              "golang",
              "rust",
              "php",
              "dotnet",
              "django",
              "flask",
              "express",
              "spring_boot",
              "rails",
              "laravel",
              "postgres",
              "mysql",
              "mongodb",
              "redis",
              "elasticsearch",
              "cassandra",
              "sqlite",
              "rabbitmq",
              "kafka",
              "nats",
              "redis_queue",
              "memcached",
              "redis_cache",
              "nginx",
              "apache",
              "haproxy",
              "traefik",
              "static_files",
              "cdn",
              "celery",
              "sidekiq",
              "resque",
              "background_worker",
              "cron",
              "scheduler",
              "reverse_proxy",
              "api_gateway",
              "prometheus",
              "grafana",
              "jaeger",
              "zipkin",
              "docker",
              "custom_container"
            ]
          },
          "detection_confidence" => %{"type" => "number", "minimum" => 0.0, "maximum" => 1.0},
          "status" => %{
            "type" => "string",
            "enum" => [
              "detecting",
              "detected",
              "analysis_failed",
              "deployable",
              "building",
              "build_failed",
              "image_pulling",
              "image_pull_failed",
              "deploying",
              "deployment_failed",
              "starting",
              "start_failed",
              "running",
              "healthy",
              "unhealthy",
              "degraded",
              "stopped",
              "stopping",
              "crashed",
              "killed",
              "updating",
              "scaling",
              "restarting",
              "migrating",
              "error",
              "timeout",
              "resource_limit_exceeded",
              "configuration_error",
              "terminating",
              "terminated",
              "cleanup_failed"
            ]
          },
          "container_id" => %{"type" => "string", "description" => "Container identifier"},
          "image_id" => %{"type" => "string", "description" => "Docker image identifier"},
          "deployment_config" => %{
            "type" => "object",
            "description" => "Deployment configuration"
          },
          "port_mappings" => %{"type" => "object", "description" => "Port mapping configuration"},
          "environment_variables" => %{
            "type" => "object",
            "description" => "Environment variables"
          },
          "resource_limits" => %{
            "type" => "object",
            "description" => "Resource limits and requests"
          },
          "scaling_config" => %{"type" => "object", "description" => "Scaling configuration"},
          "health_check_config" => %{
            "type" => "object",
            "description" => "Health check configuration"
          },
          "created_at" => %{"type" => "string", "format" => "date-time"},
          "updated_at" => %{"type" => "string", "format" => "date-time"},
          "deployed_at" => %{"type" => "string", "format" => "date-time"},
          "last_health_check_at" => %{"type" => "string", "format" => "date-time"}
        },
        "required" => ["id", "name", "folder_path", "service_type", "status"]
      },
      "TopologyDetection" => %{
        "type" => "object",
        "@context" => "https://kyozo.store/api/v1/vocab#TopologyDetection",
        "properties" => %{
          "id" => %{"type" => "string", "format" => "uuid"},
          "folder_path" => %{"type" => "string", "description" => "Analyzed folder path"},
          "detection_timestamp" => %{"type" => "string", "format" => "date-time"},
          "status" => %{
            "type" => "string",
            "enum" => ["analyzing", "completed", "failed", "cancelled"]
          },
          "detected_patterns" => %{
            "type" => "object",
            "description" => "Detected service patterns with confidence scores"
          },
          "service_graph" => %{"type" => "object", "description" => "Service dependency graph"},
          "recommended_services" => %{"type" => "array", "items" => %{"type" => "object"}},
          "deployment_strategy" => %{
            "type" => "string",
            "enum" => ["docker_compose", "kubernetes", "compose_stack", "single_container"]
          },
          "total_services_detected" => %{"type" => "integer", "minimum" => 0},
          "created_at" => %{"type" => "string", "format" => "date-time"},
          "updated_at" => %{"type" => "string", "format" => "date-time"}
        },
        "required" => ["id", "folder_path", "detection_timestamp", "status"]
      },
      "DeploymentEvent" => %{
        "type" => "object",
        "@context" => "https://kyozo.store/api/v1/vocab#DeploymentEvent",
        "properties" => %{
          "id" => %{"type" => "string", "format" => "uuid"},
          "event_type" => %{
            "type" => "string",
            "enum" => [
              "deployment_started",
              "deployment_completed",
              "deployment_failed",
              "build_started",
              "build_completed",
              "build_failed",
              "container_started",
              "container_stopped",
              "container_crashed",
              "service_scaled",
              "health_check_failed",
              "health_check_recovered",
              "configuration_updated"
            ]
          },
          "event_data" => %{"type" => "object", "description" => "Event-specific data"},
          "duration_ms" => %{
            "type" => "integer",
            "minimum" => 0,
            "description" => "Operation duration in milliseconds"
          },
          "sequence_number" => %{
            "type" => "integer",
            "description" => "Sequential number per service"
          },
          "occurred_at" => %{"type" => "string", "format" => "date-time"},
          "status" => %{
            "type" => "string",
            "enum" => ["success", "failure", "in_progress", "cancelled"]
          },
          "error_details" => %{
            "type" => "object",
            "description" => "Error information for failed events"
          },
          "created_at" => %{"type" => "string", "format" => "date-time"}
        },
        "required" => ["id", "event_type", "sequence_number", "occurred_at"]
      },
      "ServiceDependency" => %{
        "type" => "object",
        "@context" => "https://kyozo.store/api/v1/vocab#ServiceDependency",
        "properties" => %{
          "id" => %{"type" => "string", "format" => "uuid"},
          "dependency_type" => %{
            "type" => "string",
            "enum" => ["requires", "connects_to", "depends_on", "waits_for", "communicates_with"]
          },
          "connection_string" => %{
            "type" => "string",
            "description" => "Connection string template"
          },
          "environment_variable" => %{
            "type" => "string",
            "description" => "Environment variable name"
          },
          "startup_order" => %{"type" => "integer", "minimum" => 0, "maximum" => 100},
          "is_required" => %{
            "type" => "boolean",
            "description" => "Whether dependency is required"
          },
          "health_check_path" => %{"type" => "string", "description" => "Health check endpoint"},
          "timeout_seconds" => %{"type" => "integer", "minimum" => 1, "maximum" => 300},
          "retry_count" => %{"type" => "integer", "minimum" => 0, "maximum" => 10},
          "created_at" => %{"type" => "string", "format" => "date-time"},
          "updated_at" => %{"type" => "string", "format" => "date-time"}
        },
        "required" => ["id", "dependency_type"]
      },
      "Team" => %{
        "type" => "object",
        "@context" => "https://kyozo.store/api/v1/vocab#Team",
        "properties" => %{
          "id" => %{"type" => "string", "format" => "uuid"},
          "name" => %{"type" => "string"},
          "description" => %{"type" => "string"},
          "created_at" => %{"type" => "string", "format" => "date-time"},
          "updated_at" => %{"type" => "string", "format" => "date-time"}
        },
        "required" => ["id", "name"]
      },
      "Error" => %{
        "type" => "object",
        "properties" => %{
          "errors" => %{
            "type" => "array",
            "items" => %{
              "type" => "object",
              "properties" => %{
                "id" => %{"type" => "string"},
                "status" => %{"type" => "string"},
                "code" => %{"type" => "string"},
                "title" => %{"type" => "string"},
                "detail" => %{"type" => "string"},
                "source" => %{
                  "type" => "object",
                  "properties" => %{
                    "pointer" => %{"type" => "string"},
                    "parameter" => %{"type" => "string"}
                  }
                },
                "meta" => %{"type" => "object"}
              }
            }
          }
        }
      }
    }
  end
end
