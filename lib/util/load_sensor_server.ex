defmodule LoadSensorServer do
  use GenServer

  @max_size 10
  @tolerance 0.15

   defstruct [:pubsub, 
     :sensor, 
     :offset, 
     :current_value, 
     :value_stack, 
     :squarer_stack,
     :stable]

  # Client API
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def get_current_value do
    GenServer.call(__MODULE__, :get_value)
  end
  
  def subscribe do
    GenServer.call(__MODULE__, :subscribe)
  end

  def stop do
    GenServer.stop(__MODULE__)
  end

  def tare do
    GenServer.call(__MODULE__, :tare)
  end

  def stable? do
    GenServer.call(__MODULE__, :stable?)
  end

  def get_mean do
    GenServer.call(__MODULE__, :get_mean)
  end

  
  # Server callbacks
   @impl true
  def init( [pubsub: pubsub, sensor: sensor]) do
    # Schedule first reading
    schedule_reading()
    {:ok, %__MODULE__{
      pubsub: pubsub,   
      sensor: sensor, 
      offset: 0, 
      current_value: 0,
      value_stack: List.duplicate(0.0, @max_size), 
      squarer_stack: List.duplicate(0.0, @max_size),
      stable: false}}
  end

   @impl true
  def handle_info(:read_sensor, state) do
    new_value = state.sensor
    |> Task.async_stream(HX712Server, :read_load, [])
    |> Enum.reduce(state.offset, fn x, acc -> elem(x,1) + acc end)
    
    # Calculate stability
    new_value_stack = push_stack(state.value_stack,new_value)
    new_squarer_stack = push_stack(state.squarer_stack,new_value**2)
    ss = Enum.sum(new_squarer_stack) - Enum.sum(new_value_stack)**2/@max_size
    stable = ss  < @tolerance * @max_size

    # Broadcast the new value
    Phoenix.PubSub.broadcast(state.pubsub, "scale", 
      {:load_updated, %{value: new_value, stable: stable, ss: ss}})
    
    # Schedule next reading
    schedule_reading()
    {:noreply, %{state | 
          current_value: new_value, 
          value_stack: new_value_stack, 
          squarer_stack: new_squarer_stack,
          stable: stable}}
  end
  
  def handle_info(result, state) do
    IO.inspect(result, label: "Result")
    {:noreply, state}
  end

  @impl true
  def handle_call(:get_value, _from, state) do
    {:reply, state.current_value, state}
  end

  def handle_call(:get_mean, _from, state) do
    {:reply, Enum.sum(state.value_stack)/@max_size, state}
  end

  def handle_call(:tare, from, state) do
    Task.async(__MODULE__, :tare, [from]) 
    {:reply, {:ok, "Tare startet"}, state}
  end

  def handle_call(:stable?, _from, state) do
    {:reply, state.stable, state}
  end

  #def handle_call(:tare, _from, state) do
  #  new_offset = state.offset - state.current_value
  #  {:reply, new_offset, %{state | offset: new_offset}}
  #end
  
  defp schedule_reading do
    # Adjust interval as needed (500ms = 0.5 seconds)
    Process.send_after(self(), :read_sensor, 500)
  end
  
  defp push_stack(stack, new_value) do
    [new_value | stack]
    |> Enum.take(@max_size)
  end

  def tare({pid, _alias} ) do
    if stable?() do
      send(pid,{:tare, get_mean() })
    else
      Phoenix.PubSub.subscribe(:my_pubsub, "scale")
      wait_for_broadcast()
      send(pid,{:tare, get_mean()})
    end
  end

  def wait_for_broadcast do
    receive do
      {:load_updated, %{stable: true}} ->
        :ok
      {:load_updated, %{stable: false}} ->
        :ok
      _ ->
        wait_for_broadcast()
    end
  end

end