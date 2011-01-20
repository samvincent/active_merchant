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
    
    class OrbitalPaymentechGateway < Gateway
      API_VERSION = "4.9"
      
      POST_HEADERS = {
        "MIME-Version" => "1.0",
        "Content-Type" => "Application/PTI46",
        "Content-transfer-encoding" => "text",
        "Request-number" => '1',
        "Document-type" => "Request",
        "Interface-Version" => "Ruby|ActiveMerchant|Proprietary Gateway"
      }
      
      SUCCESS, APPROVED = '0', '00'
      
      class_inheritable_accessor :primary_test_url, :secondary_test_url, :primary_live_url, :secondary_live_url, :customer_profiles
      
      self.primary_test_url = "https://orbitalvar1.paymentech.net/authorize"
      self.secondary_test_url = "https://orbitalvar2.paymentech.net/authorize"
      
      self.primary_live_url = "https://orbital1.paymentech.net/authorize"
      self.secondary_live_url = "https://orbital2.paymentech.net/authorize"
      
      # Orbital offers storing Customer Profiles which can later be used to
      # process transactions using the :customer_ref_num.
      #
      # By default authorizations and purchases will create a customer profile.
      # If your Chase MID doesn't support this feature, you can set customer_profiles to false
      self.customer_profiles = true
      
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
      
      # A – Authorization request
      #
      # note: To use an existing customer profile
      #  @gateway.authorize(100, nil, {:order_id => '1', :customer_ref_num => '1000'}, true)
      #
      def authorize(money, creditcard, options = {}, profile_txn = false)
        order = build_new_order_xml('A', money, options) do |xml|
          add_creditcard(xml, creditcard, options[:currency]) unless creditcard.nil? and profile_txn
          add_address(xml, creditcard, options)
          add_customer_data(xml, options, profile_txn) if self.customer_profiles
        end
        commit(order)
      end
      
      # AC – Authorization and Capture
      #
      # note: To use an existing customer profile, see authorize notes.
      #
      def purchase(money, creditcard, options = {}, profile_txn = false)
        order = build_new_order_xml('AC', money, options) do |xml|
          add_creditcard(xml, creditcard, options[:currency]) unless creditcard.nil? and profile_txn
          add_address(xml, creditcard, options)   
          add_customer_data(xml, options, profile_txn) if self.customer_profiles
        end
        commit(order)
      end                       
      
      # MFC - Mark For Capture
      def capture(money, authorization, options = {})
        commit(build_mark_for_capture_xml(money, authorization, options))
      end
      
      # R – Refund request
      #
      # note: currently supporting refunds via :tx_ref_num (authorization)
      # and with profile transactions.
      #
      def refund(money, authorization, options = {}, profile_txn = false)
        options.merge!(:authorization => authorization) if authorization
        order = build_new_order_xml('R', money, options) do |xml|
          add_refund(xml, options[:currency])
          if self.customer_profiles and profile_txn
            xml.tag! :CustomerRefNum, options[:customer_ref_num] 
          end
        end
        commit(order)
      end
      
      # setting money to nil will perform a full void
      def void(money, authorization, options = {})
        order = build_void_request_xml(money, authorization, options)
        commit(order)
      end
      
      # ==== Customer Profiles
      # :customer_ref_num should be set unless your happy with Orbital providing one
      #
      # :customer_profile_order_override_ind can be set to map
      # the CustomerRefNum to OrderID or Comments. Defaults to 'NO' - no mapping
      #
      #   'NO' - No mapping to order data
      #   'OI' - Use <CustomerRefNum> for <OrderID> 
      #   'OD' - Use <CustomerRefNum> for <Comments>
      #   'OA' - Use <CustomerRefNum> for <OrderID> and <Comments>
      # 
      # :order_default_description can be set optionally. 64 char max.
      #
      # :order_default_amount can be set optionally. integer as cents.
      #
      # :status defaults to Active
      #
      #   'A' - Active
      #   'I' - Inactive
      #   'MS'	- Manual Suspend
      
      def add_customer_profile(creditcard, options = {})
        options.merge!(:customer_profile_action => 'C')
        order = build_customer_request_xml(creditcard, options)
        commit(order)
      end
      
      def update_customer_profile(creditcard, options = {})
        options.merge!(:customer_profile_action => 'U')
        order = build_customer_request_xml(creditcard, options)
        commit(order)
      end
      
      def retrieve_customer_profile(customer_ref_num)
        options = {:customer_profile_action => 'R', :customer_ref_num => customer_ref_num}
        order = build_customer_request_xml(nil, options)
        commit(order)
      end
      
      def delete_customer_profile(customer_ref_num)
        options = {:customer_profile_action => 'D', :customer_ref_num => customer_ref_num}
        order = build_customer_request_xml(nil, options)
        commit(order)
      end
      
      private                       
            
      def add_customer_data(xml, options, profile_txn = false)
        if profile_txn
          xml.tag! :CustomerRefNum, options[:customer_ref_num]
        else
          if options[:customer_ref_num]
            xml.tag! :CustomerProfileFromOrderInd, 'S'
            xml.tag! :CustomerRefNum, options[:customer_ref_num]
          else
            xml.tag! :CustomerProfileFromOrderInd, 'A'
          end
          xml.tag! :CustomerProfileOrderOverrideInd, options[:customer_profile_order_override_ind] || 'NO'
        end
      end
      
      def add_soft_descriptors(xml, soft_desc)
        xml.tag! :SDMerchantName, soft_desc.merchant_name
        xml.tag! :SDProductDescription, soft_desc.product_description
        # Never send more than one of the following
        xml.tag!(:SDMerchantCity, soft_desc.merchant_city)   ||
        xml.tag!(:SDMerchantPhone, soft_desc.merchant_phone) ||
        xml.tag!(:SDMerchantURL, soft_desc.merchant_url)     ||
        xml.tag!(:SDMerchantEmail, soft_desc.merchant_email)
      end

      def add_address(xml, creditcard, options)
        if address = options[:billing_address] || options[:address]
          xml.tag! :AVSzip, address[:zip]
          xml.tag! :AVSaddress1, address[:address1]
          xml.tag! :AVSaddress2, address[:address2]
          xml.tag! :AVScity, address[:city]
          xml.tag! :AVSstate, address[:state]
          xml.tag! :AVSphoneNum, address[:phone] ? address[:phone].scan(/\d/).to_s : nil
          xml.tag! :AVSname, creditcard.name
          xml.tag! :AVScountryCode, address[:country]
        end
      end
      
      # For Profile requests
      def add_customer_address(xml, options)
        if address = options[:billing_address] || options[:address]
          xml.tag! :CustomerAddress1, address[:address1]
          xml.tag! :CustomerAddress2, address[:address2]
          xml.tag! :CustomerCity, address[:city]
          xml.tag! :CustomerState, address[:state]
          xml.tag! :CustomerZIP, address[:zip]
          xml.tag! :CustomerPhone, address[:phone] ? address[:phone].scan(/\d/).to_s : nil
          xml.tag! :CustomerCountryCode, address[:country]
        end
      end

      # <CardSecValInd> - If you are trying to collect a Card Verification Number (CardSecVal) 
      # for a Visa or Discover transaction, pass one of these values:
      #
      # 1 - Value is Present
      # 2 - Value on card but illegible
      # 9 - Cardholder states data not available
      # Only supports 1 (yes) or 9 (n/a) right now
      def add_creditcard(xml, creditcard, currency=nil)      
        xml.tag! :AccountNum, creditcard.number
        xml.tag! :Exp, creditcard.expiry_date.expiration.strftime("%m%y")
        
        currency = Country.find(currency || self.default_currency).code(:numeric).to_s
        xml.tag! :CurrencyCode, currency
        xml.tag! :CurrencyExponent, '2' # Will need updating to support currencies such as the Yen.
        
        if %w(visa discover).include? CreditCard.type?(creditcard.number)
          xml.tag! :CardSecValInd, creditcard.verification_value? ? '1' : '9'
        end
        xml.tag! :CardSecVal,  creditcard.verification_value if creditcard.verification_value?
      end
      
      def add_refund(xml, currency=nil)
        xml.tag! :AccountNum, nil
        
        currency = Country.find(currency || self.default_currency).code(:numeric).to_s
        xml.tag! :CurrencyCode, currency
        xml.tag! :CurrencyExponent, '2' # Will need updating to support currencies such as the Yen.
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
        headers = POST_HEADERS.merge("Content-length" => order.size.to_s)
        request = lambda {return parse(ssl_post(remote_url, order, headers))}
        
        # Failover URL will be used in the event of a connection error
        begin response = request.call; rescue ConnectionError; retry end
                
        # We add the order xml to the response for communication logging purposes 
        Response.class_eval { attr_accessor :order }
        Response.new(success?(response), message_from(response), response,
          {:authorization => response[:tx_ref_num],
           :test => self.test?,
           :avs_result => {:code => response[:avs_resp_code]},
           :cvv_result => response[:cvv2_resp_code]
          }
        ).tap { |response| response.order = order }
      end
      
      def remote_url
        unless $!.class == ActiveMerchant::ConnectionError
          self.test? ? self.primary_test_url : self.primary_live_url
        else
          self.test? ? self.secondary_test_url : self.secondary_live_url
        end
      end

      def success?(response)
        if response[:message_type] == "R"
          response[:proc_status] == SUCCESS
        elsif response[:customer_profile_action]
          response[:profile_proc_status] == SUCCESS
        else
          response[:proc_status] == SUCCESS &&
          response[:resp_code] == APPROVED 
        end
      end
      
      def message_from(response)
        response[:resp_msg] || response[:status_msg] || response[:customer_profile_message]
      end
      
      def ip_authentication?
        @options[:ip_authentication] == true
      end
      
      def build_new_order_xml(action, money, parameters = {})
        xml = Builder::XmlMarkup.new(:indent => 2)
        xml.instruct!(:xml, :version => '1.0', :encoding => 'UTF-8')
        xml.tag! :Request do
          xml.tag! :NewOrder do
            xml.tag! :OrbitalConnectionUsername, @options[:login] unless ip_authentication?
            xml.tag! :OrbitalConnectionPassword, @options[:password] unless ip_authentication?
            xml.tag! :IndustryType, "EC" # E-Commerce transaction 
            xml.tag! :MessageType, action
            xml.tag! :BIN, '000002' # PNS Tampa
            xml.tag! :MerchantID, @options[:merchant_id]
            xml.tag! :TerminalID, parameters[:terminal_id] || '001'            
            
            yield xml if block_given?
            
            xml.tag! :Comments, parameters[:comments] if parameters[:comments]
            xml.tag! :OrderID, parameters[:order_id]
            xml.tag! :Amount, money
            
            set_recurring_ind(xml, parameters)
            
            # Append Transaction Reference Number at the end for Refund transactions
            xml.tag! :TxRefNum, parameters[:authorization] if (parameters[:authorization] and action == "R")
            
            # Set Soft Descriptors at the end
            if parameters[:soft_descriptors].is_a?(OrbitalSoftDescriptors)
              add_soft_descriptors(xml, parameters[:soft_descriptors]) 
            end
          end
        end
        xml.target!
      end
      
      # For Canadian transactions on PNS Tampa on New Order
      # RF - First Recurring Transaction
      # RS - Subsequent Recurring Transactions
      def set_recurring_ind(xml, parameters)
        if parameters[:recurring_ind]
          raise "RecurringInd must be set to either \"RF\" or \"RS\"" unless %w(RF RS).include?(parameters[:recurring_ind])
          xml.tag! :RecurringInd, parameters[:recurring_ind] 
        end
      end
      
      def build_mark_for_capture_xml(money, authorization, parameters = {})
        xml = Builder::XmlMarkup.new(:indent => 2)
        xml.instruct!(:xml, :version => '1.0', :encoding => 'UTF-8')
        xml.tag! :Request do
          xml.tag! :MarkForCapture do
            xml.tag! :OrbitalConnectionUsername, @options[:login] unless ip_authentication?
            xml.tag! :OrbitalConnectionPassword, @options[:password] unless ip_authentication?
            xml.tag! :OrderID, parameters[:order_id]
            xml.tag! :Amount, money
            xml.tag! :BIN, '000002' # PNS Tampa
            xml.tag! :MerchantID, @options[:merchant_id]
            xml.tag! :TerminalID, parameters[:terminal_id] || '001'
            xml.tag! :TxRefNum, authorization
          end
        end
        xml.target!
      end
      
      def build_void_request_xml(money, authorization, parameters = {})
        xml = Builder::XmlMarkup.new(:indent => 2)
        xml.instruct!(:xml, :version => '1.0', :encoding => 'UTF-8')
        xml.tag! :Request do
          xml.tag! :Reversal do
            xml.tag! :OrbitalConnectionUsername, @options[:login] unless ip_authentication?
            xml.tag! :OrbitalConnectionPassword, @options[:password] unless ip_authentication?
            xml.tag! :TxRefNum, authorization
            xml.tag! :TxRefIdx, parameters[:transaction_index]
            xml.tag! :AdjustedAmt, money
            xml.tag! :OrderID, parameters[:order_id]
            xml.tag! :BIN, '000002' # PNS Tampa
            xml.tag! :MerchantID, @options[:merchant_id]
            xml.tag! :TerminalID, parameters[:terminal_id] || '001'
          end
        end
        xml.target!
      end
      
      def build_customer_request_xml(creditcard, options = {})
        xml = Builder::XmlMarkup.new(:indent => 2)
        xml.instruct!(:xml, :version => '1.0', :encoding => 'UTF-8')
        xml.tag! :Request do
          xml.tag! :Profile do
            xml.tag! :OrbitalConnectionUsername, @options[:login] unless ip_authentication?
            xml.tag! :OrbitalConnectionPassword, @options[:password] unless ip_authentication?
            xml.tag! :CustomerBin, '000002' # PNS Tampa
            xml.tag! :CustomerMerchantID, @options[:merchant_id]
            xml.tag! :CustomerName, creditcard.name if creditcard
            xml.tag! :CustomerRefNum, options[:customer_ref_num] if options[:customer_ref_num]
            
            add_customer_address(xml, options)
            
            xml.tag! :CustomerProfileAction, options[:customer_profile_action] # C, R, U, D
            xml.tag! :CustomerProfileOrderOverrideInd, options[:customer_profile_order_override_ind] || 'NO'
            
            if options[:customer_profile_action] == 'C'
              xml.tag! :CustomerProfileFromOrderInd, options[:customer_ref_num] ? 'S' : 'A'
            end
            
            xml.tag! :OrderDefaultDescription, options[:order_default_description][0..63] if options[:order_default_description]
            xml.tag! :OrderDefaultAmount, options[:order_default_amount] if options[:order_default_amount]
            
            if ['C', 'U'].include? options[:customer_profile_action]
              xml.tag! :CustomerAccountType, 'CC' # Only credit card supported
              xml.tag! :Status, options[:status] || 'A' # Active
            end
            
            xml.tag! :CCAccountNum, creditcard.number if creditcard
            xml.tag! :CCExpireDate, creditcard.expiry_date.expiration.strftime("%m%y") if creditcard
          end
        end
        xml.target!
      end
      
    end
  end
end
