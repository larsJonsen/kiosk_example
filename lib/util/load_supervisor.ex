defmodule LoadSupervisor do

  use Supervisor

  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  def stop() do
    Supervisor.stop( __MODULE__)
  end

  @impl Supervisor
  def init(_args) do

    children = 
    if Mix.target() == :host do
      [
      {Phoenix.PubSub,  name: :my_pubsub},
     %{
        id: LoadSensor_1,
        start: {HX712Proxy, :start_link, [[addo_pin: 17, adsk_pin: 22, 
        scale: -102.2123125, offset: 8303686.6875, name: :sensor_1]]}
      },
      %{
        id: LoadSensor_2,
        start: {HX712Proxy, :start_link, [[addo_pin: 18, adsk_pin: 32, 
        scale: -102.2123125, offset: 8303686.6875, name: :sensor_2]]}
      },
      %{
        id: Scale,
        start: {LoadSensorServer, :start_link, [[pubsub: :my_pubsub, sensor: [:sensor_1, :sensor_2]]]}
      },
      %{
        id: Dosing,
        start: {DosingServer, :start_link, [[open_pin: 3, close_pin: 4,  pubsub: :my_pubsub, name: :dose]]}
      },
    ]
 
    else
      [
      {Phoenix.PubSub,  name: :my_pubsub},
     %{
        id: LoadSensor,
        start: {HX712Server, :start_link, [[addo_pin: 17, adsk_pin: 22, 
        scale: -102.2123125, offset: 8303686.6875, name: :sensor_1]]}
      },
      %{
        id: Scale,
        start: {LoadSensorServer, :start_link, [[pubsub: :my_pubsub, sensor: [:sensor_1]]]}
      },
      %{
        id: Dosing,
        start: {DosingServer, :start_link, [[open_pin: 3, close_pin: 4,  pubsub: :my_pubsub, name: :dose]]}
      },
    ]
  end
    Supervisor.init(children, strategy: :rest_for_one)
  end

end
