defmodule DirupWeb do
  @moduledoc """
  The entrypoint for defining your web interface, such
  as controllers, components, channels, and so on.

  This can be used in your application as:

      use DirupWeb, :controller
      use DirupWeb, :html

  The definitions below will be executed for every controller,
  component, etc, so keep them short and clean, focused
  on imports, uses and aliases.

  Do NOT define functions inside the quoted expressions
  below. Instead, define additional modules and import
  those modules here.
  """

  def static_paths, do: ~w(
    assets
    fonts
    images
    robots.txt
    favicon.ico
    sw.js
    sw.config.js
    android-chrome-192x192.png
    android-chrome-512x512.png
    apple-touch-icon.png
    browserconfig.xml
    favicon-16x16.png
    favicon-32x32.png
    mstile-150x150.png
    og.png
    safari-pinned-tab.svg
    screenshot-narrow-light.png
    screenshot-narrow-dark.png
    screenshot-wide-light.png
    screenshot-wide-dark.png
    manifest.webmanifest
    sitemap.xml
  )

  def router do
    quote do
      use Phoenix.Router, helpers: false

      # Import common connection and controller functions to use in pipelines
      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.LiveView.Router
    end
  end

  def channel do
    quote do
      use Phoenix.Channel
    end
  end

  def controller do
    quote do
      use Phoenix.Controller, formats: [:html, :json]

      import Plug.Conn
      use Gettext, backend: DirupWeb.Gettext

      unquote(verified_routes())
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView,
        layout: {DirupWeb.Layouts, :app}

      import LiveSvelte

      unquote(html_helpers())
    end
  end

  def live_component do
    quote do
      use Phoenix.LiveComponent

      unquote(html_helpers())
    end
  end

  def component do
    quote do
      use Phoenix.Component

      unquote(html_helpers())
    end
  end

  def html do
    quote do
      use Phoenix.Component

      # Import convenience functions from controllers
      import Phoenix.Controller,
        only: [get_csrf_token: 0, view_module: 1, view_template: 1]

      # Include general helpers for rendering HTML
      unquote(html_helpers())
    end
  end

  defp html_helpers do
    quote do
      import LiveSvelte
      # HTML escaping functionality
      import Phoenix.HTML

      import DirupWeb.CoreComponents,
        except: [button: 1, button_link: 2, show_modal: 1, show_modal: 2, hide_modal: 1]

      # Core UI components and translation
      # import DirupWeb.CoreComponents
      use Gettext, backend: DirupWeb.Gettext

      # Common modules used in templates
      alias Phoenix.LiveView.JS
      alias DirupWeb.Layouts

      import Tails

      # Routes generation with the ~p sigil
      unquote(verified_routes())
    end
  end

  def verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: DirupWeb.Endpoint,
        router: DirupWeb.Router,
        statics: DirupWeb.static_paths()
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/live_view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
