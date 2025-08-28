defmodule Dirup.Workspaces.Blob do
  @derive {Jason.Encoder, only: [:id, :hash, :size, :content_type, :encoding, :created_at]}

  @moduledoc """
  Blob resource for storing document content with hash-based deduplication.

  Blobs provide content-addressable storage where identical content shares
  the same blob, reducing storage overhead and enabling efficient caching.
  """

  use Ash.Resource,
    otp_app: :dirup,
    domain: Dirup.Workspaces,
    authorizers: [Ash.Policy.Authorizer],
    data_layer: AshPostgres.DataLayer,
    extensions: [AshJsonApi.Resource]

  require Ash.Query

  json_api do
    type "blob"

    routes do
      base "/blobs"
      get :read
      index :read
    end
  end

  postgres do
    table "blobs"
    repo Dirup.Repo

    custom_indexes do
      index [:hash], unique: true
      index [:content_type]
      index [:size]
      index [:created_at]
    end
  end

  # GraphQL configuration removed during GraphQL cleanup

  actions do
    defaults [:read, :destroy]

    create :create_blob do
      argument :content, :string, allow_nil?: false
      accept [:content_type, :encoding]

      change before_action(fn changeset, _context ->
               content = Ash.Changeset.get_argument(changeset, :content)

               if content do
                 hash = generate_hash(content)
                 size = byte_size(content)

                 changeset
                 |> Ash.Changeset.change_attribute(:hash, hash)
                 |> Ash.Changeset.change_attribute(:size, size)
               else
                 changeset
               end
             end)

      # Store content after creating the blob record
      change after_action(fn changeset, blob, _context ->
               content = Ash.Changeset.get_argument(changeset, :content)

               case store_content(blob.hash, content) do
                 :ok -> {:ok, blob}
                 {:error, reason} -> {:error, reason}
               end
             end)
    end

    create :find_or_create do
      argument :content, :string, allow_nil?: false
      accept [:content_type, :encoding]

      change before_action(fn changeset, _context ->
               content = Ash.Changeset.get_argument(changeset, :content)

               if content do
                 hash = generate_hash(content)

                 # Check if blob already exists
                 case __MODULE__ |> Ash.Query.filter(hash == ^hash) |> Ash.read_one() do
                   {:ok, existing_blob} when not is_nil(existing_blob) ->
                     # Return existing blob without creating new one
                     Ash.Changeset.add_error(changeset,
                       field: :hash,
                       message: "exists",
                       value: existing_blob
                     )

                   {:ok, nil} ->
                     # Proceed with creation
                     size = byte_size(content)

                     changeset
                     |> Ash.Changeset.change_attribute(:hash, hash)
                     |> Ash.Changeset.change_attribute(:size, size)

                   {:error, _} ->
                     changeset
                 end
               else
                 changeset
               end
             end)

      change after_action(fn changeset, blob, _context ->
               content = Ash.Changeset.get_argument(changeset, :content)

               case store_content(blob.hash, content) do
                 :ok -> {:ok, blob}
                 {:error, reason} -> {:error, reason}
               end
             end)
    end

    action :get_content, :string do
      run fn blob, _context ->
        case retrieve_content(blob.hash) do
          {:ok, content} -> {:ok, content}
          {:error, reason} -> {:error, reason}
        end
      end
    end

    action :exists?, :boolean do
      argument :hash, :string, allow_nil?: false

      run fn _blob, context ->
        hash = context.arguments.hash

        case __MODULE__ |> Ash.Query.filter(hash == ^hash) |> Ash.read_one() do
          {:ok, blob} when not is_nil(blob) -> {:ok, true}
          {:ok, nil} -> {:ok, false}
          {:error, _} -> {:ok, false}
        end
      end
    end
  end

  policies do
    policy action_type(:read) do
      # Blobs are content-addressable and can be read by anyone who knows the hash
      authorize_if always()
    end

    policy action_type(:create) do
      authorize_if actor_present()
    end

    policy action_type(:destroy) do
      # Only allow destroy if no documents reference this blob
      forbid_if expr(exists(document_blob_refs, true))
    end
  end

  validations do
    validate present([:hash, :size, :content_type])

    validate match(:hash, ~r/^[a-f0-9]{64}$/) do
      message "Hash must be a valid SHA-256 hex string"
    end

    validate compare(:size, greater_than_or_equal_to: 0) do
      message "Size must be non-negative"
    end
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :hash, :string do
      allow_nil? false
      public? true

      # SHA-256 hash
      constraints min_length: 64, max_length: 64
      description "SHA-256 hash of the content"
    end

    attribute :size, :integer do
      allow_nil? false
      public? true
      constraints min: 0
      description "Size of the content in bytes"
    end

    attribute :content_type, :string do
      allow_nil? false
      public? true
      default "application/octet-stream"
      description "MIME type of the content"
    end

    attribute :encoding, :string do
      public? true
      default "utf-8"
      description "Text encoding (for text content)"
    end

    create_timestamp :created_at
  end

  relationships do
    # TODO: Update blob system to work with new File architecture
    # has_many :document_blob_refs, Dirup.Workspaces.DocumentBlobRef do
    #   destination_attribute :blob_id
    # end

    # many_to_many :files, Dirup.Workspaces.File do
    #   through Dirup.Workspaces.DocumentBlobRef
    #   source_attribute_on_join_resource :blob_id
    #   destination_attribute_on_join_resource :file_id
    # end
  end

  calculations do
    calculate :reference_count, :integer do
      calculation fn blobs, _context ->
        # TODO: Update blob system to work with new File architecture
        # blob_ids = Enum.map(blobs, & &1.id)

        # counts = Dirup.Workspaces.DocumentBlobRef
        # |> Ash.Query.filter(blob_id in ^blob_ids)
        # |> Ash.Query.aggregate(:count, :blob_id, group: [:blob_id])
        # |> Ash.read!()
        # |> Map.new(fn %{blob_id: blob_id, count: count} -> {blob_id, count} end)

        Enum.map(blobs, fn _blob ->
          # Return 0 for now until blob system is updated
          0
        end)
      end
    end

    calculate :is_text, :boolean do
      load [:content_type]

      calculation fn blobs, _context ->
        Enum.map(blobs, fn blob ->
          String.starts_with?(blob.content_type, "text/") or
            blob.content_type in [
              "application/json",
              "application/xml",
              "application/javascript",
              "application/x-sh"
            ]
        end)
      end
    end

    calculate :storage_path, :string do
      load [:hash]

      calculation fn blobs, _context ->
        Enum.map(blobs, fn blob ->
          build_storage_path(blob.hash)
        end)
      end
    end
  end

  # Helper functions

  @doc """
  Generates SHA-256 hash for content.
  """
  def generate_hash(content) when is_binary(content) do
    :crypto.hash(:sha256, content)
    |> Base.encode16(case: :lower)
  end

  @doc """
  Builds storage path for blob content based on hash.
  Uses Git-like directory structure: first 2 chars / remaining chars
  """
  def build_storage_path(hash) when is_binary(hash) and byte_size(hash) == 64 do
    prefix = String.slice(hash, 0, 2)
    suffix = String.slice(hash, 2, 62)
    Path.join(["blobs", prefix, suffix])
  end

  @doc """
  Stores blob content to the configured storage backend.
  """
  def store_content(hash, content) do
    storage_path = build_storage_path(hash)
    backend = Application.get_env(:dirup, :blob_storage_backend, :disk)

    case backend do
      :disk ->
        store_content_disk(storage_path, content)

      :s3 ->
        store_content_s3(storage_path, content)

      _ ->
        {:error, "Unknown storage backend: #{backend}"}
    end
  end

  @doc """
  Retrieves blob content from storage.
  """
  def retrieve_content(hash) do
    storage_path = build_storage_path(hash)
    backend = Application.get_env(:dirup, :blob_storage_backend, :disk)

    case backend do
      :disk ->
        retrieve_content_disk(storage_path)

      :s3 ->
        retrieve_content_s3(storage_path)

      _ ->
        {:error, "Unknown storage backend: #{backend}"}
    end
  end

  # Private storage implementation functions

  defp store_content_disk(storage_path, content) do
    full_path = Path.join([blob_storage_root(), storage_path])

    with :ok <- File.mkdir_p(Path.dirname(full_path)),
         :ok <- File.write(full_path, content) do
      :ok
    else
      {:error, reason} -> {:error, "Failed to store blob: #{reason}"}
    end
  end

  defp retrieve_content_disk(storage_path) do
    full_path = Path.join([blob_storage_root(), storage_path])

    case File.read(full_path) do
      {:ok, content} -> {:ok, content}
      {:error, :enoent} -> {:error, "Blob not found"}
      {:error, reason} -> {:error, "Failed to retrieve blob: #{reason}"}
    end
  end

  defp store_content_s3(storage_path, content) do
    config = s3_config()
    bucket = config[:bucket]

    case ExAws.S3.put_object(bucket, storage_path, content)
         |> ExAws.request() do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, "Failed to store blob in S3: #{inspect(reason)}"}
    end
  end

  defp retrieve_content_s3(storage_path) do
    config = s3_config()
    bucket = config[:bucket]

    case ExAws.S3.get_object(bucket, storage_path)
         |> ExAws.request() do
      {:ok, %{body: content}} -> {:ok, content}
      {:error, {:http_error, 404, _}} -> {:error, "Blob not found in S3"}
      {:error, reason} -> {:error, "Failed to retrieve blob from S3: #{inspect(reason)}"}
    end
  end

  defp s3_config do
    Application.get_env(:dirup, :s3_storage, [])
  end

  defp blob_storage_root do
    Application.get_env(
      :dirup,
      :blob_storage_root,
      Path.join([File.cwd!(), "priv", "storage", "blobs"])
    )
  end

  @doc """
  Creates or finds existing blob for content.
  """
  def create_or_find(content, content_type \\ "application/octet-stream", encoding \\ "utf-8") do
    hash = generate_hash(content)

    case __MODULE__ |> Ash.Query.filter(hash == ^hash) |> Ash.read_one() do
      {:ok, existing_blob} when not is_nil(existing_blob) ->
        {:ok, existing_blob}

      {:ok, nil} ->
        case Ash.create(
               __MODULE__,
               %{
                 content: content,
                 content_type: content_type,
                 encoding: encoding
               },
               action: :create_blob
             ) do
          {:ok, blob} -> {:ok, blob}
          {:error, reason} -> {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Determines content type from content and filename.
  """
  def detect_content_type(content, filename \\ nil) do
    cond do
      filename && String.ends_with?(filename, ".md") ->
        "text/markdown"

      filename && String.ends_with?(filename, ".json") ->
        "application/json"

      filename && String.ends_with?(filename, ".html") ->
        "text/html"

      filename && String.ends_with?(filename, ".js") ->
        "application/javascript"

      filename && String.ends_with?(filename, ".py") ->
        "text/x-python"

      is_text_content?(content) ->
        "text/plain"

      true ->
        "application/octet-stream"
    end
  end

  @doc """
  Checks if content appears to be text.
  """
  def is_text_content?(content) when is_binary(content) do
    # Simple heuristic: check for null bytes and high percentage of printable chars
    not String.contains?(content, <<0>>) and
      String.printable?(content, 0.8)
  end

  @doc """
  Checks if S3 storage is properly configured.
  """
  def s3_configured? do
    config = s3_config()

    config[:bucket] != nil and
      config[:region] != nil and
      (config[:access_key_id] != nil or System.get_env("AWS_ACCESS_KEY_ID") != nil) and
      (config[:secret_access_key] != nil or System.get_env("AWS_SECRET_ACCESS_KEY") != nil)
  end

  @doc """
  Tests S3 connectivity by attempting to list bucket contents.
  """
  def test_s3_connection do
    if not s3_configured?() do
      {:error, "S3 not configured"}
    else
      config = s3_config()
      bucket = config[:bucket]

      case ExAws.S3.list_objects_v2(bucket, max_keys: 1)
           |> ExAws.request() do
        {:ok, _} -> :ok
        {:error, reason} -> {:error, "S3 connection failed: #{inspect(reason)}"}
      end
    end
  end

  @doc """
  Migrates blobs from disk to S3 storage.
  """
  def migrate_to_s3 do
    if not s3_configured?() do
      {:error, "S3 not configured"}
    else
      case __MODULE__ |> Ash.read() do
        {:ok, blobs} ->
          results = Enum.map(blobs, &migrate_blob_to_s3/1)
          failed = Enum.filter(results, &match?({:error, _}, &1))

          if Enum.empty?(failed) do
            {:ok, "Migrated #{length(blobs)} blobs to S3"}
          else
            {:error, "Migration partially failed: #{length(failed)} blobs failed"}
          end

        {:error, reason} ->
          {:error, "Failed to list blobs: #{inspect(reason)}"}
      end
    end
  end

  defp migrate_blob_to_s3(blob) do
    disk_path = Path.join([blob_storage_root(), build_storage_path(blob.hash)])

    case File.read(disk_path) do
      {:ok, content} ->
        case store_content_s3(build_storage_path(blob.hash), content) do
          :ok -> {:ok, blob.hash}
          {:error, reason} -> {:error, {blob.hash, reason}}
        end

      {:error, reason} ->
        {:error, {blob.hash, "Failed to read from disk: #{reason}"}}
    end
  end
end
