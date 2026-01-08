defmodule KioskExample.SensorReader do
  use GenServer

  # Client API
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def get_data do
    GenServer.call(__MODULE__, :get_data)
  end

  def stop do
    GenServer.stop(__MODULE__)
  end

  # Server Callbacks
  @impl true
  def init(opts) do
    # Default 5 seconds
    interval = Keyword.get(opts, :interval, 5000)
    schedule_read(interval)

    {:ok,
     %{
       data: nil,
       interval: interval,
       last_read: nil
     }}
  end

  @impl true
  def handle_call(:get_data, _from, state) do
    {:reply, {state.data, state.last_read}, state}
  end

  @impl true
  def handle_info(:read_sensor, state) do
    # Replace this with your actual sensor reading function
    data = read_sensor()

    # Schedule next read
    schedule_read(state.interval)

    {:noreply, %{state | data: data, last_read: DateTime.utc_now()}}
  end

  # Private functions
  defp schedule_read(interval) do
    Process.send_after(self(), :read_sensor, interval)
  end

  defp read_sensor do
    # Replace with your actual sensor reading logic
    # For example:
    # {:ok, temperature} = SensorHardware.read_temperature()
    # temperature

    # Mock data for demonstration
    :rand.uniform(100)
  end
end
