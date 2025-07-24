defmodule HX712Proxy do
  use GenServer
  require Logger

  defstruct [:addo, :adsk, :scale, :offset, :name]
  
  def start_link([addo_pin: _addo_pin, adsk_pin: _adsk_pin, 
    scale: _scale, offset: _offset, name: name] = opts) do
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def read_load(name) do
    GenServer.call(name, :read_load, 3)
  end

  def tare(name) do
    GenServer.call(name, :tare, 10000)
  end

  def stop(name) do
    GenServer.stop(name)
  end

  def set_offset(name, offset) do
    GenServer.call(name, {:offset, offset})
  end

  def set_scale(name, scale) do
    GenServer.call(name, {:scale, scale})
  end

  def calibrate(name) do
    GenServer.call(name, :calibrate, 60000)
  end


  @impl true
  def init([addo_pin: addo_pin, adsk_pin: adsk_pin, 
    scale: scale, offset: offset, name: name]) do
    schedule_reading()
      {:ok, %__MODULE__{
        addo: addo_pin, 
        adsk: adsk_pin,
        scale: scale, 
        offset: offset,
        name: name, 
      }}
  end

  @impl true
  def handle_info(:read_sensor, state) do
    data = hx712_read_one(state)
        # Broadcast the new value
    Phoenix.PubSub.broadcast(:my_pubsub, "sensor", 
      {:sensor_update, Map.put_new(%{}, state.name, data)})
    # Schedule next reading
    schedule_reading()
    {:noreply, state}
  end

  defp schedule_reading do
    # Adjust interval as needed (100ms = 0.1 seconds)
    Process.send_after(self(), :read_sensor, 100)
  end



  @impl true
  def handle_call(:read_load, _from, state) do
    data = :rand.uniform(500)/100 + 300
    {:reply, data, state}
  end

  def handle_call(:tare, _from, state) do
     read = Enum.reduce(1..16, 0, fn _x,acc -> acc + :rand.uniform(500)/100 + 300 end) / 16
      new_offset = read * state.scale + state.offset
     {:reply, new_offset, %{state | offset: new_offset}}
  end   

  def handle_call({:offset, offset}, _from, state) do
     {:reply, offset, %{state | offset: offset}}
  end

  def handle_call( {:scale, scale}, _from, state) do
     {:reply, scale, %{state | scale: scale}}
  end

  def handle_call( :calibrate, _from, state) do
    IO.gets("Remove any items from scale. Press enter when ready.")
    offset = Enum.reduce(1..16, 0, fn _x,acc -> acc + 
      hx712_read_one(%{state | offset: 0, scale: 1}) end) / 16
    IO.gets("Please place an item of known weight on the scale. Press enter when ready.")
    measured_weight  = Enum.reduce(1..16, 0, fn _x,acc -> acc + 
       hx712_read_one(%{state | offset: offset, scale: 1}) end) / 16
    item_weight = getNum("")
    scale = measured_weight / item_weight
    {:reply, %{offset: offset, scale: scale}, %{state | offset: offset, scale: scale}}
  end

   def hx712_read_one(%__MODULE__{addo: _addo, adsk: _adsk, offset: _offset, scale: _scale}) do 
     :rand.uniform(500)/100 + 300
   end

   def getNum(str) do
       case Float.parse(str) do
      {x, ""} -> x
      {x, "\n"} -> x
      _ ->
        new_str = IO.gets("Please enter the item's weight in grams.\n>")
        getNum(new_str)
      end
  end
  
end
