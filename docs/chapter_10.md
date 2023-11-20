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