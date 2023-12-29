# Hands-On with Phoenix LiveView
In chapter 7 we did a typical web application by passing HTML fragments from the server to the client, and also by passing JSON data to the client. In both solutions, the front end received the Channel's message and modified the interface based on its content.

LiveView changes this paradgm by defining your application's user interface in Elixir code. The interface is automatically kept up to date by sending content differences from server to client.


## Build a LiveView Product Page

### Set Up Your Project

Add the phonenix_live_view library.

- in mix.exs:
```elixir
    {:phoenix_html, "~> 3.3"},
    {:phoenix_live_view, "~> 0.17.3"}
```

Run `mix deps.get`.

Point the phoenix_live_view dependency to the local dependency version, like so:
- in assets/package.json:
```json
  "dependencies": {
    "phoenix": "file:../deps/phoenix",
    "phoenix_html": "file:../deps/phoenix_html",
    "phoenix_live_view": "file:../deps/phoenix_live_view"
  },
```

Run `cd assets/ && npm install`.

Run `mix phx.gen.secret 32` to generate a salt.

- in config/config.exs:
```elixir
# Configures the endpoint
config :sneakers_23, Sneakers23Web.Endpoint,
  ...
  # run `mix phx.gen.secret 32` to generate a salt.
  live_view: [signing_salt: "/ajDEEbMUBavA2yTmsZe3dE5xVJ6W35J"]
```

Set up endpoint to know live view.

- in lib/sneakers_23_web/endpoint.ex:
```elixir
  socket "/live", Phoenix.LiveView.Socket,
    websocket: true,
    longpoll: false
```

We're ready to use LiveView now.

### Using LiveView
Each LiveView must define a render/1 function, but most will also define a mount/2 function and event handlers.

- in lib/sneakers_23_web/live/product_page_live.ex:
```elixir
defmodule Sneakers23Web.ProductPageLive do
  use Phoenix.LiveView

  alias Sneakers23Web.ProductView

  def render(assigns) do
    Phoenix.View.render(ProductView, "live_index.html", assigns)
  end

  def mount(_params, _session, socket) do
    {:ok, products} = Sneakers23.Inventory.get_complete_products()
    socket = assign(socket, :products, products)

    {:ok, socket}
  end
end
```

This LiveView fethces the complete listing of products, exactly like Sneakers23Web.ProductController does. It assigns the data into socket state, making it usable by the render/1 function.

Copy the existing file to:
- From: lib/sneakers_23_web/templates/product/index.html.eex
- To: lib/sneakers_23_web/templates/product/live_index.html.leex


Subscribe to the topic for each product.

- in lib/sneakers_23_web/live/product_page_live.ex:
```elixir
  def mount(_params, _session, socket) do
    {:ok, products} = Sneakers23.Inventory.get_complete_products()
    socket = assign(socket, :products, products)

    if (connected?(socket)) do
      subscribe_to_products(products)
    end

    {:ok, socket}
  end

  defp subscribe_to_products(products) do
    Enum.each(products, fn %{id: id} ->
      Phoenix.PubSub.subscribe(Sneakers23.PubSub, "product:#{id}")
    end)
  end
```

LiveView first renders the template sever-side. In this case, the web process is going to quickly complete, so we don't want to subscribe to the PubSub topics. We use connected?/1 for code that we want to run only when connected in Socket mode.

- in lib/sneakers_23_web/live/product_page_live.ex:
```elixir
  def handle_info(%{event: "released"}, socket) do
    {:noreply, load_products_from_memory(socket)}
  end
  
  def handle_info(%{event: "stock_change"}, socket) do
    {:noreply, load_products_from_memory(socket)}
  end
  
  defp load_products_from_memory(socket) do
    {:ok, products} = Sneakers23.Inventory.get_complete_products()
    assign(socket, :products, products)
  end
```

We need to expose a route for our LiveView. There are several different ways that we could mount a LiveView. We'll use the Router based approach.

- in lib/sneakers_23_web/router.ex:
```elixir

  import Phoenix.LiveView.Router

  scope "/", Sneakers23Web do
    pipe_through :browser

    ...
    
    live "/drops", ProductPageLive
  end
```

