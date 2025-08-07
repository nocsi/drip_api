defmodule KyozoWeb.PortalHTML do
  @moduledoc """
  This module contains pages rendered by PortalController.

  See the `portal_html` directory for all templates available.
  """
  use KyozoWeb, :html

  embed_templates "portal_html/*"
end