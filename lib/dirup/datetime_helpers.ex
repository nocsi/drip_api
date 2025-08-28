defmodule Dirup.DateTimeHelpers do
  @moduledoc """
  DateTime utility functions for Dirup.

  Provides commonly used date/time operations that are not available
  in the standard DateTime module.
  """

  @doc """
  Returns a DateTime representing the beginning of the month for the given DateTime.

  ## Examples

      iex> dt = ~U[2024-03-15 14:30:45Z]
      iex> Dirup.DateTimeHelpers.beginning_of_month(dt)
      ~U[2024-03-01 00:00:00Z]

      iex> dt = ~U[2024-01-31 23:59:59Z]
      iex> Dirup.DateTimeHelpers.beginning_of_month(dt)
      ~U[2024-01-01 00:00:00Z]
  """
  def beginning_of_month(%DateTime{} = datetime) do
    %{datetime | day: 1, hour: 0, minute: 0, second: 0, microsecond: {0, 0}}
  end

  @doc """
  Returns a DateTime representing the end of the month for the given DateTime.

  ## Examples

      iex> dt = ~U[2024-02-15 14:30:45Z]
      iex> Dirup.DateTimeHelpers.end_of_month(dt)
      ~U[2024-02-29 23:59:59.999999Z]

      iex> dt = ~U[2024-01-15 14:30:45Z]
      iex> Dirup.DateTimeHelpers.end_of_month(dt)
      ~U[2024-01-31 23:59:59.999999Z]
  """
  def end_of_month(%DateTime{} = datetime) do
    last_day = days_in_month(datetime.year, datetime.month)
    %{datetime | day: last_day, hour: 23, minute: 59, second: 59, microsecond: {999_999, 6}}
  end

  @doc """
  Returns a DateTime representing the beginning of the day for the given DateTime.

  ## Examples

      iex> dt = ~U[2024-03-15 14:30:45Z]
      iex> Dirup.DateTimeHelpers.beginning_of_day(dt)
      ~U[2024-03-15 00:00:00Z]
  """
  def beginning_of_day(%DateTime{} = datetime) do
    %{datetime | hour: 0, minute: 0, second: 0, microsecond: {0, 0}}
  end

  @doc """
  Returns a DateTime representing the end of the day for the given DateTime.

  ## Examples

      iex> dt = ~U[2024-03-15 14:30:45Z]
      iex> Dirup.DateTimeHelpers.end_of_day(dt)
      ~U[2024-03-15 23:59:59.999999Z]
  """
  def end_of_day(%DateTime{} = datetime) do
    %{datetime | hour: 23, minute: 59, second: 59, microsecond: {999_999, 6}}
  end

  @doc """
  Returns a DateTime representing the beginning of the week (Monday) for the given DateTime.

  ## Examples

      iex> dt = ~U[2024-03-15 14:30:45Z] # Friday
      iex> Dirup.DateTimeHelpers.beginning_of_week(dt)
      ~U[2024-03-11 00:00:00Z] # Monday
  """
  def beginning_of_week(%DateTime{} = datetime) do
    days_from_monday = Date.day_of_week(datetime) - 1

    datetime
    |> DateTime.add(-days_from_monday, :day)
    |> beginning_of_day()
  end

  @doc """
  Returns a DateTime representing the end of the week (Sunday) for the given DateTime.

  ## Examples

      iex> dt = ~U[2024-03-15 14:30:45Z] # Friday
      iex> Dirup.DateTimeHelpers.end_of_week(dt)
      ~U[2024-03-17 23:59:59.999999Z] # Sunday
  """
  def end_of_week(%DateTime{} = datetime) do
    days_to_sunday = 7 - Date.day_of_week(datetime)

    datetime
    |> DateTime.add(days_to_sunday, :day)
    |> end_of_day()
  end

  @doc """
  Returns a DateTime representing the beginning of the year for the given DateTime.

  ## Examples

      iex> dt = ~U[2024-06-15 14:30:45Z]
      iex> Dirup.DateTimeHelpers.beginning_of_year(dt)
      ~U[2024-01-01 00:00:00Z]
  """
  def beginning_of_year(%DateTime{} = datetime) do
    %{datetime | month: 1, day: 1, hour: 0, minute: 0, second: 0, microsecond: {0, 0}}
  end

  @doc """
  Returns a DateTime representing the end of the year for the given DateTime.

  ## Examples

      iex> dt = ~U[2024-06-15 14:30:45Z]
      iex> Dirup.DateTimeHelpers.end_of_year(dt)
      ~U[2024-12-31 23:59:59.999999Z]
  """
  def end_of_year(%DateTime{} = datetime) do
    %{datetime | month: 12, day: 31, hour: 23, minute: 59, second: 59, microsecond: {999_999, 6}}
  end

  @doc """
  Add months to a DateTime, handling edge cases properly.

  ## Examples

      iex> dt = ~U[2024-01-31 12:00:00Z]
      iex> Dirup.DateTimeHelpers.add_months(dt, 1)
      ~U[2024-02-29 12:00:00Z] # Adjusts to last day of February in leap year

      iex> dt = ~U[2024-01-15 12:00:00Z]
      iex> Dirup.DateTimeHelpers.add_months(dt, 2)
      ~U[2024-03-15 12:00:00Z]
  """
  def add_months(%DateTime{} = datetime, months) when is_integer(months) do
    new_month = datetime.month + months
    {new_year, new_month} = normalize_year_month(datetime.year, new_month)

    # Handle day overflow (e.g., Jan 31 + 1 month = Feb 28/29)
    max_day = days_in_month(new_year, new_month)
    new_day = min(datetime.day, max_day)

    %{datetime | year: new_year, month: new_month, day: new_day}
  end

  @doc """
  Check if a year is a leap year.

  ## Examples

      iex> Dirup.DateTimeHelpers.leap_year?(2024)
      true

      iex> Dirup.DateTimeHelpers.leap_year?(2023)
      false

      iex> Dirup.DateTimeHelpers.leap_year?(2000)
      true

      iex> Dirup.DateTimeHelpers.leap_year?(1900)
      false
  """
  def leap_year?(year) when is_integer(year) do
    rem(year, 4) == 0 and (rem(year, 100) != 0 or rem(year, 400) == 0)
  end

  @doc """
  Get the number of days in a given month and year.

  ## Examples

      iex> Dirup.DateTimeHelpers.days_in_month(2024, 2)
      29

      iex> Dirup.DateTimeHelpers.days_in_month(2023, 2)
      28

      iex> Dirup.DateTimeHelpers.days_in_month(2024, 4)
      30
  """
  def days_in_month(year, month) when is_integer(year) and is_integer(month) do
    case month do
      m when m in [1, 3, 5, 7, 8, 10, 12] -> 31
      m when m in [4, 6, 9, 11] -> 30
      2 -> if leap_year?(year), do: 29, else: 28
    end
  end

  @doc """
  Get the age in years between two dates.

  ## Examples

      iex> birth = ~U[1990-06-15 00:00:00Z]
      iex> current = ~U[2024-06-14 23:59:59Z]
      iex> Dirup.DateTimeHelpers.age_in_years(birth, current)
      33

      iex> birth = ~U[1990-06-15 00:00:00Z]
      iex> current = ~U[2024-06-15 00:00:00Z]
      iex> Dirup.DateTimeHelpers.age_in_years(birth, current)
      34
  """
  def age_in_years(%DateTime{} = birth_date, %DateTime{} = current_date \\ DateTime.utc_now()) do
    years = current_date.year - birth_date.year

    # Adjust if birthday hasn't occurred this year yet
    if current_date.month < birth_date.month or
         (current_date.month == birth_date.month and current_date.day < birth_date.day) do
      years - 1
    else
      years
    end
  end

  @doc """
  Format a DateTime as a human-readable relative time string.

  ## Examples

      iex> now = DateTime.utc_now()
      iex> ago = DateTime.add(now, -3600, :second)
      iex> Dirup.DateTimeHelpers.time_ago(ago, now)
      "1 hour ago"
  """
  def time_ago(%DateTime{} = datetime, %DateTime{} = reference_time \\ DateTime.utc_now()) do
    diff_seconds = DateTime.diff(reference_time, datetime, :second)

    cond do
      diff_seconds < 60 ->
        "#{diff_seconds} second#{if diff_seconds != 1, do: "s"} ago"

      diff_seconds < 3600 ->
        minutes = div(diff_seconds, 60)
        "#{minutes} minute#{if minutes != 1, do: "s"} ago"

      diff_seconds < 86400 ->
        hours = div(diff_seconds, 3600)
        "#{hours} hour#{if hours != 1, do: "s"} ago"

      diff_seconds < 2_592_000 ->
        days = div(diff_seconds, 86400)
        "#{days} day#{if days != 1, do: "s"} ago"

      diff_seconds < 31_536_000 ->
        months = div(diff_seconds, 2_592_000)
        "#{months} month#{if months != 1, do: "s"} ago"

      true ->
        years = div(diff_seconds, 31_536_000)
        "#{years} year#{if years != 1, do: "s"} ago"
    end
  end

  # Private helper functions

  defp normalize_year_month(year, month) when month > 12 do
    years_to_add = div(month - 1, 12)
    new_month = rem(month - 1, 12) + 1
    {year + years_to_add, new_month}
  end

  defp normalize_year_month(year, month) when month < 1 do
    years_to_subtract = div(-month, 12) + 1
    new_month = month + years_to_subtract * 12
    {year - years_to_subtract, new_month}
  end

  defp normalize_year_month(year, month), do: {year, month}
end
