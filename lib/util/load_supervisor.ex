defmodule LoadSupervisor do
  use Supervisor

  @target Mix.target()

  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(args) do
   Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  def stop() do
    Supervisor.stop(__MODULE__)
  end

  @impl Supervisor
  def init(_args) do
   Supervisor.init(children(), strategy: :rest_for_one)
  end

   defp validate_children(children) do
    Enum.reduce_while(children, :ok, fn child, _acc ->
      %{id: id, start: {module, function, args}} = child
      IO.inspect(id, label: "reduce while")
      case apply(module, function, args) do
        {:ok, pid} ->
          IO.inspect(pid, label: ":ok")
          #Stop the process since we're just validating
          #Process.exit(pid, :normal)
          {:cont, :ok}
        
        {:error, reason} ->
          IO.inspect(reason, label: ":error")
          {:halt, {:error, {id, reason}}}
      end
    end)
  end

  def validate_sensor(%{id: id, start: {module, function, args},test: :sensor} = child) do
    case apply(module, function, args) do
      {:ok, pid} ->
        apply(module, :stop, [pid])
        :ok
      {:error, reason} -> {:error, reason} 
    end
  end

    def validate_sensor(%{id: id, start: {module, function, args}} =child) do
    case apply(module, function, args) do
      {:ok, pid} ->
        apply(module, :stop, [pid])
        :ok
      {:error, reason} -> {:error, reason} 
    end
  end

  defp children() do
    case @target do
      :host ->
        [
          #{Phoenix.PubSub, name: :my_pubsub},
          %{
            id: LoadSensor_1,
            start:
              {HX712Proxy, :start_link,
               [  %{
                   addo_pin: 17,
                   adsk_pin: 22,
                   scale: -102.2123125,
                   offset: 8_303_686.6875,
                   name: :sensor_1,
                    pubsub: KioskExample.PubSub
                 }
               ],
               test: :sensor}
          },
          %{
            id: LoadSensor_2,
            start:
              {HX712Proxy, :start_link,
               [
                 %{
                   addo_pin: 18,
                   adsk_pin: 32,
                   scale: -102.2123125,
                   offset: 8_303_686.6875,
                   name: :sensor_2,
                    pubsub: KioskExample.PubSub
                 }
               ],
              test: :sensor}
          },
          %{
            id: Scale,
            start:
              {SensorServer, :start_link,
               [%{pubsub: KioskExample.PubSub, sensor: [:sensor_1, :sensor_2]}]}
          },
          %{
            id: Dosing,
            start:
              {DosingServer, :start_link,
               [[open_pin: 20, close_pin: 21,  pubsub: KioskExample.PubSub, name: :dose]]}
          }
        ]

      _ ->
        [
          #{Phoenix.PubSub, name: :my_pubsub},
          %{
            id: LoadSensor_1,
            start:
              {HX712Server, :start_link,
               [
                 %{
                   addo_pin: 17,
                   adsk_pin: 22,
                   scale: 211.21431995738635,
                   offset: 8_264_455.25,
                   name: :sensor_1,
                   pubsub: KioskExample.PubSub
                 }
               ]},
              test: :sensor
          },
          %{
            id: LoadSensor_2,
            start:
              {HX712Server, :start_link,
               [
                 %{
                   addo_pin: 10,
                   adsk_pin: 11,
                   scale: 213.82009055397728,
                   offset: 8_342_070.25,
                   name: :sensor_2,
                  pubsub: KioskExample.PubSub
                 }
               ],
              test: :sensor}
          },
          %{
            id: Scale,
            start:
              {SensorServer, :start_link,
               [%{pubsub: KioskExample.PubSub, sensor: [:sensor_1, :sensor_2]}]}
          },
          %{
            id: Dosing,
            start:
              {DosingServer, :start_link,
               [[open_pin: 20, close_pin: 21, pubsub: KioskExample.PubSub, name: :dose]]}
          }
        ]
    end
  end
end
