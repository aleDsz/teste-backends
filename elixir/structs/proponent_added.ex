defmodule ProponentAdded do
  @fields ~w(
    event_id
    event_schema
    event_action
    event_timestamp
    proposal_id
    proponent_id
    proponent_name
    proponent_age
    proponent_monthly_income
    proponent_is_main
  )a

  defstruct @fields

  def get_header(), do: @fields
end
