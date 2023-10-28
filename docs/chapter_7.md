# Build a Real-Time Sneader Store

## Set Up the Project

Obs.: I changed the .tool-versions file to have the local elixir and erlang versions. Here, I put:

elixir 1.14.0
erlang 25.0

Updating to theses versions, we need to update some parts of code.

- in `config/config.exs`:
remove: `pubsub: [name: Sneakers23.PubSub, adapter: Phoenix.PubSub.PG2]`
add: `pubsub_server: Sneakers23.PubSub`

- in `lib/sneakers_23/application.ex`:
add to the children list: `{Phoenix.PubSub, name: Sneakers23.PubSub},`

- in `test/support/conn_case.ex`:
remove: `use Phoenix.ConnTest`
add:
  `import Plug.Conn`
  `import Phoenix.ConnTest`

- in `test/support/channel_case.ex`:
remove: `use Phoenix.ChannelTest`
add:
  `import Phoenix.ChannelTest`
  `import Sneakers23Web.ChannelCase`

- in `mix.exs`:
remove:
  `{:phoenix, "~> 1.4.7"},`
  `{:phoenix_pubsub, "~> 1.1"},`
add:
  `{:phoenix, "~> 1.5.0"},`
  `{:phoenix_pubsub, "~> 2.0"},`

remove: `compilers: [:phoenix, :gettext] ++ Mix.compilers(),`
add: `compilers: [:phoenix] ++ Mix.compilers(),`

To use the database without install it, we need to create a docker-compose file with the following code, and put the file in the root path.

Create file `docker-compose.yaml` and add the code below:
```docker-compose
version: '3.5'
services:

  db:
    image: postgres
    container_name: sneakers_23_store_database
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: sneakers_23_dev
    restart: always
    ports:
    - '5432:5432'
    # volumes:
    #   - pgdata:/var/lib/postgresql/data

volumes:
  pgdata:
```

Now run the docker-compose file with the command: `docker-compose up`.
With the database up we can follow the commands below.

Open another terminal and run:
(maybe it command is necessary) `mix deps.update --all`
`mix deps.get`
`mix ecto.setup`
`mix test`

Here, all tests must be green.

If you try run the project with node version 17 or later, you will find this error:
`error:0308010C:digital envelope routines::unsupported`

One solution is downgrade node version to 16, then downgrade if it is necessary.

Run the commands below to update and install libraries:
`npm --prefix assets update`
`npm --prefix assets install`

Use the following commands to seed the database and then start the server.

`mix ecto.reset`
`mix run -e "Sneakers23Mock.Seeds.seed!()"`
`iex -S mix phx.server`

Now, visit `http://localhost:4000` and you will see a "coming soon..." page. This changes when you release one of the products using a helper function, as below.
In terminal, run:
`iex(2)> Sneakers23.Inventory.mark_product_released!(1)`

When you refresh the page, you will see that the size selector is available.
Finally, you can ensure that the front end updates as shoes are sold.

Run:
`iex(3)> Sneakers23Mock.InventoryReducer.sell_random_until_gone!(500)`

You must see the final message: Elixir.Sneakers23Mock.InventoryReducer sold out!

As you refresh, the size selector on the front end will change colors and then become disabled once the InventoryReducer finishes.

