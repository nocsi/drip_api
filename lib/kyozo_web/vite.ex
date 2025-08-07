defmodule Vite do
  @moduledoc """
  Helper for Vite assets paths in development and production.
  """

  def path(asset) do
    case Application.get_env(:kyozo, :env) do
      :dev -> "http://localhost:5180/" <> asset
      _ -> get_production_path(asset)
    end
  end

  defp get_production_path(asset) do
    manifest = get_manifest(:kyozo)

    case Path.extname(asset) do
      ".css" -> get_main_css_in(manifest)
      _ -> get_asset_path(manifest, asset)
    end
  end

  defp get_manifest(app_name) do
    manifest_path = Path.join(:code.priv_dir(app_name), "static/.vite/manifest.json")

    with {:ok, content} <- File.read(manifest_path),
         {:ok, decoded} <- Jason.decode(content) do
      decoded
    else
      _ -> raise "Could not read Vite manifest at #{manifest_path}"
    end
  end

  defp get_main_css_in(manifest) do
    manifest
    |> Enum.flat_map(fn {_key, entry} -> Map.get(entry, "css", []) end)
    |> Enum.find(&String.contains?(&1, "app"))
    |> case do
      nil -> raise "Main CSS file not found in manifest"
      file -> "/#{file}"
    end
  end

  defp get_asset_path(manifest, asset) do
    case manifest[asset] do
      %{"file" => file} -> "/#{file}"
      _ -> raise "Asset #{asset} not found in manifest"
    end
  end
end
