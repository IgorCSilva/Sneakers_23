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

    test "the update is sent to the client", %{test: test_name} do
      {_, %{p1: p1}} = Test.Factory.InventoryFactory.complete_products()

      # Turn mode shared to enable communication between test and Server processes.
      Ecto.Adapters.SQL.Sandbox.mode(Sneakers23.Repo, {:shared, self()})
      {:ok, pid} = Server.start_link(name: test_name, loader_mod: DatabaseLoader)

      Sneakers23Web.Endpoint.subscribe("product:#{p1.id}")

      Sneakers23.Inventory.mark_product_released!(p1.id, pid: pid)
      assert_received %Phoenix.Socket.Broadcast{event: "released"}
    end
  end

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
end