## Data structures
Inventory:
```elixir
%Sneakers23.Inventory.Inventory{
  items: %{
    200 => %Sneakers23.Inventory.Item{
      __meta__: #Ecto.Schema.Metadata<:loaded, "items">,
      id: 200,
      size: "10",
      sku: "i1",
      product_id: 137,
      product: #Ecto.Association.NotLoaded<association :product is not loaded>,
      inserted_at: ~N[2023-10-24 11:47:54],
      updated_at: ~N[2023-10-24 11:47:54]
    },
    201 => %Sneakers23.Inventory.Item{
      __meta__: #Ecto.Schema.Metadata<:loaded, "items">,
      id: 201,
      size: "10",
      sku: "i2",
      product_id: 137,
      product: #Ecto.Association.NotLoaded<association :product is not loaded>,
      inserted_at: ~N[2023-10-24 11:47:54],
      updated_at: ~N[2023-10-24 11:47:54]
    },
    202 => %Sneakers23.Inventory.Item{
      __meta__: #Ecto.Schema.Metadata<:loaded, "items">,
      id: 202,
      size: "10",
      sku: "i3",
      product_id: 138,
      product: #Ecto.Association.NotLoaded<association :product is not loaded>,
      inserted_at: ~N[2023-10-24 11:47:54],
      updated_at: ~N[2023-10-24 11:47:54]
    }
  },
  products: %{
    137 => %Sneakers23.Inventory.Product{
      __meta__: #Ecto.Schema.Metadata<:loaded, "products">,
      id: 137,
      brand: "brand",
      color: "color",
      main_image_url: "url",
      name: "name",
      order: 1,
      price_usd: 100,
      released: false,
      sku: "p1",
      inserted_at: ~N[2023-10-24 11:47:54],
      updated_at: ~N[2023-10-24 11:47:54]
    },
    138 => %Sneakers23.Inventory.Product{
      __meta__: #Ecto.Schema.Metadata<:loaded, "products">,
      id: 138,
      brand: "brand",
      color: "color",
      main_image_url: "url",
      name: "name",
      order: 0,
      price_usd: 100,
      released: false,
      sku: "p2",
      inserted_at: ~N[2023-10-24 11:47:54],
      updated_at: ~N[2023-10-24 11:47:54]
    }
  },
  availability: %{
    198 => %Sneakers23.Inventory.ItemAvailability{
      __meta__: #Ecto.Schema.Metadata<:loaded, "item_availabilities">,
      id: 198,
      available_count: 1,
      item_id: 200,
      item: #Ecto.Association.NotLoaded<association :item is not loaded>,
      inserted_at: ~N[2023-10-24 11:47:54],
      updated_at: ~N[2023-10-24 11:47:54]
    },
    199 => %Sneakers23.Inventory.ItemAvailability{
      __meta__: #Ecto.Schema.Metadata<:loaded, "item_availabilities">,
      id: 199,
      available_count: 2,
      item_id: 201,
      item: #Ecto.Association.NotLoaded<association :item is not loaded>,
      inserted_at: ~N[2023-10-24 11:47:54],
      updated_at: ~N[2023-10-24 11:47:54]
    },
    200 => %Sneakers23.Inventory.ItemAvailability{
      __meta__: #Ecto.Schema.Metadata<:loaded, "item_availabilities">,
      id: 200,
      available_count: 3,
      item_id: 202,
      item: #Ecto.Association.NotLoaded<association :item is not loaded>,
      inserted_at: ~N[2023-10-24 11:47:54],
      updated_at: ~N[2023-10-24 11:47:54]
    }
  }
}
```

Product:
```elixir
%{
  __meta__: #Ecto.Schema.Metadata<:loaded, "products">,
  __struct__: Sneakers23.Inventory.Product,
  brand: "brand",
  color: "color",
  id: 139,
  inserted_at: ~N[2023-10-24 11:52:29],
  items: [
    %{
      __meta__: #Ecto.Schema.Metadata<:loaded, "items">,
      __struct__: Sneakers23.Inventory.Item,
      available_count: 1,
      id: 203,
      inserted_at: ~N[2023-10-24 11:52:29],
      product: #Ecto.Association.NotLoaded<association :product is not loaded>,
      product_id: 139,
      size: "10",
      sku: "i1",
      updated_at: ~N[2023-10-24 11:52:29]
    },
    %{
      __meta__: #Ecto.Schema.Metadata<:loaded, "items">,
      __struct__: Sneakers23.Inventory.Item,
      available_count: 2,
      id: 204,
      inserted_at: ~N[2023-10-24 11:52:29],
      product: #Ecto.Association.NotLoaded<association :product is not loaded>,
      product_id: 139,
      size: "10",
      sku: "i2",
      updated_at: ~N[2023-10-24 11:52:29]
    }
  ],
  main_image_url: "url",
  name: "name",
  order: 1,
  price_usd: 100,
  released: false,
  sku: "p1",
  updated_at: ~N[2023-10-24 11:52:29]
}
```
## Render Real-Time HTML with Channels
We'll levarage a Channel to send data from the server to a client.
Let's start by updating our Endpoint with a new Socket.
- in lib/sneakers_23_web/endpoint.ex, remove the existing socket definition and add the code below:
```elixir
  socket "/product_socket", Sneakers23Web.ProductSocket,
    websocket: true,
    longpoll: false
```

Remove the file generated by Phoenix `lib/sneakers_23_web/channels/user_socket.ex`.

