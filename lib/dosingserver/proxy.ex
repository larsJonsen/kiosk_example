defmodule Proxy do
  use GenServer
  require Logger
  import Bitwise

  defstruct [:addo, :adsk, :scale, :offset, :name, :mother]

  def start_link(%{name: name} = opts) do
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def read_load(name) do
    GenServer.call(name, :read_load, 3)
  end

#  def tare(name) do
#    GenServer.call(name, :tare, 10000)
#  end

  def stop(name) do
    GenServer.stop(name)
  end

  def set_offset(name, offset) do
    GenServer.call(name, {:offset, offset})
  end

  def set_scale(name, scale) do
    GenServer.call(name, {:scale, scale})
  end

#  def calibrate(name) do
#    GenServer.call(name, :calibrate, 60000)
#  end

  def raw16(name, offset \\ 0) do
    GenServer.call(name, {:raw16,  {:offset, offset}})
  end

  @impl true
  def init(%{
        addo_pin: addo_pin,
        adsk_pin: adsk_pin,
        scale: scale,
        offset: offset,
        name: name,
        mother: mother
      }) do
    schedule_reading()
    Logger.info("init HX712Proxy: #{inspect(name)}")
    with {:ok, %{addo: addo, adsk: adsk}} <- hx712_start(%{addo_pin: addo_pin, adsk_pin: adsk_pin}),
        {:ok, state} <- do_state(%{ addo: addo, adsk: adsk, scale: scale, 
                                  offset: offset, name: name, mother: mother }),
        {:ok,_} <- hx712_read_one(state) do
          {:ok, state}
    else
      {:error, error} ->
         Logger.error("Fejl HX712Proxy: #{inspect(error)}")
          {:error, error}
    end
  end


  @impl true
  def handle_info(:read_sensor, state) do
    with {:ok, data} <- hx712_read_one(state) do
      send(state.mother,  {:sensor_update, Map.put_new(%{}, state.name, data)})
    # Broadcast the new value
    #  Phoenix.PubSub.broadcast(
    #    state. sub,
    #    "sensor",
    #    {:sensor_update, Map.put_new(%{}, state.name, data)}
    #  )
    {:ok, data}
    else
      _ -> 
        Logger.error("Fejl HX712Proxy handel_info :read_sensor")
      end
    # Schedule next reading
    schedule_reading()
    {:noreply, state}
  end

  defp schedule_reading do
    # Adjust interval as needed (100ms = 0.1 seconds)
    Process.send_after(self(), :read_sensor, 100)
  end

  @impl true
  def handle_call( {:raw16,  {:offset, offset}}, _from, state) do
    value =
      Enum.reduce(1..16, 0, fn _x, acc ->
        acc + hx712_read_one!(%{state | offset: offset, scale: 1})
      end) / 16
    {:reply, value, state}
  end


  def handle_call(:read_load, _from, state) do
    data = :rand.uniform(500) / 100 + 300
    {:reply, data, state}
  end

  def handle_call(:tare, _from, state) do
    read = Enum.reduce(1..16, 0, fn _x, acc -> acc + :rand.uniform(500) / 100 + 300 end) / 16
    new_offset = read * state.scale + state.offset
    {:reply, new_offset, %{state | offset: new_offset}}
  end

  def handle_call({:offset, offset}, _from, state) do
    {:reply, offset, %{state | offset: offset}}
  end

  def handle_call({:scale, scale}, _from, state) do
    {:reply, scale, %{state | scale: scale}}
  end

