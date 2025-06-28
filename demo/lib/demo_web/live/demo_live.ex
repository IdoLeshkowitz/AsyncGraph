defmodule DemoWeb.DemoLive do
  use Phoenix.LiveView

  def mount(_params, _session, socket) do
    steps = [
      AsyncGraph.build_step(:assign_a, fn _-> {:ok, "a"} end),
      AsyncGraph.build_step(:assign_b, fn _-> {:ok, "b"} end),
      AsyncGraph.build_step(:assign_c, fn result_b -> {:ok,  result_b <> "c"} end, [:assign_a]),
      AsyncGraph.build_step(:assign_d, fn _-> {:ok, "d"} end, [:assign_b]),
      AsyncGraph.build_step(:assign_e, fn _ -> {:ok, "e"} end, [:assign_c, :assign_d])
    ]

    if connected?(socket) do
      {:ok, pid} =  AsyncGraph.init(steps, :graph_a, self())
      # dbg("gen server pid - #{inspect(pid)}")
    end


    {:ok, socket}
  end

  def handle_info({:async_graph, graph_name, step, {:ok, res}}, socket) do
    dbg("Graph #{graph_name} completed step #{step}, with the result - #{res}")
    AsyncGraph.fire_next_step(graph_name, res)
    {:noreply, socket}
  end

  def handle_info({:async_graph, graph_name, step, {:error, reason}}, socket) do
    dbg("Graph #{graph_name} failed in step #{step}, with reason - #{reason}")
    {:noreply, socket}
  end

  def handle_info({:async_graph, graph_name, :complete}, socket) do
    dbg("Graph #{graph_name} completed")
    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    """
  end
end
