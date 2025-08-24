defmodule Kyozo.Billing.AppleReceiptValidator do
  @moduledoc """
  Validates Apple App Store receipts and parses subscription information
  """
  require Logger

  @apple_production_url "https://buy.itunes.apple.com/verifyReceipt"
  @apple_sandbox_url "https://sandbox.itunes.apple.com/verifyReceipt"

  @doc """
  Validates an Apple receipt and returns parsed subscription data
  """
  def validate_and_parse(receipt_data) when is_binary(receipt_data) do
    password = get_app_store_shared_secret()

    request_body = %{
      "receipt-data" => receipt_data,
      "password" => password,
      "exclude-old-transactions" => true
    }

    # Try production first, fall back to sandbox
    case make_request(@apple_production_url, request_body) do
      {:ok, response} ->
        parse_response(response)

      # Sandbox receipt sent to production
      {:error, 21007} ->
        make_request(@apple_sandbox_url, request_body)
        |> case do
          {:ok, response} -> parse_response(response)
          error -> error
        end

      error ->
        error
    end
  end

  @doc """
  Validates receipt from Apple's server-to-server notifications
  """
  def validate_notification(notification_payload) do
    with {:ok, receipt_data} <- extract_receipt_from_notification(notification_payload),
         {:ok, parsed_data} <- validate_and_parse(receipt_data) do
      notification_type = notification_payload["notification_type"]

      {:ok,
       %{
         notification_type: notification_type,
         subscription_data: parsed_data,
         environment: notification_payload["environment"]
       }}
    end
  end

  @doc """
  Check if a subscription is currently active based on Apple receipt data
  """
  def subscription_active?(receipt_info) do
    now = DateTime.utc_now()
    expires_at = parse_apple_date(receipt_info["expires_date_ms"])
    grace_period_expires = parse_apple_date(receipt_info["grace_period_expires_date_ms"])

    cond do
      expires_at && DateTime.compare(expires_at, now) == :gt -> true
      grace_period_expires && DateTime.compare(grace_period_expires, now) == :gt -> true
      true -> false
    end
  end

  # Private functions

  defp make_request(url, body) do
    headers = [{"Content-Type", "application/json"}]
    json_body = Jason.encode!(body)

    case HTTPoison.post(url, json_body, headers, recv_timeout: 30_000) do
      {:ok, %HTTPoison.Response{status_code: 200, body: response_body}} ->
        case Jason.decode(response_body) do
          {:ok, response} -> {:ok, response}
          {:error, _} -> {:error, "Invalid JSON response from Apple"}
        end

      {:ok, %HTTPoison.Response{status_code: status_code}} ->
        {:error, "HTTP #{status_code} from Apple"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, "Network error: #{reason}"}
    end
  end

  defp parse_response(%{"status" => 0, "receipt" => receipt}) do
    latest_receipt_info = receipt["latest_receipt_info"] || []
    pending_renewal_info = receipt["pending_renewal_info"] || []

    # Get the most recent transaction
    latest_transaction =
      latest_receipt_info
      |> Enum.sort_by(& &1["expires_date_ms"], :desc)
      |> List.first()

    if latest_transaction do
      pending_info =
        Enum.find(pending_renewal_info, fn info ->
          info["original_transaction_id"] == latest_transaction["original_transaction_id"]
        end) || %{}

      {:ok,
       %{
         original_transaction_id: latest_transaction["original_transaction_id"],
         latest_transaction_id: latest_transaction["transaction_id"],
         product_id: latest_transaction["product_id"],
         purchase_date: parse_apple_date(latest_transaction["purchase_date_ms"]),
         expires_date: parse_apple_date(latest_transaction["expires_date_ms"]),
         auto_renew_status: pending_info["auto_renew_status"] == "1",
         grace_period_expires_date:
           parse_apple_date(latest_transaction["grace_period_expires_date_ms"]),
         is_trial_period: latest_transaction["is_trial_period"] == "true",
         is_in_intro_offer_period: latest_transaction["is_in_intro_offer_period"] == "true",
         cancellation_date: parse_apple_date(latest_transaction["cancellation_date_ms"]),
         web_order_line_item_id: latest_transaction["web_order_line_item_id"],
         environment: receipt["environment"] || "Production"
       }}
    else
      {:error, "No valid subscription transactions found in receipt"}
    end
  end

  defp parse_response(%{"status" => status}) when status != 0 do
    error_message =
      case status do
        21000 -> "The App Store could not read the JSON object you provided."
        21002 -> "The data in the receipt-data property was malformed or missing."
        21003 -> "The receipt could not be authenticated."
        21004 -> "The shared secret you provided does not match the shared secret on file."
        21005 -> "The receipt server is not currently available."
        21006 -> "This receipt is valid but the subscription has expired."
        21007 -> "This receipt is from the sandbox environment."
        21008 -> "This receipt is from the production environment."
        21009 -> "Internal data access error."
        21010 -> "The user account cannot be found or has been deleted."
        _ -> "Unknown error (#{status})"
      end

    {:error, error_message}
  end

  defp parse_apple_date(nil), do: nil

  defp parse_apple_date(date_ms) when is_binary(date_ms) do
    case Integer.parse(date_ms) do
      {timestamp, _} -> DateTime.from_unix!(timestamp, :millisecond)
      _ -> nil
    end
  end

  defp extract_receipt_from_notification(payload) do
    case payload do
      %{"unified_receipt" => %{"latest_receipt" => receipt}} -> {:ok, receipt}
      %{"latest_receipt" => receipt} -> {:ok, receipt}
      _ -> {:error, "No receipt data in notification"}
    end
  end

  defp get_app_store_shared_secret do
    System.get_env("APPLE_APP_STORE_SHARED_SECRET") ||
      Application.get_env(:kyozo, :apple_app_store_shared_secret) ||
      raise "APPLE_APP_STORE_SHARED_SECRET not configured"
  end
end
