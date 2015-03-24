require 'base64'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    # REST API implementation for Beanstream's latest server to server API
    #
    # Initially supporting capture and authorization for processing Legato tokens only
    # as this will be the most popular use of the new REST API for new Beanstream users
    # selecting Legato to limit their PCI compliance scope.
    #
    # http://developer.beanstream.com/documentation/legato/take-payment-legato-token/
    #
    # gateway = ActiveMerchant::Billing::BeanstreamRestGateway.new(
    #   :merchant_id => '100080000',
    #   :passcode    => '6EF5C0Db8E89410E8835433A54f169c2'
    # )
    #
    # options = {
    #   :order_id => '00001',
    #   :billing_address => {
    #     :name => 'Georg Jetson',
    #     :phone => '555-555-5555',
    #     :address1 => '838 W Hastings St',
    #     :address2 => 'Apt 5737',
    #     :city => 'Vancouver',
    #     :state => 'BC',
    #     :country => 'CA',
    #     :zip => 'V6C0A6'
    #   },
    #   :email => 'georg@example.com',
    #   :ip => '127.0.0.1',
    #   :ref1 => 'reference one',
    #   :ref2 => 'reference two'
    # }
    #
    # gateway.purchase(1000, 'token', options)
    #
    class BeanstreamRestGateway < Gateway
      PAYMENT_URL = 'https://www.beanstream.com/api/v1/payments'

      self.default_currency = 'CAD'

      # The countries the gateway supports merchants from as 2 digit ISO country codes
      self.supported_countries = ['CA', 'US']

      # The card types supported by the payment gateway
      # base.supported_cardtypes = [
      #   :visa, :master, :american_express, :discover, :diners_club, :jcb
      # ]

      # The homepage URL of the gateway
      self.homepage_url = 'http://www.beanstream.com/'
      self.live_url = PAYMENT_URL

      # The name of the gateway
      self.display_name = 'Beanstream'

      APPROVED = '1'
      DECLINED = '0'

      def headers
        headers = {}
        headers['Content-Type'] = "application/json"
        headers['Authorization'] = \
          'Passcode ' + Base64.strict_encode64(
            @options[:merchant_id].to_s + ':' + @options[:passcode].to_s
          ).force_encoding("utf-8")

        headers
      end

      def authorize(money, token, options = {})
        post = {}
        add_amount(post, money)
        add_order_number(post, options)
        add_token(post, token, options.merge(capture: false))
        add_customer_ip(post, options)
        add_language_and_comments(post, options)
        add_address(post, options)
        add_references(post, options)
        commit(post)
      end

      def purchase(money, token, options = {})
        post = {}
        add_amount(post, money)
        add_order_number(post, options)
        add_token(post, token, options.merge(capture: true))
        add_customer_ip(post, options)
        add_language_and_comments(post, options)
        add_address(post, options)
        add_references(post, options)
        commit(post)
      end

      def add_amount(post, money)
        post[:amount] = money
      end

      def add_order_number(post, options)
        raise "Unique :order_id required" unless options[:order_id]
        post[:order_number] = options[:order_id]
      end

      def add_address(post, options)
        address = {}
        address[:name]           = options[:billing_address][:name]
        address[:address_line_1] = options[:billing_address][:address1]
        address[:address_line_2] = options[:billing_address][:address2]
        address[:city]           = options[:billing_address][:city]
        address[:province]       = options[:billing_address][:state]
        address[:country]        = options[:billing_address][:country]
        address[:postal_code]    = options[:billing_address][:zip]
        address[:phone_number]   = options[:billing_address][:phone]
        address[:email_address]  = options[:email]

        post[:billing] = address
      end


      def add_token(post, token, options)
        post[:payment_method] = "token"
        post[:token] = {
          complete: options[:capture],
          code: token,
          name: options[:billing_address] ? options[:billing_address][:name] : nil
        }
      end

      def add_references(post, options)
        custom = {}
        custom[:ref1] = options[:ref1] if options[:ref1]
        custom[:ref2] = options[:ref2] if options[:ref2]
        custom[:ref3] = options[:ref3] if options[:ref3]
        custom[:ref4] = options[:ref4] if options[:ref4]
        custom[:ref5] = options[:ref5] if options[:ref5]

        post[:custom] = custom if custom.keys.any?
      end

      def add_language_and_comments(post, options)
        post[:language] = options[:language] || 'en'
        post[:comments] = options[:comments] || '' # Comments are required

        if post[:language].length >= 3
          raise 'Language option must be no more than 3 chars'
        end
      end

      def add_customer_ip(post, options)
        post[:customer_ip] = options[:ip] if options[:ip]
      end

      def success?(response)
        response["approved"] == APPROVED
      end

      def message_from(response)
        response["message"]
      end

      def authorization_from(response)
        response['auth_code']
      end

      def commit(params)
        post(post_data(params))
      end

      def post_data(params)
        params.to_json
      end

      def post(data, use_profile_api=nil)
        response = parse(ssl_post(self.live_url, data, headers))
        build_response(success?(response), message_from(response), response,
          :test => test? || response['auth_code'] == "TEST",
          :authorization => authorization_from(response),
          :cvv_result => (response['card'] && response['card']['cvd_match'] == 1),
          :avs_result => {code: response['card'] && response['card']['address_match'] == 1}
        )
      end

      def build_response(*args)
        Response.new(*args)
      end

      def parse(body)
        JSON.parse(body)
      end

    end
  end
end
