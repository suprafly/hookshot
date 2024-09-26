defmodule Hookshot.EventProcessor do
  @moduledoc """
  The Broadway pipeline.

  Following the example,
  https://blog.appsignal.com/2019/12/12/how-to-use-broadway-in-your-elixir-application.html
  """
  use Broadway

  alias Broadway.Message
  alias Hookshot.Subscriptions
  alias Hookshot.Webhooks

  def start_link({producer_opts, processor_opts}) do
    producer_opts = [
      module: {Hookshot.EventProducer, []},
      transformer: {__MODULE__, :transform, []},
    ] |> Keyword.merge(producer_opts)

    processor_opts = [default: processor_opts]

    Broadway.start_link(__MODULE__,
      name: __MODULE__,
      producer: producer_opts,
      processors: processor_opts
    )
  end

  @impl true
  def handle_message(:default, message, _context) do
    message
    |> Message.update_data(fn event ->
      # Update the target right before the event goes out.
      # This is necessary because a user may have changed their webhook url.
      subscription = Subscriptions.get_subscription!(event.subscription_id)
      %{event | target: subscription.target} |> Webhooks.dispatch_event()
    end)
  end

  def transform(event, _opts) do
    %Message{
      data: event,
      acknowledger: {__MODULE__, :ack_id, :ack_data}
    }
  end

  def ack(:ack_id, _successful, _failed) do
    :ok
  end
end
