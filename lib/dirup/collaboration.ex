defmodule Dirup.Collaboration do
  @moduledoc """
  Collaboration domain for real-time collaborative editing features.

  This domain provides:
  - Real-time document synchronization
  - Operational transformation for concurrent edits
  - Live cursor tracking and presence awareness
  - Collaborative session management
  - Conflict resolution for simultaneous edits
  """

  use Ash.Domain

  resources do
    resource Dirup.Collaboration.Session
    resource Dirup.Collaboration.Operation
    resource Dirup.Collaboration.Cursor
    resource Dirup.Collaboration.Presence
  end
end
