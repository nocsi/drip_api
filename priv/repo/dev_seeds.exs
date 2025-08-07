# Development Seeds
#
# This file contains seeds for development environment only.
# It creates test data and demo users for easy development.

alias Kyozo.Accounts
alias Kyozo.Workspaces

IO.puts("🌱 Seeding development data...")

# Helper function to safely create or get existing record
defp create_or_get(module, action, params, opts \\ []) do
  case module
       |> Ash.Changeset.for_action(action, params)
       |> Ash.create(opts) do
    {:ok, record} ->
      {:ok, record}
    {:error, %Ash.Error.Invalid{errors: errors}} ->
      # Check for unique constraint violations
      unique_error = Enum.find(errors, fn error ->
        case error do
          %Ash.Error.Changes.InvalidAttribute{field: field} when field in [:email, :name, :slug] -> true
          _ -> false
        end
      end)

      if unique_error do
        # Try to find existing record by unique field
        field = unique_error.field
        value = Map.get(params, field)

        case module |> Ash.Query.filter(^ref(field) == ^value) |> Ash.read() do
          {:ok, [existing]} -> {:ok, existing}
          {:ok, []} -> {:error, :not_found}
          {:ok, multiple} when length(multiple) > 1 -> {:ok, List.first(multiple)}
          {:error, error} -> {:error, error}
        end
      else
        {:error, errors}
      end

    {:error, error} -> {:error, error}
  end
end

# Create development admin user
admin_email = "admin@kyozo.dev"
admin_password = "devpassword123"

IO.puts("Creating development admin user...")
case create_or_get(Accounts.User, :register_with_password, %{
  email: admin_email,
  password: admin_password,
  password_confirmation: admin_password
}) do
  {:ok, admin_user} ->
    # Set admin role and confirm user
    admin_user = admin_user
    |> Ash.Changeset.for_action(:set_role, %{role: :admin})
    |> Ash.update!()

    admin_user
    |> Ash.Changeset.for_action(:update, %{confirmed_at: DateTime.utc_now()})
    |> Ash.update!()

    IO.puts("✅ Development admin user ready!")
    IO.puts("   Email: #{admin_email}")
    IO.puts("   Password: #{admin_password}")
    IO.puts("   Role: admin")

  {:error, error} ->
    IO.puts("❌ Failed to create development admin user:")
    IO.inspect(error)
end

# Create demo users
IO.puts("Creating demo users...")
demo_users_data = [
  %{
    email: "alice@example.com",
    password: "password123",
    password_confirmation: "password123",
    name: "Alice Developer",
    role: :user
  },
  %{
    email: "bob@example.com", 
    password: "password123",
    password_confirmation: "password123",
    name: "Bob Designer",
    role: :user
  },
  %{
    email: "charlie@example.com",
    password: "password123", 
    password_confirmation: "password123",
    name: "Charlie Manager",
    role: :user
  }
]

demo_users = Enum.map(demo_users_data, fn user_data ->
  case create_or_get(Accounts.User, :register_with_password, Map.drop(user_data, [:name, :role])) do
    {:ok, user} ->
      # Set role and confirm user
      user = user
      |> Ash.Changeset.for_action(:set_role, %{role: user_data.role})
      |> Ash.update!()

      user
      |> Ash.Changeset.for_action(:update, %{
        confirmed_at: DateTime.utc_now(),
        name: user_data.name
      })
      |> Ash.update!()

      IO.puts("✅ Demo user created: #{user_data.email}")
      user

    {:error, error} ->
      IO.puts("⚠️  Could not create demo user #{user_data.email}: #{inspect(error)}")
      nil
  end
end)
|> Enum.reject(&is_nil/1)

# Create demo teams
IO.puts("Creating demo teams...")
teams_data = [
  %{
    name: "AI Research Lab",
    slug: "ai-research",
    description: "Machine learning and AI research projects"
  },
  %{
    name: "Design Systems", 
    slug: "design-systems",
    description: "UI/UX design documentation and guidelines"
  },
  %{
    name: "Product Team",
    slug: "product-team", 
    description: "Product planning and documentation"
  }
]