Now, define ProductSocket.
- in lib/sneakers_23_web/channels/product_socket.ex:
```elixir
defmodule Sneakers23Web.ProductSocket do
  use Phoenix.Socket

  ## Channels
  channel "product:*", Sneakers23Web.ProductChannel

  def connect(_params, socket, _connect_info) do
    {:ok, socket}
  end

  def id(_socket) do
    nil
  end
end
```

After that, create the ProductChannel.
- in lib/sneakers_23_web/channels/product_channel.ex:
```elixir
defmodule Sneakers23Web.ProductChannel do
  use Phoenix.Channel

  alias Sneakers23Web.{Endpoint, ProductView}

  def join("product:" <> _sku, %{}, socket) do
    {:ok, socket}
  end

  ## Defining a broadcast function to render our size selector HTML for a given product.
  def notify_product_released(product = %{id: id}) do
    size_html = Phoenix.View.render_to_string(
      ProductView,
      "_sizes.html",
      product: product
    )

    ## size_html
    # "<form class=\"size-container\" action=\"/cart/add\" method=\"POST\">\n\n    <button\n      type=\"submit\"\n      class=\"size-container__entry\n             size-container__entry--level-low\"\n      name=\"item_id\"\n      value=\"206\"\n\n    >\n10\n    </button>\n\n    <button\n      type=\"submit\"\n      class=\"size-container__entry\n             size-container__entry--level-low\"\n      name=\"item_id\"\n      value=\"207\"\n\n    >\n10\n    </button>\n\n</form>\n"

    Endpoint.broadcast!("product:#{id}", "released", %{
      size_html: size_html
    })
  end
end
```

Write tests:
- in test/sneakers_23_web/channels/product_channel_test.exs:
```elixir
defmodule Sneakers23Web.ProductChannelTest do
  use Sneakers23Web.ChannelCase, async: true
  alias Sneakers23Web.{Endpoint, ProductChannel}
  alias Sneakers23.Inventory.{CompleteProduct, Server, DatabaseLoader}

  describe "notify_product_released/1" do
    test "the size selector for the product is broadcast" do
      {inventory, _data} = Test.Factory.InventoryFactory.complete_products()
      [_, product] = CompleteProduct.get_complete_products(inventory)

      topic = "product:#{product.id}"
      Endpoint.subscribe(topic)
      ProductChannel.notify_product_released(product)

      assert_broadcast "released", %{size_html: html}
      assert html =~ "size-container__entry"
      Enum.each(product.items, fn item ->
        assert html =~ ~s(value="#{item.id}")
      end)
    end
  end
end
```

We'll use our Sneakers23Web module as our web context and will define a function that delegates to the ProductChannel.
- in lib/sneakers_23_web.ex:
```elixir
defdelegate notify_product_released(product), to: Sneakers23Web.ProductChannel
```

Add the following test at the end of the existing describe block:
```elixir
    test "the update is sent to the client", %{test: test_name} do
      {_, %{p1: p1}} = Test.Factory.InventoryFactory.complete_products()

      # Turn mode shared to enable communication between test and Server processes.
      Ecto.Adapters.SQL.Sandbox.mode(Sneakers23.Repo, {:shared, self()})
      {:ok, pid} = Server.start_link(name: test_name, loader_mod: DatabaseLoader)
      
      Sneakers23Web.Endpoint.subscribe("product:#{p1.id}")

      Sneakers23.Inventory.mark_product_released!(p1.id, pid: pid)
      assert_received %Phoenix.Socket.Broadcast{event: "released"}
    end
```

Now, make Inventory.mark_product_released!/2 call notify_product_released/1 to make test pass.
- in lib/sneakers_23/inventory.ex:
```elixir
  def mark_product_released!(id), do: mark_product_released!(id, [])

  def mark_product_released!(product_id, opts) do
    pid = Keyword.get(opts, :pid, __MODULE__)

    %{id: id} = Store.mark_product_released!(product_id)
    {:ok, inventory} = Server.mark_product_released!(pid, id)
    {:ok, product} = CompleteProduct.get_product_by_id(inventory, id)
    Sneakers23Web.notify_product_released(product)

    :ok
  end
```

All of the tests will now pass. The Inventory context provides a function that marks the product as released in the database, changes it locally in the Inventory.Server process, then pushes the new state to any connected clients.

With the back end configured, let's connect our front end by using the Phoenix Channel JavaScript client.

