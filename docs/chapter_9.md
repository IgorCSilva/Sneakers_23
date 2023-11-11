# Build a Real-Time Shopping Cart

## Set Up the Project
Download the base code in https://pragprog.com/titles/sbsockets/real-time-phoenix/.

Copy to this project the following files from the code base downloaded:
from /sneakers_23_cart_base/assets/css/app.css
to /sneakers_23/assets/css/app.css

from /sneakers_23_cart_base/assets/js/cartRenderer.js
to /sneakers_23/assets/js/cartRenderer.js

## Scaffold Your Shopping Cart Channel

### Build a Functional Core
- in lib/sneakers_23/checkout/shopping_cart.ex:
```elixir
defmodule Sneakers23.Checkout.ShoppingCart do
  defstruct items: []

  def new(), do: %__MODULE__{}

  def add_item(cart = %{items: items}, id) when is_integer(id) do
    if id in items do
      {:error, :duplicate_item}
    else
      {:ok, %{cart | items: [id | items]}}
    end
  end

  def remove_item(cart = %{items: items}, id) when is_integer(id) do
    if id in items do
      {:ok, %{cart | items: List.delete(items, id)}}
    else
      {:error, :not_found}
    end
  end

  def item_ids(%{items: items}), do: items

  @base Sneakers23Web.Endpoint
  @salt "shopping cart serialization"
  @max_age 86400 * 7

  def serialize(cart = %__MODULE__{}) do
    {:ok, Phoenix.Token.sign(@base, @salt, cart, max_age: @max_age)}
  end

  def deserialize(serialized) do
    case Phoenix.Token.verify(@base, @salt, serialized, max_age: @max_age) do
      {:ok, data} ->
        items = Map.get(data, :items, [])
        {:ok, %__MODULE__{items: items}}

      e = {:error, _reason} ->
        e
    end
  end
end
```

Now expose the ShoppingCart functions.
- in lib/sneakers_23/checkout.ex:
```elixir
defmodule Sneakers23.Checkout do
  alias __MODULE__.{ShoppingCart}

  defdelegate add_item_to_cart(cart, item), to: ShoppingCart, as: :add_item
  defdelegate cart_item_ids(cart), to: ShoppingCart, as: :item_ids
  defdelegate export_cart(cart), to: ShoppingCart, as: :serialize
  defdelegate remove_item_from_cart(cart, item), to: ShoppingCart, as: :remove_item

  def restore_cart(nil), do: ShoppingCart.new()
  def restore_cart(serialized) do
    case ShoppingCart.deserialize(serialized) do
      {:ok, cart} -> cart
      {:error, _} -> restore_cart(nil)
    end
  end
end
```

We need to generate and store a random identifier in the cookie session.
First we need to generate a cart identifier.
- in lib/sneakers_23/checkout.ex:
```elixir
  @cart_id_length 64
  def generate_cart_id() do
    :crypto.strong_rand_bytes(@cart_id_length)
    |> Base.encode64()
    |> binary_part(0, @cart_id_length)
  end
```

We want our shopping cart to be on every page, including new pages that don't yet exist.
The Plug library allows us to easily create modules that'll execute on all page loads.

- in lib/sneakers_23_web/plugs/cart_id_plug.ex:
```elixir
defmodule Sneakers23Web.CartIdPlug do
  import Plug.Conn

  def init(_), do: []

  def call(conn, _) do
    {:ok, conn, cart_id} = get_cart_id(conn)
    assign(conn, :cart_id, cart_id)
  end

  defp get_cart_id(conn) do
    case get_session(conn, :cart_id) do
      nil ->
        cart_id = Sneakers23.Checkout.generate_cart_id()
        {:ok, put_session(conn, :cart_id, cart_id), cart_id}

      cart_id ->
        {:ok, conn, cart_id}
    end
  end
end
```

It's important to use put_session in order to save the cart ID in the shopper's session. Without this, every refresh would give a new cart ID.

Now add the following JavaScript snnipet.
- in lib/sneakers_23_web/templates/layout/app.html.eex:
```html
  ...
  <body>
    <header>
      <h2>Sneakers23</h2>
    </header>

    <%= render @view_module, @view_template, assigns %>
    
    <%= if assigns[:cart_id] do %>
      <div id="cart-container"></div>
      <script type="text/javascript">
        window.cartId = "<%= @cart_id %>"
      </script>
    <% end %>
    
    <script type="text/javascript" src="<%= Routes.static_path(@conn, "/js/app.js") %>"></script>
  </body>
  ...
```

