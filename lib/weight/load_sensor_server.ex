defmodule KioskExample.LoadSensorServer do
  use GenServer
  

  # Client API
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def get_current_value do
    GenServer.call(__MODULE__, :get_value)
  end
  
  def subscribe do
    Phoenix.PubSub.subscribe(KioskExample.PubSub, "load_sensor")
  end
  
  # Server callbacks
  def init(_opts) do
    # Schedule first reading
    schedule_reading()
    {:ok, %{current_value: 0}}
  end
  
  def handle_info(:read_sensor, state) do
    # Read your sensor here
    new_value = read_load_sensor()
    
    # Broadcast the new value
    Phoenix.PubSub.broadcast(KioskExample.PubSub, "load_sensor", {:load_updated, new_value})
    
    # Schedule next reading
    schedule_reading()
    
    {:noreply, %{state | current_value: new_value}}
  end

  def handle_call(:get_value, _from, state) do
    {:reply, state.current_value, state}
  end
  
  defp schedule_reading do
    # Adjust interval as needed (5000ms = 5 seconds)
    Process.send_after(self(), :read_sensor, 500)
  end
  
  defp read_load_sensor do
    # Your actual sensor reading logic here
    # This is just a placeholder
    :rand.uniform(1000)
  end
end