- in assets/js/app.js:
```javascript
import css from "../css/app.css"
import { productSocket } from "./socket"
import dom from "./dom"

const productIds = dom.getProductIds()

if (productIds.length > 0) {
  productSocket.connect()
  productIds.forEach((id) => setupProductChannel(productSocket, id))
}

function setupProductChannel(socket, productId) {
  const productChannel = socket.channel(`product:${productId}`)
  productChannel.join()
    .receive("error", () => {
      console.error("Channel join failed")
    })
}
```

- in assets/js/socket.js:
```javascript
import { Socket } from "phoenix"

export const productSocket = new Socket("/product_socket")
```

- in assets/js/dom.js:
```javascript
const dom = {}

function getProductIds() {
  const products = document.querySelectorAll('.product-listing')
  return Array.from(products).map((el) => el.dataset.productId)
}

dom.getProductIds = getProductIds

export default dom
```

At this point, everything is complete for our Socket to connect. Try it out by starting `mix phx.server` and visiting `http://localhost:4000`.
Obs.: Remember always up the database container with command `docker-compose up` and use the correct node version.

For my machine:
`docker-compose up`
`nvm use v16.0.0 && mix phx.server`

After access the web page, you should see a Socket request in the "Network" tab as well as Channel join messages for product:1 and product:2 in server terminal.
Stop the server and restart it with this command:
`iex -S mix phx.server`

Then trigger the release message.
```
iex(1)> {:ok, products} = Sneakers23.Inventory.get_complete_products()
iex(2)> List.last(products) |> Sneakers23Web.notify_product_released()
```

You can run this as many times as you want because it doesn't modify data for now. Try to watch the network message tab (product_socket connection, not live_reload) while you execute it. You should see the "released" message come through with an HTML payload.

Make front end listen for this event in order to display the HTML.
- in assets/js/app.js:
```javascript
function setupProductChannel(socket, productId) {
  const productChannel = socket.channel(`product:${productId}`)
  productChannel.join()
    .receive("error", () => {
      console.error("Channel join failed")
    })

  productChannel.on('released', ({ size_html }) => {
    dom.replaceProductComingSoon(productId, size_html)
  })
}
```

- in assets/js/dom.js:
```javascript
...

function replaceProductComingSoon(productId, sizeHtml) {
  const name = `.product-soon-${productId}`
  const productSoonEls = document.querySelectorAll(name)

  productSoonEls.forEach((el) => {
    const fragment = document.createRange().createContextualFragment(sizeHtml)
    el.replaceWith(fragment)
  })
}

dom.replaceProductComingSoon = replaceProductComingSoon

...
```

Now trigger notify_product_released/1 in the console when you have the page loaded:
```
mix ecto.reset
mix run -e "Sneakers23Mock.Seeds.seed!()"

iex -S mix phx.server

iex(2)> Sneakers23.Inventory.mark_product_released!(1)
iex(3)> Sneakers23.Inventory.mark_product_released!(2)
```

You will see the size components appear without page refresh.

## Update a Client with Real-Time Data
Let's add the stock level change function to the ProductChannel module.

- in lib/sneakers_23_web/channels/product_channel.ex:
```elixir
  def notify_item_stock_change(
    previous_item: %{available_count: old},
    current_item: %{available_count: new, id: id, product_id: p_id}
  ) do
    case {
      ProductView.availability_to_level(old),
      ProductView.availability_to_level(new)
    } do
      {same, same} when same != "out" ->
        {:ok, :no_change}
        
      {_, new_level} ->
        Endpoint.broadcast!("product:#{p_id}", "stock_change", %{
          product_id: p_id,
          item_id: id,
          level: new_level
        })
        
        {:ok, :broadcast}
    end
  end
```

Then, write a test.
- in test/sneakers_23_web/channels/product_channel_test.exs:
```elixir
  describe "notify_item_stock_change/1" do
    setup _ do
      {inventory, _data} =
        Test.Factory.InventoryFactory.complete_products()

      [product = %{items: [item]}, _] =
        CompleteProduct.get_complete_products(inventory)

      topic = "product:#{product.id}"
      Endpoint.subscribe(topic)

      {:ok, %{product: product, item: item}}
    end

    test "the ame stock level doesn't broadcast an event", %{item: item} do
      opts = [previous_item: item, current_item: item]
      assert ProductChannel.notify_item_stock_change(opts) == {:ok, :no_change}

      refute_broadcast "stock_change", _
    end

    test "a stock level change broadcasts an event", %{item: item, product: product} do
      new_item = Map.put(item, :available_count, 0)
      opts = [previous_item: item, current_item: new_item]
      assert ProductChannel.notify_item_stock_change(opts) == {:ok, :broadcast}

      payload = %{item_id: item.id, product_id: product.id, level: "out"}
      assert_broadcast "stock_change", ^payload

    end
  end
```

