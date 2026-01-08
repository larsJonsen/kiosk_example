defmodule Calibrate do

  def calibrate(name) do

  	IO.gets("Remove any items from scale. Press enter when ready.")

  	offset = Proxy.raw16(name)

    IO.gets("Please place an item of known weight on the scale. Press enter when ready.")

    measured_weight = Proxy.raw16(name, offset)

    item_weight = getNum("")

    scale = measured_weight / item_weight
    {:ok, %{offset: offset, scale: scale}}
  end

  def getNum(str) do
    case Float.parse(str) do
      {x, ""} ->
        x

      {x, "\n"} ->
        x

      _ ->
        new_str = IO.gets("Please enter the item's weight in grams.\n>")
        getNum(new_str)
    end
  end

end