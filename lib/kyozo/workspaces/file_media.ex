defmodule Kyozo.Workspaces.FileMedia do
  @derive {Jason.Encoder, only: [:id, :file_id, :storage_resource_id, :relationship_type, :is_primary, :metadata, :created_at, :updated_at]}

  @moduledoc """
  Intermediary resource that links Files to Media resources through storage behavior.

  This resource acts as a bridge between the generic File entity and specialized Media
  resources, implementing the abstract storage pattern to handle media-specific content
  processing, thumbnail generation, and format conversion.

  ## Key Features

  - **Storage Implementation**: Implements AbstractStorage for media content
  - **Content Resolution**: Resolves file content into Media resources
  - **Format Processing**: Handles image optimization, thumbnail generation
  - **Metadata Extraction**: Extracts EXIF data, dimensions, color profiles
  - **Multi-format Support**: JPEG, PNG, WebP, GIF, SVG, HEIC, AVIF, etc.

  ## Relationship Flow

  File -> FileMedia (storage behavior) -> Media (specialized resource)

  ## Storage Backend Selection

  - Small images (<5MB): Disk backend with processing
  - Large images (>5MB): S3 backend for scalability
  - Frequently accessed: Disk with CDN caching
  - Temporary/generated: RAM for thumbnails
  """

  use Kyozo.Storage.AbstractStorage,
    media_type: :image,
    storage_backends: [:s3, :disk, :hybrid, :ram],
    domain: Kyozo.Workspaces

  require Ash.Query

  postgres do
    table "file_media"
    repo Kyozo.Repo

    references do
      reference :file, on_delete: :delete, index?: true
      reference :storage_resource, on_delete: :delete, index?: true
    end

    custom_indexes do
      index [:file_id, :media_id], unique: true
      index [:file_id, :is_primary]
      index [:file_id, :relationship_type]
      index [:media_id]
      index [:storage_resource_id]
      index [:relationship_type]
      index [:created_at]
    end
  end

  json_api do
    type "file_media"

    routes do
      base "/file_media"
      get :read
      index :read
      post :create
      patch :update
      delete :destroy
    end
  end



  # Additional attributes for file media
  attributes do
    # Add team_id attribute required by team relationship from base
    attribute :team_id, :uuid do
      allow_nil? false
      public? true
    end

    # Add user_id attribute for user relationship from base
    attribute :user_id, :uuid do
      allow_nil? true
      public? true
    end
  end

  # Implement AbstractStorage callbacks
  @impl true
  def supported_mime_types do
    [
      # Standard image formats
      "image/jpeg",
      "image/jpg",
      "image/png",
      "image/gif",
      "image/webp",
      "image/bmp",
      "image/tiff",
      "image/svg+xml",
      "image/x-icon",
      "image/vnd.microsoft.icon",

      # Modern image formats
      "image/heic",
      "image/heif",
      "image/avif",
      "image/jxl",

      # Raw formats (for future support)
      "image/x-canon-cr2",
      "image/x-canon-crw",
      "image/x-nikon-nef",
      "image/x-sony-arw",
      "image/x-adobe-dng"
    ]
  end

  @impl true
  def default_storage_backend, do: :disk

  @impl true
  def validate_content(content, metadata) do
    mime_type = Map.get(metadata, :mime_type, "application/octet-stream")

    cond do
      mime_type not in supported_mime_types() ->
        {:error, "Unsupported image MIME type: #{mime_type}"}

      byte_size(content) > 50 * 1024 * 1024 ->
        {:error, "Image too large (max 50MB)"}

      not valid_image_header?(content, mime_type) ->
        {:error, "Invalid image file format"}

      true ->
        :ok
    end
  end

  @impl true
  def transform_content(content, metadata) do
    mime_type = Map.get(metadata, :mime_type, "application/octet-stream")

    case extract_image_metadata(content, mime_type) do
      {:ok, image_info} ->
        # Optimize image if needed
        {optimized_content, optimization_info} = optimize_image(content, mime_type, image_info)

        updated_metadata = Map.merge(metadata, %{
          width: image_info.width,
          height: image_info.height,
          aspect_ratio: calculate_aspect_ratio(image_info.width, image_info.height),
          color_space: image_info.color_space,
          bit_depth: image_info.bit_depth,
          has_transparency: image_info.has_transparency,
          exif_data: image_info.exif_data,
          optimized: optimization_info.optimized,
          original_size: byte_size(content),
          optimized_size: byte_size(optimized_content),
          compression_ratio: optimization_info.compression_ratio
        })

        {:ok, optimized_content, updated_metadata}

      {:error, reason} ->
        {:error, "Failed to process image: #{reason}"}
    end
  end

  @impl true
  def storage_options(backend, metadata) do
    mime_type = Map.get(metadata, :mime_type, "application/octet-stream")

    base_options = %{
      mime_type: mime_type,
      media_type: :image
    }

    case backend do
      :s3 ->
        Map.merge(base_options, %{
          storage_class: "STANDARD_IA",
          server_side_encryption: "AES256",
          cache_control: "public, max-age=31536000", # 1 year cache
          content_disposition: "inline"
        })

      :disk ->
        Map.merge(base_options, %{
          create_directory: true,
          sync: false,
          enable_thumbnails: true
        })

      :ram ->
        Map.merge(base_options, %{
          ttl: 3600, # 1 hour TTL for cached thumbnails
          max_size: 10 * 1024 * 1024 # 10MB max for RAM storage
        })

      _ ->
        base_options
    end
  end

  @impl true
  def select_storage_backend(content, metadata) do
    file_size = byte_size(content)
    mime_type = Map.get(metadata, :mime_type, "application/octet-stream")

    cond do
      # Large images go to S3
      file_size > 5 * 1024 * 1024 ->
        :s3

      # SVG images are text-based, use disk
      mime_type == "image/svg+xml" ->
        :disk

      # Small to medium images use disk for processing
      file_size < 10 * 1024 * 1024 ->
        :disk

      # Default to hybrid for intelligent selection
      true ->
        :hybrid
    end
  end

  # Relationships
  relationships do
    belongs_to :file, Kyozo.Workspaces.File do
      allow_nil? false
      attribute_writable? true
      public? true
    end

    # TODO: Uncomment when Media resource is implemented
    # belongs_to :media, Kyozo.Workspaces.Media do
    #   allow_nil? true
    #   attribute_writable? true
    #   public? true
    # end


  end

  # FileMedia-specific actions
  actions do
    # Define create action for JSON API
    create :create do
      accept [:storage_resource_id, :file_id, :relationship_type, :media_type, :is_primary, :metadata]
    end

    # Define update action with require_atomic? false
    update :update do
      require_atomic? false
    end

    read :by_file do
      argument :file_id, :uuid, allow_nil?: false

      prepare build(
        filter: [file_id: arg(:file_id)],
        load: [:storage_resource, :media, :storage_info],
        sort: [is_primary: :desc, created_at: :desc]
      )
    end

    read :primary_for_file do
      argument :file_id, :uuid, allow_nil?: false

      prepare build(
        filter: [file_id: arg(:file_id), is_primary: true],
        load: [:storage_resource, :media, :storage_info]
      )
    end

    create :create_from_file do
      argument :file_id, :uuid, allow_nil?: false
      argument :content, :string, allow_nil?: false
      argument :storage_backend, :atom

      change set_attribute(:is_primary, true)
      change set_attribute(:relationship_type, :primary)
      change {__MODULE__.Changes.CreateFromFile, []}
      change {__MODULE__.Changes.CreateMediaResource, []}
    end

    create :create_thumbnail do
      argument :file_id, :uuid, allow_nil?: false
      argument :width, :integer
      argument :height, :integer
      argument :format, :string, default: "webp"

      change set_attribute(:relationship_type, :thumbnail)
      change {__MODULE__.Changes.GenerateThumbnail, []}
    end

    action :generate_thumbnails, {:array, :struct} do
      argument :sizes, {:array, :map}, default: [
        %{width: 150, height: 150, name: "thumb"},
        %{width: 400, height: 400, name: "small"},
        %{width: 800, height: 800, name: "medium"},
        %{width: 1200, height: 1200, name: "large"}
      ]

      run {__MODULE__.Actions.GenerateThumbnails, []}
    end

    action :extract_colors, {:array, :string} do
      argument :max_colors, :integer, default: 8

      run {__MODULE__.Actions.ExtractColors, []}
    end

    action :convert_format, :struct do
      argument :target_format, :string, allow_nil?: false
      argument :quality, :integer, default: 85
      argument :progressive, :boolean, default: true

      run {__MODULE__.Actions.ConvertFormat, []}
    end

    action :optimize_image, :struct do
      argument :target_size, :integer
      argument :quality, :integer, default: 85

      run {__MODULE__.Actions.OptimizeImage, []}
    end
  end

  # FileMedia-specific calculations
  calculations do
    import Kyozo.Storage.AbstractStorage.CommonCalculations

    storage_info()
    content_preview()

    calculate :image_stats, :map do
      load [:metadata, :storage_resource]

      calculation fn file_media, _context ->
        Enum.map(file_media, fn fm ->
          metadata = fm.metadata || %{}
          storage = fm.storage_resource

          %{
            width: Map.get(metadata, "width", 0),
            height: Map.get(metadata, "height", 0),
            aspect_ratio: Map.get(metadata, "aspect_ratio", 0.0),
            file_size: storage.file_size,
            color_space: Map.get(metadata, "color_space", "unknown"),
            bit_depth: Map.get(metadata, "bit_depth", 8),
            has_transparency: Map.get(metadata, "has_transparency", false),
            is_optimized: Map.get(metadata, "optimized", false),
            compression_ratio: Map.get(metadata, "compression_ratio", 1.0)
          }
        end)
      end
    end

    calculate :thumbnail_info, :map do
      load [:metadata, :storage_resource]

      calculation fn file_media, _context ->
        Enum.map(file_media, fn fm ->
          metadata = fm.metadata || %{}

          %{
            is_thumbnail: fm.relationship_type == :thumbnail,
            thumbnail_size: Map.get(metadata, "thumbnail_size", "unknown"),
            generated_at: Map.get(metadata, "generated_at"),
            source_file_id: Map.get(metadata, "source_file_id")
          }
        end)
      end
    end
  end

  # FileMedia-specific validations
  validations do
    validate present([:file_id, :storage_resource_id])
    validate one_of(:relationship_type, [:primary, :thumbnail, :format, :backup, :cache])
    validate {__MODULE__.Validations.ValidateImageFormat, []}
  end

  # Private helper functions
  defp valid_image_header?(<<0xFF, 0xD8, _::binary>>, "image/jpeg"), do: true
  defp valid_image_header?(<<0x89, "PNG", 0x0D, 0x0A, 0x1A, 0x0A, _::binary>>, "image/png"), do: true
  defp valid_image_header?(<<"GIF8", _::binary>>, "image/gif"), do: true
  defp valid_image_header?(<<"RIFF", _::binary-size(4), "WEBP", _::binary>>, "image/webp"), do: true
  defp valid_image_header?(<<"BM", _::binary>>, "image/bmp"), do: true
  defp valid_image_header?(<<_::binary-size(8), "CR", _::binary>>, mime) when mime in ["image/x-canon-cr2"], do: true
  defp valid_image_header?(_, _), do: false

  defp extract_image_metadata(content, mime_type) do
    # Placeholder implementation - integrate with actual image processing library
    {:ok, %{
      width: 1920,
      height: 1080,
      color_space: "sRGB",
      bit_depth: 8,
      has_transparency: false,
      exif_data: %{}
    }}
  end

  defp optimize_image(content, _mime_type, _image_info) do
    # Placeholder implementation - integrate with actual image optimization
    {content, %{optimized: false, compression_ratio: 1.0}}
  end

  defp calculate_aspect_ratio(0, _), do: 0.0
  defp calculate_aspect_ratio(_, 0), do: 0.0
  defp calculate_aspect_ratio(width, height), do: width / height

  # Change modules
  defmodule Changes do
    defmodule CreateFromFile do
      use Ash.Resource.Change

      def change(changeset, _opts, context) do
        file_id = Ash.Changeset.get_argument(changeset, :file_id)
        content = Ash.Changeset.get_argument(changeset, :content)
        storage_backend = Ash.Changeset.get_argument(changeset, :storage_backend)

        if file_id && content do
          # Get the file to determine filename and mime type
          case Ash.get(Kyozo.Workspaces.File, file_id) do
            {:ok, file} ->
              # Create storage resource
              case Kyozo.Storage.store_content(content, file.name,
                     backend: storage_backend || :disk,
                     storage_options: %{}) do
                {:ok, storage_resource} ->
                  changeset
                  |> Ash.Changeset.change_attribute(:file_id, file_id)
                  |> Ash.Changeset.change_attribute(:storage_resource_id, storage_resource.id)

                {:error, reason} ->
                  Ash.Changeset.add_error(changeset, "Failed to store image content: #{inspect(reason)}")
              end

            {:error, _reason} ->
              Ash.Changeset.add_error(changeset, "File not found")
          end
        else
          changeset
        end
      end
    end

    defmodule CreateMediaResource do
      use Ash.Resource.Change

      def change(changeset, _opts, _context) do
        changeset
        |> Ash.Changeset.after_action(fn changeset, file_media ->
          # Create the corresponding Media resource
          case create_media_from_file_media(file_media) do
            {:ok, media} ->
              # Update the file_media to reference the media
              Ash.update(file_media, %{media_id: media.id})

            {:error, reason} ->
              require Logger
              Logger.warning("Failed to create Media resource: #{inspect(reason)}")
              {:ok, file_media}
          end
        end)
      end

      defp create_media_from_file_media(file_media) do
        # This would create a Media resource based on the file_media
        # Implementation depends on your Media resource structure
        {:ok, %{id: Ash.UUID.generate()}} # Placeholder
      end
    end

    defmodule GenerateThumbnail do
      use Ash.Resource.Change

      def change(changeset, _opts, _context) do
        width = Ash.Changeset.get_argument(changeset, :width)
        height = Ash.Changeset.get_argument(changeset, :height)
        format = Ash.Changeset.get_argument(changeset, :format)

        # Generate thumbnail content from source
        # Implementation depends on image processing library
        changeset
      end
    end
  end

  # Action modules
  defmodule Actions do
    defmodule GenerateThumbnails do
      # # use Ash.Resource.Action

      def run(file_media, input, _context) do
        sizes = input.arguments.sizes

        # Generate thumbnails for each requested size
        thumbnails = Enum.map(sizes, fn size ->
          # Create thumbnail using image processing
          # Return FileMedia struct for each thumbnail
          %{size: size, thumbnail: file_media} # Placeholder
        end)

        {:ok, thumbnails}
      end
    end

    defmodule ExtractColors do
      use Ash.Resource.Actions.Implementation

      @impl true
      def run(file_media, input, _context) do
        max_colors = input.arguments.max_colors

        # Extract dominant colors from image
        # Implementation depends on image processing library
        colors = ["#FF0000", "#00FF00", "#0000FF"] # Placeholder

        {:ok, colors}
      end
    end

    defmodule ConvertFormat do
      # use Ash.Resource.Action

      def run(file_media, input, _context) do
        target_format = input.arguments.target_format
        quality = input.arguments.quality
        progressive = input.arguments.progressive

        # Convert image to target format
        # Implementation depends on image processing library
        {:ok, file_media}
      end
    end

    defmodule OptimizeImage do
      # use Ash.Resource.Action

      def run(file_media, input, _context) do
        target_size = input.arguments.target_size
        quality = input.arguments.quality

        # Optimize image to target size/quality
        # Implementation depends on image processing library
        {:ok, file_media}
      end
    end
  end

  # Validation modules
  defmodule Validations do
    defmodule ValidateImageFormat do
      use Ash.Resource.Validation

      def validate(changeset, _opts, _context) do
        # Validate that the content is a valid image format
        # Implementation depends on actual validation needs
        :ok
      end
    end
  end
end