Add the plug to Router module.
- in lib/sneakers_23_web/router.ex:
```elixir
  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug Sneakers23Web.CartIdPlug
  end
```

Now, start your browser:
`mix phx.server`

and visit `http://localhost:4000`. Open the console tab, type `window.cartId` and press enter. You need to see an id.
If you refresh or open multipe tabs, you will always see the same ID. If you open your browser incognito, you'll see a different ID.

## Build Your Shopping Cart Channel
Channels are just processes. Each ShoppingCartChannel represents one open instance of Sneakers23.

### Create the Channel
- in lib/sneakers_23_web/channels/product_socket.ex:
```elixir
...
  channel "cart:*", Sneakers23Web.ShoppingCartChannel

...
```

- in lib/sneakers_23_web/channels/shopping_cart_channel.ex:
```elixir
defmodule Sneakers23Web.ShoppingCartChannel do
  use Phoenix.Channel

  alias Sneakers23.Checkout

  def join("cart:" <> id, params, socket) when byte_size(id) == 64 do
    cart = get_cart(params)
    socket = assign(socket, :cart, cart)

    {:ok, socket}
  end

  defp get_cart(params) do
    params
    |> Map.get("serialized", nil)
    |> Checkout.restore_cart()
  end
end
```

Now, we need to render the cart to a map that can be sent to the client.
- in lib/sneakers_23_web/views/cart_view.ex:
```elixir
defmodule Sneakers23Web.CartView do

  def cart_to_map(cart) do
    {:ok, serialized} = Sneakers23.Checkout.export_cart(cart)

    {:ok, products} = Sneakers23.Inventory.get_complete_products()
    item_ids = Sneakers23.Checkout.cart_item_ids(cart)
    items = render_items(products, item_ids)

    %{items: items, serialized: serialized}
  end

  defp render_items(_, []), do: []
  defp render_items(products, item_ids) do
    for product <- products,
        item <- product.items,
        item.id in item_ids do
      render_item(product, item)
    end
    |> Enum.sort_by(& &1.id)
  end

  @product_attrs [
    :brand, :color, :name, :price_usd, :main_image_url, :released
  ]

  @item_attrs [:id, :size, :sku]

  defp render_item(product, item) do
    product_attributes = Map.take(product, @product_attrs)
    item_attributes = Map.take(item, @item_attrs)

    product_attributes
    |> Map.merge(item_attributes)
    |> Map.put(:out_of_stock, item.available_count == 0)
  end
end
```

Next, let's change the ShoppingCartChannel to use the cart_to_map/1 function. We'll push the cart to the client when a client joins.
- in lib/sneakers_23_web/channels/shopping_cart_channel.ex:
```elixir
  import Sneakers23Web.CartView, only: [cart_to_map: 1]

  def join("cart:" <> id, params, socket) when byte_size(id) == 64 do
    cart = get_cart(params)
    socket = assign(socket, :cart, cart)
    send(self(), :send_cart)

    {:ok, socket}
  end

  ...

  def handle_info(:send_cart, socket = %{assigns: %{cart: cart}}) do
    push(socket, "cart", cart_to_map(cart))
    {:noreply, socket}
  end
```

Now, connect the front end to the Channel. Replace the code above the function `setupProductChannel` with the code below.
- in assets/js/app.js:
```javascript
import css from "../css/app.css"
import { productSocket } from "./socket"
import dom from "./dom"
import Cart from './cart'

productSocket.connect()

const productIds = dom.getProductIds()

productIds.forEach((id) => setupProductChannel(productSocket, id))

const cartChannel = Cart.setupCartChannel(productSocket, window.cartId, {
  onCartChange: (newCart) => {
    dom.renderCartHtml(newCart)
  }
})
```

Update `dom.js`.
- in assets/js/dom.js:
```javascript
import { getCartHtml } from './cartRenderer'

dom.renderCartHtml = (cart) => {
  const cartContainer = document.getElementById("cart-container")
  cartContainer.innerHTML = getCartHtml(cart)
}
```