Run the tests and all will pass.

- in lib/sneakers_23_web.ex:
```elixir

  defdelegate notify_item_stock_change(opts), to: Sneakers23Web.ProductChannel
```

Now, the client needs to listen for the event stock_change.
- in assets/js/app.js, at the bottom of setupProductChannel/1:
```javascript
  ...

  productChannel.on('stock_change', ({product_id, item_id, level}) => {
    dom.updateItemLevel(item_id, level)
  })
  ...
```

Change component's classes by level.
- in assets/js/dom.js:
```javascript
function updateItemLevel(itemId, level) {
  Array.from(document.querySelectorAll('.size-container__entry'))
    .filter((el) => el.value == itemId)
    .forEach((el) => {
      removeStockLevelClasses(el)
      el.classList.add(`size-container__entry--level-${level}`)
      el.disabled = level === "out"
    })
}

dom.updateItemLevel = updateItemLevel

function removeStockLevelClasses(el) {
  Array.from(el.classList)
    .filter((s) => s.startsWith('size-container__entry--level-'))
    .forEach((name) => el.classList.remove(name))
}
```

Let's test it now, marking the first six items as out-of-stock.
Run: `iex -S mix phx.server` (`nvm use v16.0.0 && iex -S mix phx.server`)
```
iex(1)> {:ok, products} = Sneakers23.Inventory.get_complete_products()
iex(2)> %{items: items} = List.first(products)
iex(3)> items |> Enum.take(6) |> Enum.each(fn item ->
          out_item = Map.put(item, :available_count, 0)
          opts = [previous_item: item, current_item: out_item]
          Sneakers23Web.notify_item_stock_change(opts)
        end)
```

Update the item_sold! function to use the notify_item_stock_change function.
- in :
```elixir
  def item_sold!(id), do: item_sold!(id, [])

  def item_sold!(item_id, opts) do
    pid = Keyword.get(opts, :pid, __MODULE__)

    avail = Store.fetch_availability_for_item(item_id)
    {:ok, old_inv, inv} = Server.set_item_availability(pid, avail)
    {:ok, old_item} = CompleteProduct.get_item_by_id(old_inv, item_id)
    {:ok, item} = CompleteProduct.get_item_by_id(inv, item_id)

    Sneakers23Web.notify_item_stock_change(previous_item: old_item, current_item: item)

    :ok
  end
```

Test now:
```
mix ecto.reset
mix run -e "Sneakers23Mock.Seeds.seed!()"
iex -S mix phx.server
iex(1)> Sneakers23.Inventory.mark_product_released!(1)
iex(2)> Sneakers23.Inventory.mark_product_released!(2)
iex(3)> Sneakers23Mock.InventoryReducer.sell_random_until_gone!()
```

You will see the items on the page start to disappear.

## Run Multiple Servers

We have a problem.
Run:
```
mix ecto.reset
mix run -e "Sneakers23Mock.Seeds.seed!()"
iex --name app@127.0.0.1 -S mix phx.server
```

Open `http://localhost:4000`.

In another shell, run:
```
iex --name back@127.0.0.1 -S mix
iex(1)> Node.connect(:"app@127.0.0.1")
iex(2)> Sneakers23.Inventory.mark_product_released!(1)
```

Everything looks good. But when you refresh the page, you back to a "comming soon" state. This is because there are two different Inventory.Server processes running, and only the "back" node received the update. The real-time message was broadcast because of Phoenix, but the underlying data was not updated in the Inventory.Server process. We can solve this problem by adding replication.

### Add Replication of Inventory Events
Phoenix PubSub can be used for more than Channel messages. At its core, it lets any process subscribe to a particular event type. You'll need to spin up a new GenServer to handle the events, as well as a context to dispatch the events.

