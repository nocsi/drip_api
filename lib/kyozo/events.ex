defmodule Kyozo.Events do
  use Ash.Domain,
    otp_app: :kyozo

    resources do
      resource Kyozo.Events.Event
    end
end
