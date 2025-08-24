defmodule Kyozo.Collaboration do
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
    resource Kyozo.Collaboration.Session
    resource Kyozo.Collaboration.Operation
    resource Kyozo.Collaboration.Cursor
    resource Kyozo.Collaboration.Presence
  end
end
