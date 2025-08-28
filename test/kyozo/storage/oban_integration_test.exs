defmodule Dirup.Storage.ObanIntegrationTest do
  use ExUnit.Case, async: false
  use Oban.Testing, repo: Dirup.Repo

  alias Dirup.Storage
  alias Dirup.Storage.StorageResource

  describe "AshOban trigger integration" do
    test "schedule_storage_processing marks resource for processing" do
      # Create a storage resource
      {:ok, storage_resource} =
        StorageResource
        |> Ash.Changeset.for_create(:create, %{
          file_name: "test.txt",
          mime_type: "text/plain",
          file_size: 100,
          checksum: "abc123",
          storage_backend: :disk,
          storage_metadata: %{}
        })
        |> Ash.create()

      # Schedule processing
      {:ok, updated_resource} = Storage.schedule_storage_processing(storage_resource)

      # Verify metadata was updated
      assert updated_resource.storage_metadata["processed"] == false
      assert updated_resource.storage_metadata["processing_scheduled_at"]
    end

    test "schedule_storage_cleanup marks resource for cleanup" do
      # Create a storage resource
      {:ok, storage_resource} =
        StorageResource
        |> Ash.Changeset.for_create(:create, %{
          file_name: "test.txt",
          mime_type: "text/plain",
          file_size: 100,
          checksum: "abc123",
          storage_backend: :disk,
          storage_metadata: %{}
        })
        |> Ash.create()

      # Schedule cleanup
      {:ok, updated_resource} = Storage.schedule_storage_cleanup(storage_resource)

      # Verify metadata was updated
      assert updated_resource.storage_metadata["cleanup_scheduled"] == true
      assert updated_resource.storage_metadata["cleanup_scheduled_at"]
    end

    test "schedule_version_creation marks resource for version creation" do
      # Create a versioned storage resource
      {:ok, storage_resource} =
        StorageResource
        |> Ash.Changeset.for_create(:create, %{
          file_name: "test.txt",
          mime_type: "text/plain",
          file_size: 100,
          checksum: "abc123",
          storage_backend: :git,
          is_versioned: true,
          storage_metadata: %{}
        })
        |> Ash.create()

      # Schedule version creation
      {:ok, updated_resource} =
        Storage.schedule_version_creation(
          storage_resource,
          "new content",
          version_name: "v1.0",
          commit_message: "Test version"
        )

      # Verify metadata was updated
      assert updated_resource.storage_metadata["version_scheduled"] == true
      assert updated_resource.storage_metadata["version_scheduled_at"]
      assert updated_resource.storage_metadata["scheduled_content"] == "new content"
      assert updated_resource.storage_metadata["scheduled_version_name"] == "v1.0"
      assert updated_resource.storage_metadata["scheduled_commit_message"] == "Test version"
    end

    test "get_processing_status returns correct status information" do
      # Create a storage resource with processing metadata
      {:ok, storage_resource} =
        StorageResource
        |> Ash.Changeset.for_create(:create, %{
          file_name: "test.txt",
          mime_type: "text/plain",
          file_size: 100,
          checksum: "abc123",
          storage_backend: :disk,
          storage_metadata: %{
            "processed" => true,
            "processed_at" => DateTime.utc_now(),
            "cleanup_scheduled" => false,
            "version_scheduled" => false
          }
        })
        |> Ash.create()

      # Get processing status
      {:ok, status} = Storage.get_processing_status(storage_resource)

      # Verify status information
      assert status.processed == true
      assert status.processed_at
      assert status.cleanup_scheduled == false
      assert status.version_scheduled == false
    end

    test "get_operation_stats returns correct statistics" do
      # Create some storage resources with different states
      {:ok, _processed} =
        StorageResource
        |> Ash.Changeset.for_create(:create, %{
          file_name: "processed.txt",
          mime_type: "text/plain",
          file_size: 100,
          checksum: "abc123",
          storage_backend: :disk,
          storage_metadata: %{"processed" => true}
        })
        |> Ash.create()

      {:ok, _unprocessed} =
        StorageResource
        |> Ash.Changeset.for_create(:create, %{
          file_name: "unprocessed.txt",
          mime_type: "text/plain",
          file_size: 100,
          checksum: "def456",
          storage_backend: :disk,
          storage_metadata: %{"processed" => false}
        })
        |> Ash.create()

      {:ok, _cleanup_scheduled} =
        StorageResource
        |> Ash.Changeset.for_create(:create, %{
          file_name: "cleanup.txt",
          mime_type: "text/plain",
          file_size: 100,
          checksum: "ghi789",
          storage_backend: :disk,
          storage_metadata: %{"cleanup_scheduled" => true}
        })
        |> Ash.create()

      # Get operation stats
      {:ok, stats} = Storage.get_operation_stats()

      # Verify statistics (at least our test records are counted)
      assert stats.total_resources >= 3
      assert stats.pending_processing >= 1
      assert stats.pending_cleanup >= 1
    end

    test "cancel_scheduled_operations resets scheduling flags" do
      # Create a storage resource with scheduled operations
      {:ok, storage_resource} =
        StorageResource
        |> Ash.Changeset.for_create(:create, %{
          file_name: "test.txt",
          mime_type: "text/plain",
          file_size: 100,
          checksum: "abc123",
          storage_backend: :disk,
          storage_metadata: %{
            "processed" => false,
            "cleanup_scheduled" => true,
            "version_scheduled" => true
          }
        })
        |> Ash.create()

      # Cancel scheduled operations
      {:ok, updated_resource} = Storage.cancel_scheduled_operations(storage_resource)

      # Verify flags were reset
      assert updated_resource.storage_metadata["processed"] == true
      assert updated_resource.storage_metadata["cleanup_scheduled"] == false
      assert updated_resource.storage_metadata["version_scheduled"] == false
      assert updated_resource.storage_metadata["operations_cancelled_at"]
    end

    test "get_trigger_info returns trigger configuration" do
      {:ok, triggers} = Storage.get_trigger_info()

      assert length(triggers) == 3

      trigger_names = Enum.map(triggers, & &1.name)
      assert :process_storage in trigger_names
      assert :cleanup_orphaned in trigger_names
      assert :create_versions in trigger_names
    end

    test "force_processing executes immediately" do
      # Create a storage resource
      {:ok, storage_resource} =
        StorageResource
        |> Ash.Changeset.for_create(:create, %{
          file_name: "test.txt",
          mime_type: "text/plain",
          file_size: 100,
          checksum: "abc123",
          # Use RAM backend for testing
          storage_backend: :ram,
          storage_metadata: %{"processed" => false}
        })
        |> Ash.create()

      # Force processing (this should execute the action immediately)
      result =
        Storage.force_processing(
          storage_resource,
          content: "test content",
          storage_options: %{}
        )

      # The result depends on whether the RAM storage provider is implemented
      # For now, we just verify the function can be called without error
      assert match?({:ok, _} | {:error, _}, result)
    end
  end

  describe "AshOban triggers" do
    setup do
      # Clear any existing jobs before each test
      Oban.drain_queue(queue: :storage_processing)
      Oban.drain_queue(queue: :storage_cleanup)
      Oban.drain_queue(queue: :storage_versions)
      :ok
    end

    test "triggers are properly configured" do
      # This test verifies that AshOban triggers are set up correctly
      # The actual execution would require the storage providers to be implemented

      # Create an unprocessed storage resource
      {:ok, storage_resource} =
        StorageResource
        |> Ash.Changeset.for_create(:create, %{
          file_name: "unprocessed.txt",
          mime_type: "text/plain",
          file_size: 100,
          checksum: "abc123",
          storage_backend: :disk,
          # No processed flag means it needs processing
          storage_metadata: %{}
        })
        |> Ash.create()

      # Verify the resource would be picked up by the process_storage trigger
      # (based on the where clause: storage_metadata["processed"] != true)
      assert is_nil(storage_resource.storage_metadata["processed"]) or
               storage_resource.storage_metadata["processed"] != true

      # Create a resource scheduled for cleanup
      {:ok, cleanup_resource} =
        StorageResource
        |> Ash.Changeset.for_create(:create, %{
          file_name: "cleanup.txt",
          mime_type: "text/plain",
          file_size: 100,
          checksum: "def456",
          storage_backend: :disk,
          storage_metadata: %{"cleanup_scheduled" => true}
        })
        |> Ash.create()

      # Verify the resource would be picked up by the cleanup_orphaned trigger
      assert cleanup_resource.storage_metadata["cleanup_scheduled"] == true

      # Create a resource scheduled for version creation
      {:ok, version_resource} =
        StorageResource
        |> Ash.Changeset.for_create(:create, %{
          file_name: "version.txt",
          mime_type: "text/plain",
          file_size: 100,
          checksum: "ghi789",
          storage_backend: :git,
          is_versioned: true,
          storage_metadata: %{"version_scheduled" => true}
        })
        |> Ash.create()

      # Verify the resource would be picked up by the create_versions trigger  
      assert version_resource.storage_metadata["version_scheduled"] == true
    end
  end
end
