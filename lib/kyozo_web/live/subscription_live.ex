defmodule KyozoWeb.SubscriptionLive do
  use KyozoWeb, :live_view

  alias Kyozo.Billing
  alias Kyozo.Billing.AppleReceiptValidator

  @impl true
  def mount(_params, session, socket) do
    if connected?(socket) do
      # Subscribe to billing events for this user
      user_id = get_user_id(session)
      Billing.subscribe("user:#{user_id}")

      # Also subscribe to real-time usage updates
      Phoenix.PubSub.subscribe(Kyozo.PubSub, "ai_usage:#{user_id}")
    end

    user = get_current_user(session)

    {:ok,
     socket
     |> assign(:current_user, user)
     |> assign(:subscription_status, :loading)
     |> assign(:usage_limits, nil)
     |> assign(:processing_receipt, false)
     |> load_subscription_data()}
  end

  @impl true
  def handle_info({:subscription_updated, subscription}, socket) do
    # Real-time subscription update from backend
    {:noreply,
     socket
     |> assign(:subscription_status, subscription.status)
     |> load_usage_limits(subscription)}
  end

  def handle_info({:ai_usage_updated, usage_data}, socket) do
    # Real-time usage update when AI API is called
    current_limits = socket.assigns.usage_limits || %{}

    updated_limits =
      Map.merge(current_limits, %{
        current_usage: usage_data.current_usage,
        remaining_requests: calculate_remaining(usage_data)
      })

    {:noreply, assign(socket, :usage_limits, updated_limits)}
  end

  def handle_info({:billing_event, event, payload}, socket) do
    case event do
      :subscription_created ->
        {:noreply,
         socket
         |> put_flash(:info, "Subscription activated successfully!")
         |> load_subscription_data()}

      :subscription_renewed ->
        {:noreply,
         socket
         |> put_flash(:info, "Subscription renewed automatically")
         |> load_subscription_data()}

      :subscription_expired ->
        {:noreply,
         socket
         |> put_flash(:warning, "Subscription has expired")
         |> assign(:subscription_status, :expired)}

      :payment_failed ->
        {:noreply,
         socket
         |> put_flash(:error, "Payment failed. Please update your payment method.")
         |> assign(:subscription_status, :past_due)}

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event(
        "validate_apple_receipt",
        %{"receipt_data" => receipt_data, "plan_code" => plan_code},
        socket
      ) do
    user = socket.assigns.current_user

    send(self(), {:validate_receipt, receipt_data, plan_code, user})

    {:noreply, assign(socket, :processing_receipt, true)}
  end

  def handle_event("refresh_subscription", _params, socket) do
    {:noreply, load_subscription_data(socket)}
  end

  @impl true
  def handle_info({:validate_receipt, receipt_data, plan_code, user}, socket) do
    case validate_apple_receipt_async(receipt_data, plan_code, user) do
      {:ok, subscription} ->
        # Broadcast to all connected devices for this user
        Phoenix.PubSub.broadcast(
          Kyozo.PubSub,
          "user:#{user.id}",
          {:subscription_updated, subscription}
        )

        {:noreply,
         socket
         |> assign(:processing_receipt, false)
         |> put_flash(:info, "Subscription validated successfully!")
         |> load_subscription_data()}

      {:error, reason} ->
        {:noreply,
         socket
         |> assign(:processing_receipt, false)
         |> put_flash(:error, "Failed to validate subscription: #{reason}")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto p-6">
      <div class="bg-white rounded-lg shadow-lg p-8">
        <h1 class="text-3xl font-bold text-gray-900 mb-8">Your Subscription</h1>
        
    <!-- Subscription Status -->
        <div class="mb-8">
          <div class="flex items-center justify-between">
            <h2 class="text-xl font-semibold text-gray-800">Current Plan</h2>
            <button
              phx-click="refresh_subscription"
              class="text-blue-600 hover:text-blue-800 font-medium"
            >
              Refresh
            </button>
          </div>

          <%= if @subscription_status == :loading do %>
            <div class="animate-pulse bg-gray-200 h-8 w-48 rounded mt-2"></div>
          <% else %>
            <div class="mt-2 flex items-center space-x-3">
              <span class="text-2xl font-bold text-gray-900">
                {format_plan_name(@subscription_status)}
              </span>
              <span class={"px-3 py-1 rounded-full text-sm font-medium #{status_color(@subscription_status)}"}>
                {format_status(@subscription_status)}
              </span>
            </div>
          <% end %>
        </div>
        
    <!-- Usage Limits -->
        <%= if @usage_limits do %>
          <div class="mb-8">
            <h3 class="text-lg font-semibold text-gray-800 mb-4">Usage This Month</h3>

            <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
              <!-- AI Requests -->
              <div class="bg-blue-50 rounded-lg p-4">
                <div class="text-blue-800 font-medium">AI Requests</div>
                <div class="text-2xl font-bold text-blue-900">
                  {@usage_limits.current_usage}
                </div>
                <div class="text-sm text-blue-600">
                  of {format_limit(@usage_limits.ai_requests_per_month)} this month
                </div>
                
    <!-- Progress bar -->
                <div class="mt-2 bg-blue-200 rounded-full h-2">
                  <div
                    class="bg-blue-600 h-2 rounded-full transition-all duration-300"
                    style={"width: #{usage_percentage(@usage_limits)}%"}
                  >
                  </div>
                </div>
              </div>
              
    <!-- Remaining Requests -->
              <div class="bg-green-50 rounded-lg p-4">
                <div class="text-green-800 font-medium">Remaining</div>
                <div class="text-2xl font-bold text-green-900">
                  {format_remaining(@usage_limits.remaining_requests)}
                </div>
                <div class="text-sm text-green-600">
                  requests left
                </div>
              </div>
              
    <!-- Rate Limit -->
              <div class="bg-purple-50 rounded-lg p-4">
                <div class="text-purple-800 font-medium">Rate Limit</div>
                <div class="text-2xl font-bold text-purple-900">
                  {@usage_limits.rate_limit_per_minute}
                </div>
                <div class="text-sm text-purple-600">
                  requests per minute
                </div>
              </div>
            </div>
          </div>
        <% end %>
        
    <!-- Apple Receipt Validation (for iOS users) -->
        <div class="mb-8 bg-gray-50 rounded-lg p-6">
          <h3 class="text-lg font-semibold text-gray-800 mb-4">
            iOS App Store Subscription
          </h3>

          <p class="text-gray-600 mb-4">
            If you purchased a subscription through the iOS app, validate it here to sync your account.
          </p>

          <%= if @processing_receipt do %>
            <div class="flex items-center space-x-2 text-blue-600">
              <svg class="animate-spin h-5 w-5" viewBox="0 0 24 24">
                <circle
                  class="opacity-25"
                  cx="12"
                  cy="12"
                  r="10"
                  stroke="currentColor"
                  stroke-width="4"
                  fill="none"
                />
                <path
                  class="opacity-75"
                  fill="currentColor"
                  d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
                />
              </svg>
              <span>Validating receipt...</span>
            </div>
          <% else %>
            <button
              class="bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700 transition-colors"
              onclick="validateAppleReceipt()"
            >
              Validate iOS Purchase
            </button>
          <% end %>
        </div>
        
    <!-- Subscription History -->
        <div class="mb-8">
          <h3 class="text-lg font-semibold text-gray-800 mb-4">Recent Activity</h3>

          <div class="space-y-3">
            <!-- This would be populated with recent subscription events -->
            <div class="flex items-center justify-between py-2 border-b border-gray-200">
              <div>
                <div class="font-medium text-gray-900">Subscription Renewed</div>
                <div class="text-sm text-gray-600">Pro Monthly - $29.99</div>
              </div>
              <div class="text-sm text-gray-500">
                2 days ago
              </div>
            </div>

            <div class="flex items-center justify-between py-2 border-b border-gray-200">
              <div>
                <div class="font-medium text-gray-900">AI Usage Alert</div>
                <div class="text-sm text-gray-600">75% of monthly limit used</div>
              </div>
              <div class="text-sm text-gray-500">
                5 days ago
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <script>
      // JavaScript integration for iOS receipt validation
      function validateAppleReceipt() {
        // This would be called from iOS app via WKWebView message handler
        if (window.webkit && window.webkit.messageHandlers.appleReceipt) {
          window.webkit.messageHandlers.appleReceipt.postMessage({
            action: 'getReceipt'
          });
        } else {
          alert('This feature is only available in the iOS app');
        }
      }

      // Handle receipt data from iOS
      window.handleAppleReceipt = function(receiptData, planCode) {
        const hook = this.liveSocket.getHookCallbacks('SubscriptionLive');
        hook.pushEvent('validate_apple_receipt', {
          receipt_data: receiptData,
          plan_code: planCode
        });
      };

      // Real-time usage updates
      window.addEventListener('phx:ai_usage_updated', (e) => {
        const { current_usage, remaining_requests } = e.detail;
        
        // Update UI immediately for better UX
        const currentUsageElements = document.querySelectorAll('[data-usage="current"]');
        currentUsageElements.forEach(el => {
          el.textContent = current_usage;
        });
        
        const remainingElements = document.querySelectorAll('[data-usage="remaining"]');
        remainingElements.forEach(el => {
          el.textContent = remaining_requests === 'unlimited' ? '∞' : remaining_requests;
        });
      });
    </script>
    """
  end

  # Private helper functions

  defp load_subscription_data(socket) do
    user = socket.assigns.current_user

    case Billing.get_active_user_subscription(user.id) do
      {:ok, subscription} ->
        socket
        |> assign(:subscription_status, subscription.status)
        |> load_usage_limits(subscription)

      {:error, :not_found} ->
        socket
        |> assign(:subscription_status, :none)
        |> assign(:usage_limits, default_free_limits())
    end
  end

  defp load_usage_limits(socket, subscription) do
    user = socket.assigns.current_user
    current_usage = get_monthly_ai_usage(user.id)

    plan_features = subscription.plan.features
    monthly_limit = Map.get(plan_features, "ai_requests_per_month", 1000)

    remaining =
      case monthly_limit do
        :unlimited -> :unlimited
        limit when is_integer(limit) -> max(0, limit - current_usage)
      end

    usage_limits = %{
      ai_requests_per_month: monthly_limit,
      current_usage: current_usage,
      remaining_requests: remaining,
      rate_limit_per_minute: Map.get(plan_features, "rate_limit_per_minute", 5)
    }

    assign(socket, :usage_limits, usage_limits)
  end

  defp default_free_limits do
    %{
      ai_requests_per_month: 1000,
      current_usage: 0,
      remaining_requests: 1000,
      rate_limit_per_minute: 5
    }
  end

  defp validate_apple_receipt_async(receipt_data, plan_code, user) do
    case AppleReceiptValidator.validate_and_parse(receipt_data) do
      {:ok, receipt_info} ->
        case Billing.get_plan_by_code(plan_code) do
          {:ok, plan} ->
            case Billing.ensure_apple_customer(user, receipt_data) do
              {:ok, customer} ->
                create_or_update_apple_subscription(customer, plan, receipt_data, receipt_info)

              {:error, reason} ->
                {:error, reason}
            end

          {:error, _} ->
            {:error, "Invalid plan code"}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp create_or_update_apple_subscription(customer, plan, receipt_data, receipt_info) do
    subscription_params = %{
      user_id: customer.user_id,
      customer_id: customer.id,
      plan_id: plan.id,
      provider: :apple,
      apple_transaction_id: receipt_info.latest_transaction_id,
      apple_original_transaction_id: receipt_info.original_transaction_id,
      apple_product_id: receipt_info.product_id,
      apple_receipt_data: receipt_data,
      status: determine_apple_status(receipt_info),
      current_period_start: receipt_info.purchase_date,
      current_period_end: receipt_info.expires_date,
      auto_renew_enabled: receipt_info.auto_renew_status
    }

    case Billing.get_subscription_by_apple_transaction(receipt_info.original_transaction_id) do
      {:ok, existing_subscription} ->
        Billing.update_subscription(existing_subscription, subscription_params)

      {:error, :not_found} ->
        Billing.create_subscription(subscription_params)
    end
  end

  defp determine_apple_status(receipt_info) do
    now = DateTime.utc_now()

    cond do
      receipt_info.cancellation_date ->
        :canceled

      DateTime.compare(receipt_info.expires_date, now) == :gt ->
        :active

      receipt_info.grace_period_expires_date &&
          DateTime.compare(receipt_info.grace_period_expires_date, now) == :gt ->
        :past_due

      true ->
        :expired
    end
  end

  defp get_monthly_ai_usage(user_id) do
    now = DateTime.utc_now()
    start_of_month = %{now | day: 1, hour: 0, minute: 0, second: 0}

    case Billing.get_monthly_usage(user_id, start_of_month.month, start_of_month.year) do
      {:ok, usage_records} ->
        usage_records
        |> Enum.filter(&(&1.service == "ai_api"))
        |> Enum.count()

      {:error, _} ->
        0
    end
  end

  defp get_current_user(session) do
    # Get user from session - implement based on your auth system
    session["current_user"]
  end

  defp get_user_id(session) do
    session["current_user"].id
  end

  defp format_plan_name(:none), do: "Free Plan"
  defp format_plan_name(:loading), do: "Loading..."
  defp format_plan_name(status) when is_atom(status), do: "Pro Plan"
  defp format_plan_name(_), do: "Unknown Plan"

  defp format_status(:active), do: "Active"
  defp format_status(:expired), do: "Expired"
  defp format_status(:past_due), do: "Past Due"
  defp format_status(:none), do: "Free"
  defp format_status(_), do: "Unknown"

  defp status_color(:active), do: "bg-green-100 text-green-800"
  defp status_color(:expired), do: "bg-red-100 text-red-800"
  defp status_color(:past_due), do: "bg-yellow-100 text-yellow-800"
  defp status_color(:none), do: "bg-gray-100 text-gray-800"
  defp status_color(_), do: "bg-gray-100 text-gray-800"

  defp format_limit(:unlimited), do: "∞"
  defp format_limit(limit) when is_integer(limit), do: "#{limit}"
  defp format_limit(_), do: "Unknown"

  defp format_remaining(:unlimited), do: "∞"
  defp format_remaining(remaining) when is_integer(remaining), do: "#{remaining}"
  defp format_remaining(_), do: "0"

  defp usage_percentage(%{current_usage: current, ai_requests_per_month: :unlimited}), do: 0

  defp usage_percentage(%{current_usage: current, ai_requests_per_month: limit})
       when is_integer(limit) and limit > 0 do
    min(100, round(current / limit * 100))
  end

  defp usage_percentage(_), do: 0

  defp calculate_remaining(%{ai_requests_per_month: :unlimited}), do: :unlimited

  defp calculate_remaining(%{current_usage: current, ai_requests_per_month: limit})
       when is_integer(limit) do
    max(0, limit - current)
  end
end
