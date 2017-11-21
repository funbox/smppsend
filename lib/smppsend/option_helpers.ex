defmodule SMPPSend.OptionHelpers do

  def find_unknown(opts, known_list) do
    opts |> Keyword.keys |> Enum.filter(fn(key) ->
      not Enum.any?(known_list, &(&1 == key))
    end)
  end

  def set_defaults(opts, defaults) do
    defaults |> Keyword.keys |> List.foldl(opts, fn(key, opts) ->
      case Keyword.has_key?(opts, key) do
        true -> opts
        false -> Keyword.put(opts, key, defaults[key])
      end
    end)
  end

  def find_missing(opts, required_list) do
    required_list |> Enum.filter(fn(name) -> not Keyword.has_key?(opts, name) end)
  end

  def convert_to_ucs2(opts, key) do
    try do
      case List.keyfind(opts, key, 0) do
        {^key, value} ->
          {:ok, List.keyreplace(opts, key, 0, {key, to_ucs2(value)})}
        nil -> {:ok, opts}
      end
    catch some, error ->
      {:error, inspect({some, error})}
    end
  end

  def convert_to_gsm(opts, key) do
    try do
      case List.keyfind(opts, key, 0) do
        {^key, value} ->
          {:ok, List.keyreplace(opts, key, 0, {key, to_gsm(value)})}
          nil -> {:ok, opts}
      end
    catch some, error ->
        {:error, inspect({some, error})}
    end
  end

  def convert_to_latin1(opts, key) do
    try do
      case List.keyfind(opts, key, 0) do
        {^key, value} ->
          {:ok, List.keyreplace(opts, key, 0, {key, to_latin1(value)})}
        nil -> {:ok, opts}
      end
    catch some, error ->
        {:error, inspect({some, error})}
    end
  end

  defp to_ucs2(str) do
    str
      |> to_charlist
      |> :xmerl_ucs.to_ucs2be
      |> (fn(x) -> Enum.reduce(x, <<>>, fn(y, acc) -> acc <> <<y>> end) end).()
      |> to_string
  end

  defp to_gsm(str) do
    str
      |> (fn(x) -> Codepagex.from_string!(x, "ETSI/GSM0338") end).()
  end

  defp to_latin1(str) do
    str
      |> (fn(x) -> Codepagex.from_string!(x, :iso_8859_1) end).()
  end
end
