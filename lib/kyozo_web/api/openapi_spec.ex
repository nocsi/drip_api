defmodule KyozoWeb.API.OpenAPISpec do
  @moduledoc """
  Complete OpenAPI 3.0 specification for Kyozo API.
  This module defines all API endpoints, schemas, and operations.
  """

  use OpenApiSpex.ControllerSpecs

  @doc """
  Returns the complete OpenAPI spec as a map.
  """
  def spec do
    %{
      openapi: "3.0.0",
      info: %{
        title: "Kyozo API",
        version: "1.0.0",
        description: """
        Kyozo API provides endpoints for managing workspaces, files, notebooks, and AI services.

        ## Authentication
        Most endpoints require Bearer token authentication. Include your API token in the Authorization header:
        ```
        Authorization: Bearer your_api_token_here
        ```

        ## Base URL
        The API is available at: `https://kyozo.store/api/v1`

        ## Rate Limiting
        API requests are rate limited to 100 requests per minute per user.
        """
      },
      servers: [
        %{
          url: "http://localhost:4000/api/v1",
          description: "Local development server"
        },
        %{
          url: "https://kyozo.store/api/v1",
          description: "Production server"
        }
      ],
      security: [
        %{bearerAuth: []}
      ],
      components: %{
        securitySchemes: %{
          bearerAuth: %{
            type: "http",
            scheme: "bearer",
            bearerFormat: "JWT"
          }
        },
        schemas: schemas()
      },
      paths: paths()
    }
  end

  defp schemas do
    %{
      # Common schemas
      Error: %{
        type: "object",
        properties: %{
          error: %{
            type: "string",
            description: "Error message"
          },
          details: %{
            type: "object",
            description: "Additional error details"
          }
        },
        required: ["error"]
      },

      # Team schemas
      Team: %{
        type: "object",
        properties: %{
          id: %{type: "string", format: "uuid"},
          name: %{type: "string"},
          slug: %{type: "string"},
          description: %{type: "string"},
          personal: %{type: "boolean"},
          created_at: %{type: "string", format: "date-time"},
          updated_at: %{type: "string", format: "date-time"}
        },
        required: ["id", "name", "slug"]
      },

      # Workspace schemas
      Workspace: %{
        type: "object",
        properties: %{
          id: %{type: "string", format: "uuid"},
          name: %{type: "string"},
          description: %{type: "string"},
          status: %{type: "string", enum: ["active", "archived", "deleted"]},
          team_id: %{type: "string", format: "uuid"},
          created_at: %{type: "string", format: "date-time"},
          updated_at: %{type: "string", format: "date-time"}
        },
        required: ["id", "name", "status", "team_id"]
      },

      # File schemas
      File: %{
        type: "object",
        properties: %{
          id: %{type: "string", format: "uuid"},
          name: %{type: "string"},
          file_path: %{type: "string"},
          content_type: %{type: "string"},
          size: %{type: "integer"},
          is_directory: %{type: "boolean"},
          workspace_id: %{type: "string", format: "uuid"},
          parent_file_id: %{type: "string", format: "uuid", nullable: true},
          created_at: %{type: "string", format: "date-time"},
          updated_at: %{type: "string", format: "date-time"}
        },
        required: ["id", "name", "file_path", "content_type", "workspace_id"]
      },
      FileCreateRequest: %{
        type: "object",
        properties: %{
          name: %{type: "string"},
          content: %{type: "string"},
          content_type: %{type: "string", default: "text/markdown"},
          parent_file_id: %{type: "string", format: "uuid", nullable: true}
        },
        required: ["name"]
      },
      FileUpdateRequest: %{
        type: "object",
        properties: %{
          content: %{type: "string"},
          name: %{type: "string"}
        }
      },

      # Notebook schemas (for markdown files opened as notebooks)
      Notebook: %{
        type: "object",
        properties: %{
          id: %{type: "string", format: "uuid"},
          title: %{type: "string"},
          content: %{type: "string", description: "Raw markdown content"},
          content_html: %{type: "string", description: "Rendered HTML"},
          status: %{type: "string", enum: ["draft", "running", "completed", "error"]},
          execution_state: %{type: "object"},
          extracted_tasks: %{
            type: "array",
            items: %{
              type: "object",
              properties: %{
                id: %{type: "string"},
                language: %{type: "string"},
                code: %{type: "string"},
                position: %{type: "integer"}
              }
            }
          },
          document_id: %{type: "string", format: "uuid"},
          workspace_id: %{type: "string", format: "uuid"},
          created_at: %{type: "string", format: "date-time"},
          updated_at: %{type: "string", format: "date-time"}
        },
        required: ["id", "title", "content", "status", "document_id"]
      },
      NotebookCreateRequest: %{
        type: "object",
        properties: %{
          title: %{type: "string"},
          auto_save_enabled: %{type: "boolean", default: true}
        }
      },
      NotebookExecuteRequest: %{
        type: "object",
        properties: %{
          environment_variables: %{
            type: "object",
            additionalProperties: %{type: "string"}
          }
        }
      },
      TaskExecuteRequest: %{
        type: "object",
        properties: %{
          task_id: %{type: "string"},
          environment_variables: %{
            type: "object",
            additionalProperties: %{type: "string"}
          }
        },
        required: ["task_id"]
      },

      # AI schemas
      AISuggestRequest: %{
        type: "object",
        properties: %{
          text: %{type: "string", description: "Text to get suggestions for"},
          context: %{type: "string", description: "Additional context"},
          max_suggestions: %{type: "integer", default: 5}
        },
        required: ["text"]
      },
      AISuggestResponse: %{
        type: "object",
        properties: %{
          suggestions: %{
            type: "array",
            items: %{
              type: "object",
              properties: %{
                text: %{type: "string"},
                confidence: %{type: "number"},
                explanation: %{type: "string"}
              }
            }
          }
        }
      },
      AIConfidenceRequest: %{
        type: "object",
        properties: %{
          text: %{type: "string", description: "Code to analyze"},
          language: %{type: "string", description: "Programming language"}
        },
        required: ["text", "language"]
      },
      AIConfidenceResponse: %{
        type: "object",
        properties: %{
          confidence_score: %{type: "number", minimum: 0, maximum: 1},
          issues: %{
            type: "array",
            items: %{
              type: "object",
              properties: %{
                type: %{type: "string"},
                message: %{type: "string"},
                line: %{type: "integer"},
                severity: %{type: "string", enum: ["error", "warning", "info"]}
              }
            }
          }
        }
      },

      # VFS schemas
      VFSFile: %{
        type: "object",
        properties: %{
          name: %{type: "string"},
          path: %{type: "string"},
          type: %{type: "string", enum: ["file", "directory"]},
          virtual: %{type: "boolean"},
          size: %{type: "integer"},
          content_type: %{type: "string"},
          icon: %{type: "string"},
          generator: %{type: "string"}
        },
        required: ["name", "path", "type", "virtual"]
      },
      VFSListing: %{
        type: "object",
        properties: %{
          path: %{type: "string"},
          files: %{
            type: "array",
            items: %{"$ref": "#/components/schemas/VFSFile"}
          },
          virtual_count: %{type: "integer"}
        }
      },
      VFSContent: %{
        type: "object",
        properties: %{
          path: %{type: "string"},
          content: %{type: "string"},
          virtual: %{type: "boolean"},
          content_type: %{type: "string"}
        }
      }
    }
  end

  defp paths do
    %{
      # Team endpoints
      "/teams": %{
        get: %{
          tags: ["Teams"],
          summary: "List teams",
          description: "List all teams the current user belongs to",
          operationId: "listTeams",
          responses: %{
            "200": %{
              description: "Success",
              content: %{
                "application/json": %{
                  schema: %{
                    type: "object",
                    properties: %{
                      data: %{
                        type: "array",
                        items: %{"$ref": "#/components/schemas/Team"}
                      }
                    }
                  }
                }
              }
            }
          }
        },
        post: %{
          tags: ["Teams"],
          summary: "Create team",
          description: "Create a new team",
          operationId: "createTeam",
          requestBody: %{
            required: true,
            content: %{
              "application/json": %{
                schema: %{
                  type: "object",
                  properties: %{
                    name: %{type: "string"},
                    description: %{type: "string"}
                  },
                  required: ["name"]
                }
              }
            }
          },
          responses: %{
            "201": %{
              description: "Team created",
              content: %{
                "application/json": %{
                  schema: %{
                    type: "object",
                    properties: %{
                      data: %{"$ref": "#/components/schemas/Team"}
                    }
                  }
                }
              }
            }
          }
        }
      },

      # Workspace endpoints
      "/teams/{team_id}/workspaces": %{
        get: %{
          tags: ["Workspaces"],
          summary: "List workspaces",
          description: "List all workspaces in a team",
          operationId: "listWorkspaces",
          parameters: [
            %{
              name: "team_id",
              in: "path",
              required: true,
              schema: %{type: "string", format: "uuid"}
            }
          ],
          responses: %{
            "200": %{
              description: "Success",
              content: %{
                "application/json": %{
                  schema: %{
                    type: "object",
                    properties: %{
                      data: %{
                        type: "array",
                        items: %{"$ref": "#/components/schemas/Workspace"}
                      }
                    }
                  }
                }
              }
            }
          }
        },
        post: %{
          tags: ["Workspaces"],
          summary: "Create workspace",
          description: "Create a new workspace in a team",
          operationId: "createWorkspace",
          parameters: [
            %{
              name: "team_id",
              in: "path",
              required: true,
              schema: %{type: "string", format: "uuid"}
            }
          ],
          requestBody: %{
            required: true,
            content: %{
              "application/json": %{
                schema: %{
                  type: "object",
                  properties: %{
                    name: %{type: "string"},
                    description: %{type: "string"}
                  },
                  required: ["name"]
                }
              }
            }
          },
          responses: %{
            "201": %{
              description: "Workspace created",
              content: %{
                "application/json": %{
                  schema: %{
                    type: "object",
                    properties: %{
                      data: %{"$ref": "#/components/schemas/Workspace"}
                    }
                  }
                }
              }
            }
          }
        }
      },

      # File endpoints
      "/teams/{team_id}/files": %{
        get: %{
          tags: ["Files"],
          summary: "List files",
          description: "List all files accessible to the team",
          operationId: "listFiles",
          parameters: [
            %{
              name: "team_id",
              in: "path",
              required: true,
              schema: %{type: "string", format: "uuid"}
            },
            %{
              name: "workspace_id",
              in: "query",
              schema: %{type: "string", format: "uuid"}
            },
            %{
              name: "parent_file_id",
              in: "query",
              schema: %{type: "string", format: "uuid"}
            }
          ],
          responses: %{
            "200": %{
              description: "Success",
              content: %{
                "application/json": %{
                  schema: %{
                    type: "object",
                    properties: %{
                      data: %{
                        type: "array",
                        items: %{"$ref": "#/components/schemas/File"}
                      }
                    }
                  }
                }
              }
            }
          }
        },
        post: %{
          tags: ["Files"],
          summary: "Create file",
          description: "Create a new markdown file",
          operationId: "createFile",
          parameters: [
            %{
              name: "team_id",
              in: "path",
              required: true,
              schema: %{type: "string", format: "uuid"}
            }
          ],
          requestBody: %{
            required: true,
            content: %{
              "application/json": %{
                schema: %{"$ref": "#/components/schemas/FileCreateRequest"}
              }
            }
          },
          responses: %{
            "201": %{
              description: "File created",
              content: %{
                "application/json": %{
                  schema: %{
                    type: "object",
                    properties: %{
                      data: %{"$ref": "#/components/schemas/File"}
                    }
                  }
                }
              }
            }
          }
        }
      },
      "/teams/{team_id}/files/{id}": %{
        get: %{
          tags: ["Files"],
          summary: "Get file",
          description: "Get a specific file by ID",
          operationId: "getFile",
          parameters: [
            %{
              name: "team_id",
              in: "path",
              required: true,
              schema: %{type: "string", format: "uuid"}
            },
            %{
              name: "id",
              in: "path",
              required: true,
              schema: %{type: "string", format: "uuid"}
            }
          ],
          responses: %{
            "200": %{
              description: "Success",
              content: %{
                "application/json": %{
                  schema: %{
                    type: "object",
                    properties: %{
                      data: %{"$ref": "#/components/schemas/File"}
                    }
                  }
                }
              }
            }
          }
        },
        patch: %{
          tags: ["Files"],
          summary: "Update file",
          description: "Update file content or metadata",
          operationId: "updateFile",
          parameters: [
            %{
              name: "team_id",
              in: "path",
              required: true,
              schema: %{type: "string", format: "uuid"}
            },
            %{
              name: "id",
              in: "path",
              required: true,
              schema: %{type: "string", format: "uuid"}
            }
          ],
          requestBody: %{
            required: true,
            content: %{
              "application/json": %{
                schema: %{"$ref": "#/components/schemas/FileUpdateRequest"}
              }
            }
          },
          responses: %{
            "200": %{
              description: "File updated",
              content: %{
                "application/json": %{
                  schema: %{
                    type: "object",
                    properties: %{
                      data: %{"$ref": "#/components/schemas/File"}
                    }
                  }
                }
              }
            }
          }
        },
        delete: %{
          tags: ["Files"],
          summary: "Delete file",
          description: "Delete a file",
          operationId: "deleteFile",
          parameters: [
            %{
              name: "team_id",
              in: "path",
              required: true,
              schema: %{type: "string", format: "uuid"}
            },
            %{
              name: "id",
              in: "path",
              required: true,
              schema: %{type: "string", format: "uuid"}
            }
          ],
          responses: %{
            "204": %{
              description: "File deleted"
            }
          }
        }
      },
      "/teams/{team_id}/files/{id}/content": %{
        get: %{
          tags: ["Files"],
          summary: "Get file content",
          description: "Get raw file content",
          operationId: "getFileContent",
          parameters: [
            %{
              name: "team_id",
              in: "path",
              required: true,
              schema: %{type: "string", format: "uuid"}
            },
            %{
              name: "id",
              in: "path",
              required: true,
              schema: %{type: "string", format: "uuid"}
            }
          ],
          responses: %{
            "200": %{
              description: "File content",
              content: %{
                "text/plain": %{
                  schema: %{type: "string"}
                }
              }
            }
          }
        }
      },

      # Notebook endpoints (for markdown files as notebooks)
      "/teams/{team_id}/files/{file_id}/notebooks": %{
        post: %{
          tags: ["Notebooks"],
          summary: "Create notebook from file",
          description: "Open a markdown file as an executable notebook",
          operationId: "createNotebookFromFile",
          parameters: [
            %{
              name: "team_id",
              in: "path",
              required: true,
              schema: %{type: "string", format: "uuid"}
            },
            %{
              name: "file_id",
              in: "path",
              required: true,
              schema: %{type: "string", format: "uuid"}
            }
          ],
          requestBody: %{
            required: true,
            content: %{
              "application/json": %{
                schema: %{"$ref": "#/components/schemas/NotebookCreateRequest"}
              }
            }
          },
          responses: %{
            "201": %{
              description: "Notebook created",
              content: %{
                "application/json": %{
                  schema: %{
                    type: "object",
                    properties: %{
                      data: %{"$ref": "#/components/schemas/Notebook"}
                    }
                  }
                }
              }
            }
          }
        }
      },
      "/teams/{team_id}/notebooks/{id}": %{
        get: %{
          tags: ["Notebooks"],
          summary: "Get notebook",
          description: "Get notebook details including extracted tasks",
          operationId: "getNotebook",
          parameters: [
            %{
              name: "team_id",
              in: "path",
              required: true,
              schema: %{type: "string", format: "uuid"}
            },
            %{
              name: "id",
              in: "path",
              required: true,
              schema: %{type: "string", format: "uuid"}
            }
          ],
          responses: %{
            "200": %{
              description: "Success",
              content: %{
                "application/json": %{
                  schema: %{
                    type: "object",
                    properties: %{
                      data: %{"$ref": "#/components/schemas/Notebook"}
                    }
                  }
                }
              }
            }
          }
        },
        delete: %{
          tags: ["Notebooks"],
          summary: "Delete notebook",
          description: "Close notebook (file remains unchanged)",
          operationId: "deleteNotebook",
          parameters: [
            %{
              name: "team_id",
              in: "path",
              required: true,
              schema: %{type: "string", format: "uuid"}
            },
            %{
              name: "id",
              in: "path",
              required: true,
              schema: %{type: "string", format: "uuid"}
            }
          ],
          responses: %{
            "204": %{
              description: "Notebook deleted"
            }
          }
        }
      },
      "/teams/{team_id}/notebooks/{id}/execute": %{
        post: %{
          tags: ["Notebooks"],
          summary: "Execute notebook",
          description: "Execute all code blocks in the notebook",
          operationId: "executeNotebook",
          parameters: [
            %{
              name: "team_id",
              in: "path",
              required: true,
              schema: %{type: "string", format: "uuid"}
            },
            %{
              name: "id",
              in: "path",
              required: true,
              schema: %{type: "string", format: "uuid"}
            }
          ],
          requestBody: %{
            content: %{
              "application/json": %{
                schema: %{"$ref": "#/components/schemas/NotebookExecuteRequest"}
              }
            }
          },
          responses: %{
            "200": %{
              description: "Execution started",
              content: %{
                "application/json": %{
                  schema: %{
                    type: "object",
                    properties: %{
                      data: %{"$ref": "#/components/schemas/Notebook"}
                    }
                  }
                }
              }
            }
          }
        }
      },
      "/teams/{team_id}/notebooks/{id}/execute/{task_id}": %{
        post: %{
          tags: ["Notebooks"],
          summary: "Execute task",
          description: "Execute a specific code block (task) in the notebook",
          operationId: "executeTask",
          parameters: [
            %{
              name: "team_id",
              in: "path",
              required: true,
              schema: %{type: "string", format: "uuid"}
            },
            %{
              name: "id",
              in: "path",
              required: true,
              schema: %{type: "string", format: "uuid"}
            },
            %{
              name: "task_id",
              in: "path",
              required: true,
              schema: %{type: "string"}
            }
          ],
          requestBody: %{
            content: %{
              "application/json": %{
                schema: %{"$ref": "#/components/schemas/TaskExecuteRequest"}
              }
            }
          },
          responses: %{
            "200": %{
              description: "Task executed",
              content: %{
                "application/json": %{
                  schema: %{
                    type: "object",
                    properties: %{
                      data: %{"$ref": "#/components/schemas/Notebook"}
                    }
                  }
                }
              }
            }
          }
        }
      },

      # AI endpoints
      "/ai/suggest": %{
        post: %{
          tags: ["AI"],
          summary: "Get AI suggestions",
          description: "Get intelligent text suggestions using AI",
          operationId: "aiSuggest",
          requestBody: %{
            required: true,
            content: %{
              "application/json": %{
                schema: %{"$ref": "#/components/schemas/AISuggestRequest"}
              }
            }
          },
          responses: %{
            "200": %{
              description: "Success",
              content: %{
                "application/json": %{
                  schema: %{"$ref": "#/components/schemas/AISuggestResponse"}
                }
              }
            }
          }
        }
      },
      "/ai/confidence": %{
        post: %{
          tags: ["AI"],
          summary: "Analyze code confidence",
          description: "Analyze code quality and confidence using AI",
          operationId: "aiConfidence",
          requestBody: %{
            required: true,
            content: %{
              "application/json": %{
                schema: %{"$ref": "#/components/schemas/AIConfidenceRequest"}
              }
            }
          },
          responses: %{
            "200": %{
              description: "Success",
              content: %{
                "application/json": %{
                  schema: %{"$ref": "#/components/schemas/AIConfidenceResponse"}
                }
              }
            }
          }
        }
      },

      # VFS endpoints
      "/teams/{team_id}/workspaces/{workspace_id}/storage/vfs": %{
        get: %{
          tags: ["VFS"],
          summary: "List VFS files",
          description: "List files including virtual generated files",
          operationId: "listVFS",
          parameters: [
            %{
              name: "team_id",
              in: "path",
              required: true,
              schema: %{type: "string", format: "uuid"}
            },
            %{
              name: "workspace_id",
              in: "path",
              required: true,
              schema: %{type: "string", format: "uuid"}
            },
            %{
              name: "path",
              in: "query",
              schema: %{type: "string", default: "/"}
            }
          ],
          responses: %{
            "200": %{
              description: "Success",
              content: %{
                "application/json": %{
                  schema: %{"$ref": "#/components/schemas/VFSListing"}
                }
              }
            }
          }
        }
      },
      "/teams/{team_id}/workspaces/{workspace_id}/storage/vfs/content": %{
        get: %{
          tags: ["VFS"],
          summary: "Read VFS file",
          description: "Read content of a virtual file",
          operationId: "readVFS",
          parameters: [
            %{
              name: "team_id",
              in: "path",
              required: true,
              schema: %{type: "string", format: "uuid"}
            },
            %{
              name: "workspace_id",
              in: "path",
              required: true,
              schema: %{type: "string", format: "uuid"}
            },
            %{
              name: "path",
              in: "query",
              required: true,
              schema: %{type: "string"}
            }
          ],
          responses: %{
            "200": %{
              description: "Success",
              content: %{
                "application/json": %{
                  schema: %{"$ref": "#/components/schemas/VFSContent"}
                }
              }
            }
          }
        }
      }
    }
  end
end
