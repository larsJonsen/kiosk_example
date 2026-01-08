defmodule Scale do
  use GenServer

  @max_size 4
  @tolerance 4

  defstruct [:pubsub, :sensor, :readings, :offset, :current_value, :value_stack, :stable, :child]

  # Client API
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def stop() do
    GenServer.stop(__MODULE__)
  end

  def get_current_value do
    GenServer.call(__MODULE__, :get_value)
  end

  def tare do
    GenServer.call(__MODULE__, :tare)
  end

  def tara do
    GenServer.call(__MODULE__, :tara)
  end

  def stable? do
    GenServer.call(__MODULE__, :stable?)
  end

  def get_mean do
    GenServer.call(__MODULE__, :get_mean)
  end

  # Server callbacks
  @impl true
  def init(%{pubsub: pubsub, sensor: sensor}) do
    Phoenix.PubSub.subscribe(pubsub, "sensor")
    # Schedule first reading
    {:ok,
     %__MODULE__{
       pubsub: pubsub,
       sensor: sensor,
       readings: Map.new(sensor, fn k -> {k, 0.0} end),
       offset: 0,
       current_value: 0,
       value_stack: List.duplicate(0.0, @max_size),
       stable: false,
       child: nil,
     }}
  end

  @impl true
  def handle_call(:get_value, _from, state) do
    {:reply, state.current_value, state}
  end

  def handle_call(:get_mean, _from, state) do
    {:reply, Enum.sum(state.value_stack) / @max_size, state}
  end

  def handle_call(:tara, from, state) do
    child = spawn(__MODULE__, :tara, [from])
    IO.inspect(child, label: "Handel call :tara")
    {:reply, {:ok, "Tara startet"}, %{state | child: child}}
  end

  def handle_call(:stable?, _from, state) do
    {:reply, state.stable, state}
  end

  @impl true
  def handle_info({:test, tekst}, state) do
    IO.inspect(tekst, label: "Handel info")
     {:noreply, state}
  end

 # def handle_info({:sensor_update, map}, state) do
 #   #IO.inspect(map, label: "Handel info")
 #       {:noreply, state}
 # end

  def handle_info({:sensor_update, map}, state) do
    new_readings = Map.merge(state.readings, map)
    new_value = sum(new_readings)
    new_value_stack = push_stack(state.value_stack, new_value)
    dif = dif(new_value_stack)
    stable = dif < @tolerance

    child = 
      if stable && state.child do
        send(state.child, :stable)
        nil
      else
        state.child
      end
#IO.inspect(dif, label: "Handel info")
 #   Phoenix.PubSub.broadcast(
 #     state.pubsub,
 #     "scale",
 #     {:scale_updated, %{value: new_value, stable: stable, dif: dif}}
 #   )
#
    {:noreply,
     %{
       state
       | current_value: new_value,
         readings: new_readings,
         value_stack: new_value_stack,
         stable: stable,
         child: child
     }}
  end

  def handle_info(result, state) do
    IO.inspect(result, label: "Result")
    {:noreply, state}
  end

  defp dif(list) do
    {a, b} = Enum.min_max(list)
    b - a
  end

  defp sum(map) do
    map
    |> Map.values()
    |> Enum.sum()
  end

  defp push_stack(stack, new_value) do
    [new_value | stack]
    |> Enum.take(@max_size)
  end


   def tara({pid, alias}) do
    IO.inspect(pid, label: "TaraII")
    receive do
       :stable ->
          send(pid, {:tara, get_mean()})
          :ok
        _->
          tara({pid, alias})
        end
  end

end
