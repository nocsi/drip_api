defmodule Dirup.WorkspacesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Dirup.Workspaces` context.
  """

  import Dirup.AccountsFixtures
  alias Dirup.Workspaces
  # TODO: Update blob system to work with new File architecture
  # alias Dirup.Workspaces.{DocumentBlobRef, Blob}

  @doc """
  Generate a workspace.
  """
  def workspace_fixture(attrs \\ %{}) do
    user = attrs[:user] || user_fixture()

    {:ok, team} =
      Dirup.Accounts.create_team(
        %{
          name: "Test Team #{System.unique_integer()}",
          description: "A test team"
        },
        actor: user
      )

    base_attrs = %{
      name: "Test Workspace #{System.unique_integer()}",
      description: "A test workspace for #{user.email}",
      team_id: team.id
    }

    workspace_attrs = Map.merge(base_attrs, Enum.into(attrs, %{}))

    {:ok, workspace} = Workspaces.create_workspace(workspace_attrs, actor: user)
    workspace
  end

  @doc """
  Generate a document.
  """
  def document_fixture(attrs \\ %{}) do
    user = attrs[:user] || user_fixture()
    workspace = attrs[:workspace] || workspace_fixture(user: user)

    base_attrs = %{
      title: "Test Document #{System.unique_integer()}",
      description: "A test document",
      workspace_id: workspace.id
    }

    document_attrs = Map.merge(base_attrs, Enum.into(attrs, %{}))

    {:ok, document} = Workspaces.create_document(document_attrs, actor: user)
    document
  end

  @doc """
  Generate a document with content stored in blob.
  """
  def document_with_content_fixture(attrs \\ %{}) do
    content =
      attrs[:content] ||
        """
        # Test Document

        This is a test document with some content.

        ```python
        print("Hello, World!")
        ```

        ## Section 2

        More content here.
        """

    document = document_fixture(attrs)

    {:ok, _blob_ref} =
      DocumentBlobRef.create_content_ref(
        document.id,
        content,
        attrs[:content_type] || "text/markdown"
      )

    document
  end

  @doc """
  Generate a notebook.
  """
  def notebook_fixture(attrs \\ %{}) do
    user = attrs[:user] || user_fixture()
    workspace = attrs[:workspace] || workspace_fixture(user: user)

    document =
      attrs[:document] ||
        document_with_content_fixture(
          user: user,
          workspace: workspace,
          title: "Notebook Document #{System.unique_integer()}"
        )

    {:ok, notebook} = Workspaces.create_from_document(document.id, actor: user)
    notebook
  end

  @doc """
  Generate a notebook with specific content.
  """
  def notebook_with_content_fixture(attrs \\ %{}) do
    content =
      attrs[:content] ||
        """
        # Machine Learning Notebook

        ## Data Analysis

        ```python
        import pandas as pd
        import numpy as np

        # Load data
        data = pd.read_csv('data.csv')
        print(data.shape)
        ```

        ## Model Training

        ```python
        from sklearn.ensemble import RandomForestClassifier

        model = RandomForestClassifier()
        model.fit(X_train, y_train)
        accuracy = model.score(X_test, y_test)
        print(f"Accuracy: {accuracy}")
        ```

        ## Results

        The model achieved good performance on the test set.

        ### Todo
        - [ ] Feature engineering
        - [ ] Hyperparameter tuning
        - [x] Basic model training
        """

    attrs_with_content = Map.put(attrs, :content, content)
    notebook_fixture(attrs_with_content)
  end

  @doc """
  Generate a blob.
  """
  def blob_fixture(attrs \\ %{}) do
    content = attrs[:content] || "Test blob content #{System.unique_integer()}"
    content_type = attrs[:content_type] || "text/plain"
    encoding = attrs[:encoding] || "utf-8"

    {:ok, blob} =
      Workspaces.create_blob(
        content: content,
        content_type: content_type,
        encoding: encoding
      )

    blob
  end

  @doc """
  Generate a document blob reference.
  """
  def document_blob_ref_fixture(attrs \\ %{}) do
    document = attrs[:document] || document_fixture()
    blob = attrs[:blob] || blob_fixture()
    ref_type = attrs[:ref_type] || "content"

    {:ok, ref} =
      Workspaces.create_ref(%{
        document_id: document.id,
        blob_id: blob.id,
        ref_type: ref_type
      })

    ref
  end

  @doc """
  Generate a task for testing.
  """
  def task_fixture(attrs \\ %{}) do
    user = attrs[:user] || user_fixture()
    workspace = attrs[:workspace] || workspace_fixture(user: user)

    base_attrs = %{
      name: "Test Task #{System.unique_integer()}",
      description: "A test task",
      language: "python",
      code: "print('Hello, World!')",
      workspace_id: workspace.id
    }

    task_attrs = Map.merge(base_attrs, Enum.into(attrs, %{}))

    {:ok, task} = Workspaces.create_task(task_attrs, actor: user)
    task
  end

  @doc """
  Generate sample markdown content with code blocks.
  """
  def sample_markdown_content do
    """
    # Sample Notebook

    This is a sample notebook with various code blocks.

    ## Python Example

    ```python
    import numpy as np
    import matplotlib.pyplot as plt

    # Generate sample data
    x = np.linspace(0, 10, 100)
    y = np.sin(x)

    # Create plot
    plt.figure(figsize=(10, 6))
    plt.plot(x, y, 'b-', linewidth=2)
    plt.title('Sine Wave')
    plt.xlabel('X')
    plt.ylabel('Y')
    plt.grid(True)
    plt.show()
    ```

    ## Elixir Example

    ```elixir
    defmodule Calculator do
      def add(a, b), do: a + b
      def multiply(a, b), do: a * b
      
      def factorial(0), do: 1
      def factorial(n) when n > 0 do
        n * factorial(n - 1)
      end
    end

    # Usage
    IO.puts Calculator.add(5, 3)
    IO.puts Calculator.factorial(5)
    ```

    ## JavaScript Example

    ```javascript
    // Async function example
    async function fetchData(url) {
      try {
        const response = await fetch(url);
        const data = await response.json();
        return data;
      } catch (error) {
        console.error('Error fetching data:', error);
        throw error;
      }
    }

    // Usage
    fetchData('https://api.example.com/data')
      .then(data => console.log(data))
      .catch(error => console.error(error));
    ```

    ## SQL Example

    ```sql
    -- Create table
    CREATE TABLE users (
      id SERIAL PRIMARY KEY,
      email VARCHAR(255) UNIQUE NOT NULL,
      name VARCHAR(255) NOT NULL,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );

    -- Insert data
    INSERT INTO users (email, name) VALUES
      ('alice@example.com', 'Alice Smith'),
      ('bob@example.com', 'Bob Johnson');

    -- Query data
    SELECT name, email, created_at
    FROM users
    WHERE created_at > '2024-01-01'
    ORDER BY created_at DESC;
    ```

    ## Bash Example

    ```bash
    #!/bin/bash

    # Function to backup database
    backup_database() {
      local db_name=$1
      local backup_dir="/backups"
      local timestamp=$(date +"%Y%m%d_%H%M%S")
      
      echo "Starting backup of $db_name..."
      
      pg_dump $db_name > "$backup_dir/${db_name}_${timestamp}.sql"
      
      if [ $? -eq 0 ]; then
        echo "Backup completed successfully"
      else
        echo "Backup failed" >&2
        exit 1
      fi
    }

    # Run backup
    backup_database "production_db"
    ```

    ## Mixed Content

    Here's some regular text between code blocks.

    ```text
    This is just plain text, not executable.
    It should not be treated as a task.
    ```

    And some more markdown content:

    - List item 1
    - List item 2
    - List item 3

    > This is a blockquote with some important information.

    **Bold text** and *italic text* for emphasis.

    ## Todo List

    - [x] Create sample notebook
    - [ ] Add more examples
    - [ ] Test execution
    - [ ] Add documentation

    ---

    *End of sample notebook*
    """
  end

  @doc """
  Generate sample design system content.
  """
  def sample_design_content do
    """
    # Design System Documentation

    ## Typography

    ### Font Families

    ```css
    :root {
      --font-primary: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
      --font-mono: 'JetBrains Mono', 'Fira Code', monospace;
    }
    ```

    ### Text Styles

    ```css
    .heading-1 {
      font-family: var(--font-primary);
      font-size: 2.25rem;
      font-weight: 700;
      line-height: 1.2;
    }

    .body-text {
      font-family: var(--font-primary);
      font-size: 1rem;
      line-height: 1.6;
    }
    ```

    ## Colors

    ### Brand Colors

    | Color | Hex | Usage |
    |-------|-----|-------|
    | Primary | #3B82F6 | Main actions |
    | Secondary | #64748B | Supporting elements |
    | Success | #10B981 | Success states |
    | Warning | #F59E0B | Warning states |
    | Error | #EF4444 | Error states |

    ## Components

    ### Button Component

    ```jsx
    import React from 'react';
    import styled from 'styled-components';

    const StyledButton = styled.button`
      padding: 0.75rem 1.5rem;
      border-radius: 0.5rem;
      font-weight: 600;
      transition: all 0.2s ease;
      
      ${props => props.variant === 'primary' && `
        background-color: #3B82F6;
        color: white;
        border: 2px solid #3B82F6;
        
        &:hover {
          background-color: #2563EB;
          border-color: #2563EB;
        }
      `}
    `;

    export const Button = ({ children, variant = 'primary', ...props }) => (
      <StyledButton variant={variant} {...props}>
        {children}
      </StyledButton>
    );
    ```

    ### Input Component

    ```jsx
    const Input = styled.input`
      padding: 0.75rem 1rem;
      border: 2px solid #E5E7EB;
      border-radius: 0.5rem;
      font-size: 1rem;
      
      &:focus {
        outline: none;
        border-color: #3B82F6;
        box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
      }
      
      &:invalid {
        border-color: #EF4444;
      }
    `;
    ```

    ## Layout System

    ```css
    .container {
      max-width: 1200px;
      margin: 0 auto;
      padding: 0 1rem;
    }

    .grid {
      display: grid;
      grid-template-columns: repeat(12, 1fr);
      gap: 1rem;
    }

    .flex {
      display: flex;
      gap: 1rem;
    }
    ```
    """
  end

  @doc """
  Generate sample project planning content.
  """
  def sample_project_content do
    """
    # Project Planning Document

    ## Project Overview

    This document outlines the development plan for the new feature set.

    ## Timeline

    ### Phase 1: Research (Weeks 1-2)
    - [ ] User research interviews
    - [ ] Competitive analysis
    - [ ] Technical feasibility study
    - [x] Project kickoff meeting

    ### Phase 2: Development (Weeks 3-8)
    - [ ] Frontend implementation
    - [ ] Backend API development
    - [ ] Database schema updates
    - [ ] Integration testing

    ### Phase 3: Testing & Launch (Weeks 9-10)
    - [ ] User acceptance testing
    - [ ] Performance optimization
    - [ ] Documentation
    - [ ] Production deployment

    ## Technical Requirements

    ### Database Schema

    ```sql
    CREATE TABLE project_features (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      name VARCHAR(255) NOT NULL,
      description TEXT,
      status VARCHAR(50) DEFAULT 'planned',
      priority INTEGER DEFAULT 1,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );

    CREATE INDEX idx_features_status ON project_features(status);
    CREATE INDEX idx_features_priority ON project_features(priority);
    ```

    ### API Endpoints

    ```elixir
    # Router configuration
    scope "/api/v1", MyAppWeb.API do
      pipe_through :api

      resources "/features", FeatureController, except: [:new, :edit] do
        patch "/status", FeatureController, :update_status
        get "/by_priority", FeatureController, :by_priority
      end
    end
    ```

    ### Frontend Components

    ```typescript
    interface Feature {
      id: string;
      name: string;
      description?: string;
      status: 'planned' | 'in_progress' | 'completed';
      priority: number;
      createdAt: string;
      updatedAt: string;
    }

    const FeatureCard: React.FC<{ feature: Feature }> = ({ feature }) => {
      return (
        <div className="feature-card">
          <h3>{feature.name}</h3>
          <p>{feature.description}</p>
          <div className="feature-meta">
            <span className={`status ${feature.status}`}>
              {feature.status}
            </span>
            <span className="priority">
              Priority: {feature.priority}
            </span>
          </div>
        </div>
      );
    };
    ```

    ## Risk Assessment

    ### High Priority Risks
    1. **Technical complexity** - New architecture may require significant refactoring
    2. **Timeline pressure** - Aggressive schedule with limited resources
    3. **Third-party dependencies** - External API reliability concerns

    ### Mitigation Strategies
    - Prototype complex features early
    - Build buffer time into schedule
    - Implement fallback mechanisms for external dependencies

    ## Success Metrics

    | Metric | Target | Measurement |
    |--------|--------|-------------|
    | User adoption | 75% | Weekly active users |
    | Performance | <2s load time | Lighthouse scores |
    | Quality | <5% bug rate | Issue tracking |

    ## Team Assignments

    - **Frontend Team**: UI/UX implementation
    - **Backend Team**: API and database work
    - **QA Team**: Testing and validation
    - **DevOps Team**: Deployment and monitoring

    ---

    **Document Status**: Draft  
    **Last Updated**: #{Date.utc_today()}  
    **Next Review**: #{Date.add(Date.utc_today(), 7)}
    """
  end

  @doc """
  Create a complete workspace setup with documents and notebooks.
  """
  def complete_workspace_fixture(attrs \\ %{}) do
    user = attrs[:user] || user_fixture()
    workspace = workspace_fixture(user: user, name: "Complete Test Workspace")

    # Create documents with different types of content
    ml_doc =
      document_with_content_fixture(
        user: user,
        workspace: workspace,
        title: "Machine Learning Notebook",
        content: sample_markdown_content()
      )

    design_doc =
      document_with_content_fixture(
        user: user,
        workspace: workspace,
        title: "Design System",
        content: sample_design_content()
      )

    project_doc =
      document_with_content_fixture(
        user: user,
        workspace: workspace,
        title: "Project Plan",
        content: sample_project_content()
      )

    # Create notebooks from documents
    {:ok, ml_notebook} = Workspaces.create_from_document(ml_doc.id, actor: user)
    {:ok, design_notebook} = Workspaces.create_from_document(design_doc.id, actor: user)
    {:ok, project_notebook} = Workspaces.create_from_document(project_doc.id, actor: user)

    %{
      user: user,
      workspace: workspace,
      documents: [ml_doc, design_doc, project_doc],
      notebooks: [ml_notebook, design_notebook, project_notebook]
    }
  end

  @doc """
  Generate binary blob content for testing.
  """
  def binary_blob_fixture(attrs \\ %{}) do
    # Create some binary data (simulating an image or file)
    # 1KB of random data
    binary_content = :crypto.strong_rand_bytes(1024)

    base_attrs = %{
      content: binary_content,
      content_type: "application/octet-stream"
    }

    attrs_merged = Map.merge(base_attrs, Enum.into(attrs, %{}))
    blob_fixture(attrs_merged)
  end

  @doc """
  Generate JSON blob for testing.
  """
  def json_blob_fixture(attrs \\ %{}) do
    json_data = %{
      "name" => "Test Data",
      "version" => "1.0.0",
      "features" => ["feature1", "feature2"],
      "metadata" => %{
        "created_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
        "author" => "test-user"
      }
    }

    content = Jason.encode!(json_data, pretty: true)

    base_attrs = %{
      content: content,
      content_type: "application/json"
    }

    attrs_merged = Map.merge(base_attrs, Enum.into(attrs, %{}))
    blob_fixture(attrs_merged)
  end
end
