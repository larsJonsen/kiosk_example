defmodule Weight.HX712 do 
  import Bitwise
  @moduledoc """ 
  Elixir module for reading data from HX711 load cell amplifier. 
  This is a translation from 8051 assembly code. 
  """ 
   
  # Define GPIO pin numbers 
  @addo_pin 17  # Data Out pin 
  @adsk_pin 22 # Clock pin 

  @scale -102.2123125
  @offset 8303686.6875


  def start() do
     # Initialize GPIO pins 
    {:ok, addo} = Circuits.GPIO.open(@addo_pin, :input) 
    {:ok, adsk} = Circuits.GPIO.open(@adsk_pin, :output) 
     Circuits.GPIO.write(adsk, 0)
    %{addo: addo, adsk: adsk}
  end
  
  def stop( %{addo: addo, adsk: adsk}) do
    Circuits.GPIO.close(addo)
    Circuits.GPIO.close(adsk)
  end
  
  def read_one(%{addo: addo, adsk: adsk}) do 
    # Wait until ADDO goes low (AD conversion completed) 
    wait_until_ready(addo) 
     
    # Read 24 bits of data 
      {value, _, _} = read_bits(24, 0, %{addo: addo, assk: adsk}) 
     
    # Final clock pulse (as in original code) 
    Circuits.GPIO.write(adsk, 1)
    Process.sleep(1) # Tiny delay (NOP equivalent) 
    Circuits.GPIO.write(adsk, 0)
    #IO.inspect(%{Time: Time.utc_now, Value: value})
    (bxor(value,0x800000) - @offset)/@scale
  end 
   
  # Wait until the ADDO pin goes low, indicating HX711 is ready 
  def wait_until_ready(pin) do 
    case Circuits.GPIO.read(pin)  do 
      1 ->  
        Process.sleep(1) 
        wait_until_ready(pin) 
      0 ->  
        :ok 
    end 
  end 
   
  # Recursively read specified number of bits from HX711 
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

  def read_avreage() do
    adxx = start()
    read = Enum.reduce(1..16, 0, fn _x,acc -> acc + read_one(adxx) end) / 16
    stop(adxx)
    read
  end

  def get_many() do
    adxx = start()
    Enum.map(1..100, fn _x -> round(read_one(adxx)) end)
    stop(adxx)
  end  
end