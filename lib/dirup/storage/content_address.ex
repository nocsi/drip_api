defmodule Dirup.Storage.ContentAddress do
  @moduledoc """
  Content-addressable storage record.

  Stores content by its SHA-256 hash with optional JSON-LD metadata and
  reference counting to support deduplication and garbage collection.
  """

  use Ash.Resource,
    otp_app: :dirup,
    domain: Dirup.Storage,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "storage_content_addresses"
    repo Dirup.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :put do
      accept [:content, :metadata_ld]

      change {__MODULE__.Changes.ComputeHashAndSize, []}
      change set_attribute(:reference_count, 1)
      upsert? true
      upsert_identity :primary
      upsert_fields [:reference_count, :content, :metadata_ld, :size_bytes, :updated_at]
    end

    update :increment_ref do
      accept []
      change increment(:reference_count)
    end

    update :decrement_ref do
      accept []
      change increment(:reference_count, amount: -1)
    end
  end

  identities do
    identity :primary, [:content_hash]
  end

  attributes do
    attribute :content_hash, :string do
      allow_nil? false
      primary_key? true
      description "SHA-256 hex digest of content"
    end

    attribute :content, :binary do
      allow_nil? false
      description "Raw content bytes"
    end

    attribute :metadata_ld, :map do
      description "JSON-LD metadata for the content"
      default %{}
    end

    attribute :size_bytes, :integer do
      allow_nil? false
      description "Size of content in bytes"
    end

    attribute :reference_count, :integer do
      allow_nil? false
      default 0
      description "Number of references to this content"
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  validations do
    validate present(:content)
  end

  defmodule Changes.ComputeHashAndSize do
    @moduledoc false
    use Ash.Resource.Change

    def change(changeset, _opts, _ctx) do
      with {:ok, content} <- Ash.Changeset.fetch_argument_or_change(changeset, :content) do
        hash = :crypto.hash(:sha256, content) |> Base.encode16(case: :lower)
        changeset
        |> Ash.Changeset.force_change_attribute(:content_hash, hash)
        |> Ash.Changeset.force_change_attribute(:size_bytes, byte_size(content))
      else
        _ -> changeset
      end
    end
  end
end
