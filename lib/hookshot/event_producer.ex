defmodule Hookshot.EventProducer do
  @moduledoc """
  Receives webhook triggers, creates events and produces
  an event stream that is consumed by `Hookshot.Processor`.
  """
  use GenStage

  require Logger

  alias Hookshot.Events
  alias Hookshot.Events.Event

  @resolve_pending_timeout 100
  @orphaned_events_timeout 5_000

  @bucket_rollover_ms 60_000
  @max_requests 10 # 100

  def start_link(_args) do
    GenStage.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_args) do
    Process.send_after(self(), :resolve_pending, @resolve_pending_timeout)
    # Process.send_after(self(), :pickup_orphaned_events, @orphaned_events_timeout)

    state = %{
      demand: 0,
      events: Events.list_pending_events(),
      rate_limiting:
        %{
          bucket_rollover_ms: @bucket_rollover_ms,
          max_requests: @max_requests
        }
    }

    {:producer, state}
  end

  @impl true
  def handle_demand(demand, state) do
    {to_dispatch, state} = resolve_demand(demand, state)

    {:noreply, to_dispatch, state}
  end

  @impl true
  def handle_info(:resolve_pending, state) do
    {to_dispatch, state} = resolve_demand(state)

    Process.send_after(self(), :resolve_pending, @resolve_pending_timeout)

    {:noreply, to_dispatch, state}
  end

  def handle_info(:pickup_orphaned_events, state) do
    events = Enum.dedup_by(state.events ++ Events.list_pending_events(), & &1.id)

    Process.send_after(self(), :pickup_orphaned_events, @orphaned_events_timeout)

    {:noreply, [], %{state | events: events}}
  end

  # defp resolve_demand(new_demand \\ 0, %{demand: pending_demand, events: events} = state) do
  #   demand = new_demand + pending_demand

  #   # metadata = %{name: __MODULE__, demand: demand}
  #   # items =
  #   #   :telemetry.span([:off_broadway_memory, :receive_messages], metadata, fn ->
  #   #     messages = Buffer.pop(state.buffer, demand) |> transform_messages(state.ack_ref)
  #   #     {messages, Map.put(metadata, :messages, messages)}
  #   #   end)

  #   num_events = length(events)
  #   events =
  #     if demand > num_events do
  #       queued_events = Hookshot.Queue.pop(demand - num_events)
  #       # events = Enum.dedup_by(events ++ queued_events, & &1.id)
  #       events ++ queued_events
  #     else
  #       events
  #     end

  #   {to_dispatch, remaining} = Enum.split(events, demand)
  #   new_demand = demand - length(to_dispatch)
  #   state = %{state | demand: new_demand, events: remaining}

  #   {to_dispatch, state}
  # end


  # The rate limited version
  defp resolve_demand(new_demand \\ 0, %{demand: pending_demand, events: events} = state) do
    demand = new_demand + pending_demand

    # metadata = %{name: __MODULE__, demand: demand}
    # items =
    #   :telemetry.span([:off_broadway_memory, :receive_messages], metadata, fn ->
    #     messages = Buffer.pop(state.buffer, demand) |> transform_messages(state.ack_ref)
    #     {messages, Map.put(metadata, :messages, messages)}
    #   end)

    %{rate_limiting: %{bucket_rollover_ms: bucket_rollover_ms, max_requests: max_requests}} = state
    {to_dispatch, remaining} = get_rate_limited_events(demand, events, bucket_rollover_ms, max_requests)

    num_events = length(to_dispatch)
    leftover_demand = demand - num_events

    queued_events = get_from_queue(leftover_demand, bucket_rollover_ms, max_requests)

    new_demand = leftover_demand - length(queued_events)

    state = %{state | demand: new_demand, events: remaining}

    {to_dispatch ++ queued_events, state}
  end

  defp get_rate_limited_events(demand, events, bucket_rollover_ms, max_requests) do
    {ready, not_ready} = Enum.split_with(events, fn event -> event_ready?(event, bucket_rollover_ms, max_requests) end)
    {to_dispatch, remaining} = Enum.split(ready, demand)
    {to_dispatch, remaining ++ not_ready}
  end

  def get_from_queue(demand, bucket_rollover_ms, max_requests) do
    queue_len = Hookshot.Queue.length()
    Enum.reduce(0..demand-1, [], fn i, acc ->
      if i > queue_len do
        acc
      else
        look_for_event_in_queue(acc, i, queue_len, bucket_rollover_ms, max_requests)
      end
    end)
  end

  defp look_for_event_in_queue(acc, i, queue_len, bucket_rollover_ms, max_requests) do
    if i >= queue_len do
      acc
    else
      with [event] <- Hookshot.Queue.pop(1),
           {true, _} <- {event_ready?(event, bucket_rollover_ms, max_requests), event} do
        [event | acc]
      else
        {false, event} ->
          Hookshot.Queue.push(event)
          look_for_event_in_queue(acc, i + 1, queue_len, bucket_rollover_ms, max_requests)

        _ ->

          look_for_event_in_queue(acc, i + 1, queue_len, bucket_rollover_ms, max_requests)
      end
    end
  end

  defp event_ready?(%Event{} = event, bucket_rollover_ms, max_requests) do
    event
    |> send_after?()
    |> event_within_rate_limit?(bucket_rollover_ms, max_requests)
  end

  defp send_after?(%Event{send_after: nil} = event) do
    # If `:send_after` is nil, then send it immediately
    {:ok, event}
  end

  defp send_after?(%Event{send_after: send_after} = event) do
    case NaiveDateTime.compare(NaiveDateTime.local_now(), send_after) do
      :lt ->
        {:error, event}

      _ ->
        {:ok, event}
    end

    # {:ok, event}
  end

  defp event_within_rate_limit?({:ok, %Event{target: target} = _event}, bucket_rollover_ms, max_requests) do
    case ExRated.check_rate(target, bucket_rollover_ms, max_requests) do
      {:ok, _} -> true
      {:error, _} -> false
    end
  end

  defp event_within_rate_limit?({_, _event}, _bucket_rollover_ms, _max_requests) do
    false
  end
end
