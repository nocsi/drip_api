defmodule Kyozo.Events.Event do
  use Ash.Resource,
    otp_app: :kyozo,
    domain: Kyozo.Events,
    extensions: [AshEvents.EventLog]

  event_log do
    # Module that implements clear_records! callback
    clear_records_for_replay Kyozo.Events.ClearAllRecords

    # Optional. Defaults to :integer, Ash.Type.UUIDv7 is the recommended option
    # if your event log is set up with multitenancy via the attribute-strategy.
    primary_key_type Ash.Type.UUIDv7

    # Optional, defaults to :uuid
    record_id_type :uuid

    # Store primary key of actors running the actions
    persist_actor_primary_key :user_id, Kyozo.Accounts.User
    # persist_actor_primary_key :system_actor, Kyozo.SystemActor, attribute_type: :string
  end

  # Optional: Configure replay overrides for version handling
  replay_overrides do
    replay_override Kyozo.Accounts.User, :create do
      versions [1]
      route_to Kyozo.Accounts.User, :old_create_v1
    end
  end
end
