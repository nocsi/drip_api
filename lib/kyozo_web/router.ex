defmodule KyozoWeb.Router do
  use KyozoWeb, :router

  import KyozoWeb.UserAuth
  use AshAuthentication.Phoenix.Router
  import AshAuthentication.Plug.Helpers

  # ===============================
  # PIPELINES
  # ===============================

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {KyozoWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :load_from_session
    plug :fetch_current_user
    plug :put_user_token
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :load_from_bearer
    plug :set_actor, :user

    plug AshAuthentication.Strategy.ApiKey.Plug,
      resource: Kyozo.Accounts.User,
      required?: false
  end

  pipeline :api_authenticated do
    plug :accepts, ["json"]
    plug :load_from_bearer
    plug :set_actor, :user
    plug KyozoWeb.Plugs.TenantAuth, :load_api_tenant
  end

  pipeline :webhook do
    plug KyozoWeb.Plugs.WebhookBodyReader
    plug :accepts, ["json"]
    plug KyozoWeb.Plugs.RawBody
  end

  pipeline :openapi do
    plug OpenApiSpex.Plug.PutApiSpec, module: KyozoWeb.APISpec
  end

  # ===============================
  # API DOCUMENTATION
  # ===============================

  scope "/" do
    pipe_through [:openapi]

    get "/api", OpenApiSpex.Plug.RenderSpec, []
    get "/openapi", OpenApiSpex.Plug.SwaggerUI, path: "/api"
  end

  # ===============================
  # WEBHOOKS (No Authentication)
  # ===============================

  scope "/webhooks" do
    pipe_through :webhook

    post "/stripe", KyozoWeb.Webhooks.StripeController, :webhook
    post "/apple", KyozoWeb.API.BillingController, :apple_webhook
  end

  # ===============================
  # PUBLIC API (v1)
  # ===============================

  scope "/api/v1", KyozoWeb.API do
    pipe_through :api

    # API Documentation
    get "/openapi.json", DocsController, :openapi
    get "/docs", DocsController, :swagger_ui

    # AI Services (with API key authentication)
    post "/ai/suggest", AIController, :suggest
    post "/ai/confidence", AIController, :confidence

    # Markdown Intelligence Services
    # PromptSpect security scanning
    post "/markdown/scan", MarkdownController, :scan
    # Impromptu prompt enhancement  
    post "/markdown/rally", MarkdownController, :rally
    # Polyglot translations
    post "/markdown/polyglot", MarkdownController, :polyglot

    # SafeMD Security Scanning (public with API key)
    post "/scan", ScanController, :scan
    post "/scan/async", ScanController, :async_scan
    get "/scan/async/:job_id", ScanController, :async_scan_result

    # SafeMD Billing (public)
    get "/safemd/pricing", SafeMDController, :pricing
    post "/safemd/checkout", SafeMDController, :create_checkout_session
    get "/safemd/checkout/success", SafeMDController, :checkout_success
    get "/safemd/checkout/cancel", SafeMDController, :checkout_cancel
  end

  # ===============================
  # AUTHENTICATED API (v1)
  # ===============================

  scope "/api/v1", KyozoWeb.API do
    pipe_through :api_authenticated

    # User Billing & Subscriptions
    get "/billing/subscription", BillingController, :get_subscription_status
    post "/billing/apple/validate", BillingController, :validate_apple_receipt
    get "/safemd/subscription", SafeMDController, :subscription_status
    post "/safemd/subscription/cancel", SafeMDController, :cancel_subscription
    post "/safemd/subscription/reactivate", SafeMDController, :reactivate_subscription

    # Teams Management
    resources "/teams", TeamsController, except: [:new, :edit] do
      # Team Members
      get "/members", TeamsController, :members
      post "/members", TeamsController, :invite_member
      delete "/members/:member_id", TeamsController, :remove_member
      patch "/members/:member_id/role", TeamsController, :update_member_role

      # Team Invitations
      get "/invitations", TeamsController, :invitations
      post "/invitations/:invitation_id/accept", TeamsController, :accept_invitation
      post "/invitations/:invitation_id/decline", TeamsController, :decline_invitation
      delete "/invitations/:invitation_id", TeamsController, :cancel_invitation
    end
  end

  # ===============================
  # TEAM-SCOPED API (v1)
  # ===============================

  scope "/api/v1/teams/:team_id", KyozoWeb.API do
    pipe_through :api_authenticated

    # Workspaces
    resources "/workspaces", WorkspacesController, except: [:new, :edit] do
      post "/archive", WorkspacesController, :archive
      post "/restore", WorkspacesController, :restore
      post "/duplicate", WorkspacesController, :duplicate
      get "/statistics", WorkspacesController, :statistics
      get "/storage", WorkspacesController, :storage_info
      patch "/storage", WorkspacesController, :change_storage_backend
      get "/files", WorkspacesController, :files
      get "/notebooks", WorkspacesController, :notebooks

      # Container Services
      get "/services", WorkspacesController, :list_services
      post "/services", WorkspacesController, :deploy_service
      post "/analyze", WorkspacesController, :analyze_topology
    end

    # Files Management
    resources "/files", FilesController, except: [:new, :edit] do
      post "/duplicate", FilesController, :duplicate
      get "/content", FilesController, :content
      patch "/content", FilesController, :update_content
      get "/versions", FilesController, :versions
      post "/render", FilesController, :render_as
      patch "/rename", FilesController, :rename
      post "/view", FilesController, :view
    end

    # File Upload (separate endpoint for multipart)
    post "/workspaces/:workspace_id/files/upload", FilesController, :upload

    # Virtual File System
    scope "/workspaces/:workspace_id/storage" do
      get "/vfs", Storage.VFSController, :index
      get "/vfs/content", Storage.VFSController, :show
      post "/vfs/share", Storage.VFSAdvancedController, :create_share
      get "/vfs/export", Storage.VFSAdvancedController, :export
      post "/vfs/templates", Storage.VFSAdvancedController, :register_template
    end

    # Notebooks (Markdown as Notebooks)
    resources "/notebooks", NotebooksController, except: [:new, :edit, :create] do
      post "/duplicate", NotebooksController, :duplicate
      post "/execute", NotebooksController, :execute
      post "/execute/:task_id", NotebooksController, :execute_task
      post "/stop", NotebooksController, :stop_execution
      post "/reset", NotebooksController, :reset_execution
      post "/collaborate", NotebooksController, :toggle_collaborative_mode
      post "/access", NotebooksController, :update_access_time
      get "/tasks", NotebooksController, :tasks
    end

    # Notebook Creation from Files
    post "/files/:file_id/notebooks", NotebooksController, :create_from_file
    get "/workspaces/:workspace_id/tasks", NotebooksController, :workspace_tasks

    # Container Services Management
    resources "/services", ServicesController, except: [:new, :edit] do
      get "/status", ServicesController, :status
      post "/start", ServicesController, :start
      post "/stop", ServicesController, :stop
      post "/restart", ServicesController, :restart
      post "/scale", ServicesController, :scale
      get "/logs", ServicesController, :logs
      get "/metrics", ServicesController, :metrics
      get "/health", ServicesController, :health_check
    end
  end

  # ===============================
  # PUBLIC WEB ROUTES
  # ===============================

  scope "/", KyozoWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    ash_authentication_live_session :authentication_optional,
      on_mount: {KyozoWeb.LiveUserAuth, :live_user_optional} do
      # Landing Pages
      live "/", Live.Landing, :index
      live "/safemd", Live.SafeMDLanding, :index
      live "/safemd/demo", Live.SafeMDDemo, :demo

      # Tools
      live "/editor", Live.Editor

      # Authentication Pages
      live "/auth/sign_in", Live.Auth.SignInLive
      live "/auth/register", Live.Auth.RegisterLive
      live "/auth/test", Live.AuthTestLive
    end

    # User Confirmation (non-LiveView)
    get "/confirm-new-user/:token", UserConfirmationController, :edit
    put "/confirm-new-user/:token", UserConfirmationController, :update
    get "/confirm-new-user", UserConfirmationController, :new
    post "/confirm-new-user", UserConfirmationController, :create
  end

  # ===============================
  # AUTHENTICATED WEB ROUTES
  # ===============================

  scope "/", KyozoWeb do
    pipe_through :browser

    ash_authentication_live_session :authenticated_routes,
      on_mount: {KyozoWeb.LiveUserAuth, :live_user_required} do
      # User Account
      live "/account", AccountLive
      live "/home", Live.Home

      # Account Groups
      scope "/accounts/groups", Accounts.Groups do
        live "/", GroupsLive
        live "/:group_id/permissions", GroupPermissionsLive
      end

      # Workspaces
      scope "/workspaces" do
        live "/", Live.Workspace.Index, :index
        live "/new", Live.Workspace.Index, :new
        live "/:id", Live.Workspace.Index, :show
        live "/:id/dashboard", Live.Workspace.Index, :show
      end

      # Teams
      live "/teams", Live.Teams.Index, :index
      live "/teams/:id", Live.Teams.Index, :show

      # Team Dashboard
      live "/team/dashboard", Live.Team.Dashboard, :dashboard
      live "/team/dashboard/svelte", Live.Team.DashboardSvelte, :dashboard

      # Container Management
      live "/containers", Live.Containers.Dashboard, :index
      live "/containers/workspace/:workspace_id", Live.Containers.Dashboard, :workspace
    end
  end

  # ===============================
  # AUTHENTICATED CONTROLLERS
  # ===============================

  scope "/", KyozoWeb do
    pipe_through [:browser, :require_authenticated_user]

    # Portal & Workspace Management
    get "/portal", PortalController, :index
    get "/teams/new", WorkspaceController, :new
    post "/teams", WorkspaceController, :create
    post "/enter-workspace", WorkspaceController, :enter

    # Team Management
    post "/set-team/:team_id", WorkspaceController, :set_current_team

    # Invitations
    post "/accept-invitation", WorkspaceController, :accept_invitation
    delete "/decline-invitation", WorkspaceController, :decline_invitation
  end

  # ===============================
  # SHARED VFS ROUTES
  # ===============================

  scope "/vfs", KyozoWeb.VFS do
    pipe_through :browser

    get "/shared/:id", SharedController, :show_html
    get "/shared/:id/raw", SharedController, :show
  end

  # ===============================
  # AUTHENTICATION ROUTES
  # ===============================

  scope "/", KyozoWeb do
    pipe_through :browser

    auth_routes AuthController, Kyozo.Accounts.User, path: "/auth"
    sign_out_route AuthController

    sign_in_route register_path: "/register",
                  reset_path: "/reset",
                  auth_routes_prefix: "/auth",
                  on_mount: [{KyozoWeb.LiveUserAuth, :live_no_user}],
                  overrides: [KyozoWeb.AuthOverrides, AshAuthentication.Phoenix.Overrides.Default]

    reset_route auth_routes_prefix: "/auth",
                overrides: [KyozoWeb.AuthOverrides, AshAuthentication.Phoenix.Overrides.Default]

    confirm_route Kyozo.Accounts.User, :confirm_new_user,
      auth_routes_prefix: "/auth",
      overrides: [KyozoWeb.AuthOverrides, AshAuthentication.Phoenix.Overrides.Default]

    magic_sign_in_route(Kyozo.Accounts.User, :magic_link,
      auth_routes_prefix: "/auth",
      overrides: [KyozoWeb.AuthOverrides, AshAuthentication.Phoenix.Overrides.Default]
    )
  end

  # ===============================
  # DEVELOPMENT ROUTES
  # ===============================

  if Application.compile_env(:kyozo, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: KyozoWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
