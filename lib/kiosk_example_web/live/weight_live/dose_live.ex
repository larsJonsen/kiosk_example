defmodule KioskExampleWeb.DoseLive do
  use KioskExampleWeb, :live_view

  import KioskExampleWeb.Components.Button

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(KioskExample.PubSub, "state")
    end

   state = try do
     {:state, state} = State.get_state() 
     state
    rescue
      _->
      Logger.error("State server not running")
      nil 
    end

  {:ok,
    socket
    |> assign(:state, state)
    |> assign(:dose, :off)
    |> assign(:valve, :off)
    |> assign(:ctrl_down, false)
    |> assign(:form, to_form(%{"dose " => nil}))}
   end

  def handle_info({:new_state, state}, socket) do
    {:noreply, assign(socket, state: state)}
  end

  def handle_info({:new_dose, state}, socket) do
    {:noreply, assign(socket, dose: state)}
  end

  def handle_info({:valve, state}, socket) do
    {:noreply, assign(socket, valve: state)}
  end

  def handle_event("test", _value, socket) do
    State.do_test()
    {:noreply, socket}
  end

  def handle_event("calibrate", _value, socket) do
    State.do_calibrate()
    {:noreply, socket}
  end

  def handle_event("off", _value, socket) do
    State.go_off()
    {:noreply, socket}
  end

  def handle_event("dose", _value, socket) do
    State.do_dosing()
    {:noreply, socket}
  end

  def handle_event("stop_dosing", _value, socket) do
    State.stop_dosing()
    {:noreply, socket}
  end

  def handle_event("start", _value, socket) do
    Dosing.do_tararing()
    {:noreply, socket}
  end

  def handle_event("start_dose", %{"dose" => dose}, socket) do
    IO.inspect(dose, label: "start_dose")
    with {dose_float, ""} <- Float.parse(dose) do
      Dosing.start_dosing({:dose, dose_float})
      {:noreply, socket}
    else
      _ ->
        Process.send_after(self(), :clear_flash, 5000)
        {:noreply, put_flash(socket, :error, "Dosis skal være et tal :-)")}
    end
  end

  def handle_event("stop", _value, socket) do
    Dosing.stop()
    {:noreply, socket}
  end

  def handle_event("validate", params, socket) do
    IO.inspect(params, label: "validate")
    {:noreply, socket}
  end

  def handle_event("keydown", %{"key" => "Control"}, socket) do
    {:noreply, assign(socket, :ctrl_down, true)}
  end

  def handle_event("keydown", %{"key" => key}, socket) do
    IO.inspect(key, label: "key")
    if socket.assigns.ctrl_down do
      case key do
       # "d" -> DosingServer.start_dosing(:dose, 3)
       # "s" -> DosingServer.stop_dosing(:dose)
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


#  def render(assigns) do
#    ~H"""
#    <div class="load-sensor-display" phx-window-keydown="keydown" phx-window-keyup="keyup">
#      <h2>Load Sensor Reading</h2>
#
#      <div class="sensor-value">
#      <p style="font-size:5em; ">
#         State: {@state}
#        </p>
#        
#        <.my_button :if={:off == @state} variant="default" color="secondary" phx-click="test">Test (Ctrl+T)</.my_button>
#        <.my_button :if={:off == @state} variant="default" color="secondary" phx-click="calibrate">Calibrate</.my_button>
#        <.my_button :if={:ready == @state} variant="default" color="secondary" phx-click="off"> Off (Ctrl+O)</.my_button>
#        <.my_button :if={:ready == @state} variant="default" color="secondary" phx-click="dose"> Dose (Ctrl+D)</.my_button>
#        <.my_button :if={:dosing == @state} variant="default" color="secondary" phx-click="stop_dosing"> Stop dosingserver (Ctrl+D)</.my_button>
#        
#        
#
#        <p :if={:dosing == @state} style="font-size:5em; ">
#          Dosing: {@dose}
#        <.simple_form for={@form} id="dose_form" phx-change="validate" phx-submit="start_dose">
#          <.input field={@form[:dose]} type="number" label="Dose" />
#          <:actions>
#            <.my_button variant="default" color="success" phx-disable-with="Starter dose...">
#            </.my_button>
#          </:actions>
#        </.simple_form>
#        <.my_button variant="default" color="secondary" phx-click="start">Start</.my_button>
#        <.my_button variant="default" color="danger" phx-click="stop">Stop</.my_button>
#        </p>
#      </div>
#    </div>
#    """
#  end
end