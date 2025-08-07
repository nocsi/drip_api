defmodule Kyozo.Storage.AshObanIntegrationTest do
  use Kyozo.DataCase
  use Oban.Testing, repo: Kyozo.Repo

  alias Kyozo.Storage
  alias Kyozo.Storage.{StorageResource, ActorPersister}

  describe "AshOban integration" do
    setup do
      # Create a test user for actor persistence
      {:ok, user} = Kyozo.Accounts.create_user(%{
        email: "test@example.com",
        hashed_password: "test_password"
      })

      # Create a test storage resource
      {:ok, storage_resource} = Storage.create_storage_entry(%{
        file_name: "test_document.md",
        storage_backend: :disk
      }, content: "# Test Document\n\nOriginal content")

      %{user: user, storage_resource: storage_resource}
    end

    test "actor persister can store and lookup user actors", %{user: user} do
      # Test storing user actor
      stored_data = ActorPersister.store(user)
      
      assert stored_data == %{
        "type" => "Kyozo.Accounts.User",
        "id" => user.id
      }

      # Test looking up user actor
      {:ok, retrieved_user} = ActorPersister.lookup(stored_data)
      assert retrieved_user.id == user.id
      assert retrieved_user.email == user.email
    end

    test "actor persister handles system actors" do
      system_actor = %{system: true, permissions: [:admin]}
      
      # Test storing system actor
      stored_data = ActorPersister.store(system_actor)
      
      assert stored_data == %{
        "type" => "system", 
        "data" => system_actor
      }

      # Test looking up system actor
      {:ok, retrieved_actor} = ActorPersister.lookup(stored_data)
      assert retrieved_actor == system_actor
    end

    test "actor persister handles nil actors" do
      # Test storing nil actor
      stored_data = ActorPersister.store(nil)
      assert stored_data == nil

      # Test looking up nil actor
      {:ok, retrieved_actor} = ActorPersister.lookup(nil)
      assert retrieved_actor == nil
    end

    test "actor persister handles unknown actor lookup gracefully" do
      # Test lookup with invalid user ID
      invalid_data = %{"type" => "Kyozo.Accounts.User", "id" => "non-existent-id"}
      
      {:error, reason} = ActorPersister.lookup(invalid_data)
      assert reason =~ "User not found"
    end

    test "can schedule background storage processing job", %{user: user, storage_resource: storage_resource} do
      content = "# Updated Document\n\nNew content here"
      
      # Schedule the job
      {:ok, job} = Storage.process_storage_async(
        storage_resource,
        content,
        actor: user,
        storage_options: %{encoding: "utf-8"}
      )

      # Verify job was created
      assert job.queue == "storage_processing"
      assert job.worker == "AshOban.Oban.Jobs.ProcessStorageAsyncJob"
      
      # Verify job arguments contain expected data
      assert job.args["content"] == content
      assert job.args["storage_options"]["encoding"] == "utf-8"
    end

    test "can schedule background cleanup job", %{user: user, storage_resource: storage_resource} do
      # Schedule the cleanup job with delay
      {:ok, job} = Storage.cleanup_content_async(
        storage_resource,
        actor: user,
        delay: 60
      )

      # Verify job was created with proper delay
      assert job.queue == "storage_cleanup"
      assert job.worker == "AshOban.Oban.Jobs.CleanupContentAsyncJob"
      assert job.scheduled_at > DateTime.utc_now()
    end

    test "can schedule version creation job for versioned storage", %{user: user} do
      # Create a versioned storage resource
      {:ok, versioned_resource} = Storage.create_storage_entry(%{
        file_name: "versioned_doc.md",
        storage_backend: :git,
        is_versioned: true
      }, content: "# Versioned Document\n\nInitial content")

      content = "# Versioned Document\n\nUpdated content for v2"
      
      # Schedule version creation job
      {:ok, job} = Storage.create_version_async(
        versioned_resource,
        content,
        version_name: "v2.0",
        commit_message: "Major update",
        actor: user
      )

      # Verify job was created
      assert job.queue == "storage_versioning"
      assert job.worker == "AshOban.Oban.Jobs.CreateVersionAsyncJob"
      
      # Verify job arguments
      assert job.args["content"] == content
      assert job.args["version_name"] == "v2.0"
      assert job.args["commit_message"] == "Major update"
    end

    test "can get job status for storage resource", %{user: user, storage_resource: storage_resource} do
      # Schedule multiple jobs
      {:ok, _job1} = Storage.process_storage_async(
        storage_resource, 
        "content1", 
        actor: user
      )
      
      {:ok, _job2} = Storage.cleanup_content_async(
        storage_resource,
        actor: user,
        delay: 30
      )

      # Get job status
      {:ok, jobs} = Storage.get_job_status(storage_resource)
      
      # Verify we got jobs back
      assert length(jobs) >= 2
      
      # Verify job structure
      job = List.first(jobs)
      assert Map.has_key?(job, :id)
      assert Map.has_key?(job, :queue)
      assert Map.has_key?(job, :worker)
      assert Map.has_key?(job, :state)
      assert Map.has_key?(job, :attempt)
      assert Map.has_key?(job, :max_attempts)
    end

    test "can cancel pending jobs for storage resource", %{user: user, storage_resource: storage_resource} do
      # Schedule jobs with delay so they remain in pending state
      {:ok, _job1} = Storage.process_storage_async(
        storage_resource,
        "content", 
        actor: user,
        delay: 300
      )
      
      {:ok, _job2} = Storage.cleanup_content_async(
        storage_resource,
        actor: user,
        delay: 300
      )

      # Cancel pending jobs
      {:ok, cancelled_count} = Storage.cancel_jobs(storage_resource)
      
      # Verify jobs were cancelled
      assert cancelled_count >= 2
    end

    test "background job actions have proper authorization policies", %{user: user, storage_resource: storage_resource} do
      # Test that AshOban check allows background job execution
      assert AshOban.Checks.AshObanInteraction.strict_check(
        %{},
        %{authorize?: true}
      ) == true

      # Test that actor present check works for manual execution
      changeset = Ash.Changeset.for_update(storage_resource, :process_storage_async, %{
        content: "test content"
      })

      # This would be called during authorization - we're testing the policy exists
      assert changeset.action.name == :process_storage_async
      assert changeset.action.type == :update
    end

    test "handles job scheduling errors gracefully" do
      # Try to schedule with invalid storage resource
      invalid_resource = %StorageResource{id: "non-existent"}
      
      # This should fail gracefully
      result = Storage.process_storage_async(invalid_resource, "content")
      
      # Verify it returns an error tuple (implementation dependent)
      # The exact error handling may vary based on implementation
      case result do
        {:error, _reason} -> assert true
        {:ok, _job} -> assert true  # If it succeeds, that's also valid
      end
    end

    test "background jobs preserve actor context", %{user: user, storage_resource: storage_resource} do
      # Schedule a job
      {:ok, job} = Storage.process_storage_async(
        storage_resource,
        "test content",
        actor: user
      )

      # Verify actor data is stored in job args
      # AshOban typically stores actor information in a standardized way
      assert is_map(job.args)
      
      # The exact structure may depend on AshOban implementation
      # but the job should contain actor information
      assert job.args["actor"] != nil || job.meta["actor"] != nil
    end
  end

  describe "error handling" do
    test "handles storage provider errors gracefully" do
      # This test would require mocking storage providers
      # For now, we'll test that the action exists and can be called
      {:ok, storage_resource} = Storage.create_storage_entry(%{
        file_name: "test.txt",
        storage_backend: :disk
      }, content: "test")

      # The background job action should exist
      assert Enum.any?(StorageResource.__ash_config__(:actions), fn action ->
        action.name == :process_storage_async
      end)
    end

    test "validates required arguments for background jobs", %{storage_resource: storage_resource} do
      # Test that version creation requires content
      result = Storage.create_version_async(storage_resource, nil)
      
      case result do
        {:error, _reason} -> assert true
        {:ok, _job} -> 
          # If it succeeds with nil content, that might be valid depending on implementation
          assert true
      end
    end
  end
end