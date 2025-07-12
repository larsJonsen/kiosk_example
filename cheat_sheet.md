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