defmodule Hookshot.Queue do
  @moduledoc """
  A queue for events.

  Adapted from: https://github.com/elliotekj/off_broadway_memory/blob/main/lib/off_broadway_memory/queue.ex
  """

  use GenServer

  @initial_state %{events: :queue.new(), length: 0}

  @doc false
  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, nil, [name: __MODULE__])
  end

  @impl true
  def init(_opts) do
    {:ok, @initial_state}
  end

  @doc """
  Push an event to the queue.
  """
  @spec push(list(any()) | any()) :: :ok
  def push(event) do
    GenServer.call(__MODULE__, {:push, event})
  end

  @doc """
  Pop events from the queue.
  """
  @spec pop(non_neg_integer()) :: list(any())
  def pop(count \\ 1) do
    GenServer.call(__MODULE__, {:pop, count})
  end

  @doc """
  List all events in the queue.
  """
  @spec list() :: :ok
  def list() do
    GenServer.call(__MODULE__, :list)
  end

  @doc """
  List all events in the queue, then clear the queue.
  """
  @spec list_and_clear() :: :ok
  def list_and_clear() do
    GenServer.call(__MODULE__, :list_and_clear)
  end

  @doc """
  Clear all events from the queue.
  """
  @spec clear() :: :ok
  def clear() do
    GenServer.call(__MODULE__, :clear)
  end

  @doc """
  Get the length of the queue.
  """
  @spec length() :: non_neg_integer()
  def length() do
    GenServer.call(__MODULE__, :length)
  end

  @impl true
  def handle_call({:push, event}, _from, state) do
    updated_events = :queue.in(event, state.events)
    {:reply, :ok, %{events: updated_events, length: state.length + 1}}
  end

  def handle_call({:pop, _count}, _from, %{length: 0} = state) do
    {:reply, [], state}
  end

  def handle_call({:pop, count}, _from, %{length: length} = state) when count >= length do
    {:reply, :queue.to_list(state.events), @initial_state}
  end

  def handle_call({:pop, count}, _from, state) do
    {events, updated_events} = :queue.split(count, state.events)

    updated_state = %{
      events: updated_events,
      length: state.length - count
    }

    {:reply, :queue.to_list(events), updated_state}
  end

  def handle_call(:clear, _from, _state) do
    {:reply, :ok, @initial_state}
  end

  def handle_call(:list, _from, state) do
    if state.length > 0 do
      {:reply, :queue.to_list(state.events), state}
    else
      {:reply, [], state}
    end
  end

  def handle_call(:list_and_clear, _from, state) do
    if state.length > 0 do
      {:reply, :queue.to_list(state.events), @initial_state}
    else
      {:reply, [], state}
    end
  end

  def handle_call(:length, _from, %{length: length} = state) do
    {:reply, length, state}
  end
end
