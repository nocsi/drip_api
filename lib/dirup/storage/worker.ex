defmodule Dirup.Storage.StorageResource.Process.Worker do
  use Oban.Worker, queue: :storage_resource

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"resource_id" => resource_id}}) do
    with {:ok, resource} <- Dirup.Storage.StorageResource.get(resource_id),
         {:ok, _} <- Dirup.Storage.StorageResource.process(resource) do
      {:ok, resource}
    else
      {:error, reason} -> {:error, reason}
    end
  end
end
