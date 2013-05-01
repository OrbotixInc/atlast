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
      t_shirt_skus = ["MTS - 001","MTM - 001","MTL-001","MTXL - 001","MTXXL-001","WTS - 001","WTM - 001","WTL - 001","WTXL - 001","YTS - 001","YTM - 001","YTL - 001","YGS - 001","YGM - 001","YGL - 001","WTXXL - 001"]
      t_shirt_skus = t_shirt_skus.map{|s| s.gsub(/ /,"").upcase}
      opts = {address: {}, ship_method: "", items: [], order_id: UUID.new.generate}.merge(options)
      builder = Builder::XmlMarkup.new
      builder.instruct! :xml, version: "1.0", encoding: "UTF-8"
      destination_country = opts[:address][:country] || "US"
      xml = builder.Orders(apiKey: key) do |orders|
        orders.Order(orderID: opts[:order_id]) do |order|
          order.CustomerInfo do |ci|
            ci.FirstName opts[:address][:first_name]
            ci.LastName opts[:address][:last_name]
            ci.Company opts[:address][:company] || ""
            ci.Address1 opts[:address][:address1]
            ci.Address2 opts[:address][:address2]
            ci.City opts[:address][:city]
            ci.State opts[:address][:state]
            ci.Zip opts[:address][:postal_code]
            ci.Country destination_country
            if destination_country != "US"
              ci.Phone opts[:address][:phone] || ""
            end
          end
          if destination_country != "US"
            order.Customs_ShipmentContents "Electronic Toy"
            declared_value = 0.0
            opts[:items].each do |item|
              clean_sku = item[:sku].gsub(/ /,"").upcase
              if ["S-001","S-002","S-002IN","S-002FC"].member?(clean_sku) || clean_sku.include?("S-002AP")
                declared_value += (60 * item[:quantity])
              elsif t_shirt_skus.member?(clean_sku)
                declared_value += (6.50 * item[:quantity])
              end
            end
            order.Customs_DeclaredValue declared_value
            order.Customs_CountryOfOrigin "China"
          end
          order.OrderDate Time.now.strftime("%D")
          order.ShipMethod opts[:ship_method]
          if opts[:gift_wrap] == "yes" || !opts[:gift_message].blank?
            order.AddGiftWrap "yes"
          else
            order.AddGiftWrap "no"
          end
          if !opts[:gift_message].blank?
            order.GiftMessage opts[:gift_message]
          end
          order.Items do |xml_items|
            opts[:items].each do |item|
              if ["SPHTEE-001S","SPHTEE-001M","SPHTEE-001L","SPHTEE-001XL"].member?(item[:sku])
                xml_items.Item do |xml_item| 
                  size = item[:sku].gsub("SPHTEE-001","")
                  xml_item.SKU "SPTM#{size}-001"
                  xml_item.Qty item[:quantity]
                end                  
              end
              xml_items.Item do |xml_item|
                xml_item.SKU item[:sku]
                xml_item.Qty item[:quantity]
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
