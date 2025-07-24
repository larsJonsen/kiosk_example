defmodule DosingServer do
  use GenServer
  require Logger

  defstruct [:name, :open_pin, :close_pin, :status, :pubsub, :desired_amount,
      :tare_weight, :target_weight, :current_weight, :dosing_start_time]

  @moduledoc """
  GenServer for handling dosing/filling operations.
  Manages the complete dosing cycle: tare -> open valve -> monitor -> close valve.
  """

  # Client API

  def start_link([open_pin: _open_pin, close_pin: _close_pin, 
    pubsub: _pubsub, name: name] = opts) do
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Start dosing process with desired amount
  """
  def start_dosing(name, desired_amount) when is_number(desired_amount) and desired_amount > 0 do
    GenServer.call(name, {:start_dosing, desired_amount})
  end

  @doc """
  Stop current dosing process
  """
  def stop_dosing(name) do
    GenServer.call(name, :stop_dosing)
  end

  @doc """
  Get current dosing status  
  """
  def get_status(name) do
    GenServer.call(name, :get_status)
  end

  def start_tare(name) do
    GenServer.cast(name, :tare)
  end

#  @doc """
#  Update scale value (called when scale broadcasts updates)
#  """
#  def update_scale_value(value) do
#    GenServer.cast(__MODULE__, {:scale_update, value})
#  end
##########
  # Server Callbacks

  @impl true
  def init([open_pin: open_pin, close_pin: close_pin, 
    pubsub: pubsub, name: name]) do
     
    # Subscribe to scale updates
    Phoenix.PubSub.subscribe(pubsub, "scale")
    
    initial_state = %__MODULE__{
      name: name,
      pubsub: pubsub,
      status: :idle,
      desired_amount: 0,
      tare_weight: 0,
      target_weight: 0,
      current_weight: 0,
      dosing_start_time: nil,
      open_pin: open_pin, 
      close_pin: close_pin, 
    }
    Logger.info("DosingServer started")
    {:ok, initial_state}
  end

  @impl true
  def handle_call({:start_dosing, desired_amount}, _from, %{status: :idle} = state) do
    IO.inspect("Starting dosing process")
    Logger.info("Starting dosing process for #{desired_amount} units")
    start_tare(self())
    Logger.info("start_tare(self())")
    {:reply, {:ok, :start_dosing}, 
       %__MODULE__{state | status: :taring, 
       desired_amount: desired_amount}}
  end

  def handle_call({:start_dosing, _}, _from, state) do
    {:reply, {:error, :already_dosing}, state}
  end

  def handle_call(:stop_dosing, _from, state) do
    case state.status do
      :idle ->
        {:reply, {:ok, :already_idle}, state}
      
      _ ->
        # Close valve and reset to idle
        close_dosing_valve(%{open_pin: state.open_pin, close_pin: state.close_pin})
        Logger.info("Dosing stopped manually")
        {:reply, {:ok, :stopped}, %__MODULE__{state |
                    status: :idle,
                    desired_amount: 0,
                    dosing_start_time: nil
        }}
    end
  end

  def handle_call(:get_status, _from, state) do
    IO.inspect("handle_call(:get_status ....")
    status_info = %{
      status: state.status,
      desired_amount: state.desired_amount,
      current_weight: state.current_weight,
      net_weight: state.current_weight - state.tare_weight,
    }
    {:reply, status_info, state}
  end

  @impl true
  def handle_info({:scale_updated,  %{value: new_value}}, state) do
    Phoenix.PubSub.broadcast(state.pubsub, "dose", 
      {state.name, %{status: state.status, 
          net_weight: state.current_weight - state.tare_weight}})
    # Handle PubSub messages from scale
    handle_cast({:scale_update, new_value}, state)
  end

  def handle_info(msg, state) do
    Logger.debug("Received unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end

  @impl true
  def handle_cast({:scale_update, new_value}, state) do
    # Update current weight and calculate net weight
    case state.status do
      :idle -> {:noreply, %__MODULE__{state | 
            current_weight: new_value}}
      :taring -> {:noreply, %__MODULE__{state | 
            current_weight: new_value}}
      :dosing -> 
        if new_value >= state.target_weight do
          close_dosing_valve(%{open_pin: state.open_pin, close_pin: state.close_pin})
          Logger.info("Dosing completed, desired weight: #{state.desired_amount}, 
            actual dose #{new_value - state.tare_weight}")
          {:noreply, %__MODULE__{state | 
              current_weight: new_value, 
              status: :idle,
              desired_amount: 0, 
              tare_weight: 0, 
              target_weight: 0,}}
        else
          {:noreply, %__MODULE__{state | 
              current_weight: new_value}}
        end     
    end
  end

  def handle_cast(:tare, state) do
    with {:ok, _text} <- SensorServer.tare(),          
      {:ok,tare_weight} <- wait_for_tare() do
        open_dosing_valve(%{open_pin: state.open_pin, close_pin: state.close_pin})
        {:noreply,  %__MODULE__{state | 
            status: :dosing, 
            tare_weight: tare_weight, 
            target_weight: state.desired_amount + tare_weight}}
    else
      _ -> {:noreply, %__MODULE__{state | status: :error}}
    end
  end

  defp wait_for_tare() do
    receive do
      {:tare, tare} ->
        Logger.info("Tare completed, #{tare}")
        {:ok, tare}
      _ ->
        wait_for_tare()
    end
  end
    
  defp open_dosing_valve(pins) do
    # Replace with actual valve open command
    Logger.debug("Opening dosing valve")
    case send_hardware_command(:open_valve, pins) do
      :ok -> :ok
      error -> {:error, error}
    end
  end

  defp close_dosing_valve(pins) do
    # Replace with actual valve close command  
    Logger.debug("Closing dosing valve")
    case send_hardware_command(:close_valve, pins) do
      :ok -> :ok
      error -> {:error, error}
    end
  end

  defp send_hardware_command(command, %{open_pin: _open_pin, close_pin: _close_pin}) do
    Logger.debug("Hardware command: #{command}")
    case command do
      :close_valve -> :ok
      :open_valve -> :ok
    end
  end
end

