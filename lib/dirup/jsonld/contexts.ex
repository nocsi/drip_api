defmodule Dirup.JSONLD.Contexts do
  @moduledoc """
  Centralized JSON-LD context definitions for Dirup.

  Provides semantic vocabularies for infrastructure manifests, services,
  dependencies, and storage objects.
  """

  @doc """
  JSON-LD context for infrastructure graphs and service manifests.
  """
  def infrastructure_context do
    %{
      "@context" => %{
        "topo" => "https://topo.dev/schema/v1/",
        "id" => "@id",
        "type" => "@type",
        "Service" => "topo:Service",
        "Workspace" => "topo:Workspace",
        "Folder" => "topo:Folder",
        "depends_on" => %{"@id" => "topo:dependsOn", "@type" => "@id"},
        "exposes" => %{"@id" => "topo:exposes"},
        "ports" => %{"@id" => "topo:ports"},
        "environment" => %{"@id" => "topo:environment"},
        "resources" => %{"@id" => "topo:resources"},
        "image" => %{"@id" => "topo:image"},
        "container" => %{"@id" => "topo:container"},
        "contentHash" => %{"@id" => "topo:contentHash"},
        "graph" => %{"@id" => "topo:graph"}
      }
    }
  end

  @doc """
  JSON-LD context for content-addressable storage objects.
  """
  def storage_context do
    %{
      "@context" => %{
        "topo" => "https://topo.dev/schema/v1/",
        "Content" => "topo:Content",
        "contentHash" => %{"@id" => "topo:contentHash"},
        "size" => %{"@id" => "topo:sizeBytes"},
        "metadata" => %{"@id" => "topo:metadata"}
      }
    }
  end
end

