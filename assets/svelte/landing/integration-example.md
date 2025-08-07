# Landing Page Integration with Phoenix LiveView

This document shows how to integrate the Svelte 5 landing page components with your Phoenix LiveView application.

## Phoenix LiveView Integration

### 1. Create a LiveView for the Landing Page

```elixir
# lib/kyozo_web/live/landing_live.ex
defmodule KyozoWeb.LandingLive do
  use KyozoWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div id="landing-page" phx-hook="LandingPage" class="min-h-screen">
      <!-- The Svelte component will mount here -->
    </div>
    """
  end
end
```

### 2. Add the Route

```elixir
# lib/kyozo_web/router.ex
defmodule KyozoWeb.Router do
  use KyozoWeb, :router

  # ... other code

  scope "/", KyozoWeb do
    pipe_through :browser

    live "/", LandingLive, :index
    # ... other routes
  end
end
```

### 3. Create the LiveView Hook

```javascript
// assets/js/hooks/landing_page.js
export default {
  mounted() {
    // Import and mount the Svelte component
    import("../svelte/landing-page.svelte").then((module) => {
      new module.default({
        target: this.el,
        props: {
          // Pass any props from LiveView if needed
        }
      });
    });
  },

  destroyed() {
    // Cleanup if needed
  }
};
```

### 4. Register the Hook

```javascript
// assets/js/app.js
import LandingPageHook from "./hooks/landing_page";

let Hooks = {
  LandingPage: LandingPageHook,
  // ... other hooks
};

let liveSocket = new LiveSocket("/live", Socket, {
  hooks: Hooks,
  params: {_csrf_token: csrfToken}
});
```

## Alternative: Direct Svelte Mount

If you prefer to mount Svelte components directly without LiveView:

### 1. Create a Static Controller

```elixir
# lib/kyozo_web/controllers/page_controller.ex
defmodule KyozoWeb.PageController do
  use KyozoWeb, :controller

  def landing(conn, _params) do
    render(conn, :landing, layout: false)
  end
end
```

### 2. Create the Template

```heex
<!-- lib/kyozo_web/controllers/page_html/landing.html.heex -->
<!DOCTYPE html>
<html lang="en" class="h-full">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <meta name="csrf-token" content={get_csrf_token()} />
    <title>Kyozo - Executable Markdown Notes</title>
    <meta name="description" content="Transform your markdown notes into interactive, executable documents with live code execution." />

    <!-- Open Graph / Facebook -->
    <meta property="og:type" content="website" />
    <meta property="og:title" content="Kyozo - Executable Markdown Notes" />
    <meta property="og:description" content="Transform your markdown notes into interactive, executable documents with live code execution." />
    <meta property="og:image" content="/images/og-image.png" />

    <!-- Twitter -->
    <meta property="twitter:card" content="summary_large_image" />
    <meta property="twitter:title" content="Kyozo - Executable Markdown Notes" />
    <meta property="twitter:description" content="Transform your markdown notes into interactive, executable documents with live code execution." />
    <meta property="twitter:image" content="/images/og-image.png" />

    <link phx-track-static rel="stylesheet" href={~p"/assets/app.css"} />
    <script defer phx-track-static type="text/javascript" src={~p"/assets/app.js"}></script>
  </head>
  <body class="h-full antialiased">
    <div id="landing-root" class="h-full"></div>

    <script type="module">
      import LandingPage from '/assets/svelte/landing-page.svelte';

      new LandingPage({
        target: document.getElementById('landing-root')
      });
    </script>
  </body>
</html>
```

### 3. Add the Route

```elixir
# In router.ex
scope "/", KyozoWeb do
  pipe_through :browser

  get "/", PageController, :landing
end
```

## Advanced Integration Patterns

### 1. Passing Data from Phoenix to Svelte

```elixir
# In your LiveView
def mount(_params, _session, socket) do
  user_count = MyApp.Analytics.get_user_count()
  github_stars = MyApp.GitHub.get_star_count("kyozo/kyozo")

  socket = assign(socket,
    user_count: user_count,
    github_stars: github_stars
  )

  {:ok, socket}
end

def render(assigns) do
  ~H"""
  <div
    id="landing-page"
    phx-hook="LandingPage"
    data-user-count={@user_count}
    data-github-stars={@github_stars}
  >
  </div>
  """
end
```