- in assets/js/cart.js:
```javascript
const Cart = {}
export default Cart

Cart.setupCartChannel = (socket, cartId, { onCartChange }) => {
  const cartChannel = socket.channel(`cart:${cartId}`, channelParams)
  const onCartChangeFn = (cart) => {
    console.debug("Cart received", cart)
    localStorage.storedCart = cart.serialized
    onCartChange(cart)
  }

  cartChannel.on("cart", onCartChangeFn)
  cartChannel.join().receive("error", () => {
    console.error("Cart join failed")
  })

  return {
    cartChannel,
    onCartChange: onCartChangeFn
  }
}

function channelParams() {
  return {
    serialized: localStorage.storedCart
  }
}
```

Finally, start the server.
`mix phx.server`

visit `http://localhost:4000`.
In console tab, you will see something like this:
`Cart received {items: [], serialized: "AdfowkAsi.eaq...93ks"}`

### Add and Remove Items to Your Cart

Add this function after the call to Cart.setupCartChannel.
- in assets/js/app.js:
```javascript
dom.onItemClick((itemId) => {
  Cart.addCartItem(cartChannel, itemId)
})
```

- in assets/js/dom.js:
```javascript
dom.onItemClick = (fn) => {
  document.addEventListener('click', (event) => {
    if (!event.target.matches('.size-container__entry')) { return }
    event.preventDefault()

    fn(event.target.value)
  })
}
```

- in assets/js/cart.js:
```javascript
Cart.addCartItem = ({ cartChannel, onCartChange }, itemId) => {
  cartRequest(cartChannel, 'add_item', { item_id: itemId }, (resp) => {
    onCartChange(resp)
  })
}

Cart.removeCartItem = ({ cartChannel, onCartChange }, itemId) => {
  cartRequest(cartChannel, 'remove_item', { item_id: itemId }, (resp) => {
    onCartChange(resp)
  })
}

function cartRequest(cartChannel, event, payload, onSuccess) {
  cartChannel.push(event, payload)
    .receive('ok', onSuccess)
    .receive('error', (resp) => console.error('Cart error', event, resp))
    .receive('timeout', () => console.error('Cart timeout', event))
}
```

Now add the event handler in back end.
- in lib/sneakers_23_web/channels/shopping_cart_channel.ex:
```elixir
  def handle_in("add_item", %{"item_id" => id}, socket = %{assigns: %{cart: cart}}) do
    case Checkout.add_item_to_cart(cart, String.to_integer(id)) do
      {:ok, new_cart} ->
        socket = assign(socket, :cart, new_cart)
        {:reply, {:ok, cart_to_map(new_cart)}, socket}

      {:error, :duplicate_item} ->
        {:reply, {:error, %{error: "duplicate_item"}}, socket}

    end
  end
```

Let's try all now.
`mix ecto.reset`
`mix run -e "Sneakers23Mock.Seeds.seed!()"`
`iex -S mix phx.server`
`iex(2)> Enum.each([1, 2], &Sneakers23.Inventory.mark_product_released!/1)`

Open `http://localhost:4000` and the console tab.
Click on one of the available shoe size. You will see a new cart appear with some informations.

Open a second tab and navigate to `http://localhost:4000`. You will see the same. If you add another item, the tabs will be out of sync, but in sync after refresh. Then we need to synchronize clients across multiple instances of the cart.

### Synchronize Multiple Channels Clients

- in lib/sneakers_23_web/channels/shopping_cart_channel.ex:
```elixir
  def handle_in("add_item", %{"item_id" => id}, socket = %{assigns: %{cart: cart}}) do
    case Checkout.add_item_to_cart(cart, String.to_integer(id)) do
      {:ok, new_cart} ->
 > > >  broadcast_cart(new_cart, socket, added: [id])
        socket = assign(socket, :cart, new_cart)
        {:reply, {:ok, cart_to_map(new_cart)}, socket}

      {:error, :duplicate_item} ->
        {:reply, {:error, %{error: "duplicate_item"}}, socket}
    end
  end

  def handle_out("cart_updated", params, socket) do
    cart = get_cart(params)
    socket = assign(socket, :cart, cart)
    push(socket, "cart", cart_to_map(cart))

    {:noreply, socket}
  end

  defp broadcast_cart(cart, socket, opts) do
    {:ok, serialized} = Checkout.export_cart(cart)

    broadcast_from(socket, "cart_updated", %{
      "serialized" => serialized,
      "added" => Keyword.get(opts, :added, []),
      "removed" => Keyword.get(opts, :removed, [])
    })
  end
```