teams = Enum.zip(teams_data, demo_users)
|> Enum.map(fn {team_data, owner} ->
  case create_or_get(Accounts.Team, :create, team_data) do
    {:ok, team} ->
      # Add owner as team member
      case Accounts.TeamMember
           |> Ash.Changeset.for_action(:create, %{
             user_id: owner.id,
             team_id: team.id,
             role: :owner
           })
           |> Ash.create() do
        {:ok, _} -> 
          IO.puts("✅ Team created: #{team.name} (owner: #{owner.email})")
        {:error, _} -> 
          IO.puts("⚠️  Team member relationship may already exist")
      end
      
      {team, owner}

    {:error, error} ->
      IO.puts("⚠️  Could not create team #{team_data.name}: #{inspect(error)}")
      nil
  end
end)
|> Enum.reject(&is_nil/1)

# Create demo workspaces
IO.puts("Creating demo workspaces...")
workspaces_data = [
  %{
    name: "ML Experiments",
    description: "Jupyter-style notebooks for ML experiments", 
    storage_backend: :git,
    is_public: false
  },
  %{
    name: "Design Docs",
    description: "Design system documentation and examples",
    storage_backend: :git, 
    is_public: false
  },
  %{
    name: "Product Planning",
    description: "Project plans, requirements, and specifications",
    storage_backend: :git,
    is_public: false
  }
]

workspaces = Enum.zip(workspaces_data, teams)
|> Enum.map(fn {workspace_data, {team, owner}} ->
  workspace_params = Map.put(workspace_data, :team_id, team.id)
  
  case create_or_get(Workspaces.Workspace, :create_workspace, workspace_params, actor: owner) do
    {:ok, workspace} ->
      IO.puts("✅ Workspace created: #{workspace.name}")
      {workspace, team, owner}

    {:error, error} ->
      IO.puts("⚠️  Could not create workspace #{workspace_data.name}: #{inspect(error)}")
      nil
  end
end)
|> Enum.reject(&is_nil/1)

