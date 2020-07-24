defmodule ProposalDeleted do
  @fields ~w(
    event_id
    event_schema
    event_action
    event_timestamp
    proposal_id
  )a

  defstruct @fields

  def get_header(), do: @fields
end
