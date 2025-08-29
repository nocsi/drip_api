# This file ensures UUID v7 everywhere
import Config

config :kyozo, Kyozo.Repo,
  migration_primary_key: [
    name: :id,
    type: :uuid,
    default: {:fragment, "uuid_generate_v7()"}
  ],
  migration_foreign_key: [type: :uuid],
  migration_timestamps: [type: :utc_datetime_usec]

config :ash, :default_uuid_version, :v7
