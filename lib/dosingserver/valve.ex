defmodule Valve do
  use GenStateMachine
  require Logger 

  alias Circuits.GPIO

  # off
  # open 
  # closed

  def start_link(opts \\ []) do
    GenStateMachine.start_link(__MODULE__, opts, name: __MODULE__)
 end

  def get_state() do
      GenStateMachine.call(__MODULE__, :get_state)
  end

  def open() do
    GenStateMachine.cast(__MODULE__, :open)
  end

  def close() do
    GenStateMachine.cast(__MODULE__, :close)
  end

  def init(_opts) do
    Process.flag(:trap_exit, true)
    # Initiate GPIO
    pins = %{open_pin: nil, close_pin: nil}
    send_hardware_command(:close_valve, pins)
    bc_new_state(:closed)
    {:ok, :closed, pins}
  end

  def terminate(_reason, _state, _data) do
    # Free up GPIO here (e.g., release the pin)
    IO.puts("Freeing up GPIO resources.")
    bc_new_state(:off)
    :ok
  end

  def handle_event({:call, from}, :get_state, state, _data) do
    GenStateMachine.reply(from, {:valve, state})
    :keep_state_and_data  
  end

  def handle_event(:cast, :open, _state, pins) do
    send_hardware_command(:open_valve, pins)
    new_state(:open, pins)
  end

  def handle_event(:cast, :close, _state, pins) do
    send_hardware_command(:close_valve, pins)
    new_state(:closed, pins)
  end

  defp new_state(state, data) do
    bc_new_state(state)
    {:next_state, state, data}
  end

  defp bc_new_state(state) do
    Phoenix.PubSub.broadcast(
    KioskExample.PubSub,
    "state",
    {:valve, state})
  end

  defp send_hardware_command(:close_valve, %{open_pin: open_pin, close_pin: close_pin}) do
    Logger.debug("Hardware command: :close_valve")

    if open_pin != nil && close_pin != nil do
      GPIO.write(open_pin, 0)
      GPIO.write(close_pin, 1)
      :ok
    end
  end

  defp send_hardware_command(:open_valve, %{open_pin: open_pin, close_pin: close_pin}) do
    Logger.debug("Hardware command: :open_valve")

    if open_pin != nil && close_pin != nil do
      GPIO.write(close_pin, 0)
      GPIO.write(open_pin, 1)
      :ok
    end
  end
end