# Create sample files with content
IO.puts("Creating sample files...")
sample_files_data = [
  # AI Research Lab files
  {
    "ML Research Notebook.md",
    "/ML Research Notebook.md",
    """
    # Machine Learning Experiment Log

    ## Data Analysis Pipeline

    This notebook demonstrates a complete machine learning workflow from data loading to model evaluation.

    ### Data Loading

    ```python
    import pandas as pd
    import numpy as np
    from sklearn.model_selection import train_test_split
    from sklearn.ensemble import RandomForestClassifier
    from sklearn.metrics import accuracy_score, classification_report

    # Load the dataset
    data = pd.read_csv('dataset.csv')
    print(f"Dataset shape: {data.shape}")
    data.head()
    ```

    ### Model Training

    ```python
    # Initialize and train the model
    rf_classifier = RandomForestClassifier(
        n_estimators=100,
        random_state=42,
        max_depth=10
    )

    rf_classifier.fit(X_train, y_train)
    y_pred = rf_classifier.predict(X_test)

    # Evaluate the model
    accuracy = accuracy_score(y_test, y_pred)
    print(f"Model Accuracy: {accuracy:.4f}")
    ```

    ## Results and Conclusions

    - Model Performance: Random Forest achieved ~85% accuracy
    - Key Features: Top 3 features account for 60% of decisions
    - Next Steps: Cross-validation and hyperparameter tuning

    ### Todo List

    - [ ] Implement cross-validation
    - [ ] Try different algorithms (SVM, XGBoost)
    - [ ] Add data visualization
    - [x] Basic model training
    - [x] Feature importance analysis
    """
  },
  # Design Systems files
  {
    "Design System Guide.md",
    "/Design System Guide.md", 
    """
    # Design System Documentation

    ## Color Palette

    Our design system uses a carefully curated color palette for accessibility and brand consistency.

    ### Primary Colors

    | Color | Hex | Usage |
    |-------|-----|-------|
    | Primary Blue | `#3B82F6` | Main actions, links |
    | Primary Dark | `#1E40AF` | Hover states |
    | Primary Light | `#DBEAFE` | Backgrounds |

    ## Typography

    ### Font Stack

    ```css
    font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
    ```

    ### Text Styles

    ```css
    .heading-1 {
      font-size: 2.25rem;
      font-weight: 700;
      line-height: 1.2;
    }

    .body-regular {
      font-size: 1rem;
      line-height: 1.5;
    }
    ```

    ## Components

    ### Button Variants

    ```html
    <button class="btn btn-primary">Primary Action</button>
    <button class="btn btn-secondary">Secondary Action</button>
    ```

    ## Accessibility Guidelines

    - All interactive elements must have focus states
    - Color contrast ratio must be at least 4.5:1
    - All images need alt text
    - Use semantic HTML elements
    """
  },
  # Product Team files
  {
    "Q4 Product Roadmap.md",
    "/Q4 Product Roadmap.md",
    """
    # Q4 2024 Product Roadmap

    ## Executive Summary

    Product development priorities for Q4 2024, focusing on user experience improvements and feature expansion.

    ## Key Objectives

    1. **Improve User Onboarding** - Reduce time to first value
    2. **Enhanced Collaboration** - Real-time editing capabilities  
    3. **Performance Optimization** - 50% faster load times
    4. **Mobile Experience** - Responsive design implementation

    ## Feature Development Timeline

    ### Week 1-2: Research & Planning
    - [ ] User interview sessions (10 participants)
    - [ ] Competitive analysis update
    - [ ] Technical architecture review
    - [x] Stakeholder alignment meeting

    ### Week 3-6: Core Development
    - [ ] Implement real-time collaboration
    - [ ] Redesign onboarding flow
    - [ ] Performance optimization (Phase 1)
    - [ ] Mobile UI components

    ## Performance Targets

    | Metric | Current | Target |
    |--------|---------|--------|
    | Page Load | 3.2s | 1.5s |
    | Time to Interactive | 4.1s | 2.0s |
    | Bundle Size | 2.1MB | 1.2MB |
    | Lighthouse Score | 72 | 90+ |

    ## Success Metrics

    ### User Engagement
    - Daily active users: +25%
    - Session duration: +40%
    - Feature adoption: >60% for new features

    ### Business Impact
    - Customer satisfaction: 4.5+ stars
    - Support tickets: -30%
    - Conversion rate: +15%

    ## Team Assignments

    | Team | Responsibility | Lead |
    |------|---------------|------|
    | Frontend | UI/UX implementation | Sarah Chen |
    | Backend | API & infrastructure | Mike Rodriguez |
    | Mobile | Responsive design | Lisa Park |
    | QA | Testing & validation | James Wilson |
    """
  }
]

# Create files in workspaces
Enum.zip(sample_files_data, workspaces)
|> Enum.each(fn {{filename, filepath, content}, {workspace, team, owner}} ->
  file_params = %{
    name: filename,
    file_path: filepath,
    content_type: "text/markdown",
    workspace_id: workspace.id,
    team_id: team.id,
    file_size: byte_size(content)
  }

  case create_or_get(Workspaces.File, :create_file, file_params, actor: owner) do
    {:ok, file} ->
      IO.puts("✅ Sample file created: #{filename} in #{workspace.name}")
    {:error, error} ->
      IO.puts("⚠️  Could not create file #{filename}: #{inspect(error)}")
  end
end)

