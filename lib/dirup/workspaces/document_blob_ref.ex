defmodule Dirup.Workspaces.DocumentBlobRef do
  @moduledoc """
  Document blob reference management for workspace files.

  This module manages references between workspace documents and their
  underlying storage blobs.
  """

  use Ash.Resource,
    domain: Dirup.Workspaces,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "document_blob_refs"
    repo Dirup.Repo
  end

  actions do
    defaults [:read, :create, :update, :destroy]
  end

  attributes do
    uuid_primary_key :id
    attribute :file_id, :uuid, allow_nil?: false
    attribute :storage_resource_id, :uuid
    attribute :content_hash, :string
    attribute :content_size, :integer
    attribute :is_primary, :boolean, default: true
    timestamps()
  end

  relationships do
    belongs_to :file, Dirup.Workspaces.File
  end
end
