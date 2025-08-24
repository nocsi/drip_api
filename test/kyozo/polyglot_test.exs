defmodule Kyozo.PolyglotTest do
  @moduledoc """
  Tests for the Polyglot module - where markdown transcends reality.
  """
  use ExUnit.Case, async: true
  alias Kyozo.Polyglot

  describe "parse/1" do
    test "detects Dockerfile in markdown" do
      markdown = """
      # My App

      ```dockerfile
      FROM elixir:1.14
      WORKDIR /app
      ```
      """

      result = Polyglot.parse(markdown)
      assert result.language == :dockerfile
      assert length(result.artifacts) == 1
      assert hd(result.artifacts).type == :dockerfile
    end

    test "detects Terraform infrastructure" do
      markdown = """
      # Infrastructure

      ```terraform
      resource "aws_instance" "web" {
        ami = "ami-123456"
      }
      ```
      """

      result = Polyglot.parse(markdown)
      assert result.language == :terraform
      assert length(result.artifacts) == 1
      assert hd(result.artifacts).type == :terraform
    end

    test "detects Kubernetes manifests" do
      markdown = """
      # Deployment

      ```yaml
      apiVersion: apps/v1
      kind: Deployment
      metadata:
        name: my-app
      ```
      """

      result = Polyglot.parse(markdown)
      assert result.language == :kubernetes
      assert length(result.artifacts) == 1
      assert hd(result.artifacts).type == :kubernetes
    end

    test "detects executable scripts" do
      markdown = """
      # Deploy Script

      <!-- polyglot:executable -->

      ```bash
      #!/bin/bash
      echo "Deploying..."
      ```
      """

      result = Polyglot.parse(markdown)
      assert result.language == :executable
      assert length(result.artifacts) == 1
      assert hd(result.artifacts).executable == true
    end

    test "detects file blocks for git repositories" do
      markdown = """
      # My Project

      ```file:.gitignore
      *.beam
      _build/
      ```

      ```file:README.md
      # Hello
      ```
      """

      result = Polyglot.parse(markdown)
      assert result.language == :git
      assert length(result.artifacts) == 2
      assert Enum.all?(result.artifacts, &(&1.type == :file))
    end

    test "extracts polyglot metadata from comments" do
      markdown = """
      <!-- polyglot:type=manifest -->
      <!-- kyozo:deploy environment=production -->

      # Document
      """

      result = Polyglot.parse(markdown)
      assert result.metadata[:type] == :polyglot
      assert result.metadata[:subtype] == :type
    end

    test "detects zero-width encoded data" do
      # Hidden message: "Hi" encoded in zero-width chars
      markdown = "Normal text​‌‍⁠ with secrets"

      result = Polyglot.parse(markdown)
      assert Map.has_key?(result.metadata, :type)
    end
  end

  describe "polyglot?/1" do
    test "returns true for polyglot documents" do
      assert Polyglot.polyglot?("```dockerfile\nFROM elixir\n```")
      assert Polyglot.polyglot?("<!-- polyglot:magic -->")
      # Zero-width chars
      assert Polyglot.polyglot?("Text​‌‍⁠")
    end

    test "returns false for plain markdown" do
      refute Polyglot.polyglot?("# Just a heading\n\nSome text.")
      refute Polyglot.polyglot?("- List item\n- Another item")
    end
  end

  describe "sanitize/1" do
    test "removes polyglot features" do
      markdown = """
      <!-- polyglot:secret -->
      Text​‌‍⁠
      <!-- kyozo:hidden -->
      [Link](e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855)
      """

      sanitized = Polyglot.sanitize(markdown)

      refute sanitized =~ "polyglot:"
      refute sanitized =~ "kyozo:"
      # Zero-width space
      refute sanitized =~ "​"
      assert sanitized =~ "[Link](#)"
    end
  end

  describe "AST building" do
    test "creates structured AST from markdown" do
      markdown = """
      # Heading

      Some text.

      ```elixir
      def hello, do: :world
      ```

      - List item
      """

      result = Polyglot.parse(markdown)

      types = result.ast |> Enum.map(& &1.type) |> Enum.uniq()
      assert :heading in types
      assert :paragraph in types
      assert :code in types
      assert :list in types
    end
  end

  describe "transpilation targets" do
    test "identifies correct transpiler modules" do
      assert Polyglot.get_transpiler(:docker) == Polyglot.Transpilers.Docker
      assert Polyglot.get_transpiler(:terraform) == Polyglot.Transpilers.Terraform
      assert Polyglot.get_transpiler(:kubernetes) == Polyglot.Transpilers.Kubernetes
      assert Polyglot.get_transpiler(:git) == Polyglot.Transpilers.Git
      assert Polyglot.get_transpiler(:bash) == Polyglot.Transpilers.Bash
    end
  end

  describe "execution targets" do
    test "identifies correct executor modules" do
      assert Polyglot.get_executor(:dockerfile) == Polyglot.Executors.Docker
      assert Polyglot.get_executor(:terraform) == Polyglot.Executors.Terraform
      assert Polyglot.get_executor(:kubernetes) == Polyglot.Executors.Kubernetes
      assert Polyglot.get_executor(:sql) == Polyglot.Executors.SQL
      assert Polyglot.get_executor(:git) == Polyglot.Executors.Git
      assert Polyglot.get_executor(:executable) == Polyglot.Executors.Shell
    end
  end
end
