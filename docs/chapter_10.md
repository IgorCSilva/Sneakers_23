# Track Connected Carts with Presence
## Plan Your Admin Dashboard
### Turn Requirements into a Plan

Our admin dashboard needs a higher level of restriction, so we will create a dedicated Socket for it.
The Admin.DashboardController is in charge of authentication and Phoenix.Token creation. The Admin.Socket only allows admins to connect, so we do not need to add topic authorization to the Admin.DashboardChannel.

Each ShoppingCartChannel will track itself in the CartTracker when the Channel connects, and this data will be read by the Admin.DashboardChannel to build the user interface.

### Set Up Your Project
Copy the files.

- sneakers_23_admin_base/assets/css/admin.css
- sneakers_23_admin_base/assets/js/admin/dom.jss
- sneakers_23_admin_base/index.html.eex

## On Track with Phoenix Tracker
Phoenix Tracker solves the problem of tracking processes and metadata about those processes across a cluster of servers.

## Use Tracker in an Application
Go back to the HelloSocket application and start in chapter_10.md file.


## Scaffold the Admin Dashboard

<!-- - in mix.exs:
```elixir

    {:basic_auth, "~> 2.2.2"}
```

Run `mix deps.get`. -->

Add to the end of the config file.
- in config/dev.exs:
```elixir
config :sneakers_23, admin_auth: [
  username: "admin",
  password: "password"
]
```

- in lib/sneakers_23_web/router.ex:
```elixir

  import Plug.BasicAuth

  pipeline :admin do
    plug :basic_auth, Application.compile_env(:sneakers_23, :admin_auth)
    plug :put_layout, {Sneakers23Web.LayoutView, :admin}
  end
  
  scope "/admin", Sneakers23Web.Admin do
    pipe_through [:browser, :admin]
    
    get "/", DashboardController, :index
  end
```

Duplicate the app.html.eex file and rename it to admin.html.eex in lib/sneakers_23_web/templates/layout path.

Delete the block of code that checks if the cart_id is present.
Next, change "app.css" to "admin.css" in admin.html.eex file. Also, change "app.js" to "amdin.js".

Now, create the dashboard controller.

- in lib/sneakers_23_web/controllers/admin/dashboard_controller.ex:
```elixir
defmodule Sneakers23Web.Admin.DashboardController do
  use Sneakers23Web, :controller

  def index(conn, _params) do
    {:ok, products} = Sneakers23.Inventory.get_complete_products()

    conn
    |> assign(:products, products)
    |> assign(:admin_token, sign_admin_token(conn))
    |> render("index.html")
  end

  defp sign_admin_token(conn) do
    Phoenix.Token.sign(conn, "admin socket", "admin")
  end
end

```

- in lib/sneakers_23_web/templates/admin/dashboard/index.html.eex:
```elixir
<div class="admin-container">
  <h1>Admin Dashboard</h1>
</div>

<script type="text/javascript">
  window.adminToken = "<%= @admin_token %>"
</script>
```

- in lib/sneakers_23_web/views/admin/dashboard_view.ex:
```elixir
defmodule Sneakers23Web.Admin.DashboardView do
  use Sneakers23Web, :view
end
```

Start your server with `mix phx.server` and visit `http://localhost:4000/admin`.

Now set socket to use Presence.

- in lib/sneakers_23_web/endpoint.ex:
```elixir
  socket "/admin_socket", Sneakers23Web.Admin.Socket,
    websocket: true,
    longpoll: false
```

- in lib/sneakers_23_web/channels/admin/socket.ex:
```elixir
defmodule Sneakers23Web.Admin.Socket do
  use Phoenix.Socket
  require Logger

  ## Channels.
  channel "admin:cart_tracker", Sneakers23Web.Admin.DashboardChannel

  def connect(%{"token" => token}, socket) do
    case verify(socket, token) do
      {:ok, _} ->
        {:ok, socket}

      {:error, err} ->
        Logger.error("#{__MODULE__} connect error #{inspect(err)}")
        :error
    end
  end

  def connect(_, _) do
    Logger.error("#{__MODULE__} connect error missing params")
    :error
  end

  def id(_socket), do: nil

  @one_day 86400

  defp verify(socket, token) do
    Phoenix.Token.verify(
      socket,
      "admin socket",
      token,
      max_age: @one_day
    )
  end
end
```

- in lib/sneakers_23_web/channels/admin/dashboard_channel.ex:
```elixir
defmodule Sneakers23Web.Admin.DashboardChannel do
  use Phoenix.Channel

  def join("admin:cart_tracker", _payload, socket) do
    {:ok, socket}
  end
end
```

Now, make the following changes in entry, output and plugins fields.
- in assets/webpack.config.js:
```javascript
{
  ...

  entry: {
    './app': glob.sync('./vendor/**/*.js').concat(['./js/app.js']),
    './admin': glob.sync('./vendor/**/*.js').concat(['./js/admin.js'])
  },
  output: {
    filename: '[name].js',
    path: path.resolve(__dirname, '../priv/static/js')
  },
  plugins: [
    new MiniCssExtractPlugin({ filename: '../css/[name].css' }),
    new CopyWebpackPlugin([{ from: 'static/', to: '../' }])
  ]
}
```

- in assets/js/admin.js:
```javascript
import { Presence } from 'phoenix'
import adminCss from '../css/admin.css'
import css from '../css/app.css'
import { adminSocket } from './admin/socket'
import dom from './admin/dom'

adminSocket.connect()

const cartTracker = adminSocket.channel('admin:cart_tracker')
const presence = new Presence(cartTracker)
window.presence = presence

cartTracker.join()
  .receive("error", () => {
    console.error('Channel join failed')
  })
```

- in assets/js/admin/socket.js:
```javascript
import { Socket } from 'phoenix'

export const adminSocket = new Socket('/admin_socket', {
  params: { token: window.adminToken }
})
```

That completes the final step of our scaffolding.
Test starting the server and accessing the dev tools to verify that /admin_socket/websocket is running and that the "admin:cart_tracker" topic has been joined.

`mix phx.server` and access `http://localhost:4000/admin`

## Track Shopping Carts in Real-Time