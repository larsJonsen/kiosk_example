# Start the Phoenix endpoint/server
{:ok, _} = KioskExampleWeb.Endpoint.start_link()

# Or if it's already configured but not started
KioskExampleWeb.Endpoint.start_link()

# Check if the endpoint is already running
KioskExampleWeb.Endpoint.__info__(:functions)

# Or check what's listening on ports
:ranch.info()

########

elixir# Check what applications are running
Application.started_applications()

# Start your kiosk application if it's not running
Application.start(:kiosk_example)

#########

log_attach

{Phoenix.PubSub, name: :my_pubsub}

HX712Server.start_link(%{addo_pin: 17, adsk_pin: 22, scale: 211.21431995738635, offset: 8264455.25, name: :sensor_1, pubsub: :my_pubsub})
HX712Server.start_link(%{addo_pin: 10, adsk_pin: 11, scale: 213.82009055397728, offset: 8342070.25, name: :sensor_2, pubsub: :my_pubsub})

SensorServer.start_link( %{pubsub: :my_pubsub, sensor: [:sensor_1, :sensor_2]})

  
{:ok, sensor} = PubSubLogger.subscribe_and_log(:my_pubsub, "scale")
PubSubLogger.stop(sensor)

{:ok, sensor} = PubSubLogger.subscribe_and_log(:my_pubsub,"sensor")
PubSubLogger.stop(sensor)

{:ok, sensor} = PubSubLogger.subscribe_and_log(:my_pubsub,"dose")
PubSubLogger.stop(sensor)

defmodule My do
  def dif(list) do
  {a,b} = Enum.min_max(list)
    b-a
  end

  def sum(map) do
    map
    |> Map.values
    |> Enum.sum
  end
end
