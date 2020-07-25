defmodule Validator do
  require Logger

  def check(messages) do
    messages
    |> Enum.group_by(& &1.event_schema)
    |> unique_events()
    |> check_statuses()
    |> validate_proposal_loan_value()
    |> validate_installments()
    |> validate_length()
    |> validate_main_proponents()
    |> validate_proponent_age()
    |> validate_warranty()
    |> validate_warranty_value()
    |> validate_warranty_province()
    |> validate_main_proponent_warranty_value()
    |> case do
      %{"proposal" => []} ->
        {:error, "Something went wrong, because there's no proposal to return"}

      %{"proposal" => proposals} ->
        proposals =
          proposals
          |> Enum.map(&Map.get(&1, :proposal_id))
          |> Enum.join(",")

        {:ok, proposals}
    end
  end

  defp unique_events(%{"proposal" => proposals, "proponent" => proponents, "warranty" => warranties}) do
    {:ok, proposals}  =
      proposals
      |> Enum.uniq_by(& &1.event_id)
      |> remove_older_events()

    {:ok, proponents}  =
      proponents
      |> Enum.uniq_by(& &1.event_id)
      |> remove_older_events()

    {:ok, warranties}  =
      warranties
      |> Enum.uniq_by(& &1.event_id)
      |> remove_older_events()

    %{
      "proposal" => proposals,
      "proponent" => proponents,
      "warranty" => warranties
    }
  end

  defp comparte_datetimes(%{event_timestamp: timestamp1}, %{event_timestamp: timestamp2}) do
    case DateTime.compare(timestamp1, timestamp2) do
      x when x in [:gt, :eq] -> true
      _ -> false
    end
  end

  defp remove_older_events([%{event_schema: "proposal"} | _tail] = events) do
    events
    |> Enum.sort(&comparte_datetimes/2)
    |> Enum.reduce_while({:ok, events}, fn event, {:ok, new_events} ->
      new_events
      |> Enum.find(& &1.event_id === event.event_id)
      |> case do
        nil ->
          {:cont, {:ok, new_events}}

        event ->
          new_events
          |> Enum.filter(& &1.event_id != event.event_id)
          |> Enum.filter(& &1.proposal_id === event.proposal_id)
          |> case do
            [] ->
              {:cont, {:ok, new_events}}

            items ->
              items
              |> Enum.filter(fn %{event_timestamp: timestamp1} ->
                case DateTime.compare(timestamp1, event.event_timestamp) do
                  :gt -> true
                  _ -> false
                end
              end)
              |> case do
                [] ->
                  {:cont, {:ok, new_events}}

                [event] ->
                  new_events =
                    new_events
                    |> Enum.filter(& &1.proposal_id != event.proposal_id)
                    |> Kernel.++([event])

                  {:cont, {:ok, new_events}}
              end
          end
      end
    end)
  end
  defp remove_older_events([%{event_schema: "warranty"} | _tail] = events) do
    events
    |> Enum.sort(&comparte_datetimes/2)
    |> Enum.reduce_while({:ok, events}, fn event, {:ok, new_events} ->
      new_events
      |> Enum.find(& &1.event_id === event.event_id)
      |> case do
        nil ->
          {:cont, {:ok, new_events}}

        event ->
          new_events
          |> Enum.filter(& &1.event_id != event.event_id)
          |> Enum.filter(& &1.warranty_id === event.warranty_id)
          |> case do
            [] ->
              {:cont, {:ok, new_events}}

            items ->
              items
              |> Enum.filter(fn %{event_timestamp: timestamp1} ->
                case DateTime.compare(timestamp1, event.event_timestamp) do
                  :gt -> true
                  _ -> false
                end
              end)
              |> case do
                [] ->
                  {:cont, {:ok, new_events}}

                [event] ->
                  new_events =
                    new_events
                    |> Enum.filter(& &1.warranty_id != event.warranty_id)
                    |> Kernel.++([event])

                  {:cont, {:ok, new_events}}
              end
          end
      end
    end)
  end
  defp remove_older_events([%{event_schema: "proponent"} | _tail] = events) do
    events
    |> Enum.sort(&comparte_datetimes/2)
    |> Enum.reduce_while({:ok, events}, fn event, {:ok, new_events} ->
      new_events
      |> Enum.find(& &1.event_id === event.event_id)
      |> case do
        nil ->
          {:cont, {:ok, new_events}}

        event ->
          new_events
          |> Enum.filter(& &1.event_id != event.event_id)
          |> Enum.filter(& &1.proponent_id === event.proponent_id)
          |> case do
            [] ->
              {:cont, {:ok, new_events}}

            items ->
              items
              |> Enum.filter(fn %{event_timestamp: timestamp1} ->
                case DateTime.compare(timestamp1, event.event_timestamp) do
                  :gt -> true
                  _ -> false
                end
              end)
              |> case do
                [] ->
                  {:cont, {:ok, new_events}}

                [event] ->
                  new_events =
                    new_events
                    |> Enum.filter(& &1.proponent_id != event.proponent_id)
                    |> Kernel.++([event])

                  {:cont, {:ok, new_events}}
              end
          end
      end
    end)
  end

  defp check_statuses(%{"proposal" => proposals, "proponent" => proponents, "warranty" => warranties}) do
    {:ok, warranties} = check_warranties(warranties)
    {:ok, proponents} = check_proponents(proponents)

    {:ok, proposals, warranties, proponents} =
      proposals
      |> Enum.reduce_while({:ok, proposals, warranties, proponents}, fn
        %ProposalCreated{}, {:ok, new_proposals, new_warranties, new_proponents} ->
          {:cont, {:ok, new_proposals, new_warranties, new_proponents}}

        %ProposalUpdated{proposal_id: proposal_id}, {:ok, new_proposals, new_warranties, new_proponents} ->
          new_proposals
          |> Enum.find(& &1.proposal_id === proposal_id)
          |> case do
            nil ->
              new_proposals =
                new_proposals
                |> Enum.filter(& &1.proposal_id != proposal_id)

              new_proponents =
                new_proponents
                |> Enum.filter(& &1.proposal_id != proposal_id)

              new_warranties =
                new_warranties
                |> Enum.filter(& &1.proposal_id != proposal_id)

              {:cont, {:ok, new_proposals, new_warranties, new_proponents}}

            _warranty ->
              new_warranties =
                new_warranties
                |> Enum.filter(& &1.proposal_id === proposal_id and &1.event_action != "created")

              {:cont, {:ok, new_proposals, new_warranties, new_proponents}}
          end

        %ProposalDeleted{proposal_id: proposal_id}, {:ok, new_proposals, new_warranties, new_proponents} ->
          new_proposals =
            new_proposals
            |> Enum.filter(& &1.proposal_id != proposal_id)

          new_proponents =
            new_proponents
            |> Enum.filter(& &1.proposal_id != proposal_id)

          new_warranties =
            new_warranties
            |> Enum.filter(& &1.proposal_id != proposal_id)

          {:cont, {:ok, new_proposals, new_warranties, new_proponents}}
      end)

    %{
      "proposal" => proposals,
      "proponent" => proponents,
      "warranty" => warranties
    }
  end

  defp check_warranties(warranties) do
    warranties
    |> Enum.reduce_while({:ok, warranties}, fn
      %WarrantyAdded{}, {:ok, new_warranties} ->
        {:cont, {:ok, new_warranties}}

      %WarrantyUpdated{warranty_id: warranty_id} = warranty, {:ok, new_warranties} ->
        new_warranties
        |> Enum.find(& &1.warranty_id === warranty_id)
        |> case do
          nil ->
            new_warranties =
              new_warranties
              |> Enum.filter(& &1.warranty_id != warranty_id)

            {:cont, {:ok, new_warranties}}

          _warranty ->
            new_warranties =
              new_warranties
              |> Enum.filter(& &1.warranty_id != warranty_id)
              |> Kernel.++([warranty])

            {:cont, {:ok, new_warranties}}
        end

      %WarrantyRemoved{warranty_id: warranty_id}, {:ok, new_warranties} ->
        new_warranties =
          new_warranties
          |> Enum.filter(& &1.warranty_id != warranty_id)

        {:cont, {:ok, new_warranties}}
    end)
  end

  defp check_proponents(proponents) do
    proponents
    |> Enum.reduce_while({:ok, proponents}, fn
      %ProponentAdded{}, {:ok, new_proponents} ->
        {:cont, {:ok, new_proponents}}

      %ProponentUpdated{proponent_id: proponent_id} = proponent, {:ok, new_proponents} ->
        new_proponents
        |> Enum.find(& &1.proponent_id === proponent_id)
        |> case do
          nil ->
            new_proponents =
              new_proponents
              |> Enum.filter(& &1.proponent_id != proponent_id)

            {:cont, {:ok, new_proponents}}

          _proponent ->
            new_proponents =
              new_proponents
              |> Enum.filter(& &1.proponent_id != proponent_id)
              |> Kernel.++([proponent])

            {:cont, {:ok, new_proponents}}
        end

      %ProponentRemoved{proponent_id: proponent_id}, {:ok, new_proponents} ->
        new_proponents =
          new_proponents
          |> Enum.filter(& &1.proponent_id != proponent_id)

        {:cont, {:ok, new_proponents}}
    end)
  end

  defp validate_proposal_loan_value(%{"proposal" => proposals} = params) do
    {:ok, new_proposals} =
      proposals
      |> Enum.reduce_while({:ok, []}, fn proposal, {:ok, proposals} ->
        cond do
          proposal.proposal_loan_value >= 30_000.00 and proposal.proposal_loan_value <= 3_000_000.00 ->
            {:cont, {:ok, proposals ++ [proposal]}}

          true ->
            Logger.error("[#{__MODULE__}] Proposal loan value is #{inspect proposal.proposal_loan_value}")
            {:cont, {:ok, proposals}}
        end
      end)

    params
    |> Map.put("proposal", new_proposals)
  end

  defp validate_installments(%{"proposal" => proposals} = params) do
    {:ok, new_proposals} =
      proposals
      |> Enum.reduce_while({:ok, []}, fn proposal, {:ok, proposals} ->
        cond do
          proposal.proposal_number_of_monthly_installments in 24..180 ->
            {:cont, {:ok, proposals ++ [proposal]}}

          true ->
            Logger.error("[#{__MODULE__}] Proposal number of installments is #{inspect proposal.proposal_number_of_monthly_installments}")
            {:cont, {:ok, proposals}}
        end
      end)

    params
    |> Map.put("proposal", new_proposals)
  end

  defp validate_length(%{"proposal" => proposals, "proponent" => proponents} = params) do
    {:ok, new_proposals, new_proponents} =
      proposals
      |> Enum.reduce_while({:ok, [], []}, fn proposal, {:ok, proposals, new_proponents} ->
        proposal_proponents =
          proponents
          |> Enum.filter(& &1.proposal_id === proposal.proposal_id)

        if length(proposal_proponents) >= 2 do
          proposals = proposals ++ [proposal]
          new_proponents = new_proponents ++ proposal_proponents

          {:cont, {:ok, proposals, new_proponents}}
        else
          Logger.error("[#{__MODULE__}] Proposal length of proponents is #{inspect length(proposal_proponents)}")
          {:cont, {:ok, proposals, new_proponents}}
        end
      end)

    params
    |> Map.put("proposal", new_proposals)
    |> Map.put("proponent", new_proponents)
  end

  defp validate_main_proponents(%{"proposal" => proposals, "proponent" => proponents} = params) do
    {:ok, new_proposals, new_proponents} =
      proposals
      |> Enum.reduce_while({:ok, [], []}, fn proposal, {:ok, proposals, new_proponents} ->
        proposal_proponents =
          proponents
          |> Enum.filter(& &1.proposal_id === proposal.proposal_id)

        main_proponents =
          proposal_proponents
          |> Enum.filter(& &1.proponent_is_main)

        if length(main_proponents) === 1 do
          proposals = proposals ++ [proposal]
          new_proponents = new_proponents ++ proposal_proponents

          {:cont, {:ok, proposals, new_proponents}}
        else
          Logger.error("[#{__MODULE__}] Proposal length of main proponents is #{inspect length(main_proponents)}")
          {:cont, {:ok, proposals, new_proponents}}
        end
      end)

    params
    |> Map.put("proposal", new_proposals)
    |> Map.put("proponent", new_proponents)
  end

  defp validate_proponent_age(%{"proposal" => proposals, "proponent" => proponents} = params) do
    {:ok, new_proposals, new_proponents} =
      proposals
      |> Enum.reduce_while({:ok, [], []}, fn proposal, {:ok, proposals, new_proponents} ->
        proposal_proponents =
          proponents
          |> Enum.filter(& &1.proposal_id === proposal.proposal_id)

        age_proponents =
          proposal_proponents
          |> Enum.filter(& &1.proponent_age >= 18)

        if length(age_proponents) >= 2 do
          proposals = proposals ++ [proposal]
          new_proponents = new_proponents ++ age_proponents

          {:cont, {:ok, proposals, new_proponents}}
        else
          Logger.error("[#{__MODULE__}] Proposal length of above age proponents is #{inspect length(age_proponents)}")
          {:cont, {:ok, proposals, new_proponents}}
        end
      end)

    params
    |> Map.put("proposal", new_proposals)
    |> Map.put("proponent", new_proponents)
  end

  defp validate_warranty(%{"proposal" => proposals, "warranty" => warranties} = params) do
    {:ok, new_proposals, new_warranties} =
      proposals
      |> Enum.reduce_while({:ok, [], []}, fn proposal, {:ok, proposals, new_warranties} ->
        proposal_warranties =
          warranties
          |> Enum.filter(& &1.proposal_id === proposal.proposal_id)

        if length(proposal_warranties) > 0 do
          proposals = proposals ++ [proposal]
          new_warranties = new_warranties ++ proposal_warranties

          {:cont, {:ok, proposals, new_warranties}}
        else
          Logger.error("[#{__MODULE__}] Proposal length of warranties is #{inspect length(proposal_warranties)}")
          {:cont, {:ok, proposals, new_warranties}}
        end
      end)

    params
    |> Map.put("proposal", new_proposals)
    |> Map.put("warranty", new_warranties)
  end

  defp validate_warranty_value(%{"proposal" => proposals, "warranty" => warranties} = params) do
    {:ok, new_proposals, new_warranties} =
      proposals
      |> Enum.reduce_while({:ok, [], []}, fn proposal, {:ok, proposals, new_warranties} ->
        proposal_warranties =
          warranties
          |> Enum.filter(& &1.proposal_id === proposal.proposal_id)

        warranty_value =
          proposal_warranties
          |> Enum.reduce(0, & &2 + &1.warranty_value)

        desired_warranty_value =
          proposal
          |> Map.get(:proposal_loan_value)
          |> Kernel.*(2)

        if warranty_value >= desired_warranty_value do
          proposals = proposals ++ [proposal]
          new_warranties = new_warranties ++ proposal_warranties

          {:cont, {:ok, proposals, new_warranties}}
        else
          Logger.error("[#{__MODULE__}] Proposal warranty value is #{inspect warranty_value}, when expected was #{inspect desired_warranty_value}")
          {:cont, {:ok, proposals, new_warranties}}
        end
      end)

    params
    |> Map.put("proposal", new_proposals)
    |> Map.put("warranty", new_warranties)
  end

  defp validate_warranty_province(%{"proposal" => proposals, "warranty" => warranties} = params) do
    {:ok, new_proposals, new_warranties} =
      proposals
      |> Enum.reduce_while({:ok, [], []}, fn proposal, {:ok, proposals, new_warranties} ->
        proposal_warranties =
          warranties
          |> Enum.filter(& &1.proposal_id === proposal.proposal_id)
          |> Enum.filter(& &1.warranty_province not in ~w(PR SC RS))

        if length(proposal_warranties) >= 2 do
          proposals = proposals ++ [proposal]
          new_warranties = new_warranties ++ proposal_warranties

          {:cont, {:ok, proposals, new_warranties}}
        else
          Logger.error("[#{__MODULE__}] Warranty from PR, SC or RS is not allowed")
          {:cont, {:ok, proposals, new_warranties}}
        end
      end)

    params
    |> Map.put("proposal", new_proposals)
    |> Map.put("warranty", new_warranties)
  end

  defp validate_main_proponent_warranty_value(%{"proposal" => proposals, "proponent" => proponents, "warranty" => warranties}) do
    {:ok, new_proposals, new_warranties, new_proponents} =
      proposals
      |> Enum.reduce_while({:ok, [], [], []}, fn proposal, {:ok, proposals, new_warranties, new_proponents} ->
        proposal_proponents =
          proponents
          |> Enum.filter(& &1.proposal_id === proposal.proposal_id)

        proposal_warranties =
          warranties
          |> Enum.filter(& &1.proposal_id === proposal.proposal_id)

        main_proponent =
          proposal_proponents
          |> Enum.find(& &1.proponent_is_main)

        proposal_loan_installment_value =
          proposal
          |> Map.get(:proposal_loan_value)
          |> Kernel./(proposal.proposal_number_of_monthly_installments)

        cond do
          main_proponent.proponent_age in 18..23 and main_proponent.proponent_monthly_income >= Kernel.*(proposal_loan_installment_value, 4) ->
            proposals = proposals ++ [proposal]
            new_proponents = new_proponents ++ proposal_proponents
            new_warranties = new_warranties ++ proposal_warranties

            {:cont, {:ok, proposals, new_warranties, new_proponents}}

          main_proponent.proponent_age in 24..50 and main_proponent.proponent_monthly_income >= Kernel.*(proposal_loan_installment_value, 3) ->
            proposals = proposals ++ [proposal]
            new_proponents = new_proponents ++ proposal_proponents
            new_warranties = new_warranties ++ proposal_warranties

            {:cont, {:ok, proposals, new_warranties, new_proponents}}

          main_proponent.proponent_age > 50 and main_proponent.proponent_monthly_income >= Kernel.*(proposal_loan_installment_value, 2) ->
            proposals = proposals ++ [proposal]
            new_proponents = new_proponents ++ proposal_proponents
            new_warranties = new_warranties ++ proposal_warranties

            {:cont, {:ok, proposals, new_warranties, new_proponents}}

          true ->
            Logger.error("[#{__MODULE__}] Main Proponent monthly income isn't allowed for this type of warranty")
            {:cont, {:ok, proposals, new_warranties, new_proponents}}
        end
      end)

    %{
      "proposal" => new_proposals,
      "proponent" => new_proponents,
      "warranty" => new_warranties,
    }
  end
end
