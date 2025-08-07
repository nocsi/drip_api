defmodule Kyozo.Workspaces.DocumentBlobRefTest do
  use Kyozo.DataCase, async: true

  alias Kyozo.Workspaces.DocumentBlobRef
  alias Kyozo.Workspaces.Blob
  alias Kyozo.Workspaces.Document
  alias Kyozo.Workspaces
  alias Kyozo.Accounts

  describe "document blob reference creation" do
    setup do
      user = insert(:user)
      workspace = insert(:workspace, user: user)
      
      {:ok, document} = Workspaces.create_document(%{
        title: "Test Document",
        workspace_id: workspace.id
      }, actor: user)
      
      content = "Test document content"
      {:ok, blob} = Workspaces.create_blob(content: content, content_type: "text/markdown")
      
      %{user: user, workspace: workspace, document: document, blob: blob, content: content}
    end

    test "creates blob reference for document", %{document: document, blob: blob} do
      assert {:ok, ref} = Workspaces.create_ref(%{
        document_id: document.id,
        blob_id: blob.id,
        ref_type: "content"
      })
      
      assert ref.document_id == document.id
      assert ref.blob_id == blob.id
      assert ref.ref_type == "content"
    end

    test "creates blob reference with content using link_content action", %{document: document} do
      content = "New content via link_content"
      
      assert {:ok, ref} = Workspaces.link_content(
        document_id: document.id,
        content: content,
        content_type: "text/markdown",
        ref_type: "content"
      )
      
      assert ref.document_id == document.id
      assert ref.ref_type == "content"
      
      # Verify blob was created
      {:ok, ref_with_blob} = Workspaces.get_document_blob_ref(ref.id, load: [:blob])
      assert ref_with_blob.blob.content_type == "text/markdown"
      assert ref_with_blob.blob.size == byte_size(content)
    end

    test "prevents duplicate references for same document and ref_type", %{document: document, blob: blob} do
      # Create first reference
      assert {:ok, _ref1} = Workspaces.create_ref(%{
        document_id: document.id,
        blob_id: blob.id,
        ref_type: "content"
      })
      
      # Try to create duplicate
      assert {:error, %Ash.Error.Invalid{}} = Workspaces.create_ref(%{
        document_id: document.id,
        blob_id: blob.id,
        ref_type: "content"
      })
    end

    test "allows multiple ref_types for same document", %{document: document, blob: blob} do
      {:ok, blob2} = Workspaces.create_blob(content: "Attachment content", content_type: "text/plain")
      
      # Create content reference
      assert {:ok, _ref1} = Workspaces.create_ref(%{
        document_id: document.id,
        blob_id: blob.id,
        ref_type: "content"
      })
      
      # Create attachment reference
      assert {:ok, _ref2} = Workspaces.create_ref(%{
        document_id: document.id,
        blob_id: blob2.id,
        ref_type: "attachment"
      })
    end
  end

  describe "content retrieval and management" do
    setup do
      user = insert(:user)
      workspace = insert(:workspace, user: user)
      
      {:ok, document} = Workspaces.create_document(%{
        title: "Test Document",
        workspace_id: workspace.id
      }, actor: user)
      
      content = "Document main content"
      {:ok, _ref} = Workspaces.link_content(
        document_id: document.id,
        content: content,
        content_type: "text/markdown",
        ref_type: "content"
      )
      
      %{user: user, document: document, content: content}
    end

    test "retrieves document content", %{document: document, content: content} do
      assert {:ok, retrieved_content} = DocumentBlobRef.get_document_content(document.id)
      assert retrieved_content == content
    end

    test "updates document content", %{document: document} do
      new_content = "Updated document content"
      
      assert {:ok, _ref} = DocumentBlobRef.update_document_content(
        document.id, 
        new_content, 
        "text/markdown"
      )
      
      assert {:ok, retrieved_content} = DocumentBlobRef.get_document_content(document.id)
      assert retrieved_content == new_content
    end

    test "creates new blob for updated content", %{document: document} do
      original_content = "Original content"
      updated_content = "Updated content"
      
      # Update content
      assert {:ok, _ref} = DocumentBlobRef.update_document_content(
        document.id,
        updated_content,
        "text/markdown"
      )
      
      # Verify new blob was created (not updated in place)
      original_hash = Blob.generate_hash(original_content)
      updated_hash = Blob.generate_hash(updated_content)
      
      assert original_hash != updated_hash
      
      # Both blobs should exist
      assert {:ok, _} = Workspaces.blob_exists?(original_hash)  
      assert {:ok, _} = Workspaces.blob_exists?(updated_hash)
    end

    test "handles missing document gracefully" do
      non_existent_id = Ash.UUID.generate()
      
      assert {:error, "No content found for document"} = 
        DocumentBlobRef.get_document_content(non_existent_id)
    end
  end

  describe "blob reference queries" do
    setup do
      user = insert(:user)
      workspace = insert(:workspace, user: user)
      
      {:ok, document} = Workspaces.create_document(%{
        title: "Multi-ref Document",
        workspace_id: workspace.id
      }, actor: user)
      
      # Create multiple blob references
      {:ok, _content_ref} = Workspaces.link_content(
        document_id: document.id,
        content: "Main content",
        content_type: "text/markdown",
        ref_type: "content"
      )
      
      {:ok, _attachment_ref} = Workspaces.link_content(
        document_id: document.id,
        content: "Attachment data",
        content_type: "application/octet-stream", 
        ref_type: "attachment"
      )
      
      {:ok, _preview_ref} = Workspaces.link_content(
        document_id: document.id,
        content: "Preview content",
        content_type: "text/html",
        ref_type: "preview"
      )
      
      %{user: user, document: document}
    end

    test "lists all blob references for document", %{document: document} do
      assert {:ok, refs} = DocumentBlobRef.list_for_document(document.id)
      
      assert length(refs) == 3
      ref_types = Enum.map(refs, & &1.ref_type) |> Enum.sort()
      assert ref_types == ["attachment", "content", "preview"]
    end

    test "gets specific blob reference by type", %{document: document} do
      assert {:ok, content_ref} = DocumentBlobRef.get_by_type(document.id, "content")
      assert content_ref.ref_type == "content"
      
      assert {:ok, attachment_ref} = DocumentBlobRef.get_by_type(document.id, "attachment")  
      assert attachment_ref.ref_type == "attachment"
      
      assert {:ok, nil} = DocumentBlobRef.get_by_type(document.id, "nonexistent")
    end

    test "queries by document using read action", %{document: document} do
      assert {:ok, refs} = Workspaces.by_document(document.id)
      assert length(refs) >= 3
    end

    test "queries by document and type", %{document: document} do
      assert {:ok, refs} = Workspaces.by_document_and_type(document.id, "content")
      assert length(refs) == 1
      assert List.first(refs).ref_type == "content"
    end
  end

  describe "content action helpers" do
    setup do
      user = insert(:user)
      workspace = insert(:workspace, user: user)
      
      {:ok, document} = Workspaces.create_document(%{
        title: "Action Test Document",
        workspace_id: workspace.id
      }, actor: user)
      
      %{user: user, document: document}
    end

    test "get_content action retrieves document content", %{document: document} do
      content = "Content for action test"
      
      {:ok, _ref} = Workspaces.link_content(
        document_id: document.id,
        content: content,
        content_type: "text/plain"
      )
      
      assert {:ok, retrieved_content} = Workspaces.get_document_blob_content(
        document.id, 
        "content"
      )
      assert retrieved_content == content
    end

    test "update_content action updates document content", %{document: document} do
      original_content = "Original action content"
      updated_content = "Updated action content"
      
      # Create initial content
      {:ok, _ref} = Workspaces.link_content(
        document_id: document.id,
        content: original_content,
        content_type: "text/plain"
      )
      
      # Update using action
      assert {:ok, _updated_ref} = Workspaces.update_document_blob_content(
        document.id,
        updated_content,
        "text/plain",
        "content"
      )
      
      # Verify update
      assert {:ok, retrieved_content} = Workspaces.get_document_blob_content(
        document.id,
        "content"
      )
      assert retrieved_content == updated_content
    end

    test "handles content_type changes in updates", %{document: document} do
      # Start with markdown
      {:ok, _ref} = Workspaces.link_content(
        document_id: document.id,
        content: "# Markdown Content",
        content_type: "text/markdown"
      )
      
      # Update to HTML
      html_content = "<h1>HTML Content</h1>"
      assert {:ok, _updated_ref} = Workspaces.update_document_blob_content(
        document.id,
        html_content,
        "text/html",
        "content"
      )
      
      # Verify content and type changed
      assert {:ok, retrieved_content} = Workspaces.get_document_blob_content(
        document.id,
        "content"
      )
      assert retrieved_content == html_content
      
      # Check blob content type
      {:ok, ref} = Workspaces.by_document_and_type(document.id, "content") |> elem(1) |> List.first()
      {:ok, ref_with_blob} = Workspaces.get_document_blob_ref(ref.id, load: [:blob])
      assert ref_with_blob.blob.content_type == "text/html"
    end
  end

  describe "calculations" do
    setup do
      user = insert(:user)
      workspace = insert(:workspace, user: user)
      
      {:ok, document} = Workspaces.create_document(%{
        title: "Calculation Test Document",
        workspace_id: workspace.id
      }, actor: user)
      
      content = "Content for calculations"
      {:ok, ref} = Workspaces.link_content(
        document_id: document.id,
        content: content,
        content_type: "text/plain"
      )
      
      %{user: user, document: document, ref: ref, content: content}
    end

    test "content calculation retrieves blob content", %{ref: ref, content: content} do
      {:ok, ref_with_content} = Workspaces.get_document_blob_ref(ref.id, load: [:content])
      assert ref_with_content.content == content
    end

    test "blob_info calculation provides blob metadata", %{ref: ref} do
      {:ok, ref_with_info} = Workspaces.get_document_blob_ref(ref.id, load: [:blob_info])
      
      blob_info = ref_with_info.blob_info
      assert blob_info.content_type == "text/plain"
      assert blob_info.encoding == "utf-8"
      assert blob_info.hash
      assert blob_info.size > 0
    end

    test "handles missing blob content gracefully" do
      # Create a reference with a non-existent blob (shouldn't happen in practice)
      user = insert(:user)
      workspace = insert(:workspace, user: user)
      
      {:ok, document} = Workspaces.create_document(%{
        title: "Test Doc",
        workspace_id: workspace.id
      }, actor: user)
      
      {:ok, fake_blob} = Workspaces.create_blob(content: "temp", content_type: "text/plain")
      
      {:ok, ref} = Workspaces.create_ref(%{
        document_id: document.id,
        blob_id: fake_blob.id,
        ref_type: "content"
      })
      
      # Delete the blob to simulate missing content
      :ok = Ash.destroy(fake_blob, authorize?: false)
      
      # Content calculation should handle missing blob
      {:ok, ref_with_content} = Workspaces.get_document_blob_ref(ref.id, load: [:content])
      assert ref_with_content.content == nil
    end
  end

  describe "validation and error handling" do
    test "requires document_id, blob_id, and ref_type" do
      assert {:error, %Ash.Error.Invalid{}} = Workspaces.create_ref(%{})
      
      assert {:error, %Ash.Error.Invalid{}} = Workspaces.create_ref(%{
        document_id: Ash.UUID.generate()
      })
      
      assert {:error, %Ash.Error.Invalid{}} = Workspaces.create_ref(%{
        document_id: Ash.UUID.generate(),
        blob_id: Ash.UUID.generate()
      })
    end

    test "validates document and blob exist", %{blob: blob} do
      user = insert(:user)
      workspace = insert(:workspace, user: user)
      
      {:ok, document} = Workspaces.create_document(%{
        title: "Validation Test",
        workspace_id: workspace.id
      }, actor: user)
      
      # Valid reference should work
      assert {:ok, _ref} = Workspaces.create_ref(%{
        document_id: document.id,
        blob_id: blob.id,
        ref_type: "content"
      })
      
      # Invalid document_id should fail
      assert {:error, %Ash.Error.Invalid{}} = Workspaces.create_ref(%{
        document_id: Ash.UUID.generate(),
        blob_id: blob.id,
        ref_type: "content"
      })
      
      # Invalid blob_id should fail  
      assert {:error, %Ash.Error.Invalid{}} = Workspaces.create_ref(%{
        document_id: document.id,
        blob_id: Ash.UUID.generate(),
        ref_type: "content"
      })
    end

    test "handles blob creation failure in link_content" do
      user = insert(:user)
      workspace = insert(:workspace, user: user)
      
      {:ok, document} = Workspaces.create_document(%{
        title: "Link Content Test",
        workspace_id: workspace.id
      }, actor: user)
      
      # Simulate blob creation failure by using invalid storage backend
      original_backend = Application.get_env(:kyozo, :blob_storage_backend)
      Application.put_env(:kyozo, :blob_storage_backend, :invalid_backend)
      
      try do
        assert {:error, %Ash.Error.Invalid{}} = Workspaces.link_content(
          document_id: document.id,
          content: "This should fail",
          content_type: "text/plain"
        )
      after
        Application.put_env(:kyozo, :blob_storage_backend, original_backend)
      end
    end
  end

  describe "helper function integration" do
    test "create_content_ref helper works correctly" do
      user = insert(:user)
      workspace = insert(:workspace, user: user)
      
      {:ok, document} = Workspaces.create_document(%{
        title: "Helper Test Document",
        workspace_id: workspace.id
      }, actor: user)
      
      content = "Helper function content"
      
      assert {:ok, ref} = DocumentBlobRef.create_content_ref(
        document.id,
        content,
        "text/markdown"
      )
      
      assert ref.ref_type == "content"
      assert ref.document_id == document.id
      
      # Verify content can be retrieved
      assert {:ok, retrieved_content} = DocumentBlobRef.get_document_content(document.id)
      assert retrieved_content == content
    end

    test "multiple reference types coexist" do
      user = insert(:user)
      workspace = insert(:workspace, user: user)
      
      {:ok, document} = Workspaces.create_document(%{
        title: "Multi-Type Document",
        workspace_id: workspace.id
      }, actor: user)
      
      # Create different types of references
      content_text = "Main document content"
      attachment_data = "Attachment binary data"
      preview_html = "<h1>Preview</h1>"
      
      {:ok, _content_ref} = DocumentBlobRef.create_content_ref(
        document.id, content_text, "text/markdown"
      )
      
      {:ok, _attachment_ref} = Workspaces.link_content(
        document_id: document.id,
        content: attachment_data,
        content_type: "application/octet-stream",
        ref_type: "attachment"
      )
      
      {:ok, _preview_ref} = Workspaces.link_content(
        document_id: document.id,
        content: preview_html,
        content_type: "text/html",
        ref_type: "preview"
      )
      
      # Verify all can be retrieved independently
      assert {:ok, content_text} == DocumentBlobRef.get_document_content(document.id)
      
      assert {:ok, attachment_data} == Workspaces.get_document_blob_content(
        document.id, "attachment"
      )
      
      assert {:ok, preview_html} == Workspaces.get_document_blob_content(
        document.id, "preview"
      )
    end
  end

  describe "authorization and policies" do
    test "user can only access refs for documents they can access" do
      user1 = insert(:user)
      user2 = insert(:user)
      
      workspace1 = insert(:workspace, user: user1)
      workspace2 = insert(:workspace, user: user2)
      
      {:ok, doc1} = Workspaces.create_document(%{
        title: "User 1 Document",
        workspace_id: workspace1.id
      }, actor: user1)
      
      {:ok, doc2} = Workspaces.create_document(%{
        title: "User 2 Document", 
        workspace_id: workspace2.id
      }, actor: user2)
      
      # Create references
      {:ok, ref1} = Workspaces.link_content(
        document_id: doc1.id,
        content: "User 1 content",
        ref_type: "content"
      )
      
      {:ok, ref2} = Workspaces.link_content(
        document_id: doc2.id,
        content: "User 2 content", 
        ref_type: "content"
      )
      
      # User 1 can access their ref
      assert {:ok, _} = Workspaces.get_document_blob_ref(ref1.id, actor: user1)
      
      # User 1 cannot access user 2's ref
      assert {:error, %Ash.Error.Forbidden{}} = Workspaces.get_document_blob_ref(ref2.id, actor: user1)
      
      # User 2 can access their ref
      assert {:ok, _} = Workspaces.get_document_blob_ref(ref2.id, actor: user2)
      
      # User 2 cannot access user 1's ref
      assert {:error, %Ash.Error.Forbidden{}} = Workspaces.get_document_blob_ref(ref1.id, actor: user2)
    end
  end
end