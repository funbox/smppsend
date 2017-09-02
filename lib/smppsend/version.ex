defmodule SMPPSend.Version do
  def version do
    Application.spec(:smppsend)
    |> Keyword.get(:vsn)
    |> to_string
  end
end
