defmodule Dirup.Workspaces.Media do
  @derive {Jason.Encoder,
           only: [
             :id,
             :title,
             :description,
             :alt_text,
             :media_type,
             :original_filename,
             :file_size,
             :mime_type,
             :dimensions,
             :metadata,
             :dominant_colors,
             :accessibility_features,
             :cdn_urls,
             :processing_status,
             :team_id,
             :created_at,
             :updated_at
           ]}

  @moduledoc """
  Notebook resource representing a rendered, interactive version of markdown documents.

  Notebooks are created from Documents with .md or .markdown extensions and provide:
  - Rendered HTML content with syntax highlighting
  - Extracted executable code blocks as tasks
  - Interactive execution environment
  - Real-time collaboration features
  - Execution history and state management
  """

  use Ash.Resource,
    otp_app: :dirup,
    domain: Dirup.Workspaces,
    authorizers: [Ash.Policy.Authorizer],
    notifiers: [Ash.Notifier.PubSub],
    data_layer: AshPostgres.DataLayer,
    extensions: [AshJsonApi.Resource]

  json_api do
    type "media"

    routes do
      base "/media"
      get :read
      index :read
      post :upload
      patch :update_metadata
      delete :destroy
    end
  end

  postgres do
    table "media"
    repo Dirup.Repo

    references do
      reference :team, on_delete: :delete, index?: true
    end

    custom_indexes do
      index [:team_id, :media_type]
      index [:team_id, :created_at]
      index [:mime_type]
      index [:file_size]
      index [:processing_status]
    end
  end

  actions do
    defaults [:read, :destroy]

    default_accept [
      :title,
      :description,
      :alt_text,
      :media_type,
      :accessibility_features
    ]

    # Primary action for uploading new media
    create :upload do
      argument :file_upload, :map, allow_nil?: false
      argument :alt_text, :string
      argument :description, :string
      argument :processing_options, :map, default: %{}

      change relate_actor(:team_member, field: :membership_id)
      change {Changes.ProcessUpload, []}
      change {Changes.ExtractMetadata, []}
      change {Changes.GenerateVariants, []}

      after_action({Changes.StartAsyncProcessing, []})
    end

    # Create media from existing file
    create :from_file do
      argument :file_id, :uuid, allow_nil?: false
      argument :alt_text, :string
      argument :description, :string

      change relate_actor(:team_member, field: :membership_id)
      change {Changes.CreateFromFile, []}
      change {Changes.ExtractMetadata, []}
      change {Changes.GenerateVariants, []}

      after_action({Changes.StartAsyncProcessing, []})
    end

    update :update_metadata do
      accept [:title, :description, :alt_text, :accessibility_features]
    end

    # Regenerate variants (thumbnails, formats, etc.)
    action :regenerate_variants, :struct do
      argument :variant_types, {:array, :atom}, default: [:thumbnails, :webp, :optimized]

      run {Actions.RegenerateVariants, []}
    end

    # Get optimized URL for specific use case
    action :get_url, :string do
      argument :variant, :string, allow_nil?: false
      argument :options, :map, default: %{}

      run {Actions.GetOptimizedUrl, []}
    end

    action :analyze_accessibility, :map do
      run {Actions.AnalyzeAccessibility, []}
    end

    action :extract_text, :string do
      run {Actions.ExtractText, []}
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if relates_to_actor_via([:team, :users])
    end

    policy action_type(:create) do
      authorize_if actor_present()
      authorize_if relates_to_actor_via([:team, :users])
    end

    policy action_type(:update) do
      authorize_if relates_to_actor_via([:team_member, :user])
    end

    policy action_type(:destroy) do
      authorize_if relates_to_actor_via([:team_member, :user])
    end
  end

  pub_sub do
    module DirupWeb.Endpoint

    publish_all :create, ["media", :team_id]
    publish_all :update, ["media", :team_id]
    publish_all :destroy, ["media", :team_id]
  end

  validations do
    validate present([:title, :original_filename, :file_size, :mime_type])
    validate {Validations.ValidateMediaType, []}
    validate {Validations.ValidateFileSize, []}
    validate {Validations.ValidateAccessibilityFeatures, []}
  end

  multitenancy do
    strategy :attribute
    attribute :team_id
  end

  multitenancy do
    strategy :attribute
    attribute :team_id
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :title, :string do
      allow_nil? false
      public? true
      constraints min_length: 1, max_length: 255
    end

    attribute :description, :string do
      public? true
      constraints max_length: 1000
    end

    attribute :alt_text, :string do
      public? true
      constraints max_length: 255
      description "Alternative text for accessibility"
    end

    attribute :media_type, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:image, :video, :audio, :document]
      default :image
    end

    attribute :original_filename, :string do
      allow_nil? false
      public? true
    end

    attribute :file_size, :integer do
      allow_nil? false
      public? true
      constraints min: 0
    end

    attribute :mime_type, :string do
      allow_nil? false
      public? true
    end

    # JSON structure: {width: 1920, height: 1080, aspect_ratio: 1.777}
    attribute :dimensions, :map do
      public? true
      default %{}
    end

    # Rich metadata including EXIF, color info, processing details
    attribute :metadata, :map do
      public? true
      default %{}
    end

    # Array of dominant colors in hex format
    attribute :dominant_colors, {:array, :string} do
      public? true
      default []
    end

    # Accessibility features detected/configured
    attribute :accessibility_features, :map do
      public? true

      default %{
        "has_alt_text" => false,
        "color_contrast_issues" => false,
        "contains_text" => false,
        "decorative" => false
      }
    end

    # CDN and delivery URLs for different formats/sizes
    attribute :cdn_urls, :map do
      public? true
      default %{}
    end

    # Processing status for async operations
    attribute :processing_status, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:pending, :processing, :completed, :failed]
      default :pending
    end

    attribute :team_id, :uuid do
      allow_nil? false
      public? true
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :team, Dirup.Accounts.Team do
      allow_nil? false
      attribute_writable? true
    end

    # Reverse relationship to files (one media can be referenced by multiple files)
    many_to_many :files, Dirup.Workspaces.File do
      through Dirup.Workspaces.FileMedia
      source_attribute_on_join_resource :media_id
      destination_attribute_on_join_resource :file_id
      public? true
    end

    # Primary file that created this media
    has_one :source_file, Dirup.Workspaces.File do
      manual Dirup.Workspaces.Media.Relationships.SourceFile
      public? true
      description "The original file that created this media resource"
    end

    # All FileMedia relationships for this media
    has_many :file_media, Dirup.Workspaces.FileMedia do
      destination_attribute :media_id
      # Internal relationship management
      public? false
    end
  end

  calculations do
    calculate :is_processed, :boolean do
      calculation expr(processing_status == :completed)
    end

    calculate :aspect_ratio, :float do
      load [:dimensions]

      calculation fn media_items, _context ->
        Enum.map(media_items, fn media ->
          case media.dimensions do
            %{"width" => w, "height" => h} when w > 0 and h > 0 ->
              w / h

            _ ->
              0.0
          end
        end)
      end
    end

    calculate :file_size_human, :string do
      load [:file_size]

      calculation fn media_items, _context ->
        Enum.map(media_items, fn media ->
          humanize_file_size(media.file_size)
        end)
      end
    end

    # Get the best URL for a given context
    calculate :best_url, :string do
      argument :context, :string, default: "default"
      argument :width, :integer
      argument :height, :integer

      load [:cdn_urls, :mime_type]

      calculation fn media_items, context ->
        Enum.map(media_items, fn media ->
          select_best_url(media, context.arguments)
        end)
      end
    end

    calculate :accessibility_score, :integer do
      load [:alt_text, :accessibility_features, :dominant_colors]

      calculation fn media_items, _context ->
        Enum.map(media_items, fn media ->
          calculate_accessibility_score(media)
        end)
      end
    end

    calculate :variants_available, {:array, :string} do
      load [:cdn_urls]

      calculation fn media_items, _context ->
        Enum.map(media_items, fn media ->
          Map.keys(media.cdn_urls || %{})
        end)
      end
    end
  end

  # Helper functions
  defp humanize_file_size(size) when size < 1024, do: "#{size} B"
  defp humanize_file_size(size) when size < 1024 * 1024, do: "#{Float.round(size / 1024, 1)} KB"

  defp humanize_file_size(size) when size < 1024 * 1024 * 1024,
    do: "#{Float.round(size / (1024 * 1024), 1)} MB"

  defp humanize_file_size(size), do: "#{Float.round(size / (1024 * 1024 * 1024), 1)} GB"

  defp select_best_url(media, args) do
    # Logic to select best URL variant based on context
    # e.g., webp for modern browsers, different sizes for responsive images
    cdn_urls = media.cdn_urls || %{}

    cond do
      args[:width] && args[:height] ->
        Map.get(cdn_urls, "#{args.width}x#{args.height}", Map.get(cdn_urls, "original"))

      args[:context] == "thumbnail" ->
        Map.get(cdn_urls, "thumbnail", Map.get(cdn_urls, "150x150"))

      args[:context] == "preview" ->
        Map.get(cdn_urls, "medium", Map.get(cdn_urls, "800x800"))

      true ->
        Map.get(cdn_urls, "original")
    end
  end

  defp calculate_accessibility_score(media) do
    score = 0

    # Has alt text
    score = if media.alt_text && String.length(media.alt_text) > 0, do: score + 30, else: score

    # Accessibility features configured
    features = media.accessibility_features || %{}
    score = if features["has_alt_text"], do: score + 20, else: score
    score = if not features["color_contrast_issues"], do: score + 25, else: score
    score = if features["decorative"] == false, do: score + 15, else: score

    # Has good color contrast (based on dominant colors)
    score = if length(media.dominant_colors || []) > 1, do: score + 10, else: score

    min(score, 100)
  end
end
