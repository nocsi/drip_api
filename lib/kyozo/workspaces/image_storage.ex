defmodule Kyozo.Workspaces.ImageStorage do
  @derive {Jason.Encoder, only: [:id, :file_id, :storage_resource_id, :relationship_type, :media_type, :is_primary, :metadata, :created_at, :updated_at]}

  @moduledoc """
  Image storage resource implementing the AbstractStorage pattern.

  This resource manages storage for image files, providing image-specific
  storage capabilities with support for thumbnails, format conversion,
  and metadata extraction.

  ## Supported MIME Types

  - Raster images: image/jpeg, image/png, image/gif, image/webp, image/bmp, image/tiff
  - Vector images: image/svg+xml
  - Raw formats: image/x-canon-cr2, image/x-adobe-dng, image/x-nikon-nef

  ## Storage Backend Selection

  - Small images (<5MB): Disk for quick access
  - Large images (>5MB): S3 for scalability
  - Thumbnails/cache: RAM for speed
  - Archive/backup: S3 with IA storage class

  ## Automatic Processing

  - Thumbnail generation for web display
  - EXIF metadata extraction
  - Format optimization (WebP conversion)
  - Progressive JPEG encoding
  """

  use Kyozo.Storage.AbstractStorage,
    media_type: :image,
    storage_backends: [:s3, :disk, :hybrid, :ram],
    domain: Kyozo.Workspaces

  require Ash.Query

  postgres do
    table "image_storages"
    repo Kyozo.Repo

    references do
      reference :file, on_delete: :delete, index?: true
      reference :storage_resource, on_delete: :delete, index?: true
    end

    custom_indexes do
      index [:file_id, :storage_resource_id], unique: true
      index [:file_id, :is_primary]
      index [:file_id, :relationship_type]
      index [:storage_resource_id]
      index [:media_type, :relationship_type]
      index [:processing_status]
      index [:created_at]
    end
  end

  json_api do
    type "image_storage"

    routes do
      base "/image_storages"
      get :read
      index :read
      post :create
      patch :update
      delete :destroy
    end
  end


  #
  #   mutations do
  #     create :create_image_storage, :create_image_storage
  #     update :update_image_storage, :update_image_storage
  #     destroy :destroy_image_storage, :destroy
  #   end
  # end

  # Additional attributes for image storage
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
      # Common web formats
      "image/jpeg",
      "image/jpg",
      "image/png",
      "image/gif",
      "image/webp",
      "image/avif",

      # Other raster formats
      "image/bmp",
      "image/tiff",
      "image/tif",
      "image/x-icon",
      "image/vnd.microsoft.icon",

      # Vector formats
      "image/svg+xml",

      # Raw camera formats
      "image/x-canon-cr2",
      "image/x-canon-crw",
      "image/x-adobe-dng",
      "image/x-nikon-nef",
      "image/x-nikon-nrw",
      "image/x-sony-arw",
      "image/x-panasonic-raw",
      "image/x-olympus-orf",
      "image/x-fuji-raf",
      "image/x-kodak-dcr",
      "image/x-pentax-pef"
    ]
  end

  @impl true
  def default_storage_backend, do: :s3

  @impl true
  def validate_content(content, metadata) do
    mime_type = Map.get(metadata, :mime_type, "application/octet-stream")

    cond do
      mime_type not in supported_mime_types() ->
        {:error, "Unsupported image MIME type: #{mime_type}"}

      byte_size(content) > 500 * 1024 * 1024 ->
        {:error, "Image too large (max 500MB)"}

      byte_size(content) < 100 ->
        {:error, "Image file too small, possibly corrupted"}

      not valid_image_header?(content, mime_type) ->
        {:error, "Invalid image file header"}

      true ->
        :ok
    end
  end

  @impl true
  def transform_content(content, metadata) do
    mime_type = Map.get(metadata, :mime_type, "application/octet-stream")

    # Extract image metadata
    case extract_image_metadata(content, mime_type) do
      {:ok, image_metadata} ->
        updated_metadata = Map.merge(metadata, %{
          image_info: image_metadata,
          processed_at: DateTime.utc_now()
        })

        # Optimize image if needed
        case optimize_image(content, mime_type, image_metadata) do
          {:ok, optimized_content} ->
            {:ok, optimized_content, updated_metadata}
          {:error, _} ->
            # Fall back to original content if optimization fails
            {:ok, content, updated_metadata}
        end

      {:error, reason} ->
        {:error, "Failed to process image: #{reason}"}
    end
  end

  @impl true
  def storage_options(backend, metadata) do
    mime_type = Map.get(metadata, :mime_type, "application/octet-stream")
    image_info = Map.get(metadata, :image_info, %{})
    file_size = Map.get(image_info, :file_size, 0)

    base_options = %{
      mime_type: mime_type,
      media_type: :image
    }

    case backend do
      :s3 ->
        storage_class = cond do
          file_size > 50 * 1024 * 1024 -> "STANDARD_IA"  # Large files
          Map.get(metadata, :relationship_type) == :backup -> "GLACIER"
          true -> "STANDARD"
        end

        Map.merge(base_options, %{
          storage_class: storage_class,
          server_side_encryption: "AES256",
          metadata: %{
            width: Map.get(image_info, :width, 0),
            height: Map.get(image_info, :height, 0),
            format: mime_type
          }
        })

      :disk ->
        Map.merge(base_options, %{
          create_directory: true,
          organize_by_date: true,
          path_template: "{year}/{month}/{day}/{filename}"
        })

      :ram ->
        Map.merge(base_options, %{
          ttl: 3600,  # 1 hour for thumbnails
          compress: true
        })

      _ ->
        base_options
    end
  end

  @impl true
  def select_storage_backend(content, metadata) do
    file_size = byte_size(content)
    relationship_type = Map.get(metadata, :relationship_type, :primary)

    cond do
      # Thumbnails and cache go to RAM
      relationship_type in [:thumbnail, :cache] ->
        :ram

      # Large images go to S3
      file_size > 5 * 1024 * 1024 ->
        :s3

      # Medium images go to disk for fast access
      file_size < 50 * 1024 * 1024 ->
        :disk

      # Very large files go to S3
      true ->
        :s3
    end
  end

  # Additional image-specific actions
  actions do
    # Define create action for JSON API
    create :create do
      accept [:storage_resource_id, :file_id, :relationship_type, :media_type, :is_primary, :metadata]
    end

    # Define update action with require_atomic? false
    update :update do
      require_atomic? false
    end

    create :create_with_thumbnails do
      argument :file_id, :uuid, allow_nil?: false
      argument :content, :string, allow_nil?: false
      argument :filename, :string, allow_nil?: false
      argument :mime_type, :string
      argument :thumbnail_sizes, {:array, :string}, default: ["150x150", "300x300", "600x600"]

      change set_attribute(:is_primary, true)
      change set_attribute(:relationship_type, :primary)
      change {__MODULE__.Changes.RelateToFile, []}
      change {__MODULE__.Changes.GenerateThumbnails, []}
    end

    action :generate_thumbnails, {:array, :struct} do
      argument :sizes, {:array, :string}, default: ["150x150", "300x300", "600x600"]

      run {__MODULE__.Actions.GenerateThumbnails, []}
    end

    action :convert_format, :struct do
      argument :target_format, :string, allow_nil?: false
      argument :quality, :integer, default: 85
      argument :progressive, :boolean, default: false

      run {__MODULE__.Actions.ConvertFormat, []}
    end

    action :extract_colors, :map do
      run {__MODULE__.Actions.ExtractColors, []}
    end

    action :detect_faces, {:array, :map} do
      run {__MODULE__.Actions.DetectFaces, []}
    end

    action :optimize_for_web, :struct do
      argument :max_width, :integer, default: 1920
      argument :max_height, :integer, default: 1080
      argument :quality, :integer, default: 80

      run {__MODULE__.Actions.OptimizeForWeb, []}
    end
  end

  # Additional relationships specific to images
  relationships do
    belongs_to :file, Kyozo.Workspaces.File do
      allow_nil? false
      attribute_writable? true
      public? true
    end



    # Self-referential relationship for thumbnails
    has_many :thumbnails, __MODULE__ do
      destination_attribute :file_id
      source_attribute :file_id
      filter expr(relationship_type == :thumbnail)
    end

    belongs_to :original_image, __MODULE__ do
      allow_nil? true
      public? true
    end
  end

  # Image-specific calculations
  calculations do
    import Kyozo.Storage.AbstractStorage.CommonCalculations

    storage_info()
    content_preview()

    calculate :image_info, :map do
      load [:metadata, :storage_resource]

      calculation fn image_storages, _context ->
        Enum.map(image_storages, fn img ->
          metadata = img.metadata || %{}
          image_info = Map.get(metadata, :image_info, %{})
          storage = img.storage_resource

          %{
            width: Map.get(image_info, :width, 0),
            height: Map.get(image_info, :height, 0),
            format: storage.mime_type,
            file_size: storage.file_size,
            color_space: Map.get(image_info, :color_space, "unknown"),
            bit_depth: Map.get(image_info, :bit_depth, 8),
            has_transparency: Map.get(image_info, :has_transparency, false),
            exif_data: Map.get(image_info, :exif, %{}),
            aspect_ratio: calculate_aspect_ratio(Map.get(image_info, :width, 0), Map.get(image_info, :height, 0))
          }
        end)
      end
    end

    calculate :thumbnail_urls, :map do
      load [:thumbnails]

      calculation fn image_storages, _context ->
        Enum.map(image_storages, fn img ->
          thumbnail_urls = Enum.reduce(img.thumbnails || [], %{}, fn thumb, acc ->
            size = Map.get(thumb.metadata || %{}, "size", "unknown")
            Map.put(acc, size, "/storage/#{thumb.storage_resource_id}/download")
          end)

          %{
            small: Map.get(thumbnail_urls, "150x150"),
            medium: Map.get(thumbnail_urls, "300x300"),
            large: Map.get(thumbnail_urls, "600x600"),
            all: thumbnail_urls
          }
        end)
      end
    end

    calculate :dominant_colors, {:array, :string} do
      load [:metadata]

      calculation fn image_storages, _context ->
        Enum.map(image_storages, fn img ->
          Map.get(img.metadata || %{}, "dominant_colors", [])
        end)
      end
    end

    calculate :is_web_optimized, :boolean do
      load [:metadata, :storage_resource]

      calculation fn image_storages, _context ->
        Enum.map(image_storages, fn img ->
          storage = img.storage_resource
          metadata = img.metadata || %{}
          image_info = Map.get(metadata, :image_info, %{})

          web_formats = ["image/webp", "image/avif", "image/jpeg"]
          is_web_format = storage.mime_type in web_formats
          is_reasonable_size = storage.file_size < 2 * 1024 * 1024  # < 2MB
          is_reasonable_dimensions = Map.get(image_info, :width, 0) <= 1920 and Map.get(image_info, :height, 0) <= 1080

          is_web_format and is_reasonable_size and is_reasonable_dimensions
        end)
      end
    end
  end

  # Image-specific validations
  validations do
    validate present([:file_id, :storage_resource_id])
    validate one_of(:relationship_type, [:primary, :thumbnail, :format, :backup, :cache])
    validate {__MODULE__.Validations.ValidateImageDimensions, []}
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
    # This would integrate with an image processing library like ImageMagick or Vix
    # For now, return basic metadata
    {:ok, %{
      width: 0,
      height: 0,
      file_size: byte_size(content),
      format: mime_type,
      color_space: "sRGB",
      bit_depth: 8,
      has_transparency: false,
      exif: %{}
    }}
  end

  defp optimize_image(content, _mime_type, _image_info) do
    # This would perform actual image optimization
    # For now, return the original content
    {:ok, content}
  end

  defp calculate_aspect_ratio(0, _), do: 0
  defp calculate_aspect_ratio(_, 0), do: 0
  defp calculate_aspect_ratio(width, height), do: width / height

  # Change modules
  defmodule Changes do
    defmodule RelateToFile do
      use Ash.Resource.Change

      def change(changeset, _opts, _context) do
        file_id = Ash.Changeset.get_argument(changeset, :file_id)
        if file_id do
          Ash.Changeset.change_attribute(changeset, :file_id, file_id)
        else
          changeset
        end
      end
    end

    defmodule GenerateThumbnails do
      use Ash.Resource.Change

      def change(changeset, _opts, context) do
        # This would be implemented to generate thumbnails after the main image is stored
        # For now, just add metadata about pending thumbnail generation
        thumbnail_sizes = Ash.Changeset.get_argument(changeset, :thumbnail_sizes) || []

        metadata = %{
          thumbnail_generation: %{
            status: "pending",
            sizes: thumbnail_sizes,
            scheduled_at: DateTime.utc_now()
          }
        }

        Ash.Changeset.change_attribute(changeset, :metadata, metadata)
      end
    end
  end

  # Action modules
  defmodule Actions do
    defmodule GenerateThumbnails do
      # # use Ash.Resource.Action

      def run(image_storage, input, _context) do
        sizes = input.arguments.sizes

        # This would integrate with an image processing library
        # For now, return a placeholder result
        {:ok, Enum.map(sizes, fn size ->
          %{size: size, status: "pending", created_at: DateTime.utc_now()}
        end)}
      end
    end

    defmodule ExtractColors do
      # use Ash.Resource.Action

      def run(_image_storage, _input, _context) do
        # This would extract dominant colors from the image
        # For now, return placeholder colors
        {:ok, %{
          dominant_colors: ["#FF6B6B", "#4ECDC4", "#45B7D1"],
          color_palette: [
            %{color: "#FF6B6B", percentage: 45.2},
            %{color: "#4ECDC4", percentage: 32.1},
            %{color: "#45B7D1", percentage: 22.7}
          ]
        }}
      end
    end
  end

  # Validation modules
  defmodule Validations do
    defmodule ValidateImageDimensions do
      use Ash.Resource.Validation

      def validate(changeset, _opts, _context) do
        metadata = Ash.Changeset.get_attribute(changeset, :metadata) || %{}
        image_info = Map.get(metadata, :image_info, %{})
        width = Map.get(image_info, :width, 0)
        height = Map.get(image_info, :height, 0)

        cond do
          width > 50000 or height > 50000 ->
            {:error, field: :metadata, message: "Image dimensions too large (max 50000x50000)"}
          width < 1 or height < 1 ->
            {:error, field: :metadata, message: "Invalid image dimensions"}
          true ->
            :ok
        end
      end
    end

    defmodule ValidateImageFormat do
      use Ash.Resource.Validation

      def validate(changeset, _opts, _context) do
        case Ash.Changeset.get_attribute(changeset, :storage_resource_id) do
          nil -> :ok
          storage_id ->
            case Ash.get(Kyozo.Storage.StorageResource, storage_id) do
              {:ok, storage} ->
                if storage.mime_type in Kyozo.Workspaces.ImageStorage.supported_mime_types() do
                  :ok
                else
                  {:error, field: :storage_resource_id, message: "Unsupported image format: #{storage.mime_type}"}
                end
              {:error, _} ->
                {:error, field: :storage_resource_id, message: "Invalid storage resource"}
            end
        end
      end
    end
  end

  # Helper function removed - using direct module reference in actions
end
