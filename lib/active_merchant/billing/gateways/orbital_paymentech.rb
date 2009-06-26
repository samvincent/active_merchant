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
            
      def authorize(money, creditcard, options = {})
        post = {}
        add_invoice(post, options)
        add_creditcard(post, creditcard)        
        add_address(post, creditcard, options)        
        add_customer_data(post, options)
        
        commit('A', money, post)
      end
      
      def purchase(money, creditcard, options = {})
        post = {}
        add_invoice(post, options)
        add_creditcard(post, creditcard)        
        add_address(post, creditcard, options)   
        add_customer_data(post, options)
             
        commit('AC', money, post)
      end                       
    
      def capture(money, authorization, options = {})
        commit('FC', money, post)
      end
      
      def refund(money, authorization, options ={})
        commit('R', money, post)
      end
    
      private                       
      
      def add_customer_data(post, options)
        
      end

      def add_address(post, creditcard, options)      
        
      end

      def add_invoice(post, options)
        
      end
      
      def add_creditcard(post, creditcard)      
      end
      
      def parse(body)
      end     
      
      def commit(action, money, parameters)
      end

      def message_from(response)
      end
      
      def post_data(action, parameters = {})
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
            xml.tag! :Exp, parameters[:month] + parameters[:year]
            xml.tag! :CurrencyCode, Country.find([parameters[:currency]).code(:numeric).to_s
            xml.tag! :CurrencyExponent, '2'
            xml.tag! :AVSzip, parameters[:zipcode]
            xml.tag! :Comments, parameter[:transaction_id]
            # xml.tag! parameters[:verification_value]
          end
        end
      end
    end
  end
end
