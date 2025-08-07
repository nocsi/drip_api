defmodule KyozoWeb.Live.AuthTestLive do
  use KyozoWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Authentication Test")
      |> assign(:current_user, socket.assigns[:current_user])

    {:ok, socket}
  end

  @impl true
  def handle_event("sign_out", _params, socket) do
    {:noreply, redirect(socket, to: "/auth/sign_out")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50 py-12 px-4 sm:px-6 lg:px-8">
      <div class="max-w-4xl mx-auto">
        <div class="text-center mb-8">
          <h1 class="text-3xl font-bold text-gray-900">Kyozo Authentication Test</h1>
          <p class="mt-2 text-gray-600">Test all authentication methods</p>
        </div>

        <%= if @current_user do %>
          <!-- Authenticated State -->
          <div class="bg-white shadow rounded-lg p-6 mb-8">
            <div class="flex items-center justify-between">
              <div>
                <h2 class="text-xl font-semibold text-green-800">✅ Authenticated</h2>
                <p class="text-gray-600 mt-1">Welcome back, <strong><%= @current_user.email %></strong>!</p>
                <p class="text-sm text-gray-500 mt-1">
                  Role: <span class="font-medium"><%= @current_user.role %></span>
                </p>
                <%= if @current_user.confirmed_at do %>
                  <p class="text-sm text-gray-500">
                    Confirmed: <span class="text-green-600">✓</span>
                  </p>
                <% else %>
                  <p class="text-sm text-yellow-600">
                    Email not confirmed yet
                  </p>
                <% end %>
              </div>
              <button
                phx-click="sign_out"
                class="px-4 py-2 bg-red-600 text-white rounded-md hover:bg-red-700 focus:outline-none focus:ring-2 focus:ring-red-500"
              >
                Sign Out
              </button>
            </div>
          </div>

          <!-- User Details Card -->
          <div class="bg-white shadow rounded-lg p-6 mb-8">
            <h3 class="text-lg font-medium text-gray-900 mb-4">User Details</h3>
            <dl class="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <div>
                <dt class="text-sm font-medium text-gray-500">User ID</dt>
                <dd class="text-sm text-gray-900"><%= @current_user.id %></dd>
              </div>
              <div>
                <dt class="text-sm font-medium text-gray-500">Email</dt>
                <dd class="text-sm text-gray-900"><%= @current_user.email %></dd>
              </div>
              <div>
                <dt class="text-sm font-medium text-gray-500">Role</dt>
                <dd class="text-sm text-gray-900">
                  <span class="px-2 py-1 text-xs font-medium bg-blue-100 text-blue-800 rounded-full">
                    <%= @current_user.role %>
                  </span>
                </dd>
              </div>
              <div>
                <dt class="text-sm font-medium text-gray-500">Confirmed At</dt>
                <dd class="text-sm text-gray-900">
                  <%= if @current_user.confirmed_at do %>
                    <%= Calendar.strftime(@current_user.confirmed_at, "%Y-%m-%d %H:%M:%S UTC") %>
                  <% else %>
                    <span class="text-yellow-600">Not confirmed</span>
                  <% end %>
                </dd>
              </div>
            </dl>
          </div>

          <!-- Available Actions -->
          <div class="bg-white shadow rounded-lg p-6">
            <h3 class="text-lg font-medium text-gray-900 mb-4">Available Actions</h3>
            <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
              <a
                href="/home"
                class="block p-4 border border-gray-200 rounded-lg hover:border-gray-300 hover:shadow-sm transition-all"
              >
                <h4 class="font-medium text-gray-900">Home</h4>
                <p class="text-sm text-gray-500 mt-1">Go to main application</p>
              </a>
              <a
                href="/editor"
                class="block p-4 border border-gray-200 rounded-lg hover:border-gray-300 hover:shadow-sm transition-all"
              >
                <h4 class="font-medium text-gray-900">Editor</h4>
                <p class="text-sm text-gray-500 mt-1">Access the document editor</p>
              </a>
              <a
                href="/portal"
                class="block p-4 border border-gray-200 rounded-lg hover:border-gray-300 hover:shadow-sm transition-all"
              >
                <h4 class="font-medium text-gray-900">Portal</h4>
                <p class="text-sm text-gray-500 mt-1">User portal</p>
              </a>
            </div>
          </div>
        <% else %>
          <!-- Unauthenticated State -->
          <div class="bg-white shadow rounded-lg p-6 mb-8">
            <h2 class="text-xl font-semibold text-red-800 mb-4">🔒 Not Authenticated</h2>
            <p class="text-gray-600 mb-6">Choose an authentication method to test:</p>

            <!-- Authentication Methods Grid -->
            <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
              <!-- Password Authentication -->
              <div class="border border-gray-200 rounded-lg p-6 hover:border-gray-300 transition-colors">
                <div class="flex items-center mb-3">
                  <div class="w-8 h-8 bg-blue-100 rounded-full flex items-center justify-center mr-3">
                    <svg class="w-4 h-4 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"></path>
                    </svg>
                  </div>
                  <h3 class="font-medium text-gray-900">Password</h3>
                </div>
                <p class="text-sm text-gray-500 mb-4">Traditional email and password login</p>
                <div class="space-y-2">
                  <a
                    href="/auth/sign_in"
                    class="block w-full text-center px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 text-sm font-medium"
                  >
                    Sign In
                  </a>
                  <a
                    href="/auth/register"
                    class="block w-full text-center px-4 py-2 border border-blue-600 text-blue-600 rounded-md hover:bg-blue-50 text-sm font-medium"
                  >
                    Register
                  </a>
                </div>
              </div>

              <!-- Magic Link Authentication -->
              <div class="border border-gray-200 rounded-lg p-6 hover:border-gray-300 transition-colors">
                <div class="flex items-center mb-3">
                  <div class="w-8 h-8 bg-purple-100 rounded-full flex items-center justify-center mr-3">
                    <svg class="w-4 h-4 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 4.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"></path>
                    </svg>
                  </div>
                  <h3 class="font-medium text-gray-900">Magic Link</h3>
                </div>
                <p class="text-sm text-gray-500 mb-4">Passwordless authentication via email</p>
                <a
                  href="/auth/magic_link"
                  class="block w-full text-center px-4 py-2 bg-purple-600 text-white rounded-md hover:bg-purple-700 text-sm font-medium"
                >
                  Send Magic Link
                </a>
              </div>

              <!-- OAuth2 Authentication -->
              <div class="border border-gray-200 rounded-lg p-6 hover:border-gray-300 transition-colors">
                <div class="flex items-center mb-3">
                  <div class="w-8 h-8 bg-green-100 rounded-full flex items-center justify-center mr-3">
                    <svg class="w-4 h-4 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"></path>
                    </svg>
                  </div>
                  <h3 class="font-medium text-gray-900">OAuth2</h3>
                </div>
                <p class="text-sm text-gray-500 mb-4">Sign in with third-party providers</p>
                <div class="space-y-2">
                  <a
                    href="/auth/apple"
                    class="flex items-center justify-center w-full px-4 py-2 bg-black text-white rounded-md hover:bg-gray-800 text-sm font-medium"
                  >
                    <svg class="w-4 h-4 mr-2" fill="currentColor" viewBox="0 0 24 24">
                      <path d="M12.017 0C5.396 0 .029 5.367.029 11.987c0 5.079 3.158 9.417 7.618 11.024-.105-.949-.199-2.403.041-3.439.219-.937 1.404-5.965 1.404-5.965s-.359-.72-.359-1.781c0-1.663.967-2.911 2.168-2.911 1.024 0 1.518.769 1.518 1.688 0 1.029-.653 2.567-.992 3.992-.285 1.193.6 2.165 1.775 2.165 2.128 0 3.768-2.245 3.768-5.487 0-2.861-2.063-4.869-5.008-4.869-3.41 0-5.409 2.562-5.409 5.199 0 1.033.394 2.143.889 2.741.099.12.112.225.085.347-.09.375-.294 1.198-.334 1.363-.053.225-.172.271-.402.165-1.495-.69-2.433-2.878-2.433-4.646 0-3.776 2.748-7.252 7.92-7.252 4.158 0 7.392 2.967 7.392 6.923 0 4.135-2.607 7.462-6.233 7.462-1.214 0-2.357-.629-2.748-1.378l-.748 2.853c-.271 1.043-1.002 2.35-1.492 3.146C9.57 23.812 10.763 24.009 12.017 24.009c6.624 0 11.99-5.367 11.99-11.988C24.007 5.367 18.641.001.001 12.017.001z"/>
                    </svg>
                    Apple
                  </a>
                  <a
                    href="/auth/google"
                    class="flex items-center justify-center w-full px-4 py-2 border border-gray-300 text-gray-700 rounded-md hover:bg-gray-50 text-sm font-medium"
                  >
                    <svg class="w-4 h-4 mr-2" viewBox="0 0 24 24">
                      <path fill="#4285F4" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"/>
                      <path fill="#34A853" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"/>
                      <path fill="#FBBC05" d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"/>
                      <path fill="#EA4335" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"/>
                    </svg>
                    Google
                  </a>
                </div>
              </div>
            </div>
          </div>

          <!-- Development User Card -->
          <div class="bg-yellow-50 border border-yellow-200 rounded-lg p-6">
            <div class="flex items-start">
              <div class="w-8 h-8 bg-yellow-100 rounded-full flex items-center justify-center mr-3 mt-1">
                <svg class="w-4 h-4 text-yellow-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
                </svg>
              </div>
              <div class="flex-1">
                <h3 class="font-medium text-yellow-800">Development Admin User</h3>
                <p class="text-sm text-yellow-700 mt-1">
                  For development and testing, you can use the pre-created admin account:
                </p>
                <div class="mt-3 p-3 bg-yellow-100 rounded border border-yellow-300">
                  <p class="text-sm font-mono text-yellow-800">
                    <strong>Email:</strong> admin@kyozo.dev<br>
                    <strong>Password:</strong> devpassword123<br>
                    <strong>Role:</strong> admin
                  </p>
                </div>
                <p class="text-xs text-yellow-600 mt-2">
                  This user is automatically created during development setup.
                </p>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end