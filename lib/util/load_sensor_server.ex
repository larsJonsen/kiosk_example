defmodule LoadSensorServer do
  use GenServer

   defstruct [:pubsub, :sensor, :offset, :current_value]

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
  
  # Server callbacks
   @impl true
  def init( [pubsub: pubsub, sensor: sensor]) do
    # Schedule first reading
    schedule_reading()
    {:ok, %__MODULE__{
      pubsub: pubsub,   
      sensor: sensor, 
      offset: 0, 
      current_value: 0}}
  end

   @impl true
  def handle_info(:read_sensor, state) do
    new_value = state.sensor
    |> Task.async_stream(HX712Server, :read_load, [])
    |> Enum.reduce(state.offset, fn x, acc -> elem(x,1) + acc end)
    # Broadcast the new value
    Phoenix.PubSub.broadcast(state.pubsub, "scale", {:load_updated, round(new_value)})
    # Schedule next reading
    schedule_reading()
    {:noreply, %{state | current_value: new_value}}
  end

  @impl true
  def handle_call(:get_value, _from, state) do
    {:reply, state.current_value, state}
  end

  def handle_call(:tare, _from, state) do
    new_offset = state.offset - state.current_value
    {:reply, new_offset, %{state | offset: new_offset}}
  end
  
  defp schedule_reading do
    # Adjust interval as needed (500ms = 0.5 seconds)
    Process.send_after(self(), :read_sensor, 500)
  end
  
end