defmodule DemoWeb.DemoLive do
  use Phoenix.LiveView
  use AsyncGraph.LiveView

  def mount(_params, _session, socket) do
    steps = [
      AsyncGraph.build_step(:assign_a, fn _ ->
        Process.sleep(2000)
        {:ok, "a"}
      end),
      AsyncGraph.build_step(
        :assign_b,
        fn _ ->
          Process.sleep(2000)
          {:ok, "b"}
        end,
        [:assign_a]
      ),
      AsyncGraph.build_step(
        :assign_c,
        fn socket ->
          Process.sleep(2000)
          {:ok, socket.assigns.graph_a.assign_a.result <> "c"}
        end,
        [:assign_b]
      )
    ]

    socket = AsyncGraph.LiveView.init(socket, steps, :graph_a)
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="text-white">
      <.async_result :let={assign_a} assign={@graph_a.assign_a}>
        <:loading>
          A loading
        </:loading>
        {assign_a}
        <.async_result :let={assign_b} assign={@graph_a.assign_b}>
          <:loading>
            B loading
          </:loading>
          {assign_b}
          <.async_result :let={assign_c} assign={@graph_a.assign_c}>
            <:loading>
              C loading
            </:loading>
            {assign_c}
          </.async_result>
        </.async_result>
      </.async_result>
    </div>
    """
  end
end
