defmodule SpawnList do
  def start_link(list) do
    {:ok, pid} = Agent.start_link(fn -> list end)
    pid
  end

  def shift(pid) do
    Agent.get_and_update(
      pid,
      fn
        [] ->
          {nil, []}

        [el | other] ->
          {el, other}
      end
    )
  end
end
