defmodule AsyncGraph do
  use GenServer

  # Client API

  def init(steps, graph_name, pid) do
    GenServer.start_link(__MODULE__, %{steps: steps, pid: pid, graph_name: graph_name},
      name: graph_name
    )
  end

  def build_step(label, task, dependencies \\ []) do
    %{
      label: label,
      task: task,
      dependencies: dependencies
    }
  end

  def fire_next_step(graph_name, args \\ nil) do
    GenServer.call(graph_name, {:fire_next_step, args})
  end

  # Server

  @opaque step :: %{
            label: atom(),
            task: (-> term()),
            dependencies: list(atom())
          }

  @impl true
  def init(state) do
    g = :digraph.new()

    vertex_to_step =
      state.steps
      |> Enum.reduce(%{}, fn step, acc ->
        Map.put(acc, :digraph.add_vertex(g), step)
      end)

    label_to_vertex = Map.new(vertex_to_step, fn {vertex, step} -> {step.label, vertex} end)

    vertex_to_step
    |> Enum.each(fn
      {vertex, %{dependencies: [_ | _] = dependencies}} ->
        Enum.each(dependencies, fn dependency ->
          # TODO - handle non existing dependencies
          in_neighbor_vertex = Map.fetch!(label_to_vertex, dependency)
          :digraph.add_edge(g, in_neighbor_vertex, vertex)
        end)

      _ ->
        nil
    end)

    state = %{
      topsort: :digraph_utils.topsort(g),
      client_pid: state.pid,
      vertex_to_step: vertex_to_step,
      graph_name: state.graph_name
    }

    {:ok, state, {:continue, {:fire_next_step, nil}}}
  end

  @impl true
  def handle_call({:fire_next_step, args}, _from, state) do
    {:reply, :ok, state, {:continue, {:fire_next_step, args}}}
  end

  @impl true
  def handle_continue({:fire_next_step, args}, %{topsort: [next_vertex | rest_vertices]} = state) do
    step = Map.fetch!(state.vertex_to_step, next_vertex)

    send(
      state.client_pid,
      {:async_graph, :step_started, state.graph_name, step.label}
    )

    case step.task.(args) do
      {:ok, _} = result ->
        send(
          state.client_pid,
          {:async_graph, :step_completed, :success, state.graph_name, step.label, result}
        )

        {:noreply, Map.replace!(state, :topsort, rest_vertices)}

      {:error, _} = result ->
        send(
          state.client_pid,
          {:async_graph, :step_completed, :failure, state.graph_name, step.label, result}
        )

        {:stop, :normal, state}
    end
  end

  @impl true
  def handle_continue({:fire_next_step, _args}, %{topsort: []} = state) do
    send(state.client_pid, {:async_graph, :graph_completed, state.graph_name})
    {:stop, :normal, state}
  end
end
