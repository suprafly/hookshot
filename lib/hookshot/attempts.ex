defmodule Hookshot.Attempts do
  @moduledoc """
  The Attempts context.
  """
  import Ecto.Query, warn: false

  alias Hookshot.Attempts.Attempt

  def all_attempts_in_last_n_days?(num_days, expected_status) do
    # Check all attempts in the last `num_days` for the `expected_status`
    num_days
    |> list_attempts_in_last_n_days()
    |> Enum.all?(fn attempt -> attempt.status == expected_status end)
  end

  def list_attempts_in_last_n_days(num_days) do
    # Check all attempts in the last `num_days`
    (from attempt in Attempt,
      where: attempt.inserted_at >= ago(^num_days, "day")
    )
    |> Hookshot.repo().all()
  end

  def create_attempt(event, status, status_code, request_sent_at, response_received_at, within_time_frame) do
    attrs = %{
      status: get_status(status),
      response_status_code: status_code,
      within_time_frame: within_time_frame,
      request_sent_at: request_sent_at,
      response_received_at: response_received_at,
    }

    %Attempt{}
    |> Attempt.create_changeset(event, event.subscription, attrs)
    |> Hookshot.repo().insert()
  end

  defp get_status(:error) do
    # The :error status comes from the dispatcher and represents a catchall for failed status codes.
    :failed
  end

  defp get_status(:retry) do
    # This is represents a failed request that was scheduled for retry.
    :failed
  end

  defp get_status(:ok) do
    :succeeded
  end
end
