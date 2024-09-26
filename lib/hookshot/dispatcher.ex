defmodule Hookshot.Dispatcher do
  @moduledoc """
  Dispatch webhooks.
  """
  # @retry_statuses [429] ++ Enum.to_list(500..511)

  def send_webhook(req) do
    req
    |> Req.Request.run_request()
    |> handle_response()
  end

  defp handle_response({request, %Req.Response{} = response}) do
    received_at = NaiveDateTime.utc_now()

    {request, response}
    |> add_received_at(received_at)
    # |> handle_timeout()
    |> verify_response_status()
    |> add_response_metadata(received_at)
  end

  defp add_received_at({request, response}, received_at) do
    response = Req.Response.put_private(response, :hookshot, %{received_at: received_at})
    {request, response}
  end

  defp verify_response_status({request, %Req.Response{status: status} = response}) do
    case Integer.digits(status) do
      [1, _, _] -> {request, process_informational(response)}
      [2, _, _] -> {request, process_successful(response)}
      [3, _, _] -> {request, process_redirection(response)}
      [4, _, _] -> {request, process_client_error(response)}
      [5, _, _] -> {request, process_server_error(response)}
    end
  end

  defp add_response_metadata({request, response}, received_at) do
    %{sent_at: sent_at} = Req.Request.get_private(request, :hookshot)
    # We need to ensure that we receive an expected
    # response and that we received it within the expected time frame

    # Let's say (https://docs.svix.com/receiving/introduction) -
    # - status code 200-299
    # - within 15s

    # todo - we should also properly handle any error status codes

    response_metadata = get_response_metadata(sent_at, received_at)
    response = Req.Response.put_private(response, :response_metadata, response_metadata)

    {request, response}
  end

  defp get_response_metadata(sent_at, received_at, expect_response_ms \\ 15_000) do
    # default is within 15 secs
    response_time = NaiveDateTime.diff(sent_at, received_at, :millisecond)

    %{
      expected_time_frame: expect_response_ms,
      within_time_frame: response_time <= expect_response_ms,
      response_time: response_time,
    }
  end

  defp process_informational(response) do
    # 100s
    # ----

    # This should be flagged as an invalid but successful response.

    merge_private(response, :hookshot, %{status: :error, flagged: :invalid})
  end

  defp process_successful(response) do
    # 200s
    # ----

    # This should be marked as a valid and successful response.

    merge_private(response, :hookshot, %{status: :ok, flagged: nil})
  end

  defp process_redirection(response)  do
    # 300s
    # ----

    # This should be flagged as an invalid response and that the target url is not valid.

    merge_private(response, :hookshot, %{status: :error, flagged: :forbidden})
  end

  defp process_client_error(response) do
    # 400s
    # ----

    # This should be flagged as an invalid response and we may need to disable the service.

    maybe_schedule_retry(response)
  end

  defp process_server_error(response)   do
    # 500s
    # ----

    # This should be flagged as an invalid response and we nned to disable the service.

    # Their server is not handling the requests correctly, so we want to back off.

    maybe_schedule_retry(response)
  end

  defp merge_private(%Req.Response{} = response, key, value_map) do
    hookshot_priv = Req.Response.get_private(response, key)
    Req.Response.put_private(response, key, Map.merge(hookshot_priv, value_map))
  end

  defp maybe_schedule_retry(%Req.Response{status: status} = response) do
    values =
      case Integer.digits(status) do
        # [4, 2, 9] -> %{status: :retry, flagged: nil}
        [4, _, _] -> %{status: :retry, flagged: nil}
        [5, _, _] -> %{status: :retry, flagged: nil}
        _ -> %{status: :error, flagged: :invalid}
      end

    merge_private(response, :hookshot, values)
  end
end
