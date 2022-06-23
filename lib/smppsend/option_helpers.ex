defmodule SMPPSend.OptionHelpers do
  def find_unknown(opts, known_list) do
    opts
    |> Keyword.keys()
    |> Enum.filter(fn key ->
      not Enum.any?(known_list, &(&1 == key))
    end)
  end

  def set_defaults(opts, defaults) do
    defaults
    |> Keyword.keys()
    |> List.foldl(opts, fn key, opts ->
      case Keyword.has_key?(opts, key) do
        true -> opts
        false -> Keyword.put(opts, key, defaults[key])
      end
    end)
  end

  def find_missing(opts, required_list) do
    required_list |> Enum.filter(fn name -> not Keyword.has_key?(opts, name) end)
  end

  def decode_hex_string(opts, key) do
    modify_text_opt(opts, key, &to_bytes/1)
  end

  def convert_to_ucs2(opts, key) do
    modify_text_opt(opts, key, &to_ucs2/1)
  end

  def convert_to_gsm(opts, key) do
    modify_text_opt(opts, key, &to_gsm/1)
  end

  def convert_to_latin1(opts, key) do
    modify_text_opt(opts, key, &to_latin1/1)
  end

  def modify_text_opt(opts, key, modifier) do
    try do
      case List.keyfind(opts, key, 0) do
        {^key, value} ->
          {:ok, List.keyreplace(opts, key, 0, {key, modifier.(value)})}

        nil ->
          {:ok, opts}
      end
    catch
      some, error ->
        {:error, inspect({some, error})}
    end
  end

  defp to_ucs2(str) do
    str
    |> to_char_list
    |> :xmerl_ucs.to_ucs2be()
    |> :erlang.list_to_binary()
  end

  defp to_bytes(hex_string) do
    Base.decode16!(hex_string, case: :mixed)
  end

  defp to_gsm(str) do
    Codepagex.from_string!(str, "ETSI/GSM0338")
  end

  defp to_latin1(str) do
    Codepagex.from_string!(str, :iso_8859_1)
  end
end
