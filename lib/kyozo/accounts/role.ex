defmodule Kyozo.Accounts.Role do
  use Ash.Type.Enum, values: [:admin, :editor, :user]
end
