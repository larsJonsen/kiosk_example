defmodule LoadReader do
  use GenServer
  require Logger

  alias Weight.HX712

  defstruct [:addo, :adsk, :data, :interval, :last_read, :error_count, :max_errors]

  # Client API
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def get_data do
    GenServer.call(__MODULE__, :get_data)
  end

  def get_status do
    GenServer.call(__MODULE__, :get_status)
  end

  def update_interval(new_interval) do
    GenServer.cast(__MODULE__, {:update_interval, new_interval})
  end

  # Server Callbacks
  @impl true
  def init(opts) do
    with %{addo: addo, adsk: adsk} <- HX712.start() do
      interval = Keyword.get(opts, :interval, 500)
      max_errors = Keyword.get(opts, :max_errors, 5)
      # Read immediately on start
      schedule_read(0)

      {:ok,
       %__MODULE__{
         addo: addo,
         adsk: adsk,
         data: nil,
         interval: interval,
         last_read: nil,
         error_count: 0,
         max_errors: max_errors
       }}
    end
  end

  @impl true
  def handle_call(:get_data, _from, state) do
    case state.data do
      nil -> {:reply, {:error, :no_data_available}, state}
      data -> {:reply, {:ok, data, state.last_read}, state}
    end
  end

  def handle_call(:get_status, _from, state) do
    status = %{
      has_data: state.data != nil,
      last_read: state.last_read,
      error_count: state.error_count,
      interval: state.interval
    }

    {:reply, status, state}
  end

  @impl true
  def handle_cast({:update_interval, new_interval}, state) do
    {:noreply, %{state | interval: new_interval}}
  end

  @impl true
  def handle_info(:read_sensor, %{addo: addo, adsk: adsk} = state) do
    data = HX712.read_one(%{addo: addo, adsk: adsk})
    {:noreply, %{state | data: data, last_read: DateTime.utc_now()}}

    # {:error, reason} ->
    #   Logger.warning("Sensor read failed: #{inspect(reason)}")
    #   
    #   new_error_count = state.error_count + 1
    #   
    #   if new_error_count >= state.max_errors do
    #     Logger.error("Max sensor errors reached, stopping reader")
    #     {:stop, :max_errors_reached, state}
    #   else
    #     # Exponential backoff on errors
    #     backoff_interval = min(state.interval * new_error_count, 60_000)
    #     schedule_read(backoff_interval)
    #     
    #     {:noreply, %{state | error_count: new_error_count}}
    #   end
  end

  # Private functions
  defp schedule_read(interval) do
    Process.send_after(self(), :read_sensor, interval)
  end

  def read_sensor do
    try do
      # Replace with your actual sensor reading logic
      # Example:
      # case YourSensorModule.read() do
      #   {:ok, value} -> {:ok, value}
      #   {:error, reason} -> {:error, reason}
      # end

      # Mock implementation
      if :rand.uniform() > 0.1 do
        {:ok, %{temperature: :rand.uniform(100), humidity: :rand.uniform(100)}}
      else
        {:error, :sensor_timeout}
      end
    rescue
      exception -> {:error, exception}
    end
  end
end