#  def handle_call(:calibrate, _from, state) do
#    IO.gets("Remove any items from scale. Press enter when ready.")
#
#    offset =
#      Enum.reduce(1..16, 0, fn _x, acc ->
#        acc +
#          hx712_read_one(%{state | offset: 0, scale: 1})
#      end) / 16
#
#    IO.gets("Please place an item of known weight on the scale. Press enter when ready.")
#
#    measured_weight =
#      Enum.reduce(1..16, 0, fn _x, acc ->
#        acc +
#          hx712_read_one(%{state | offset: offset, scale: 1})
#      end) / 16
#
#    item_weight = getNum("")
#    scale = measured_weight / item_weight
#    {:reply, %{offset: offset, scale: scale}, %{state | offset: offset, scale: scale}}
#  end

  defp hx712_start(%{addo_pin: addo_pin, adsk_pin: adsk_pin}) do
    {:ok, %{addo: addo_pin, adsk: adsk_pin}}
    # Initialize GPIO pins 
    #with {:ok, addo} <- Circuits.GPIO.open(addo_pin, :input),
    #    {:ok, adsk} <- Circuits.GPIO.open(adsk_pin, :output) do
    #       Circuits.GPIO.write(adsk, 0)
    #      {:ok, %{addo: addo, adsk: adsk}}
    #else 
    #  _ -> {:error, "Failed setting GPIO pins for HX712"}
    #end
  end

  defp hx712_read_one!(%__MODULE__{addo: addo, adsk: adsk, offset: offset, scale: scale}) do
    {:ok,value} =  hx712_read_one(%__MODULE__{addo: addo, adsk: adsk, offset: offset, scale: scale})
    value 
  end

  defp hx712_read_one(%__MODULE__{addo: addo, adsk: adsk, offset: offset, scale: scale}) do
    with {:ok, :ready} <- wait_until_ready(addo, 100),  # 100ms timeout
         {:ok, value} <- read_raw_value(addo, adsk),
         {:ok, scaled_value} <- calculate_value(value, offset, scale) do
      {:ok, scaled_value}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp do_state(%{ addo: addo, adsk: adsk, scale: scale, 
    offset: offset, name: name, mother: mother }) do 
    try do
       {:ok, %__MODULE__{
           addo: addo,
           adsk: adsk,
           scale: scale,
           offset: offset,
           name: name,
           mother: mother
         }}
      rescue
        _ -> {:error, "Fejl HX712Proxy do_state: #{inspect(name)}"}
      end
  end

  defp wait_until_ready(pin, max_count, count \\ 1) do
    if count > max_count do
      Logger.error("Fejl HX712Proxy: sensor_timeout")
      {:error, :sensor_timeout}
    else
      case 0 do
         0 -> 
          {:ok, :ready}
         1 -> 
          Process.sleep(1)
          wait_until_ready(pin, max_count, count + 1)
          _ -> 
          Logger.error("Fejl HX712Proxy: gpio_read_failed")
          {:error, :gpio_read_failed}
      end
    end
  end

  defp read_raw_value(addo, adsk) do
    try do
      {value, _, _} = read_bits(24, 0, %{addo: addo, adsk: adsk})
      # Final clock pulse
      #with :ok <- Circuits.GPIO.write(adsk, 1),
      #     :ok <- Process.sleep(1),
      #     :ok <- Circuits.GPIO.write(adsk, 0) do
        {:ok, value}
     # else
     #   _ ->
     #     Logger.error("Fejl HX712Proxy: gpio_write_failed")
     #     {:error, :gpio_write_failed}
     # end
    rescue
      _ ->
      Logger.error("Fejl HX712Proxy: read_bits_failed")
      {:error, :read_bits_failed}
    end
  end

  defp calculate_value(value, offset, scale) do
    if scale == 0 do
      Logger.error("Fejl HX712Proxy: invalid_scale")
      {:error, :invalid_scale}
    else
      result = (bxor(value, 0x800000) - offset) / scale
      {:ok, result}
    end
  end  

  def read_bits(_bits_remaining, _acc, %{addo: _addo, adsk: _adsk}) do
       {345,0,0}
    end

  #def hx712_read_one(%__MODULE__{addo: _addo, adsk: _adsk, offset: _offset, scale: _scale}) do
  #  :rand.uniform(500) / 100 + 300
  #end

#  def getNum(str) do
#    case Float.parse(str) do
#      {x, ""} ->
#        x
#
#      {x, "\n"} ->
#        x
#
#      _ ->
#        new_str = IO.gets("Please enter the item's weight in grams.\n>")
#        getNum(new_str)
#    end
#  end
end
