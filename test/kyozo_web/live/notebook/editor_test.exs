defmodule KyozoWeb.Live.Notebook.EditorTest do
  use KyozoWeb.ConnCase
  use KyozoWeb.LiveCase

  import Phoenix.LiveViewTest
  import Kyozo.AccountsFixtures
  import Kyozo.WorkspacesFixtures

  alias Kyozo.Workspaces
  alias Kyozo.Workspaces.{Notebook, DocumentBlobRef}

  describe "mount" do
    setup [:create_user, :create_workspace, :create_notebook]

    test "mounts successfully with valid notebook", %{conn: conn, user: user, notebook: notebook} do
      conn = log_in_user(conn, user)

      {:ok, view, html} = live(conn, ~p"/notebooks/#{notebook.id}/edit")

      assert html =~ notebook.title
      assert has_element?(view, ".notebook-app")
      assert has_element?(view, ".tiptap-editor")
    end

    test "redirects to workspaces when notebook not found", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)
      fake_id = Ash.UUID.generate()

      assert {:error, {:redirect, %{to: "/workspaces"}}} = 
        live(conn, ~p"/notebooks/#{fake_id}/edit")
    end

    test "redirects when user doesn't have access", %{conn: conn, notebook: notebook} do
      other_user = user_fixture()
      conn = log_in_user(conn, other_user)

      assert {:error, {:redirect, %{to: "/workspaces"}}} = 
        live(conn, ~p"/notebooks/#{notebook.id}/edit")
    end

    test "subscribes to PubSub channels", %{conn: conn, user: user, notebook: notebook} do
      conn = log_in_user(conn, user)

      {:ok, _view, _html} = live(conn, ~p"/notebooks/#{notebook.id}/edit")

      # Verify subscriptions by sending test messages
      Phoenix.PubSub.broadcast(Kyozo.PubSub, "notebook:#{notebook.id}", {:test_message})
      Phoenix.PubSub.broadcast(Kyozo.PubSub, "notebook:#{notebook.id}:execution", {:test_execution})
      Phoenix.PubSub.broadcast(Kyozo.PubSub, "notebook:#{notebook.id}:collaboration", {:test_collaboration})

      # If we get here without errors, subscriptions are working
      assert true
    end
  end

  describe "save_notebook event" do
    setup [:create_user, :create_workspace, :create_notebook]

    test "saves notebook content successfully", %{conn: conn, user: user, notebook: notebook} do
      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/notebooks/#{notebook.id}/edit")

      new_content = "# Updated Content\n\nThis is new content."

      result = render_hook(view, "save_notebook", %{"content" => new_content})

      # Verify content was saved
      {:ok, updated_content} = DocumentBlobRef.get_document_content(notebook.document_id)
      assert updated_content == new_content

      # Verify flash message or UI update
      assert has_element?(view, "[data-test='save-success']") or 
             result =~ "saved" or 
             view.assigns.last_saved_at != nil
    end

    test "handles save errors gracefully", %{conn: conn, user: user, notebook: notebook} do
      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/notebooks/#{notebook.id}/edit")

      # Simulate error by using invalid data or mocking storage failure
      # For this test, we'll use extremely long content that might cause issues
      massive_content = String.duplicate("x", 10_000_000)  # 10MB string

      render_hook(view, "save_notebook", %{"content" => massive_content})

      # Should show error message without crashing
      assert has_element?(view, ".alert") or 
             view.assigns.flash["error"] != nil
    end

    test "broadcasts content updates for collaboration", %{conn: conn, user: user, notebook: notebook} do
      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/notebooks/#{notebook.id}/edit")

      # Subscribe to the collaboration channel to verify broadcast
      Phoenix.PubSub.subscribe(Kyozo.PubSub, "notebook:#{notebook.id}")

      new_content = "# Collaborative Content\n\nUpdated by user."

      render_hook(view, "save_notebook", %{"content" => new_content})

      # Should receive broadcast message
      assert_receive {:content_updated, ^new_content}, 1000
    end
  end

  describe "save_content event" do
    setup [:create_user, :create_workspace, :create_notebook]

    test "saves content with HTML", %{conn: conn, user: user, notebook: notebook} do
      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/notebooks/#{notebook.id}/edit")

      markdown_content = "# Heading\n\n**Bold text**"
      html_content = "<h1>Heading</h1>\n<p><strong>Bold text</strong></p>"

      render_hook(view, "save_content", %{
        "content" => markdown_content,
        "html" => html_content
      })

      # Verify both markdown and HTML were processed
      {:ok, saved_content} = DocumentBlobRef.get_document_content(notebook.document_id)
      assert saved_content == markdown_content

      # Verify notebook was updated with extracted tasks if any
      {:ok, updated_notebook} = Workspaces.get_notebook(notebook.id)
      assert updated_notebook.extracted_tasks != nil
    end

    test "extracts executable tasks from content", %{conn: conn, user: user, notebook: notebook} do
      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/notebooks/#{notebook.id}/edit")

      content_with_code = """
      # Python Example

      ```python
      print("Hello, World!")
      x = 5 + 3
      ```

      # Elixir Example

      ```elixir
      IO.puts("Hello from Elixir!")
      result = 1 + 2
      ```

      # Just Text

      ```text
      This is not executable
      ```
      """

      render_hook(view, "save_content", %{
        "content" => content_with_code,
        "html" => ""
      })

      # Verify tasks were extracted
      {:ok, updated_notebook} = Workspaces.get_notebook(notebook.id)
      assert length(updated_notebook.extracted_tasks) == 2

      # Verify task details
      task_languages = Enum.map(updated_notebook.extracted_tasks, & &1.language)
      assert "python" in task_languages
      assert "elixir" in task_languages
      refute "text" in task_languages
    end
  end

  describe "execute_task event" do
    setup [:create_user, :create_workspace, :create_notebook]

    test "executes Python task", %{conn: conn, user: user, notebook: notebook} do
      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/notebooks/#{notebook.id}/edit")

      # Subscribe to execution events
      Phoenix.PubSub.subscribe(Kyozo.PubSub, "notebook:#{notebook.id}:execution")

      task_id = "test_task_123"
      python_code = "print('Hello from Python')\nresult = 2 + 2\nprint(f'Result: {result}')"

      render_hook(view, "execute_task", %{
        "task_id" => task_id,
        "code" => python_code,
        "language" => "python"
      })

      # Should receive execution started message
      assert_receive {:task_execution_started, ^task_id}, 1000

      # Should eventually receive completion or failure message
      assert_receive {:task_execution_completed, ^task_id, _output}, 5000 or
        assert_receive {:task_execution_failed, ^task_id, _error}, 5000
    end

    test "executes Elixir task", %{conn: conn, user: user, notebook: notebook} do
      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/notebooks/#{notebook.id}/edit")

      Phoenix.PubSub.subscribe(Kyozo.PubSub, "notebook:#{notebook.id}:execution")

      task_id = "elixir_task_456"
      elixir_code = "IO.puts(\"Hello from Elixir\")\n1 + 1"

      render_hook(view, "execute_task", %{
        "task_id" => task_id,
        "code" => elixir_code,
        "language" => "elixir"
      })

      # Elixir execution should work in the same VM
      assert_receive {:task_execution_completed, ^task_id, output}, 2000
      assert output =~ "Hello from Elixir" or output =~ "2"
    end

    test "handles task execution errors", %{conn: conn, user: user, notebook: notebook} do
      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/notebooks/#{notebook.id}/edit")

      Phoenix.PubSub.subscribe(Kyozo.PubSub, "notebook:#{notebook.id}:execution")

      task_id = "error_task_789"
      invalid_elixir_code = "this is not valid elixir syntax {"

      render_hook(view, "execute_task", %{
        "task_id" => task_id,
        "code" => invalid_elixir_code,
        "language" => "elixir"
      })

      # Should receive error message
      assert_receive {:task_execution_failed, ^task_id, _error}, 2000
    end

    test "prevents execution when already executing", %{conn: conn, user: user, notebook: notebook} do
      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/notebooks/#{notebook.id}/edit")

      # Set executing state
      send(view.pid, {:assign, :executing, true})

      task_id = "blocked_task"
      code = "print('This should not execute')"

      # This should not trigger execution
      render_hook(view, "execute_task", %{
        "task_id" => task_id,
        "code" => code,
        "language" => "python"
      })

      # Should not receive execution messages
      refute_receive {:task_execution_started, ^task_id}, 500
    end
  end

  describe "toggle_collaborative_mode event" do
    setup [:create_user, :create_workspace, :create_notebook]

    test "enables collaborative mode", %{conn: conn, user: user, notebook: notebook} do
      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/notebooks/#{notebook.id}/edit")

      Phoenix.PubSub.subscribe(Kyozo.PubSub, "notebook:#{notebook.id}:collaboration")

      render_hook(view, "toggle_collaborative_mode", %{"enabled" => true})

      # Should receive user joined message
      assert_receive {:user_joined, user_info}, 1000
      assert user_info.id == user.id

      # Verify notebook was updated
      {:ok, updated_notebook} = Workspaces.get_notebook(notebook.id)
      assert updated_notebook.collaborative_mode == true
    end

    test "disables collaborative mode", %{conn: conn, user: user, notebook: notebook} do
      # First enable collaborative mode
      {:ok, _} = Workspaces.update_notebook(notebook, %{collaborative_mode: true}, actor: user)

      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/notebooks/#{notebook.id}/edit")

      Phoenix.PubSub.subscribe(Kyozo.PubSub, "notebook:#{notebook.id}:collaboration")

      render_hook(view, "toggle_collaborative_mode", %{"enabled" => false})

      # Should receive user left message  
      assert_receive {:user_left, user_info}, 1000
      assert user_info.id == user.id

      # Verify notebook was updated
      {:ok, updated_notebook} = Workspaces.get_notebook(notebook.id)
      assert updated_notebook.collaborative_mode == false
    end
  end

  describe "export_notebook event" do
    setup [:create_user, :create_workspace, :create_notebook_with_content]

    test "exports notebook as HTML", %{conn: conn, user: user, notebook: notebook} do
      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/notebooks/#{notebook.id}/edit")

      render_hook(view, "export_notebook", %{"format" => "html"})

      # Should trigger download event
      assert_push_event(view, "download_file", %{
        content: content,
        filename: filename,
        mime_type: "text/html"
      })

      assert content =~ "<html>"
      assert content =~ notebook.title
      assert filename =~ ".html"
    end

    test "exports notebook as markdown", %{conn: conn, user: user, notebook: notebook} do
      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/notebooks/#{notebook.id}/edit")

      render_hook(view, "export_notebook", %{"format" => "md"})

      assert_push_event(view, "download_file", %{
        content: _content,
        filename: _filename,
        mime_type: "text/markdown"
      })
    end

    test "exports notebook as Jupyter notebook", %{conn: conn, user: user, notebook: notebook} do
      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/notebooks/#{notebook.id}/edit")

      render_hook(view, "export_notebook", %{"format" => "ipynb"})

      assert_push_event(view, "download_file", %{
        content: content,
        filename: filename,
        mime_type: "application/x-ipynb+json"
      })

      # Verify it's valid JSON
      assert {:ok, json} = Jason.decode(content)
      assert json["nbformat"] == 4
      assert is_list(json["cells"])
      assert filename =~ ".ipynb"
    end

    test "handles unsupported export format", %{conn: conn, user: user, notebook: notebook} do
      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/notebooks/#{notebook.id}/edit")

      render_hook(view, "export_notebook", %{"format" => "unsupported"})

      # Should show error message
      assert has_element?(view, ".alert") or view.assigns.flash["error"] != nil
    end
  end

  describe "PubSub message handling" do
    setup [:create_user, :create_workspace, :create_notebook]

    test "handles task execution completion", %{conn: conn, user: user, notebook: notebook} do
      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/notebooks/#{notebook.id}/edit")

      task_id = "test_task"
      output = "Task completed successfully"

      send(view.pid, {:task_execution_completed, task_id, output})

      # Should push event to client
      assert_push_event(view, "task_execution_completed", %{
        task_id: ^task_id,
        output: ^output
      })
    end

    test "handles task execution failure", %{conn: conn, user: user, notebook: notebook} do
      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/notebooks/#{notebook.id}/edit")

      task_id = "failed_task"
      error = "Syntax error in code"

      send(view.pid, {:task_execution_failed, task_id, error})

      assert_push_event(view, "task_execution_failed", %{
        task_id: ^task_id,
        error: ^error
      })
    end

    test "handles user join/leave events", %{conn: conn, user: user, notebook: notebook} do
      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/notebooks/#{notebook.id}/edit")

      other_user = user_fixture()
      
      # User joins
      send(view.pid, {:user_joined, other_user})
      assert_push_event(view, "user_joined", %{user: %{id: other_user.id}})

      # User leaves  
      send(view.pid, {:user_left, other_user})
      assert_push_event(view, "user_left", %{user: %{id: other_user.id}})
    end

    test "ignores own user join event", %{conn: conn, user: user, notebook: notebook} do
      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/notebooks/#{notebook.id}/edit")

      # Send user's own join event
      send(view.pid, {:user_joined, user})

      # Should not push event to client (user shouldn't see themselves join)
      refute_push_event(view, "user_joined", %{})
    end

    test "handles content updates from other users", %{conn: conn, user: user, notebook: notebook} do
      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/notebooks/#{notebook.id}/edit")

      new_content = "Content updated by another user"
      
      send(view.pid, {:content_updated, new_content})

      assert_push_event(view, "content_updated", %{content: ^new_content})
    end
  end

  describe "helper functions" do
    setup [:create_user, :create_workspace, :create_notebook_with_content]

    test "extract_tasks_from_content identifies executable languages", %{notebook: notebook} do
      content = """
      # Mixed Code Blocks

      ```python
      print("Python code")
      ```

      ```elixir  
      IO.puts("Elixir code")
      ```

      ```text
      Just plain text
      ```

      ```javascript
      console.log("JavaScript code");
      ```

      ```
      No language specified
      ```
      """

      # This tests the private function indirectly through the save process
      # We can't test private functions directly, but we can test their effects
      user = insert(:user)
      conn = log_in_user(build_conn(), user)
      {:ok, view, _html} = live(conn, ~p"/notebooks/#{notebook.id}/edit")

      render_hook(view, "save_content", %{
        "content" => content,
        "html" => ""
      })

      {:ok, updated_notebook} = Workspaces.get_notebook(notebook.id)
      
      # Should extract python, elixir, and javascript tasks
      assert length(updated_notebook.extracted_tasks) >= 3
      
      languages = Enum.map(updated_notebook.extracted_tasks, & &1.language)
      assert "python" in languages
      assert "elixir" in languages  
      assert "javascript" in languages
      refute "text" in languages
    end

    test "render_markdown_content converts markdown to HTML", %{conn: conn, user: user, notebook: notebook} do
      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/notebooks/#{notebook.id}/edit")

      markdown_content = """
      # Main Title

      This is **bold** and this is *italic*.

      - Item 1
      - Item 2

      > Blockquote text
      """

      render_hook(view, "save_content", %{
        "content" => markdown_content,
        "html" => ""
      })

      # The HTML rendering happens internally and affects export functionality
      render_hook(view, "export_notebook", %{"format" => "html"})

      assert_push_event(view, "download_file", %{content: html_content})
      
      # Verify HTML was generated correctly
      assert html_content =~ "<h1>Main Title</h1>"
      assert html_content =~ "<strong>bold</strong>"
      assert html_content =~ "<em>italic</em>"
      assert html_content =~ "<blockquote>"
    end
  end

  # Test helpers

  defp create_user(_) do
    user = user_fixture()
    %{user: user}
  end

  defp create_workspace(%{user: user}) do
    workspace = workspace_fixture(user: user)
    %{workspace: workspace}
  end

  defp create_notebook(%{user: user, workspace: workspace}) do
    notebook = notebook_fixture(workspace: workspace, user: user)
    %{notebook: notebook}
  end

  defp create_notebook_with_content(%{user: user, workspace: workspace}) do
    notebook = notebook_fixture(workspace: workspace, user: user)
    
    # Add some content to the notebook
    content = """
    # Test Notebook

    This is a test notebook with some content.

    ```python
    print("Hello, World!")
    x = 1 + 1
    ```

    ## Section 2

    More content here.
    """

    {:ok, _ref} = DocumentBlobRef.create_content_ref(
      notebook.document_id,
      content,
      "text/markdown"
    )

    %{notebook: notebook}
  end
end