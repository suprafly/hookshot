defmodule Mix.Tasks.Hookshot.Seed.EventTypes do
  @moduledoc """
  This task seeds event types.

  ## Usage

      mix hookshot.seed.event_types

  """
  @shortdoc "Creates migrations to add the required tables to the db."

  use Mix.Task

  def run(_args) do
    Mix.Task.run("app.start")
    %{event_types: event_types, errors: _errors} = generate_seeds()
    IO.puts "Created events: #{inspect(Enum.reverse(event_types))}"
  end

  def generate_seeds do
    :hookshot
    |> Application.get_env(:event_types)
    |> Enum.reduce(%{event_types: [], errors: []},
      fn {resource, actions}, acc ->
        Enum.reduce(actions, acc,
          fn action, %{event_types: event_types, errors: errors} ->
            case Hookshot.EventTypes.create_event_type(resource, action) do
              {:ok, event_type} ->
                %{event_types: [event_type.name | event_types], errors: errors}
              {:error, error} ->
                %{event_types: event_types, errors: [error | errors]}
            end
          end)
      end)
  end
end
