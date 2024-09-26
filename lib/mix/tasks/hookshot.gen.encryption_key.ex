defmodule Mix.Tasks.Hookshot.Gen.EncryptionKey do
  @moduledoc """
  This task generates an encryption key.

  ## Usage

      mix hookshot.gen.encryption_key

  """
  @shortdoc "Generate an encryption key."

  use Mix.Task

  def run(_args) do
    :crypto.strong_rand_bytes(32)
    |> Base.encode64()
    |> IO.puts()
  end
end
