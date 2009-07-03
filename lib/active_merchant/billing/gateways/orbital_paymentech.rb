require File.dirname(__FILE__) + '/orbital_paymentech/orbital_soft_descriptors.rb'
require "rexml/document"

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    # For more information on Orbital, visit the {integration center}[http://download.chasepaymentech.com]
    #     
    # ==== Authentication Options
    # 
    # The Orbital Gateway supports two methods of authenticating incoming requests:
    # Source IP authentication and Connection Username/Password authentication
    # 
    # In addition, these IP addresses/Connection Usernames must be affiliated with the Merchant IDs 
    # for which the client should be submitting transactions.
    # 
    # This does allow Third Party Hosting service organizations presenting on behalf of other 
    # merchants to submit transactions.  However, each time a new customer is added, the 
    # merchant or Third-Party hosting organization needs to ensure that the new Merchant IDs 
    # or Chain IDs are affiliated with the hosting companies IPs or Connection Usernames.
    # 
    # If the merchant expects to have more than one merchant account with the Orbital 
    # Gateway, it should have its IP addresses/Connection Usernames affiliated at the Chain 
    # level hierarchy within the Orbital Gateway.  Each time a new merchant ID is added, as
    # long as it is placed within the same Chain, it will simply work.  Otherwise, the additional 
    # MIDs will need to be affiliated with the merchant IPs or Connection Usernames respectively.
    # For example, we generally affiliate all Salem accounts [BIN 000001] with 
    # their Company Number [formerly called MA #] number so all MIDs or Divisions under that 
    # Company will automatically be affiliated.
    
    class OrbitalGateway < Gateway
      API_VERSION = "4.6"
      
      POST_HEADERS = {
        "MIME-Version" => "1.0",
        "Content-Type" => "Application/PTI46",
        "Content-transfer-encoding" => "text",
        "Request-number" => '1',
        "Document-type" => "Request",
        "Interface-Version" => "Ruby|ActiveMerchant|Proprietary Gateway"
      }
      
      APPROVED = '00'
      
      class_inheritable_accessor :primary_test_url, :secondary_test_url, :primary_live_url, :secondary_live_url
      
      self.primary_test_url = "https://orbitalvar1.paymentech.net/authorize"
      self.secondary_test_url = "https://orbitalvar2.paymentech.net/authorize"
      
      self.primary_live_url = "orbital1.paymentech.net/authorize"
      self.secondary_live_url = "orbital2.paymentech.net/authorize"
      
      self.supported_countries = ["US", "CA"]
      self.default_currency = "CA"
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :diners_club, :jcb]
      
      self.display_name = 'Orbital Paymentech'
      self.homepage_url = 'http://chasepaymentech.com/'
      
      self.money_format = :cents
            
      def initialize(options = {})
        unless options[:ip_authentication] == true
          requires!(options, :login, :password, :merchant_id)
          @options = options
        end
        super
      end
      
      # Message Type
      # A – Authorization request
      def authorize(money, creditcard, options = {})
        order = build_new_order_xml('A', money) do |xml|
          add_invoice(xml, options)
          add_creditcard(xml, creditcard)        
          add_address(xml, creditcard, options)   
          add_customer_data(xml, options)
        end
        commit(order)
      end
      
      # Message Type
      # AC – Authorization and Mark for Capture
      def purchase(money, creditcard, options = {})
        order = build_new_order_xml('AC', money, options) do |xml|
          add_invoice(xml, options)
          add_creditcard(xml, creditcard, options[:currency])        
          add_address(xml, creditcard, options)   
          # add_customer_data(xml, options)
        end
        commit(order)
      end                       
      
      
      # Message Type
      # FC – Force-Capture request
      def capture(money, authorization, options = {})
        commit('FC', money, post)
      end
      
      # Message Type
      # R – Refund request
      def refund(money, authorization, options ={})
        commit('R', money, post)
      end
    
      private                       
            
      def add_customer_data(xml, options)
        if options[:customer_ref_num]
          xml.tag! :CustomerProfileFromOrderInd, 'S'
          xml.tag! :CustomerRefNum, options[:customer_ref_num]
        else
          xml.tag! :CustomerProfileFromOrderInd, 'A'
        end
      end
      
      def add_soft_descriptors(xml, soft_desc)
        xml.tag! :SDMerchantName, soft_desc.merchant_name
        xml.tag! :SDProductDescription, soft_desc.product_description
        xml.tag! :SDMerchantCity, soft_desc.merchant_city
        xml.tag! :SDMerchantPhone, soft_desc.merchant_phone
        xml.tag! :SDMerchantURL, soft_desc.merchant_url
        xml.tag! :SDMerchantEmail, soft_desc.merchant_email
        
      end

      def add_address(xml, creditcard, options)      
        if address = options[:billing_address] || options[:address]
          xml.tag! :AVSzip, address[:zip]
          xml.tag! :AVSaddress1, address[:address1]
          xml.tag! :AVSaddress2, address[:address2]
          xml.tag! :AVScity, address[:city]
          xml.tag! :AVSstate, address[:state]
          xml.tag! :AVSphoneNum, address[:phone]
          xml.tag! :AVSname, creditcard.name
          xml.tag! :AVScountryCode, address[:country]
        end
      end

      def add_invoice(xml, options)
        
      end
      
      def add_creditcard(xml, creditcard, currency = nil)      
        xml.tag! :AccountNum, creditcard.number
        xml.tag! :Exp, creditcard.expiry_date.expiration.strftime("%m%y")
        
        currency = Country.find(currency || self.default_currency).code(:numeric).to_s
        xml.tag! :CurrencyCode, currency
        xml.tag! :CurrencyExponent, '2' # Will need updating to support currencies such as the Yen.
        
        xml.tag! :CardSecVal,  creditcard.verification_value if creditcard.verification_value?
      end
      
      def parse(body)
        response = {}
        xml = REXML::Document.new(body)
        root = REXML::XPath.first(xml, "//Response") ||
               REXML::XPath.first(xml, "//ErrorResponse")
        if root
          root.elements.to_a.each do |node|
            recurring_parse_element(response, node)
          end
        end
        response
      end     
      
      def recurring_parse_element(response, node)
        if node.has_elements?
          node.elements.each{|e| recurring_parse_element(response, e) }
        else
          response[node.name.underscore.to_sym] = node.text
        end
      end
      
      def commit(order)
        response = parse(ssl_post(self.primary_test_url, order, POST_HEADERS.merge("Content-length" => order.size.to_s)))
        Response.new(
          success?(response),
          message_from(response),
          response
        )
      end

      def success?(response)
        response[:resp_code] == APPROVED
      end
      
      def message_from(response)
        response[:resp_msg]
      end
      
      def build_new_order_xml(action, money, parameters = {})
        xml = Builder::XmlMarkup.new(:indent => 2)
        xml.instruct!(:xml, :version => '1.0', :encoding => 'UTF-8')
        xml.tag! :Request do
          xml.tag! :NewOrder do
            xml.tag! :OrbitalConnectionUsername, @options[:login]
            xml.tag! :OrbitalConnectionPassword, @options[:password]
            xml.tag! :IndustryType, "EC" # E-Commerce transaction 
            xml.tag! :MessageType, action
            xml.tag! :BIN, '000002' # PNS Tampa
            xml.tag! :MerchantID, @options[:merchant_id]
            xml.tag! :TerminalID, parameters[:terminal_id] || '001'
            xml.tag! :CardBrand, ""
            
            yield xml
            
            xml.tag! :Comments, parameters[:comments] if parameters[:comments]
            xml.tag! :OrderID, parameters[:order_id]
            xml.tag! :Amount, money
          end
        end
        xml.target!
      end
      
    end
  end
end
