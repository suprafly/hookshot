defmodule Hookshot.Ecto.EncryptedMap do
  @moduledoc """
  Ecto Type for encrypted map fields.

  ## Example

        schema "events" do
          field :data, Hookshot.Ecto.EncryptedMap
        end
  """
  use Ecto.Type

  alias Hookshot.Crypto

  def type do
    :binary
  end

  def cast(value) do
    Ecto.Type.cast(:map, value)
  end

  def dump(value) do
    value
    |> Hookshot.json().encode!()
    |> Crypto.encrypt()
  end

  def load(value) do
    value
    |> Crypto.decrypt!()
    |> Hookshot.json().decode()
  end

  def embed_as(_) do
    :self
  end

  def equal?(term1, term2) do
    term1 == term2
  end
end
