 defmodule Dosing do
  use GenStateMachine
# idle tararing, dosing, stoped, finish
# idle -> tararing, tara, :ok -> dosing
# dosing -> finish, scale_update
# tararing, dosing -> stoped, stop

 def start_link(opts \\ []) do
    GenStateMachine.start_link(__MODULE__, opts, name: __MODULE__)
 end

  def get_state() do
      GenStateMachine.call(__MODULE__, :get_state)
  end

 # def do_tararing() do
 #   GenStateMachine.cast(__MODULE__, :tararing)
 # end

  def stop() do
    GenStateMachine.cast(__MODULE__, :stop)
  end

  def start_dosing({:dose, dose_float}) do
      GenStateMachine.cast(__MODULE__, {:dose, dose_float})
  end


 # Define the initial state and data
  def init(_opts) do
    bc_new_state(:idle)
    {:ok, :idle, %{
      desired_amount: 0.0,
      tara_weight: 0.0,
      target_weight: 0.0}}
  end


  def handle_event(:info, {:tara, value}, :tararing, data) do
    IO.inspect(value, label: "Handel info, value")
    Valve.open()
    new_state(:dosing, %{data | tara_weight: value, target_weight: data.desired_amount + value})
  end

  def handle_event(:info, {:scale_update, new_value}, :dosing, data) do
    cond do
      new_value >= data.target_weight ->
        Valve.close()
        Scale.tara()
        new_state(:finish, data)
      true ->
        :keep_state_and_data 
    end    
  end

  def handle_event(:info, {:tara, value}, :finish, data) do
    IO.inspect(%{desired_amount: data.desired_amount,
          achived_amount: value - data.tara_weight }, label: "Handle evnet finish")
    new_state(:idle, %{
      desired_amount: 0.0,
      tara_weight: 0.0,
      target_weight: 0.0})
  end

  # call
  def handle_event({:call, from}, :get_state, state, _data) do
    GenStateMachine.reply(from, {:state, state})
    :keep_state_and_data  
  end

  def handle_event(:cast, {:dose, dose_float}, :idle, data) do
    Scale.tara()
    new_state(:tararing, %{data | desired_amount: dose_float})
  end
    
  # def handle_event(:cast, :tararing, :idle, data) do
  #   pid = self()
  #   IO.inspect(pid, label: "Testing")
  #   Task.start_link(__MODULE__, :tara, [pid])
  #   new_state(:tararing, data)
  # end

  def handle_event(:cast, :stop, _state, data) do
    new_state(:idle, data)
  end

  defp new_state(state, data) do
    bc_new_state(state)
    {:next_state, state, data}
  end

  defp bc_new_state(state) do
    Phoenix.PubSub.broadcast(
    KioskExample.PubSub,
    "state",
    {:new_dose, state})
  end

#  def tara({pid, _alias}) do
#      IO.inspect(pid, label: "tara")
#      Process.sleep(2000)
#      IO.inspect(pid, label: "tara II")
#      send(pid, {:tara, 230})
#  end
#
  def tara(pid) do
      IO.inspect(pid, label: "tara pid")
      Process.sleep(2000)
      IO.inspect(pid, label: "tara II")
      send(pid, {:tara, 230})
  end

end