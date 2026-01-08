defmodule State do
  use GenStateMachine
  require Logger

#off testing, clibrting, error, ready, dosing
# off -> testing, do_test
# off -> calibrating, do_calibrate -> off
# calibarting :ok -> ready, :error -> error
# ready -> dosing, do_dosing
# dosing -> ready, stop_dosing


  def start_link(opts \\ []) do
    GenStateMachine.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def get_state() do
      GenStateMachine.call(__MODULE__, :get_state)
  end

  def do_test() do
    GenStateMachine.cast(__MODULE__, :do_test)
  end

  def go_off() do
    GenStateMachine.cast(__MODULE__, :go_off)
  end

  def do_calibrate() do
    GenStateMachine.cast(__MODULE__, :do_calibrate)
  end

  def do_dosing() do
    with {:ok, _pid} <- StateSupervisor.start_dose() do
      GenStateMachine.cast(__MODULE__, :do_dosing)
    else
      {:error, reason} ->
        GenStateMachine.cast(__MODULE__, {:fail, reason})
    end
  end
  
  def error_test(reason) do
    GenStateMachine.cast(__MODULE__, {:fail, reason})
  end

  def do_reste do
    GenStateMachine.cast(__MODULE__, :reset)
  end

  def stop_dosing() do
    GenStateMachine.cast(__MODULE__, :stop_dosing)
  end

  # Define the initial state and data
  def init(_opts) do
    bc_new_state(:off)
    {:ok, :off, %{}}
  end

  # call
  def handle_event({:call, from}, :get_state, state, _data) do
    GenStateMachine.reply(from, {:state, state})
    :keep_state_and_data  
  end


  # info
  def handle_event(:info, {:test, :ok}, :testing, data) do
    new_state(:ready, data)
  end

  def handle_event(:info, {:test, {:error, list}}, :testing, data) do
    Enum.map(list, fn {a,b} -> if a == :error, do: IO.inspect(b, label: "error") 
     end)   
    new_state(:error, data)
  end

  def handle_event(:info, {:calibrate, :ok}, :calibrating, data) do
    new_state(:ready, data)
  end

  # cast
  def handle_event(:cast, :do_test, :off, data) do
    pid = self()
    IO.inspect(pid, label: "Testing")
    Task.start_link(fn -> test(pid) end)
    new_state(:testing, data)
  end

  def handle_event(:cast, :go_off, _state, data) do
    new_state(:off, data)
  end
   
  def handle_event(:cast, :do_calibrate, :off, data) do
    new_state(:calibrating, data)
  end

   def handle_event(:cast, :do_dosing, :ready, data) do
    new_state(:dosing, data)
  end

  def handle_event(:cast, :stop_dosing, :dosing, data) do
    stop_dosesupervisor()
    new_state(:ready, data)
  end
  
  def handle_event(:cast, :stop_dosing, _state, _data) do
    stop_dosesupervisor()
    :keep_state_and_data 
  end

  # Handle the :fail event in the :processing state
  def handle_event(:cast, {:fail, reason}, _state, data) do
    stop_dosesupervisor()
    Logger.info(reason)
    new_state(:error, data)
  end

  # Handle the :reset event in the :error state
  def handle_event(:cast, :reset, :error, data) do
    new_state(:off, data)
  end

  defp stop_dosesupervisor do
    if Process.whereis(DoseSupervisor), do:  StateSupervisor.stop_dose() 
  end

  defp new_state(state,data) do
    bc_new_state(state)
    {:next_state, state, data}
  end

  defp bc_new_state(state) do
    Phoenix.PubSub.broadcast(
    KioskExample.PubSub,
    "state",
    {:new_state, state})
  end

  def test(pid) do
    IO.inspect(pid, label: "test")
    Process.sleep(2000)
    IO.inspect(pid, label: "test II")
    send(pid, {:test, :ok})
   # send(pid, {:test, {:error, [{:error, "reason"}]}})
  end
end
