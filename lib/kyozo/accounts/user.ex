defmodule Kyozo.Accounts.User do
  @derive {Jason.Encoder, only: [:id, :name, :email, :current_team, :role, :confirmed_at]}
  
  use Ash.Resource,
    otp_app: :kyozo,
    domain: Kyozo.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource, AshAuthentication, AshEvents.Events],
    notifiers: [Kyozo.Accounts.User.Notifiers.CreatePersonalTeamNotification]

  authentication do
    add_ons do
      log_out_everywhere do
        apply_on_password_change? true
      end

      confirmation :confirm_new_user do
        monitor_fields [:email]
        confirm_on_create? true
        confirm_on_update? true
        require_interaction? true
        confirmed_at_field :confirmed_at

        auto_confirm_actions [
          :reset_password_with_token,
          :seed_admin
        ]

        sender Kyozo.Accounts.User.Senders.SendNewUserConfirmationEmail
      end
    end

    tokens do
      enabled? true
      token_resource Kyozo.Accounts.Token
      signing_secret Kyozo.Secrets
      store_all_tokens? true
      require_token_presence_for_authentication? true
    end

    strategies do
      password :password do
        identity_field :email
        sign_in_tokens_enabled? true
        hash_provider AshAuthentication.BcryptProvider

        resettable do
          sender Kyozo.Accounts.User.Senders.SendPasswordResetEmail
          # these configurations will be the default in a future release
          password_reset_action_name :reset_password_with_token
          request_password_reset_action_name :request_password_reset_token
        end
      end

      oauth2 :google do
        client_id Kyozo.Secrets
        client_secret Kyozo.Secrets
        redirect_uri Kyozo.Secrets
        authorize_url "https://accounts.google.com/o/oauth2/v2/auth"
        token_url "https://oauth2.googleapis.com/token"
        user_url "https://www.googleapis.com/oauth2/v2/userinfo"
        authorization_params scope: "openid email profile"
        register_action_name :register_with_google
        sign_in_action_name :sign_in_with_google
      end

      oauth2 :github do
        client_id Kyozo.Secrets
        client_secret Kyozo.Secrets
        redirect_uri Kyozo.Secrets
        authorize_url "https://github.com/login/oauth/authorize"
        token_url "https://github.com/login/oauth/access_token"
        user_url "https://api.github.com/user"
        authorization_params scope: "user:email"
        register_action_name :register_with_github
        sign_in_action_name :sign_in_with_github
      end

      magic_link :magic_link do
        identity_field :email
        registration_enabled? true
        require_interaction? true
        sender Kyozo.Accounts.User.Senders.SendMagicLinkEmail
      end

      api_key :api_key do
        api_key_relationship :valid_api_keys
        api_key_hash_attribute :api_key_hash
      end
    end
  end

  # GraphQL configuration removed during GraphQL cleanup

  json_api do
    type "user"

    routes do
      base "/users"
      get :read
      get :current_user, route: "/me"
      index :read
      post :register_with_password
    end
  end

  postgres do
    table "users"
    repo Kyozo.Repo
  end

  events do
    # Specify your event log resource
    event_log(Kyozo.Events.Event)

    # Optionally ignore certain actions. This is mainly used for actions
    # that are kept around for supporting previous event versions, and
    # are configured as replay_overrrides in the event log (see above).
    # ignore_actions [:old_create_v1]

    # Optionally specify version numbers for actions
    current_action_versions(register_with_password: 4)
  end

  actions do
    defaults [:update]

    actions do
      read :read do
        primary? true
      end

      destroy :destroy do
        primary? true
      end

      read :current_user do
        get? true
        manual Kyozo.CurrentUserRead
      end

      update :set_current_team do
        description "Set the current team for the user"
        argument :team, :string, allow_nil?: false, sensitive?: false
        change set_attribute(:current_team, arg(:team))
      end
    end

    # create :register_with_apple do
    #   argument :user_info, :map, allow_nil?: false
    #   argument :oauth_tokens, :map, allow_nil?: false, sensitive?: true
    #   upsert? true
    #   upsert_identity :unique_email

    #   change AshAuthentication.GenerateTokenChange
    #   change Kyozo.Accounts.User.Oauth2

    #   change AshAuthentication.Strategy.OAuth2.IdentityChange
    #   change fn changeset, _ ->
    #     user_info = Ash.Changeset.get_argument(changeset, :user_info)

    #     Ash.Changeset.change_attributes(
    #       changeset,
    #       Map.take(user_info, ["email", "name", "picture"])
    #     )
    #   end
    #   upsert_fields []
    #   change set_attribute(:confirmed_at, &DateTime.utc_now/0)
    # end

    # create :register_with_google do
    #   argument :user_info, :map, allow_nil?: false
    #   argument :oauth_tokens, :map, allow_nil?: false
    #   upsert? true
    #   upsert_identity :unique_email

    #   change AshAuthentication.GenerateTokenChange

    #   change fn changeset, _ ->
    #     user_info = Ash.Changeset.get_argument(changeset, :user_info)

    #     Ash.Changeset.change_attributes(
    #       changeset,
    #       Map.take(user_info, ["email", "name", "picture"])
    #     )
    #   end
    # end

    # update :set_role do
    #   accept [:role]
    # end

    read :get_by_subject do
      description "Get a user by the subject claim in a JWT"
      argument :subject, :string, allow_nil?: false
      get? true
      prepare AshAuthentication.Preparations.FilterBySubject
    end

    update :change_password do
      # Use this action to allow users to change their password by providing
      # their current password and a new password.

      require_atomic? false
      accept []
      argument :current_password, :string, sensitive?: true, allow_nil?: false

      argument :password, :string,
        sensitive?: true,
        allow_nil?: false,
        constraints: [min_length: 8]

      argument :password_confirmation, :string, sensitive?: true, allow_nil?: false

      validate confirm(:password, :password_confirmation)

      validate {AshAuthentication.Strategy.Password.PasswordValidation,
                strategy_name: :password, password_argument: :current_password}

      change {AshAuthentication.Strategy.Password.HashPasswordChange, strategy_name: :password}
    end

    read :sign_in_with_password do
      description "Attempt to sign in using a email and password."
      get? true

      argument :email, :ci_string do
        description "The email to use for retrieving the user."
        allow_nil? false
      end

      argument :password, :string do
        description "The password to check for the matching user."
        allow_nil? false
        sensitive? true
      end

      # validates the provided email and password and generates a token
      prepare AshAuthentication.Strategy.Password.SignInPreparation

      metadata :token, :string do
        description "A JWT that can be used to authenticate the user."
        allow_nil? false
      end
    end

    read :sign_in_with_token do
      # In the generated sign in components, we validate the
      # email and password directly in the LiveView
      # and generate a short-lived token that can be used to sign in over
      # a standard controller action, exchanging it for a standard token.
      # This action performs that exchange. If you do not use the generated
      # liveviews, you may remove this action, and set
      # `sign_in_tokens_enabled? false` in the password strategy.

      description "Attempt to sign in using a short-lived sign in token."
      get? true

      argument :token, :string do
        description "The short-lived sign in token."
        allow_nil? false
        sensitive? true
      end

      # validates the provided sign in token and generates a token
      prepare AshAuthentication.Strategy.Password.SignInWithTokenPreparation

      metadata :token, :string do
        description "A JWT that can be used to authenticate the user."
        allow_nil? false
      end
    end

    create :seed_admin do
      description "Create an admin user for seeding purposes (bypasses confirmation)"

      argument :name, :string do
        allow_nil? false
        constraints min_length: 2, max_length: 100
      end

      argument :email, :ci_string do
        allow_nil? false
      end

      argument :password, :string do
        description "The proposed password for the user, in plain text."
        allow_nil? false
        constraints min_length: 5
        sensitive? true
      end

      # Sets the name from the argument
      change set_attribute(:name, arg(:name))
      # Sets the email from the argument
      change set_attribute(:email, arg(:email))
      # Hashes the provided password
      change AshAuthentication.Strategy.Password.HashPasswordChange
      # Generates an authentication token for the user
      change AshAuthentication.GenerateTokenChange
      change set_context(%{strategy_name: :password})
      # Confirm the user immediately without email
      change set_attribute(:confirmed_at, &DateTime.utc_now/0)
    end

    create :register_with_password do
      description "Register a new user with a email and password."

      argument :name, :string do
        allow_nil? false
        constraints min_length: 2, max_length: 100
      end

      argument :email, :ci_string do
        allow_nil? false
      end

      argument :password, :string do
        description "The proposed password for the user, in plain text."
        allow_nil? false
        constraints min_length: 5
        sensitive? true
      end

      argument :password_confirmation, :string do
        description "The proposed password for the user (again), in plain text."
        allow_nil? false
        sensitive? true
      end

      # Sets the name from the argument
      change set_attribute(:name, arg(:name))
      # Sets the email from the argument
      change set_attribute(:email, arg(:email))

      # Hashes the provided password
      change AshAuthentication.Strategy.Password.HashPasswordChange

      # Generates an authentication token for the user
      change AshAuthentication.GenerateTokenChange

      # <- add this line

      change set_context(%{strategy_name: :password})

      # validates that the password matches the confirmation
      validate AshAuthentication.Strategy.Password.PasswordConfirmationValidation

      metadata :token, :string do
        description "A JWT that can be used to authenticate the user."
        allow_nil? false
      end
    end

    create :register_with_google do
      description "Register a new user with Google OAuth2."
      upsert? true
      upsert_identity :email

      argument :user_info, :map do
        allow_nil? false
      end

      argument :oauth_tokens, :map do
        allow_nil? false
      end

      change fn changeset, %{arguments: %{user_info: user_info}} ->
        email = Map.get(user_info, "email") || Map.get(user_info, :email)
        name = Map.get(user_info, "name") || Map.get(user_info, :name) || email

        changeset
        |> Ash.Changeset.change_attribute(:email, email)
        |> Ash.Changeset.change_attribute(:name, name)
        |> Ash.Changeset.change_attribute(:confirmed_at, DateTime.utc_now())
      end

      change AshAuthentication.GenerateTokenChange

      metadata :token, :string do
        description "A JWT that can be used to authenticate the user."
        allow_nil? false
      end
    end

    create :register_with_github do
      description "Register a new user with GitHub OAuth2."
      upsert? true
      upsert_identity :email

      argument :user_info, :map do
        allow_nil? false
      end

      argument :oauth_tokens, :map do
        allow_nil? false
      end

      change fn changeset, %{arguments: %{user_info: user_info}} ->
        email = Map.get(user_info, "email") || Map.get(user_info, :email)

        name =
          Map.get(user_info, "name") || Map.get(user_info, :name) ||
            Map.get(user_info, "login") || Map.get(user_info, :login) || email

        changeset
        |> Ash.Changeset.change_attribute(:email, email)
        |> Ash.Changeset.change_attribute(:name, name)
        |> Ash.Changeset.change_attribute(:confirmed_at, DateTime.utc_now())
      end

      change AshAuthentication.GenerateTokenChange

      metadata :token, :string do
        description "A JWT that can be used to authenticate the user."
        allow_nil? false
      end
    end

    read :sign_in_with_google do
      description "Sign in an existing user with Google OAuth2."
      get? true

      argument :user_info, :map do
        allow_nil? false
      end

      argument :oauth_tokens, :map do
        allow_nil? false
      end

      argument :email, :string do
        allow_nil? false
      end

      filter expr(email == ^arg(:email))

      prepare fn query, %{arguments: %{user_info: user_info}} ->
        email = Map.get(user_info, "email") || Map.get(user_info, :email)
        Ash.Query.set_argument(query, :email, email)
      end

      metadata :token, :string do
        description "A JWT that can be used to authenticate the user."
        allow_nil? false
      end
    end

    read :sign_in_with_github do
      description "Sign in an existing user with GitHub OAuth2."
      get? true

      argument :user_info, :map do
        allow_nil? false
      end

      argument :oauth_tokens, :map do
        allow_nil? false
      end

      argument :email, :string do
        allow_nil? false
      end

      filter expr(email == ^arg(:email))

      prepare fn query, %{arguments: %{user_info: user_info}} ->
        email = Map.get(user_info, "email") || Map.get(user_info, :email)
        Ash.Query.set_argument(query, :email, email)
      end

      metadata :token, :string do
        description "A JWT that can be used to authenticate the user."
        allow_nil? false
      end
    end

    action :request_password_reset_token do
      description "Send password reset instructions to a user if they exist."

      argument :email, :ci_string do
        allow_nil? false
      end

      # creates a reset token and invokes the relevant senders
      run {AshAuthentication.Strategy.Password.RequestPasswordReset, action: :get_by_email}
    end

    read :get_by_email do
      description "Looks up a user by their email"
      get? true

      argument :email, :ci_string do
        allow_nil? false
      end

      filter expr(email == ^arg(:email))
    end

    update :reset_password_with_token do
      argument :reset_token, :string do
        allow_nil? false
        sensitive? true
      end

      argument :password, :string do
        description "The proposed password for the user, in plain text."
        allow_nil? false
        constraints min_length: 6
        sensitive? true
      end

      argument :password_confirmation, :string do
        description "The proposed password for the user (again), in plain text."
        allow_nil? false
        sensitive? true
      end

      # validates the provided reset token
      validate AshAuthentication.Strategy.Password.ResetTokenValidation

      # validates that the password matches the confirmation
      validate AshAuthentication.Strategy.Password.PasswordConfirmationValidation

      # Hashes the provided password
      change AshAuthentication.Strategy.Password.HashPasswordChange

      # Generates an authentication token for the user
      change AshAuthentication.GenerateTokenChange
    end

    read :search_users do
      argument :search, :string, default: ""

      filter expr(
               contains(
                 string_downcase(name),
                 string_downcase(^arg(:search))
               ) and
                 id != ^actor(:id)
             )

      prepare build(load: :membership_status)
      prepare build(limit: 5)
    end

    # create :sign_in_with_magic_link do
    #   description "Sign in or register a user with magic link."

    #   argument :token, :string do
    #     description "The token from the magic link that was sent to the user"
    #     allow_nil? false
    #   end

    #   upsert? true
    #   upsert_identity :unique_email
    #   upsert_fields [:email, :confirmed_at]

    #   # Uses the information from the token to create or sign in the user
    #   change AshAuthentication.Strategy.MagicLink.SignInChange

    #   metadata :token, :string do
    #     allow_nil? false
    #   end
    # end

    # action :request_magic_link do
    #   argument :email, :ci_string do
    #     allow_nil? false
    #   end

    #   run AshAuthentication.Strategy.MagicLink.Request
    # end

    # OAuth2 actions temporarily disabled for initial setup

    read :sign_in_with_api_key do
      argument :api_key, :string, allow_nil?: false
      prepare AshAuthentication.Strategy.ApiKey.SignInPreparation
    end

    # read :sign_in_with_apple do
    #   argument :user_info, :map, allow_nil?: false
    #   argument :oauth_tokens, :map, allow_nil?: false
    #   prepare AshAuthentication.Strategy.OAuth2.SignInPreparation

    #   filter expr(email == get_path(^arg(:user_info), [:email]))
    # end
  end

  policies do
    bypass AshAuthentication.Checks.AshAuthenticationInteraction do
      authorize_if always()
    end

    # policy action_type(:read) do
    #   access_type :filter # This is the default access type. It is here for example.
    #   authorize_if expr(active == false)
    # end

    policy action_type(:read) do
      authorize_if relates_to_actor_via([:teams, :users])
      authorize_if actor_attribute_equals(:role, "admin")
    end

    policy action(:read) do
      # This doesn’t work because the actor is not set.
      authorize_if actor_present()
      # The policy will return `:authorized` only here when `:read` is called
      # through the API, because apparently AshAuthentication failed to set the actor.
      # authorize_if always()
    end

    policy action(:sign_in_with_password) do
      authorize_if always()
    end

    policy action_type(:create) do
      description "Anyone can create a tweet"
      authorize_if always()
    end

    policy action_type(:update) do
      description "Only an admin or the user who tweeted can edit their tweet"
      # first check this. If true, then this policy passes
      authorize_if actor_attribute_equals(:admin?, true)
      # then check this. If true, then this policy passes
      authorize_if relates_to_actor_via(:user)
      # otherwise, there is nothing left to check and no decision, so *this policy fails*
    end

    policy always() do
      forbid_if always()
    end
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
      constraints min_length: 2, max_length: 100
    end

    attribute :email, :ci_string do
      allow_nil? false
      public? true
    end

    attribute :current_team, :string do
      description "The current team the user is accessing the app with"
    end

    attribute :hashed_password, :string do
      allow_nil? true
      sensitive? true
      public? false
    end

    attribute :picture, :string do
      public? true
    end

    attribute :confirmed_at, :utc_datetime_usec
  end

  relationships do
    many_to_many :teams, Kyozo.Accounts.Team do
      through Kyozo.Accounts.UserTeam
      source_attribute_on_join_resource :user_id
      destination_attribute_on_join_resource :team_id
    end

    many_to_many :groups, Kyozo.Accounts.Group do
      through Kyozo.Accounts.UserGroup
      source_attribute_on_join_resource :user_id
      destination_attribute_on_join_resource :group_id
    end

    has_many :valid_api_keys, Kyozo.Accounts.ApiKey do
      filter expr(valid)
    end

    # many_to_many :workspaces, Kyozo.Workspace.Workspacedo
    #   through Noted.Workspace.TeamMember
    #   source_attribute_on_join_resource :user_id
    #    destination_attribute_on_join_resource :workspace_id
    #   join_relationship :team_membership
    # end

    has_many :invitations, Kyozo.Accounts.Invitation do
      destination_attribute :invited_user_id
    end
  end

  calculations do
    calculate :role, :string, expr(team_membership.role)
    calculate :membership_id, :string, expr(team_membership.id)

    calculate :membership_status,
              :string,
              expr(
                cond do
                  not is_nil(role) -> "#{role}"
                  not is_nil(invitations.invited_user_id) -> "invited"
                  true -> nil
                end
              )
  end

  identities do
    identity :unique_email, [:email]
  end

  # OAuth2 functions temporarily disabled for initial setup
end
