defmodule Hookshot.Ecto.Encrypted do
  @moduledoc """
  Ecto Type for encrypted fields.

  ## Example

        schema "events" do
          field :data, Hookshot.Ecto.Encrypted
        end
  """

  use Ecto.Type

  alias Hookshot.Crypto

  def type do
    :binary
  end

  def cast(value) do
    {:ok, to_string(value)}
  end

  def dump(value) do
    value
    |> to_string()
    |> Crypto.encrypt()
  end

  def load(value) do
    Crypto.decrypt(value)
  end

  def embed_as(_) do
    :self
  end

  def equal?(term1, term2) do
    term1 == term2
  end
end
