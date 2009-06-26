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
      
      self.test_url = "orbitalvar1.paymentech.net/authorize"
      # self.test_url_secondary = "orbitalvar2.paymentech.net/authorize"
      
      self.live_url = "orbital1.paymentech.net/authorize"
      # self.live_url_secondary = "orbital2.paymentech.net/authorize"
      
      self.supported_countries = ["US", "CA"]
      self.default_currency = "CA"
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :diners_club, :jcb]
      
      self.display_name = 'Orbital Paymentech'
      self.homepage = 'http://chasepaymentech.com/'
      
      self.money_format = :cents
            
      def initialize(options = {:currency => 'CA', :terminal_id => '001'})
        unless options[:ip_authentication] == true
          requires!(options, :login, :password, :merchant_id)
          @options = options
        end
        super
      end
      
      # Message Type
      # A – Authorization request
      def authorize(money, creditcard, options = {})
        order = build_new_order('A', money) do |xml|
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
        order = build_new_order('AC', money) do |xml|
          add_invoice(xml, options)
          add_creditcard(xml, creditcard)        
          add_address(xml, creditcard, options)   
          add_customer_data(xml, options)
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
        
      end

      def add_address(xml, creditcard, options)      
        xml.tag! :AVSaddress1
        xml.tag! :AVSaddress2
        xml.tag! :AVScity
        xml.tag! :AVSstate
        xml.tag! :AVSzip
        xml.tag! :AVSphoneNum
      end

      def add_invoice(xml, options)
        
      end
      
      def add_creditcard(xml, creditcard)      
        xml.tag! :Exp, creditcard.expiry_date
        xml.tag! :CardSecVal,  creditcard.verification_value if creditcard.requires_verification_value?
        xml.tag! :CurrencyCode, Country.find([parameters[:currency]).code(:numeric).to_s
        xml.tag! :CurrencyExponent, '2' # Will need updating to support currencies such as the Yen.
      end
      
      def parse(body)
      end     
      
      def commit(action, money, parameters)
      end

      def message_from(response)
      end
      
      def build_new_order(action, parameters = {})
        xml = Builder::XmlMarkup.new(:indent => 2)
        xml.instruct!(:xml, :version => '1.1', :encoding => 'utf-8')
        xml.tag! :request do
          xml.tag! :new_order do
            xml.tag! :OrbitalConnectionUsername, paramaters[:login]
            xml.tag! :OrbitalConnectionPassword, paramaters[:password]
            xml.tag! :IndustryType, "EC" # eCommerce transaction 
            xml.tag! :MessageType, action
            xml.tag! :BIN, '000002' # PNS, Salem is '000001'
            xml.tag! :MerchantID, paramaters[:merchant_id]
            xml.tag! :AccountNum, parameters[:number]
            
            yield xml
            
            xml.tag! :Comments, parameters[:comments] if parameters[:comments]
            xml.tag! :OrderID
            
            xml.tag! :Amount
          end
        end
        xml.target!
      end
      
    end
  end
end
