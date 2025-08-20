defmodule KyozoWeb.Router do
  use KyozoWeb, :router

  import KyozoWeb.UserAuth
  alias Kyozo.JSONAPI

  use AshAuthentication.Phoenix.Router

  import AshAuthentication.Plug.Helpers

  pipeline :mcp do
    # Temporarily disabled for testing - re-enable authentication later
    # plug AshAuthentication.Strategy.ApiKey.Plug,
    #   resource: Kyozo.Accounts.User,
    #   required?: true
  end

  pipeline :graphql do
    plug :load_from_bearer
    plug :set_actor, :user
    plug AshGraphql.Plug
  end

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

  pipeline :openapi do
    plug OpenApiSpex.Plug.PutApiSpec, module: KyozoWeb.APISpec
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :load_from_bearer
    plug :set_actor, :user
    plug JSONAPI.ContentTypeNegotiation
    plug JSONAPI.FormatRequired
    plug JSONAPI.ResponseContentType
    plug JSONAPI.Deserializer
    plug JSONAPI.UnderscoreParameters

    plug AshAuthentication.Strategy.ApiKey.Plug,
      resource: Kyozo.Accounts.User,
      # if you want to require an api key to be supplied, set `required?` to true
      required?: false
  end

  pipeline :api_authenticated do
    plug :accepts, ["json"]
    plug :load_from_bearer
    plug :set_actor, :user
    plug KyozoWeb.Plugs.TenantAuth, :load_api_tenant
    plug JSONAPI.ContentTypeNegotiation
    plug JSONAPI.FormatRequired
    plug JSONAPI.ResponseContentType
    plug JSONAPI.Deserializer
    plug JSONAPI.UnderscoreParameters
  end

  scope "/gql" do
    pipe_through [:graphql]

    forward "/playground", Absinthe.Plug.GraphiQL,
      schema: Module.concat(["KyozoWeb.GraphqlSchema"]),
      socket: Module.concat(["KyozoWeb.GraphqlSocket"]),
      interface: :simple

    forward "/", Absinthe.Plug, schema: Module.concat(["KyozoWeb.GraphqlSchema"])
  end

  scope "/" do
    pipe_through [:openapi]

    get "/api", OpenApiSpex.Plug.RenderSpec, []
    get "/openapi", OpenApiSpex.Plug.SwaggerUI, path: "/api"
  end

  scope "/api/json" do
    pipe_through [:api]

    forward "/swaggerui", OpenApiSpex.Plug.SwaggerUI,
      path: "/api/json/open_api",
      default_model_expand_depth: 4

    forward "/", KyozoWeb.AshJsonApiRouter
  end

  scope "/api/v1", KyozoWeb.API do
    pipe_through :api_authenticated

    # Teams API (authentication required, but no specific tenant)
    resources "/teams", TeamsController, except: [:new, :edit] do
      get "/members", TeamsController, :members
      post "/members", TeamsController, :invite_member
      delete "/members/:member_id", TeamsController, :remove_member
      patch "/members/:member_id/role", TeamsController, :update_member_role

      get "/invitations", TeamsController, :invitations
      post "/invitations/:invitation_id/accept", TeamsController, :accept_invitation
      post "/invitations/:invitation_id/decline", TeamsController, :decline_invitation
      delete "/invitations/:invitation_id", TeamsController, :cancel_invitation

      # get "/workspaces", TeamsController, :workspaces
    end
  end

  scope "/api/v1/teams/:team_id", KyozoWeb.API do
    pipe_through :api_authenticated

    # Workspaces API (team-scoped)
    resources "/workspaces", WorkspacesController, except: [:new, :edit] do
      post "/archive", WorkspacesController, :archive
      post "/restore", WorkspacesController, :restore
      post "/duplicate", WorkspacesController, :duplicate
      get "/statistics", WorkspacesController, :statistics
      get "/storage", WorkspacesController, :storage_info
      patch "/storage", WorkspacesController, :change_storage_backend

      get "/files", WorkspacesController, :files
      get "/notebooks", WorkspacesController, :notebooks
    end

    # Documents API (team-scoped)
    resources "/files", FileController, except: [:new, :edit] do
      post "/workspaces/:workspace_id/files/upload", FileController, :upload
      post "/duplicate", FileController, :duplicate
      get "/content", FileController, :content
      patch "/content", FileController, :update_content
      get "/versions", FileController, :versions
      post "/render", FileController, :render_as
      patch "/rename", FileController, :rename
      post "/view", FileController, :view
    end

    # Notebooks API (team-scoped)
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

    post "/files/:file_id/notebooks", NotebooksController, :create_from_file
    get "/workspaces/:workspace_id/tasks", NotebooksController, :workspace_tasks
  end

  scope "/", KyozoWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    ash_authentication_live_session :authentication_optional,
      on_mount: {KyozoWeb.LiveUserAuth, :live_user_optional} do
      live "/", Live.Landing, :index
      live "/editor", Live.Editor
      live "/auth/test", Live.AuthTestLive

      # Authentication routes
      live "/auth/sign_in", Live.Auth.SignInLive
      live "/auth/register", Live.Auth.RegisterLive
    end

    # get "/register", UserRegistrationController, :new
    # post "/register", UserRegistrationController, :create
    get "/login", UserSessionController, :new
    post "/login", UserSessionController, :create
    get "/confirm-new-user/:token", UserConfirmationController, :edit
    put "/confirm-new-user/:token", UserConfirmationController, :update
    get "/confirm-new-user", UserConfirmationController, :new
    post "/confirm-new-user", UserConfirmationController, :create
  end

  scope "/", KyozoWeb do
    pipe_through :browser

    ash_authentication_live_session :authenticated_routes,
      on_mount: {KyozoWeb.LiveUserAuth, :live_user_required} do
      live "/account", AccountLive
      live "/home", Live.Home

      scope "/accounts/groups", Accounts.Groups do
        live "/", GroupsLive
        live "/:group_id/permissions", GroupPermissionsLive
      end

      # Native Svelte 5 routes - these will serve the Svelte app
      scope "/workspaces" do
        live "/", Live.Workspace.Index, :index
        live "/new", Live.Workspace.Index, :new
        live "/:id", Live.Workspace.Index, :show
        live "/:id/dashboard", Live.Workspace.Index, :show

        # scope "/:id/files" do
        #   live "/", Live.Workspace.Files.Index, :index
        #   live "/:id", Live.Workspace.Files.Index, :show
        #   live "/new", Live.Workspace.Files.Index, :new
        #   live "/media", Live.Workspace.Files.Index, :media
        #   live "/links", Live.Workspace.Files.Index, :links
        #   live "/:id/dashboard", Live.Workspace.Files.Index, :show
        # end
      end

      # Teams routes - LiveView to establish socket connection for Svelte
      live "/teams", Live.Teams.Index, :index
      live "/teams/:id", Live.Teams.Index, :show

      # Team dashboard routes
      live "/team/dashboard", Live.Team.Dashboard, :dashboard
      live "/team/dashboard/svelte", Live.Team.DashboardSvelte, :dashboard

      # # Document editor routes
      # live "/documents/:id/edit", Live.Document.Editor, :edit

      # # Notebook editor routes
      # live "/notebooks/:id/edit", Live.Notebook.Editor, :edit
    end
  end

  scope "/auth", KyozoWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    # OAuth2 routes handled by AshAuthentication
    # get "/:provider", OAuth2Controller, :request
    # get "/:provider/callback", OAuth2Controller, :callback
  end

  scope "/", KyozoWeb do
    pipe_through [:browser, :require_authenticated_user]

    get "/portal", PortalController, :index
    get "/teams/new", WorkspaceController, :new
    post "/teams", WorkspaceController, :create
    post "/enter-workspace", WorkspaceController, :enter
    delete "/decline-invitation", WorkspaceController, :decline_invitation
    post "/accept-invitation", WorkspaceController, :accept_invitation

    # Set current team for workspace access
    post "/set-team/:team_id", WorkspaceController, :set_current_team
  end

  # scope "/workspace", NotedWeb do
  #   pipe_through [
  #     :browser,
  #     :require_authenticated_user,
  #     :ensure_tenant,
  #     :load_user_membership_data,
  #     :set_permissions
  #   ]

  #   get "/", WorkspaceController, :show
  #   get "/search-users", WorkspaceController, :search_users
  #   post "/invite-user", WorkspaceController, :invite_user
  #   put "/change-member-role", WorkspaceController, :change_role
  #   delete "/cancel-invitation", WorkspaceController, :cancel_invitation
  #   delete "/remove-team-member", WorkspaceController, :remove_team_member
  #   delete "/leave-team", WorkspaceController, :leave_team
  #   delete "/delete-team", WorkspaceController, :delete_team
  #   resources "/notes", NotesController, except: [:index, :show]
  # end

  scope "/mcp" do
    pipe_through :mcp

    forward "/", AshAi.Mcp.Router,
      tools: [
        # Basic Ash tools for interacting with resources
        :read_ash_resource,
        :create_ash_resource,
        :update_ash_resource,
        :list_ash_resources,
        # File system tools
        :read_file,
        :write_file,
        :list_directory
      ],
      protocol_version_statement: "2024-11-05",
      otp_app: :kyozo
  end

  scope "/", KyozoWeb do
    pipe_through :browser

    auth_routes AuthController, Kyozo.Accounts.User, path: "/auth"
    sign_out_route AuthController

    # Remove these if you'd like to use your own authentication views
    sign_in_route register_path: "/register",
                  reset_path: "/reset",
                  auth_routes_prefix: "/auth",
                  on_mount: [{KyozoWeb.LiveUserAuth, :live_no_user}],
                  overrides: [KyozoWeb.AuthOverrides, AshAuthentication.Phoenix.Overrides.Default]

    # Remove this if you do not want to use the reset password feature
    reset_route auth_routes_prefix: "/auth",
                overrides: [KyozoWeb.AuthOverrides, AshAuthentication.Phoenix.Overrides.Default]

    # Remove this if you do not use the confirmation strategy
    confirm_route Kyozo.Accounts.User, :confirm_new_user,
      auth_routes_prefix: "/auth",
      overrides: [KyozoWeb.AuthOverrides, AshAuthentication.Phoenix.Overrides.Default]

    # Remove this if you do not use the magic link strategy.
    magic_sign_in_route(Kyozo.Accounts.User, :magic_link,
      auth_routes_prefix: "/auth",
      overrides: [KyozoWeb.AuthOverrides, AshAuthentication.Phoenix.Overrides.Default]
    )

    # OAuth2 routes temporarily disabled for initial setup
    # oauth_sign_in_route(Kyozo.Accounts.User, :apple,
    #   auth_routes_prefix: "/auth",
    #   overrides: [KyozoWeb.AuthOverrides, AshAuthentication.Phoenix.Overrides.Default]
    # )

    # oauth_sign_in_route(Kyozo.Accounts.User, :google,
    #   auth_routes_prefix: "/auth",
    #   overrides: [KyozoWeb.AuthOverrides, AshAuthentication.Phoenix.Overrides.Default]
    # )
  end

  # Other scopes may use custom stacks.
  # scope "/api", KyozoWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:kyozo, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: KyozoWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