It's possible for nodes to become out of sync from this replicated approach. For non-critical data, the benefits of scalability are often worth the trade-off of potential data incorrectness. In Sneakers23, we never use the replicated data as a source of truth for important operations, such as the purchase process. Instead, we use the database to ensure that these operations are consistent.

We'll first write the Genserver and then work our way up through the various layers.
- in lib/sneakers_23/replication/server.ex:
```elixir
defmodule Sneakers23.Replication.Server do
  use GenServer

  alias Sneakers23.Inventory

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    Phoenix.PubSub.subscribe(Sneakers23.PubSub, "inventory_replication")
    {:ok, nil}
  end

  def handle_info({:mark_product_released!, product_id}, state) do
    Inventory.mark_product_released!(product_id, being_replicated?: true)
    {:noreply, state}
  end

  def handle_info({:item_sold!, id}, state) do
    Inventory.item_sold!(id, being_replicated?: true)
    {:noreply, state}
  end
end
```

Our process subcribes to the "inventory_replication" event. Any message that is sent to this topic will be received by the process as messages.

Now, define the Replication context.
- in lib/sneakers_23/replication.ex:
```elixir
defmodule Sneakers23.Replication do
  alias __MODULE__.{Server}

  defdelegate child_spec(opts), to: Server

  def mark_product_released!(product_id) do
    broadcast!({:mark_product_released!, product_id})
  end

  def item_sold!(item_id) do
    broadcast!({:item_sold!, item_id})
  end

  defp broadcast!(data) do
    # Send message to all processes except the local process. In this case, only
    # remote nodes will receive replication events.
    Phoenix.PubSub.broadcast_from!(
      Sneakers23.PubSub,
      server_pid(),
      "inventory_replication",
      data
    )
  end

  defp server_pid() do
    Process.whereis(Server)
  end
end
```

Let's add this new GenServer to our Application module.
- in lib/sneakers_23/application.ex:
```elixir
    children = [
      {Phoenix.PubSub, name: Sneakers23.PubSub},
      Sneakers23.Repo,
      Sneakers23Web.Endpoint,
      Sneakers23.Inventory,
      Sneakers23.Replication
    ]
```

Now, we need to put them to use in the Inventory context functions.
- in lib/sneakers_23/inventory.ex:
```elixir

  alias Sneakers23.Replication

  def mark_product_released!(id), do: mark_product_released!(id, [])

  def mark_product_released!(product_id, opts) do
    pid = Keyword.get(opts, :pid, __MODULE__)
    being_replicated? = Keyword.get(opts, :being_replicated?, false)

    %{id: id} = Store.mark_product_released!(product_id)
    {:ok, inventory} = Server.mark_product_released!(pid, id)
    
    unless being_replicated? do
      Replication.mark_product_released!(product_id)
      {:ok, product} = CompleteProduct.get_product_by_id(inventory, id)
      Sneakers23Web.notify_product_released(product)
    end

    :ok
  end

  def item_sold!(id), do: item_sold!(id, [])

  def item_sold!(item_id, opts) do
    pid = Keyword.get(opts, :pid, __MODULE__)
    being_replicated? = Keyword.get(opts, :being_replicated?, false)

    avail = Store.fetch_availability_for_item(item_id)
    {:ok, old_inv, inv} = Server.set_item_availability(pid, avail)
    
    unless being_replicated? do
      Replication.item_sold!(item_id)
      {:ok, old_item} = CompleteProduct.get_item_by_id(old_inv, item_id)
      {:ok, item} = CompleteProduct.get_item_by_id(inv, item_id)
      
      Sneakers23Web.notify_item_stock_change(previous_item: old_item, current_item: item)
    end

    :ok
  end
```

At this moment, we have a completely connected replicated system.
We can replicate the previous test that not worked to see if it is all right now.

Run:
```
mix ecto.reset
mix run -e "Sneakers23Mock.Seeds.seed!()"
iex --name app@127.0.0.1 -S mix phx.server
```

Open `http://localhost:4000` and see the modifications after each command.

In another shell, run:
```
iex --name back@127.0.0.1 -S mix
iex(1)> Node.connect(:"app@127.0.0.1")
iex(2)> Sneakers23.Inventory.mark_product_released!(1)
iex(3)> Sneakers23.Inventory.mark_product_released!(2)
iex(4)> Sneakers23Mock.InventoryReducer.sell_random_until_gone!()
```

After refresh page, all needs to be equal before refresh.