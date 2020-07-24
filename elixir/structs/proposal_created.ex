defmodule ProposalCreated do
  @fields ~w(
    event_id
    event_schema
    event_action
    event_timestamp
    proposal_id
    proposal_loan_value
    proposal_number_of_monthly_installments
  )a

  defstruct @fields

  def get_header(), do: @fields
end
