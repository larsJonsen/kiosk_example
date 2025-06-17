defmodule HX712Server do
  use GenServer
  require Logger
  import Bitwise

  defstruct [:addo, :adsk, :scale, :offset]
  
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

  @impl true
  def init([addo_pin: addo_pin, adsk_pin: adsk_pin, 
    scale: scale, offset: offset, name: _name]) do
    with %{addo: addo, adsk: adsk} <- hx712_start(%{addo_pin: addo_pin, adsk_pin: adsk_pin}) do
      {:ok, %__MODULE__{
        addo: addo, 
        adsk: adsk,
        scale: scale, 
        offset: offset,
      }}
    else
      _ -> {:error, nil}
    end
  end


  @impl true
  def handle_call(:read_load, _from, state) do
    data = hx712_read_one(state)
    {:reply, data, state}
  end

  def handle_call(:tare, _from, state) do
     read = Enum.reduce(1..16, 0, fn _x,acc -> acc + hx712_read_one(state) end) / 16
    new_offset = read * state.scale + state.offset
     {:reply, new_offset, %{state | offset: new_offset}}
  end
  
  def hx712_start(%{addo_pin: addo_pin, adsk_pin: adsk_pin}) do
     # Initialize GPIO pins 
    {:ok, addo} = Circuits.GPIO.open(addo_pin, :input) 
    {:ok, adsk} = Circuits.GPIO.open(adsk_pin, :output) 
     Circuits.GPIO.write(adsk, 0)
    %{addo: addo, adsk: adsk}
  end
  
  def hx712_read_one(%__MODULE__{addo: addo, adsk: adsk, offset: offset, scale: scale}) do 
      # Wait until ADDO goes low (AD conversion completed) 
      wait_until_ready(addo) 
       
      # Read 24 bits of data 
        {value, _, _} = read_bits(24, 0, %{addo: addo, assk: adsk}) 
       
      # Final clock pulse (as in original code) 
      Circuits.GPIO.write(adsk, 1)
      Process.sleep(1) # Tiny delay (NOP equivalent) 
      Circuits.GPIO.write(adsk, 0)
      #IO.inspect(%{Time: Time.utc_now, Value: value})
      (bxor(value,0x800000) - offset)/scale
    end 

   def wait_until_ready(pin) do 
    case Circuits.GPIO.read(pin)  do 
      1 ->  
        Process.sleep(1) 
        wait_until_ready(pin) 
      0 ->  
        :ok 
    end 
  end 

  defp read_bits(0, acc, _), do: {acc, 0, 0} 
   
  defp read_bits(bits_remaining, acc, %{addo: addo, assk: adsk}) do 
    # Clock pulse (PD_SCK set high) 
    Circuits.GPIO.write(adsk, 1) 
    #Process.sleep(0.0002) # Tiny delay (NOP equivalent) 
     
    # PD_SCK set low 
    Circuits.GPIO.write(adsk, 0) 
     
    # Read one bit 
    bit_value = Circuits.GPIO.read(addo) 
   # IO.inspect(bit_value)
     
    # Shift and accumulate (equivalent to RLC A operations in assembly) 
    new_acc = (acc <<< 1) ||| bit_value 
     
    # Continue with remaining bits 
    read_bits(bits_remaining - 1, new_acc, %{addo: addo, assk: adsk}) 
  end 
end