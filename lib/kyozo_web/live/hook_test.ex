defmodule KyozoWeb.Live.HookTest do
  use KyozoWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-8">
      <h1 class="text-2xl font-bold mb-6">LiveView Hook Test</h1>
      <!-- Basic Debug Hook Test -->
      <div class="mb-8 p-4 border rounded">
        <h2 class="text-lg font-semibold mb-2">Debug Hook Test</h2>
        <div phx-hook="DebugHook" id="debug-hook-test" class="p-4 bg-gray-100 rounded">
          This text should be replaced if DebugHook is working
        </div>
      </div>
      <!-- Simple JavaScript Hook Test -->
      <div class="mb-8 p-4 border rounded">
        <h2 class="text-lg font-semibold mb-2">Simple Hook Test</h2>
        <div phx-hook="SimpleHook" id="simple-hook-test" class="p-4 bg-blue-100 rounded">
          SimpleHook should modify this text
        </div>
      </div>
      <!-- Connection Status -->
      <div class="mb-8 p-4 border rounded">
        <h2 class="text-lg font-semibold mb-2">Connection Status</h2>
        <div class="text-sm text-gray-600">
          Check browser console for debug logs
        </div>
      </div>
    </div>
    """
  end
end