The function broadcast_from/3 differs from the function broadcast/3 because the calling process will not receive the message. Only other processes - other ShoppingCartChannels with the same cart ID - will receive the message. This way, the other processes will save data in their channel's states.

Let's try again:
`mix ecto.reset`
`mix run -e "Sneakers23Mock.Seeds.seed!()"`
`iex -S mix phx.server`
`iex(2)> Enum.each([1, 2], &Sneakers23.Inventory.mark_product_released!/1)`

Open `http://localhost:4000` and the console tab.
Click on one of the available shoe size. You will see a new cart appear with some informations.

Open a second tab and navigate to `http://localhost:4000`. You will see the same. If you add another item, the tabs will be synchronized.

Now, add remove item behaviour.

- in lib/sneakers_23_web/channels/shopping_cart_channel.ex:
```elixir
  def handle_in("remove_item", %{"item_id" => id}, socket = %{assigns: %{cart: cart}}) do
    case Checkout.remove_item_from_cart(cart, String.to_integer(id)) do
      {:ok, new_cart} ->
        broadcast_cart(new_cart, socket, removed: [id])
        socket = assign(socket, :cart, new_cart)
        {:reply, {:ok, cart_to_map(new_cart)}, socket}

      {:error, :not_found} ->
        {:reply, {:error, %{error: "not_found"}}, socket}
    end
  end
```

- in assets/js/app.js:
```javascript
  dom.onItemRemoveClick((itemId) => {
    Cart.removeCartItem(cartChannel, itemId)
  })
```

- in assets/js/dom.js:
```javascript
dom.onItemRemoveClick = (fn) => {
  document.addEventListener('click', (event) => {
    if (!event.target.matches('.cart-item__remove')) { return }
    event.preventDefault()

    fn(event.target.dataset.itemId)
  })
}
```

Now you can test adding and removing items from the cart, even with multiple tabs opened.

## Add Real-Time Out-Of-Stock Alerts

### PubSub in the Shopping Cart Channel
- in lib/sneakers_23_web/channels/shopping_cart_channel.ex:
```elixir

  def join("cart:" <> id, params, socket) when byte_size(id) == 64 do
    cart = get_cart(params)
    socket = assign(socket, :cart, cart)
    send(self(), :send_cart)
>>> enqueue_cart_subscriptions(cart)

    {:ok, socket}
  end

  def handle_in("add_item", %{"item_id" => id}, socket = %{assigns: %{cart: cart}}) do
    case Checkout.add_item_to_cart(cart, String.to_integer(id)) do
      {:ok, new_cart} ->
>>>     send(self(), {:subscribe, id})
        broadcast_cart(new_cart, socket, added: [id])
        socket = assign(socket, :cart, new_cart)
        {:reply, {:ok, cart_to_map(new_cart)}, socket}

      {:error, :duplicate_item} ->
        {:reply, {:error, %{error: "duplicate_item"}}, socket}
    end
  end

  def handle_in("remove_item", %{"item_id" => id}, socket = %{assigns: %{cart: cart}}) do
    case Checkout.remove_item_from_cart(cart, String.to_integer(id)) do
      {:ok, new_cart} ->
>>>     send(self(), {:unsubscribe, id})
        broadcast_cart(new_cart, socket, removed: [id])
        socket = assign(socket, :cart, new_cart)
        {:reply, {:ok, cart_to_map(new_cart)}, socket}

      {:error, :not_found} ->
        {:reply, {:error, %{error: "not_found"}}, socket}
    end
  end

  def handle_out("cart_updated", params, socket) do
>>> modify_subscriptions(params)
    cart = get_cart(params)
    socket = assign(socket, :cart, cart)
    push(socket, "cart", cart_to_map(cart))

    {:noreply, socket}
  end

  defp modify_subscriptions(%{"added" => add, "removed" => remove}) do
    Enum.each(add, & send(self(), {:subscribe, &1}))
    Enum.each(remove, & send(self(), {:unsubscribe, &1}))
  end

  def handle_info({:subscribe, item_id}, socket) do
    Phoenix.PubSub.subscribe(Sneakers23.PubSub, "item_out:#{item_id}")
    {:noreply, socket}
  end

  defp enqueue_cart_subscriptions(cart) do
    cart
    |> Checkout.cart_item_ids()
    |> Enum.each(fn id ->
      send(self(), {:subscribe, id})
    end)
  end

  def handle_info({:item_out, id}, socket = %{assigns: %{cart: cart}}) do
    push(socket, "cart", cart_to_map(cart))
    {:noreply, socket}
  end
```