```javascript
// In the hook
export default {
  mounted() {
    const userCount = this.el.dataset.userCount;
    const githubStars = this.el.dataset.githubStars;

    import("../svelte/landing-page.svelte").then((module) => {
      new module.default({
        target: this.el,
        props: {
          userCount: parseInt(userCount),
          githubStars: parseInt(githubStars)
        }
      });
    });
  }
};
```

### 2. Handling User Authentication

```elixir
def mount(_params, session, socket) do
  current_user = get_current_user(session)

  socket = assign(socket, current_user: current_user)
  {:ok, socket}
end

def render(assigns) do
  ~H"""
  <div
    id="landing-page"
    phx-hook="LandingPage"
    data-authenticated={not is_nil(@current_user)}
    data-user={if @current_user, do: Jason.encode!(@current_user), else: "null"}
  >
  </div>
  """
end
```

### 3. Real-time Updates

```elixir
def mount(_params, _session, socket) do
  if connected?(socket) do
    :timer.send_interval(30_000, self(), :update_stats)
  end

  {:ok, assign_stats(socket)}
end

def handle_info(:update_stats, socket) do
  {:noreply, assign_stats(socket)}
end

defp assign_stats(socket) do
  assign(socket,
    user_count: MyApp.Analytics.get_user_count(),
    active_documents: MyApp.Analytics.get_active_documents()
  )
end
```

## Performance Optimization

### 1. Code Splitting

```javascript
// Load landing page components lazily
const loadLandingPage = () => import("../svelte/landing-page.svelte");

export default {
  mounted() {
    // Only load when the component is actually visible
    const observer = new IntersectionObserver((entries) => {
      if (entries[0].isIntersecting) {
        loadLandingPage().then((module) => {
          new module.default({
            target: this.el
          });
        });
        observer.disconnect();
      }
    });

    observer.observe(this.el);
  }
};
```

### 2. Preloading Critical Resources

```heex
<!-- In your layout or template head -->
<link rel="modulepreload" href={~p"/assets/svelte/landing-page.svelte"} />
<link rel="preload" href={~p"/assets/css/app.css"} as="style" />
```

## SEO Optimization

### 1. Server-Side Meta Tags

```elixir
defmodule KyozoWeb.LandingLive do
  use KyozoWeb, :live_view

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Kyozo - Executable Markdown Notes")
      |> assign(:meta_description, "Transform your markdown notes into interactive, executable documents with live code execution.")
      |> assign(:meta_keywords, "markdown, executable, literate programming, documentation, jupyter, notebook")

    {:ok, socket}
  end
end
```

### 2. Structured Data

Add structured data to your template:

```heex
<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "SoftwareApplication",
  "name": "Kyozo",
  "description": "Executable markdown notes application for literate programming",
  "applicationCategory": "DeveloperApplication",
  "operatingSystem": "Web",
  "offers": {
    "@type": "Offer",
    "price": "0",
    "priceCurrency": "USD"
  }
}
</script>
```

## Analytics Integration

### 1. Event Tracking

```javascript
// In your Svelte components
function trackEvent(eventName, properties = {}) {
  // Send events back to Phoenix
  window.dispatchEvent(new CustomEvent('analytics:track', {
    detail: { eventName, properties }
  }));
}

// In your hook
export default {
  mounted() {
    window.addEventListener('analytics:track', (event) => {
      this.pushEvent('track_event', event.detail);
    });
  }
};
```

```elixir
# In your LiveView
def handle_event("track_event", %{"eventName" => event_name, "properties" => properties}, socket) do
  MyApp.Analytics.track_event(event_name, properties)
  {:noreply, socket}
end
```

## Deployment Considerations

### 1. Asset Compilation

Ensure your `mix.exs` includes proper asset compilation:

```elixir
defp aliases do
  [
    setup: ["deps.get", "assets.setup", "assets.build"],
    "assets.setup": ["cmd --cd assets npm install"],
    "assets.build": ["cmd --cd assets npm run build"],
    "assets.deploy": [
      "cmd --cd assets npm run build",
      "phx.digest"
    ]
  ]
end
```

### 2. CDN Configuration

For production, consider serving assets from a CDN:

```elixir
# config/prod.exs
config :kyozo, KyozoWeb.Endpoint,
  static_url: [host: "cdn.kyozo.com", port: 443, scheme: "https"]
```

This integration approach gives you the best of both worlds: the real-time capabilities of Phoenix LiveView with the rich interactivity of Svelte 5 components.