Modify the code above the definition of cartChannel in app.js to look like the following.
- in :
```javascript
productSocket.connect()

if (document.querySelectorAll("[data-phx-main]").length) {
  // connectToLiveView()
} else {
  const productIds = dom.getProductIds()
  productIds.forEach((id) => setupProductChannel(productSocket, id))
}
```

It's important to understand that LiveView separates server rendering from real-time updates.
Let's test.

```
mix ecto.reset
mix run -e "Sneakers23Mock.Seeds.seed!()"

iex -S mix phx.server
```

Next, load `http://localhost:4000/dops`.
Now, release the products.

```
iex(1)> Enum.each([1, 2], &Sneakers23.Inventory.mark_product_released!/1)
```

If you see the page it not has changed.
Let's make it real-time.

- in assets/js/socket.js:
```javascript
import { Socket } from "phoenix"
import { LiveSocket } from "phoenix_live_view"

export const productSocket = new Socket("/product_socket")

export function connectToLiveView() {
  const liveSocket = new LiveSocket("/live", Socket)
  liveSocket.connect()
}
```

Now, uncomment the function call in app.js.
- in assets/js/app.js:
```javascript

import { productSocket, connectToLiveView } from "./socket"

if (document.querySelectorAll("[data-phx-main]").length) {
  connectToLiveView()
} else {
```

Let's test again.

```
mix ecto.reset
mix run -e "Sneakers23Mock.Seeds.seed!()"

iex -S mix phx.server
```

Next, load `http://localhost:4000/dops`.
Now, release the products.

```sh
iex(1)> Enum.each([1, 2], &Sneakers23.Inventory.mark_product_released!/1)
```

***OBS***.: at this point the real-time communication doesn't work. The <!DOCTYPE html> does not appear when inspect the browser page.

```sh
iex(2)> Sneakers23Mock.InventoryReducer.sell_random_until_gone!
```

### Write Tests for a LiveView
- in mix.exs:
```elixir

  {:floki, ">= 0.0.0", only: :test}
```

Run `mix deps.get`

- in test/sneakers_23_web/live/product_page_live_test.exs:
```elixir
defmodule Sneakers23Web.ProductPageLiveTest do
  use Sneakers23Web.ConnCase, async: false
  import Phoenix.LiveViewTest

  alias Sneakers23.Inventory

  setup _ do
    {inventory, _data} = Test.Factory.InventoryFactory.complete_products()
    {:ok, _} = GenServer.call(Inventory, {:test_set_inventory, inventory})

    {:ok, %{inventory: inventory}}
  end

  defp release_all(%{products: products}) do
    products
    |> Map.keys()
    |> Enum.each(& Inventory.mark_product_released!(&1))
  end

  defp sell_all(%{availability: availability}) do
    availability
    |> Map.values()
    |> Enum.each(fn %{item_id: id, available_count: count} ->
      Enum.each((1..count), fn _ ->
        Sneakers23.Checkout.SingleItem.sell_item(id)
      end)
    end)
  end

  test "the disconnected view renders the product HTML", %{conn: conn} do
    html = get(conn, "/drops") |> html_response(200)
    assert html =~ ~s(<main class="product-list">)
    assert html =~ ~s(coming soon...)
  end

  test "the live view connects", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/drops")
    assert html =~ ~s(<main class="product-list">)
    assert html =~ ~s(coming soon...)
  end

  test "product releases are picked up", %{conn: conn, inventory: inventory} do
    {:ok, view, html} = live(conn, "/drops")
    assert html =~ ~s(coming soon...)

    release_all(inventory)
    html = render(view)

    refute html =~ ~s(coming soon...)
    Enum.each(inventory.items, fn {id, _} ->
      assert html =~ ~s(name="item_id" value="#{id}")
    end)
  end

  test "sold out items are picked up", %{conn: conn, inventory: inventory} do
    {:ok, view, html} = live(conn, "/drops")

    release_all(inventory)
    sell_all(inventory)
    html = render(view)

    Enum.each(inventory.items, fn {id, _} ->
      assert html =~ ~s(size-container__entry--level-out" name="item_id" value="#{id}")
    end)
  end
end
```

Run `mix test test/sneakers_23_web/live/product_page_live_test.exs`.

***Obs***.: Is there one test failure.