defmodule AsyncGraph.LiveView do
  alias Phoenix.LiveView.AsyncResult
  @doc false
  defmacro __using__(_opts) do
    quote do
      import AsyncGraph.LiveView

      @before_compile AsyncGraph.LiveView
    end
  end

  def init(%Phoenix.LiveView.Socket{} = socket, steps, graph_name) do
    async_results = Map.new(steps, &{&1.label, AsyncResult.ok(nil)})
    socket = Phoenix.Component.assign(socket, graph_name, async_results)

    if Phoenix.LiveView.connected?(socket) do
      case AsyncGraph.init(steps, graph_name, socket.root_pid) do
        {:ok, _pid} ->
          socket

        {:error, {:already_started, _pid}} ->
          socket

        reason ->
          raise "Failed to start graph server, reason: #{inspect(reason)}"
      end
    end

    socket
  end

  def fire_next_step(socket, graph_name) do
    AsyncGraph.fire_next_step(graph_name, socket)
  end

  @doc false
  defmacro __before_compile__(_env) do
    quote do
      def handle_info(
            {:async_graph, :step_completed, :success, graph_name, step, {:ok, res}},
            socket
          ) do
        AsyncGraph.LiveView.fire_next_step(socket, graph_name)

        async_result =
          socket.assigns
          |> Map.fetch!(graph_name)
          |> Map.fetch!(step)

        socket =
          update(socket, graph_name, fn async_results ->
            Map.put(async_results, step, Phoenix.LiveView.AsyncResult.ok(async_result, res))
          end)

        {:noreply, socket}
      end

      def handle_info(
            {:async_graph, :step_completed, :failure, graph_name, step, {:error, reason}},
            socket
          ) do
        async_result =
          socket.assigns
          |> Map.fetch!(graph_name)
          |> Map.fetch!(step)

        socket =
          update(socket, graph_name, fn async_results ->
            Map.put(
              async_results,
              step,
              Phoenix.LiveView.AsyncResult.failed(async_result, reason)
            )
          end)

        {:noreply, socket}
      end

      def handle_info({:async_graph, :graph_completed, graph_name}, socket) do
        {:noreply, socket}
      end

      def handle_info({:async_graph, :step_started, graph_name, step}, socket) do
        socket =
          update(socket, graph_name, fn async_results ->
            Map.put(async_results, step, Phoenix.LiveView.AsyncResult.loading())
          end)

        {:noreply, socket}
      end
    end
  end
end
