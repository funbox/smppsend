defmodule SMPPSend.Version do
  def version do
    Application.loaded_applications()
    |> List.keyfind(:smppsend, 0)
    |> case do
      {_, _, vsn} -> vsn
      _ -> "unknown"
    end
    |> to_string
  end
end
