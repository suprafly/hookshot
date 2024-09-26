defmodule Hookshot.Crypto do
  @cipher :aes_256_gcm
  @aad "AES256GCM"

  def encrypt(plaintext, key \\ nil) do
    random_iv = get_random_iv()
    in_text = to_string(plaintext)
    key = key || get_key()
    encrypt_flag = true

    try do
      {cipher_text, tag} =
        :crypto.crypto_one_time_aead(@cipher, key, random_iv, in_text, @aad, encrypt_flag)

      {:ok, random_iv <> tag <> cipher_text}

    rescue
      _ -> {:error, :encryption_error}
    end
  end

  def decrypt(binary_cipher_text, key \\ nil) do
    try do
      <<iv::binary-16, tag::binary-16, cipher_text::binary>> = binary_cipher_text
      key = key || get_key()
      encrypt_flag = false
      {:ok, :crypto.crypto_one_time_aead(@cipher, key, iv, cipher_text, @aad, tag, encrypt_flag)}
    rescue
      _ -> {:error, :decryption_error}
    end
  end

  defp get_random_iv do
    :crypto.strong_rand_bytes(16)
  end

  defp get_key() do
    "HOOKSHOT_ENCRYPTION_KEY"
    |> System.get_env()
    |> String.replace_leading("'", "")
    |> String.replace_trailing("'", "")
    |> Base.decode64!()
  end
end
