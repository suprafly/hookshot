defmodule Hookshot.Webhooks do
  @moduledoc """
  This is the main interface for all internal library functionality.

  This should not be used as by library users.
  """
  require Logger

  alias Hookshot.Attempts
  alias Hookshot.Attempts.Attempt
  alias Hookshot.Dispatcher
  alias Hookshot.Events
  alias Hookshot.Events.Event
  alias Hookshot.Subscriptions

  def dispatch_event(%Event{status: :pending} = event) do
    event
    |> create_request()
    |> maybe_put_signed_header(event)
    |> Dispatcher.send_webhook()
    |> handle_response()
  end

  def dispatch_event(event) do
    Logger.info "Webhhook dispatch error for event #{event.id}: Cannot dispatch an event with status #{event.status}"

    {:error, event}
  end

  defp create_request(event) do
    data = Hookshot.webhook_payload().new(event)
    priv_attrs = %{event: event, sent_at: NaiveDateTime.utc_now()}

    Req.new(
      method: :post,
      url: event.target,
      body: Jason.encode!(data),
      headers: [
        {"content-type", "application/json"}
      ]
    )
    |> Req.Request.put_private(:hookshot, priv_attrs)
  end

  defp maybe_put_signed_header(req, %Event{signature_data: nil} = _event) do
    req
  end

  defp maybe_put_signed_header(req, %Event{} = event) do
    header = Map.get(event, :signature_header, Event.default_signature_header())
    Req.Request.put_header(req, header, event.signature_data)
  end

  defp handle_response({request, %Req.Response{} = response}) do
    {request, response}
    |> log_response()
    |> create_attempt()
    |> maybe_retry()
    |> maybe_update_event()
    |> maybe_disable_subscription()
  end

  defp handle_response({_request, exception}) do
    raise exception
  end

  defp log_response({request, response}) do
    %{event: event} = Req.Request.get_private(request, :hookshot)

    Logger.info "Webhhook response for event #{event.id}: #{response.status}"

    {request, response}
  end

  defp create_attempt({request, response}) do
    %{event: event, sent_at: sent_at} = Req.Request.get_private(request, :hookshot)
    %{received_at: received_at, status: status} = Req.Response.get_private(response, :hookshot)
    %{within_time_frame: within_time_frame} = Req.Response.get_private(response, :response_metadata)

    case Attempts.create_attempt(event, status, response.status, sent_at, received_at, within_time_frame) do
      {:ok, attempt} ->
        # Add the attempt to the response so we can access it later
        {request, Req.Response.put_private(response, :hookshot_attempt, {:ok, attempt})}

      {:error, error} ->

        Logger.error "Failed to create an Attempt for webhhook event #{event.id}."

        {request, Req.Response.put_private(response, :hookshot_attempt, {:error, error})}
    end
  end

  defp maybe_retry({request, response}) do
    with %{event: event} <- Req.Request.get_private(request, :hookshot),
         %{status: :retry} <- Req.Response.get_private(response, :hookshot) do
      schedule_retry(event)
    end

    {request, response}
  end

  defp maybe_update_event({request, %Req.Response{status: 200} = response}) do
    %{event: event} = Req.Request.get_private(request, :hookshot)

    Events.update_event(event, %{status: :completed})

    {request, response}
  end

  defp maybe_update_event({request, %Req.Response{} = response}) do
    %{event: event} = Req.Request.get_private(request, :hookshot)

    # If the status failed and we are past the number of retries, then
    # the event is unsendable, so we mark it as :failed and abandon it.
    if event.retries >= max_attempts() do
      Events.update_event(event, %{status: :failed})

      Logger.error "Webhhook event #{event.id} failed and abandoned."
    end

    {request, response}
  end

  defp maybe_disable_subscription({request, %Req.Response{} = response}, num_days \\ 3) do
    # Check if this has failed, if it has then, check if all attempts
    # have failed for a period of 3 days. If so, the subscription should be disabled.
    with {:ok, %Attempt{status: :failed}} <- Req.Response.get_private(response, :hookshot_attempt),
         true <- Attempts.all_attempts_in_last_n_days?(num_days, :failed),
         %{event: event} <- Req.Request.get_private(request, :hookshot) do
      # If too many requests have been out of the time frame,
      # we should disable the subscription and provide a :flagged_reason.
      as_of_date = NaiveDateTime.local_now() |> NaiveDateTime.to_string()
      reason = "All attempts have failed since for a period of #{num_days} days as of #{as_of_date}"
      _ = Subscriptions.disable_subscription(event.subscription_id, reason)
      {request, response}
    end
  end

  defp schedule_retry(%Event{retries: retries} = event) do
    if retries < max_attempts() do
      with {:ok, retry_ms} <- Hookshot.Retry.next_retry_ms(event, max_attempts()),
           send_after = NaiveDateTime.local_now() |> NaiveDateTime.add(retry_ms, :millisecond),
           attrs = %{retries: event.retries + 1, send_after: send_after},
           {:ok, event} <- Events.update_event(event, attrs) do

        Hookshot.Queue.push(event)
        {:ok, event}
      else
        {:error, changeset} ->
          Logger.error "Webhhook schedule retry failed: #{inspect(changeset)}"
      end
    end
  end

  defp max_attempts, do: 5
end
