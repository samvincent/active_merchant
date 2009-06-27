module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class OrbitalSoftDescriptors
      include Validateable
      
      def initialize(options = {})
        @merchant_name = options[:merchant_name]
        @product_description = options[:product_description]
        @merchant_city = options[:merchant_city]
        @merchant_phone = options[:merchant_phone]
        @merchant_url = options[:merchant_url]
        @merchant_email = options[:merchant_email]
      end
      
      def validate
        
      end
      
    end
  end
end
