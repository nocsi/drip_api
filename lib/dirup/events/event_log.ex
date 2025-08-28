defmodule Dirup.Events.Event do
  use Ash.Resource,
    otp_app: :dirup,
    domain: Dirup.Events,
    extensions: [AshEvents.EventLog]

  event_log do
    # Module that implements clear_records! callback
    clear_records_for_replay(Dirup.Events.ClearAllRecords)

    # Optional. Defaults to :integer, Ash.Type.UUIDv7 is the recommended option
    # if your event log is set up with multitenancy via the attribute-strategy.
    primary_key_type(Ash.Type.UUIDv7)

    # Optional, defaults to :uuid
    record_id_type(:uuid)

    # Store primary key of actors running the actions
    persist_actor_primary_key(:user_id, Dirup.Accounts.User)
    # persist_actor_primary_key :system_actor, Dirup.SystemActor, attribute_type: :string
  end

  # Optional: Configure replay overrides for version handling
  replay_overrides do
    replay_override Dirup.Accounts.User, :create do
      versions([1])
      route_to(Dirup.Accounts.User, :old_create_v1)
    end
  end
end
