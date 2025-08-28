defmodule Dirup.Workspaces.BlobTest do
  use Dirup.DataCase, async: true

  alias Dirup.Workspaces.Blob
  alias Dirup.Workspaces

  describe "blob creation and storage" do
    test "creates blob with content and generates hash" do
      content = "Hello, World!"

      assert {:ok, blob} = Workspaces.create_blob(content: content, content_type: "text/plain")

      assert blob.hash == Blob.generate_hash(content)
      assert blob.size == byte_size(content)
      assert blob.content_type == "text/plain"
      assert blob.encoding == "utf-8"
    end

    test "generates consistent hash for same content" do
      content = "Test content for hashing"

      hash1 = Blob.generate_hash(content)
      hash2 = Blob.generate_hash(content)

      assert hash1 == hash2
      # SHA-256 hex string
      assert String.length(hash1) == 64
      assert Regex.match?(~r/^[a-f0-9]{64}$/, hash1)
    end

    test "creates different hashes for different content" do
      content1 = "First content"
      content2 = "Second content"

      hash1 = Blob.generate_hash(content1)
      hash2 = Blob.generate_hash(content2)

      assert hash1 != hash2
    end

    test "deduplicates identical content" do
      content = "Duplicate content test"

      # Create first blob
      assert {:ok, blob1} = Workspaces.create_blob(content: content, content_type: "text/plain")

      # Try to create second blob with same content
      assert {:ok, blob2} =
               Workspaces.find_or_create_blob(content: content, content_type: "text/plain")

      # Should return the same blob (deduplication)
      assert blob1.id == blob2.id
      assert blob1.hash == blob2.hash
    end

    test "handles different content types" do
      json_content = ~s({"key": "value"})

      assert {:ok, blob} =
               Workspaces.create_blob(
                 content: json_content,
                 content_type: "application/json"
               )

      assert blob.content_type == "application/json"
    end

    test "handles binary content" do
      binary_content = <<1, 2, 3, 4, 5>>

      assert {:ok, blob} =
               Workspaces.create_blob(
                 content: binary_content,
                 content_type: "application/octet-stream"
               )

      assert blob.size == 5
      assert blob.content_type == "application/octet-stream"
    end
  end

  describe "blob content retrieval" do
    test "retrieves stored content correctly" do
      content = "Content to retrieve"

      assert {:ok, blob} = Workspaces.create_blob(content: content)
      assert {:ok, retrieved_content} = Workspaces.get_blob_content(blob.id)

      assert retrieved_content == content
    end

    test "handles missing blob gracefully" do
      non_existent_id = Ash.UUID.generate()

      assert {:error, _reason} = Workspaces.get_blob_content(non_existent_id)
    end
  end

  describe "blob utilities" do
    test "builds correct storage path" do
      # 64 char hash
      hash = "abcdef1234567890" <> String.duplicate("0", 48)

      path = Blob.build_storage_path(hash)

      assert path == "blobs/ab/cdef1234567890" <> String.duplicate("0", 46)
    end

    test "detects content type from filename" do
      assert Blob.detect_content_type("", "test.md") == "text/markdown"
      assert Blob.detect_content_type("", "test.json") == "application/json"
      assert Blob.detect_content_type("", "test.html") == "text/html"
      assert Blob.detect_content_type("", "test.js") == "application/javascript"
      assert Blob.detect_content_type("", "test.py") == "text/x-python"
    end

    test "detects text content" do
      assert Blob.is_text_content?("Hello, World!")
      assert Blob.is_text_content?("Multi\nline\ntext")
      refute Blob.is_text_content?(<<0, 1, 2, 3>>)
    end

    test "create_or_find helper function" do
      content = "Helper function test"

      # First call creates
      assert {:ok, blob1} = Blob.create_or_find(content, "text/plain")

      # Second call finds existing
      assert {:ok, blob2} = Blob.create_or_find(content, "text/plain")

      assert blob1.id == blob2.id
    end
  end

  describe "validations" do
    test "requires valid hash format" do
      invalid_params = %{
        hash: "invalid-hash",
        size: 10,
        content_type: "text/plain"
      }

      assert {:error, %Ash.Error.Invalid{}} = Ash.create(Blob, invalid_params)
    end

    test "requires non-negative size" do
      content = "Test content"

      # This should fail at the changeset level since we auto-calculate size
      changeset =
        Ash.Changeset.for_create(Blob, :create_blob, %{
          content: content,
          content_type: "text/plain"
        })

      # Manually override size to negative (simulating bad data)
      changeset = Ash.Changeset.change_attribute(changeset, :size, -1)

      assert {:error, %Ash.Error.Invalid{}} = Ash.create(changeset)
    end

    test "requires hash and content_type" do
      assert {:error, %Ash.Error.Invalid{}} = Ash.create(Blob, %{size: 10})
    end
  end

  describe "blob reference counting" do
    setup do
      content = "Referenced content"
      {:ok, blob} = Workspaces.create_blob(content: content)

      %{blob: blob, content: content}
    end

    test "calculates reference count correctly", %{blob: blob} do
      # Create some documents that reference this blob
      user = insert(:user)
      workspace = insert(:workspace, user: user)

      # Create documents
      {:ok, doc1} =
        Workspaces.create_document(
          %{
            title: "Doc 1",
            workspace_id: workspace.id
          },
          actor: user
        )

      {:ok, doc2} =
        Workspaces.create_document(
          %{
            title: "Doc 2",
            workspace_id: workspace.id
          },
          actor: user
        )

      # Create blob references
      {:ok, _ref1} =
        Workspaces.create_ref(%{
          document_id: doc1.id,
          blob_id: blob.id,
          ref_type: "content"
        })

      {:ok, _ref2} =
        Workspaces.create_ref(%{
          document_id: doc2.id,
          blob_id: blob.id,
          ref_type: "content"
        })

      # Load blob with reference count
      {:ok, blob_with_count} = Workspaces.get_blob(blob.id, load: [:reference_count])

      assert blob_with_count.reference_count == 2
    end
  end

  describe "S3 storage configuration" do
    test "checks S3 configuration status" do
      # This will depend on test environment setup
      # In most cases, S3 won't be configured in test
      refute Blob.s3_configured?()
    end

    @tag :integration
    test "S3 connection test" do
      case Blob.test_s3_connection() do
        :ok ->
          # S3 is configured and working
          assert true

        {:error, "S3 not configured"} ->
          # Expected in test environment
          assert true

        {:error, reason} ->
          # S3 is configured but connection failed
          flunk("S3 connection failed: #{reason}")
      end
    end
  end

  describe "disk storage" do
    test "stores and retrieves content from disk" do
      content = "Disk storage test content"

      # Ensure we're using disk storage for this test
      original_backend = Application.get_env(:dirup, :blob_storage_backend)
      Application.put_env(:dirup, :blob_storage_backend, :disk)

      try do
        assert {:ok, blob} = Workspaces.create_blob(content: content)
        assert {:ok, retrieved} = Workspaces.get_blob_content(blob.id)
        assert retrieved == content
      after
        Application.put_env(:dirup, :blob_storage_backend, original_backend)
      end
    end

    test "handles storage path creation" do
      content = "Path creation test"
      hash = Blob.generate_hash(content)
      storage_path = Blob.build_storage_path(hash)

      # Verify path structure
      assert String.starts_with?(storage_path, "blobs/")
      parts = String.split(storage_path, "/")
      assert length(parts) == 3
      # First 2 chars of hash
      assert String.length(Enum.at(parts, 1)) == 2
    end
  end

  describe "blob lifecycle" do
    test "prevents deletion of referenced blobs" do
      user = insert(:user)
      workspace = insert(:workspace, user: user)
      content = "Protected content"

      {:ok, blob} = Workspaces.create_blob(content: content)

      {:ok, document} =
        Workspaces.create_document(
          %{
            title: "Protected Document",
            workspace_id: workspace.id
          },
          actor: user
        )

      {:ok, _ref} =
        Workspaces.create_ref(%{
          document_id: document.id,
          blob_id: blob.id,
          ref_type: "content"
        })

      # Should not be able to delete blob with references
      assert {:error, %Ash.Error.Forbidden{}} = Ash.destroy(blob)
    end

    test "allows deletion of unreferenced blobs" do
      content = "Unreferenced content"

      {:ok, blob} = Workspaces.create_blob(content: content)

      # Should be able to delete blob without references
      assert :ok = Ash.destroy(blob)
    end
  end

  describe "blob aggregates and calculations" do
    test "calculates storage path" do
      content = "Path calculation test"

      {:ok, blob} = Workspaces.create_blob(content: content)
      {:ok, blob_with_path} = Workspaces.get_blob(blob.id, load: [:storage_path])

      expected_path = Blob.build_storage_path(blob.hash)
      assert blob_with_path.storage_path == expected_path
    end

    test "determines if content is text" do
      {:ok, text_blob} =
        Workspaces.create_blob(
          content: "Text content",
          content_type: "text/plain"
        )

      {:ok, json_blob} =
        Workspaces.create_blob(
          content: ~s({"key": "value"}),
          content_type: "application/json"
        )

      {:ok, binary_blob} =
        Workspaces.create_blob(
          content: <<1, 2, 3, 4>>,
          content_type: "application/octet-stream"
        )

      {:ok, text_blob_loaded} = Workspaces.get_blob(text_blob.id, load: [:is_text])
      {:ok, json_blob_loaded} = Workspaces.get_blob(json_blob.id, load: [:is_text])
      {:ok, binary_blob_loaded} = Workspaces.get_blob(binary_blob.id, load: [:is_text])

      assert text_blob_loaded.is_text
      # JSON is considered text
      assert json_blob_loaded.is_text
      refute binary_blob_loaded.is_text
    end
  end

  describe "error handling" do
    test "handles storage backend errors gracefully" do
      # Simulate storage backend failure by using invalid backend
      original_backend = Application.get_env(:dirup, :blob_storage_backend)
      Application.put_env(:dirup, :blob_storage_backend, :invalid_backend)

      try do
        content = "Error handling test"

        assert {:error, %Ash.Error.Invalid{}} = Workspaces.create_blob(content: content)
      after
        Application.put_env(:dirup, :blob_storage_backend, original_backend)
      end
    end

    test "handles file system errors" do
      # This would require mocking File operations for comprehensive testing
      # For now, we'll test with an invalid storage root
      original_root = Application.get_env(:dirup, :blob_storage_root)
      Application.put_env(:dirup, :blob_storage_root, "/invalid/path/that/does/not/exist")
      Application.put_env(:dirup, :blob_storage_backend, :disk)

      try do
        content = "File system error test"

        # This should fail due to invalid storage path
        assert {:error, %Ash.Error.Invalid{}} = Workspaces.create_blob(content: content)
      after
        Application.put_env(:dirup, :blob_storage_root, original_root)
      end
    end
  end

  # Helper function to create test blob
  defp create_test_blob(content \\ "Test content", content_type \\ "text/plain") do
    {:ok, blob} = Workspaces.create_blob(content: content, content_type: content_type)
    blob
  end
end
