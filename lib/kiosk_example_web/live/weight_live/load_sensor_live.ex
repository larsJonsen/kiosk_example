defmodule KioskExampleWeb.LoadSensorLive do
  use KioskExampleWeb, :live_view

  import KioskExampleWeb.Components.Button

  
  def mount(_params, _session, socket) do
    # Subscribe to sensor updates
    if connected?(socket) do
      Phoenix.PubSub.subscribe(:my_pubsub, "scale")
      Phoenix.PubSub.subscribe(:my_pubsub, "dose")
    end
    
    # Get initial value
    initial_value = SensorServer.get_current_value()
    {:ok, socket
          |>assign(:load_value, initial_value)
          |>assign(:stable, false)
          |>assign(:status, :start)
          |>assign(:dif, 0.0)
          |>assign(:net_weight, 0.0)
          |>assign(:ctrl_down, false)
          |>assign(:form, to_form(%{"dose" => nil}))
        }
  end
  
  def handle_info({:scale_updated, %{value: new_value, stable: stable, dif: dif}}, socket) do
    {:noreply, assign(socket, [load_value: new_value, stable: stable, dif: dif])}
  end

  def handle_info({:dose, %{status: status, net_weight: net_weight}}, socket) do 
    {:noreply, assign(socket, [status: status, net_weight: net_weight])}
  end

  def handle_info(:clear_flash, socket) do
    {:noreply, clear_flash(socket)}
  end

#  def handle_event("tare", _value, socket) do
#    LoadSensorServer.tare()
#    {:noreply, socket}
#  end

  def handle_event("dose", _value, socket) do
    DosingServer.start_dosing(:dose, 3)
    {:noreply, socket}
  end

  def handle_event("stop", _value, socket) do
    DosingServer.stop_dosing(:dose)
    {:noreply, socket}
  end

  def handle_event("keydown", %{"key" => "Control"}, socket) do
    {:noreply, assign(socket, :ctrl_down, true)}
  end
    
  def handle_event("keydown", %{"key" => key}, socket) do
    IO.inspect(key, label: "key")
    if socket.assigns.ctrl_down do
      case key do
        "d" -> DosingServer.start_dosing(:dose, 3)
        "s" -> DosingServer.stop_dosing(:dose)
        _ -> nil
      end
    end
    {:noreply, socket}
  end

  def handle_event("keydown", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("keyup", %{"key" => "Control"}, socket) do
    {:noreply, assign(socket, :ctrl_down, false)}
  end

  def handle_event("keyup", _params, socket) do
      {:noreply, socket}
  end

  def handle_event("validate", params, socket) do
      IO.inspect(params, label: "validate")
      {:noreply, socket}
  end

  def handle_event("start_dose", %{"dose" => dose}, socket) do
      IO.inspect(dose, label: "start_dose")
      with {dose_float,""} <- Float.parse(dose) do
        DosingServer.start_dosing(:dose, dose_float)
        {:noreply, socket}
      else
        _ -> 
            Process.send_after(self(), :clear_flash, 5000)
           {:noreply, put_flash(socket, :error, "Dosis skal være et tal :-)")}  
      end   
  end

  def my_round(x,n) do
    cond do
      is_float(x) -> x |> Decimal.from_float |> Decimal.round(n)
      is_integer(x) -> x |> Decimal.new |> Decimal.round(n)
      is_binary(x) -> x |> Decimal.new |> Decimal.round(n)
      true -> Decimal.round(x,n)
    end
   
  end

  #   <.button variant="default" color="danger"> {@ss}  <./button>

  def render(assigns) do
    ~H"""
    <div class="load-sensor-display" phx-window-keydown="keydown" phx-window-keyup="keyup">
      <h2>Load Sensor Reading</h2>
  
      <div class="sensor-value">
        <p style="font-size:15em; ">
        <%= round(@load_value) %>
        </p>
        <.my_button variant="default" color="secondary" phx-click="tare">  Tare (Ctrl+T)  </.my_button>
       <.my_button :if={not @stable} variant="default" color="danger" >   {@dif}   </.my_button>
       <.my_button :if={@stable} variant="default" color="success" >   {@dif}  </.my_button>
        <p style="font-size:15em; ">
        <%= round(@net_weight) %>
        </p>

        <.simple_form
        for={@form}
        id="dose_form"
        phx-change="validate"
        phx-submit="start_dose"
      >
        <.input field={@form[:dose]} type="number" label="Dose" />
        <:actions>
        <.my_button variant="default" color="success" phx-disable-with="Starter dose...">  {@status}  </.my_button> 
        </:actions>   
      </.simple_form>
      <.my_button variant="default" color="danger" phx-click="stop">  Stop  </.my_button>
      </div>
    </div>
    """
  end
end