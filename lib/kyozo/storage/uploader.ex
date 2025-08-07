defmodule Kyozo.Storage.Uploader do
  alias Kyozo.Storage.Locator

  @type storage :: atom()
  @type option :: {atom(), any()}

  @callback store(any(), storage, [option]) :: {:ok, Locator.t()} | {:error, any()}
  @callback build_options(any(), storage, [option]) :: [option]
  @callback build_metadata(Locator.t(), storage, [option]) :: Keyword.t() | map()

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @behaviour Kyozo.Storage.Uploader

      @storages Keyword.fetch!(opts, :storages)

      @impl Kyozo.Storage.Uploader
      def store(upload, storage_key, opts \\ []) do
        storage = fetch_storage!(upload, storage_key)

        upload
        |> storage.put(build_options(upload, storage_key, opts))
        |> case do
          {:ok, id} ->
            locator =
              Kyozo.Storage.add_metadata(
                Locator.new!(id: id, storage: storage),
                build_metadata(upload, storage_key, opts)
              )

            {:ok, locator}

          error_tuple ->
            error_tuple
        end
      end

      @impl Kyozo.Storage.Uploader
      def build_metadata(_, _, _), do: []

      @impl Kyozo.Storage.Uploader
      def build_options(_, _, instance_opts), do: instance_opts

      defp fetch_storage!(upload, storage) do
        @storages
        |> case do
          {m, f, a} -> apply(m, f, [upload | a])
          storages when is_list(storages) -> storages
        end
        |> Keyword.fetch(storage)
        |> case do
          {:ok, storage} ->
            storage

          _ ->
            raise "#{storage} not found in #{__MODULE__} storages. Available: #{inspect(Keyword.keys(@storages))}"
        end
      end

      defoverridable build_options: 3, build_metadata: 3
    end
  end
end
