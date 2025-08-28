defmodule Validations.ValidateMediaType do
  @moduledoc """
  Placeholder validation for media type. Ensures compile; real rules can be added later.
  """
  use Ash.Resource.Validation

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def validate(_changeset, _opts), do: :ok
end

defmodule Validations.ValidateFileSize do
  @moduledoc """
  Placeholder validation for file size. Ensures compile; real rules can be added later.
  """
  use Ash.Resource.Validation

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def validate(_changeset, _opts), do: :ok
end

defmodule Validations.ValidateAccessibilityFeatures do
  @moduledoc """
  Placeholder validation for accessibility features. Ensures compile; real rules can be added later.
  """
  use Ash.Resource.Validation

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def validate(_changeset, _opts), do: :ok
end