- in lib/sneakers_23_web.ex:
```elixir
  def notify_local_item_stock_change(%{available_count: 0, id: id}) do
    Sneakers23.PubSub
    |> Phoenix.PubSub.node_name()
    |> Phoenix.PubSub.direct_broadcast(
      Sneakers23.PubSub, "item_out:#{id}", {:item_out, id}
    )
  end

  def notify_local_item_stock_change(_), do: false
```

local_broadcast function works almost this same way, but is more performant.
direct_broadcast sends out a broadcast. The broadcast will only be run on the specified node, which is the same one that called the initial function. If we broadcast the message to al nodes, then we would have a race condition and the CartView could potentiall render an out-of-stock item as available.

Modify the item_sold! function to this.
- in lib/sneakers_23/inventory.ex:
```elixir
  def item_sold!(id), do: item_sold!(id, [])

  def item_sold!(item_id, opts) do
    pid = Keyword.get(opts, :pid, __MODULE__)
    being_replicated? = Keyword.get(opts, :being_replicated?, false)

    avail = Store.fetch_availability_for_item(item_id)
    {:ok, old_inv, inv} = Server.set_item_availability(pid, avail)
    {:ok, item} = CompleteProduct.get_item_by_id(inv, item_id)

    unless being_replicated? do
      Replication.item_sold!(item_id)
      {:ok, old_item} = CompleteProduct.get_item_by_id(old_inv, item_id)

      Sneakers23Web.notify_item_stock_change(previous_item: old_item, current_item: item)
    end
    
    Sneakers23Web.notify_local_item_stock_change(item)

    :ok
  end
```

### Complete the Checkout Process
Copy and paste the following files to this project.
- sneakers_23_cart/lib/sneakers_23_web/controllers/checkout_controller.ex
- sneakers_23_cart/lib/sneakers_23_web/templates/checkout
- sneakers_23_cart/lib/sneakers_23_web/views/checkout_view.ex

Next, add the router entries to you Router module.
- in :
```elixir

  get "/checkout", CheckoutController, :show
  post "/checkout", CheckoutController, :purchase
  get "/checkout/complete", CheckoutController, :success
```

- in lib/sneakers_23/checkout.ex:
```elixir
  def purchase_cart(cart, opts \\ []) do
    Sneakers23.Repo.transaction(fn ->
      Enum.each(cart_item_ids(cart), fn id ->
        case Sneakers23.Checkout.SingleItem.sell_item(id, opts) do
          :ok -> :ok
          
          _ -> Sneakers23.Repo.rollback(:purchase_failed)
            
        end
      end)
      
      :purchase_complete
    end)
  end
```

## Acceptance Test the Shopping Cart

### First Scenario
Let's test now.
```
mix ecto.reset
mix run -e "Sneakers23Mock.Seeds.seed!()"

iex -S mix phx.server

iex(1)> Enum.each([1, 2], &Sneakers23.Inventory.mark_product_released!/1)
```

Now, follow the acceptance test steps from 4 to 12.

### Second Scenario
Now test with multiple servers.
```
mix ecto.reset
mix run -e "Sneakers23Mock.Seeds.seed!()"

iex --name app@127.0.0.1 -S mix phx.server
# Do not run commands from the "app" server.

iex --name backend@127.0.0.1 -S mix
iex(1)> Node.connect(:"app@127.0.0.1")

iex(2)> Enum.each([1, 2], &Sneakers23.Inventory.mark_product_released!/1)

# Follow steps 4-6
iex(3)> Sneakers23Mock.InventoryReducer.sell_random_until_gone!()

# Follow steps 8+
```