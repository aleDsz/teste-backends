defmodule WarrantyUpdated do
  @fields ~w(
    event_id
    event_schema
    event_action
    event_timestamp
    proposal_id
    warranty_id
    warranty_value
    warranty_province
  )a

  defstruct @fields

  def get_header(), do: @fields
end