# Create additional sample files
additional_files = [
  {"Getting Started.md", """
  # Welcome to Kyozo!

  This is your first document. Here are some things you can do:

  ## Features
  - Write in Markdown
  - Create notebooks for interactive content
  - Collaborate with your team
  - Version control with Git

  ## Quick Tips
  - Use `Ctrl+S` to save (or `Cmd+S` on Mac)
  - Press `Ctrl+/` for keyboard shortcuts
  - Click the `+` button to create new files

  Happy writing! 🚀
  """},
  {"Project Notes.md", """
  # Project Notes

  ## Ideas
  - [ ] Add real-time collaboration
  - [ ] Implement dark mode
  - [ ] Create mobile app
  - [x] Set up development environment

  ## Meeting Notes
  
  ### Weekly Standup - #{Date.utc_today()}
  - Discussed Q4 roadmap
  - Reviewed user feedback
  - Planned next sprint

  ## Resources
  - [Documentation](https://docs.kyozo.com)
  - [API Reference](https://api.kyozo.com)
  - [Community](https://community.kyozo.com)
  """}
]

# Add additional files to first workspace
if length(workspaces) > 0 do
  {first_workspace, first_team, first_owner} = List.first(workspaces)
  
  Enum.each(additional_files, fn {filename, content} ->
    file_params = %{
      name: filename,
      file_path: "/#{filename}",
      content_type: "text/markdown", 
      workspace_id: first_workspace.id,
      team_id: first_team.id,
      file_size: byte_size(content)
    }

    case create_or_get(Workspaces.File, :create_file, file_params, actor: first_owner) do
      {:ok, _file} ->
        IO.puts("✅ Additional file created: #{filename}")
      {:error, error} ->
        IO.puts("⚠️  Could not create additional file #{filename}: #{inspect(error)}")
    end
  end)
end

# Create sample blobs for testing
IO.puts("Creating sample blobs...")
sample_blobs = [
  {
    """
    {
      "project": "Kyozo API",
      "version": "1.0.0", 
      "features": ["notebooks", "collaboration", "blob-storage"],
      "metrics": {
        "users": 1000,
        "documents": 5000,
        "storage_gb": 250
      }
    }
    """,
    "application/json"
  },
  {
    """
    <!DOCTYPE html>
    <html>
    <head>
      <title>Sample HTML</title>
      <style>
        body { font-family: Arial, sans-serif; margin: 2rem; }
        .highlight { background: yellow; }
      </style>
    </head>
    <body>
      <h1>Welcome to Kyozo</h1>
      <p>This is a <span class="highlight">sample HTML document</span>
         stored as a blob.</p>
    </body>
    </html>
    """,
    "text/html"
  }
]

Enum.each(sample_blobs, fn {content, content_type} ->
  case Workspaces.create_blob(%{
    content: content,
    content_type: content_type
  }) do
    {:ok, _blob} ->
      IO.puts("✅ Sample blob created: #{content_type}")
    {:error, error} ->
      IO.puts("⚠️  Could not create blob: #{inspect(error)}")
  end
end)

# Show development summary
IO.puts("")
IO.puts("🎉 Development seeding complete!")
IO.puts("")
IO.puts("📊 Summary:")
IO.puts("   👤 Users: #{length(demo_users) + 1} (#{length(demo_users)} demo + 1 admin)")
IO.puts("   🏢 Teams: #{length(teams)}")
IO.puts("   💼 Workspaces: #{length(workspaces)}")
IO.puts("   📄 Files: #{length(sample_files_data) + length(additional_files)}")
IO.puts("   💾 Blobs: #{length(sample_blobs)}")
IO.puts("")
IO.puts("🔑 Demo Login Credentials:")
IO.puts("   📧 #{admin_email} / 🔒 #{admin_password} (admin)")

Enum.each(demo_users_data, fn user ->
  IO.puts("   📧 #{user.email} / 🔒 #{user.password}")
end)

IO.puts("")
IO.puts("🌐 Access the application at: http://localhost:4000")
IO.puts("   📝 Login at: http://localhost:4000/auth/sign_in")
IO.puts("   📊 Dashboard: http://localhost:4000/workspaces")
IO.puts("")
IO.puts("✅ Development environment ready!")