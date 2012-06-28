module Atlast
  class Fulfillment
    attr_accessor :key

    def initialize(key, env="not-production")
      @key = key
      if env == "production"
        @root_url = "https://api.atlastfulfillment.com"
      else
        @root_url = "http://staging.api.atlastfulfillment.com"
      end
    end

    def products
      products_xml = RestClient.get(@root_url+"/products.aspx", params: {key: key})
      Crack::XML.parse products_xml
    end

    def product(sku)
    end

    def inventory(sku=nil)
      params = {key: key}
      params[:sku] = sku if sku

      inventory_xml = RestClient.get @root_url + "/inventory.aspx", params: params
      Crack::XML.parse inventory_xml
    end

    def available?(sku)
      inventory(sku)["response"]["products"]["product"]["availableQuantity"].to_i > 0
    end

    def ship(options = {})
      opts = {address: {}, ship_method: "", items: [], order_id: UUID.new.generate}.merge(options)
      builder = Builder::XmlMarkup.new
      builder.instruct! :xml, version: "1.0", encoding: "UTF-8"
      xml = builder.Orders(apiKey: key) do |orders|
        orders.Order(orderID: opts[:order_id]) do |order|
          order.CustomerInfo do |ci|
            ci.FirstName opts[:address][:first_name]
            ci.LastName opts[:address][:last_name]
            ci.Address1 opts[:address][:address]
            ci.Address2 opts[:address][:suite]
            ci.City opts[:address][:city]
            ci.State opts[:address][:state]
            ci.Zip opts[:address][:postal_code]
            ci.Country "USA"
          end
          order.OrderDate Time.now.strftime("%D")
          order.ShipMethod opts[:ship_method]
          if opts[:gift_message].blank?
            order.AddGiftWrap "no"
          else
            order.AddGiftWrap "yes"
            order.GiftMessage opts[:gift_message]
          end
          order.Items do |xml_items|
            opts[:items].each do |item|
              xml_items.Item do |xml_item|
                xml_item.SKU item.sku
                xml_item.Qty item.quantity
              end
            end
          end
        end
      end
      response = RestClient.post(@root_url + "/post_shipments.aspx", xml, content_type: :xml, accept: :xml)
      Crack::XML.parse response
    end

    def cancel(order_id)
      params = {key: key, orderId: order_id}
      response = RestClient.get @root_url + "/cancel_shipment.aspx", params: params
      Crack::XML.parse response
    end

    def shipment_status(order_id)
      params = {key: key, id: order_id}
      response = RestClient.get @root_url + "/shipments.aspx", params: params
      Crack::XML.parse response
    end
  end

end
