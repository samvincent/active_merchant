require 'test_helper'

# REST API test for use with Legato tokens
class BeanstreamRestTest < Test::Unit::TestCase
  def setup
    Base.mode = :test

    @gateway = BeanstreamRestGateway.new(
                 :merchant_id => 'merchant id',
                 :passcode => 'passcode'
               )

    @token = 'PAYMENTt0keN'

    @amount = 1000

    @options = {
      :order_id => generate_unique_id,
      :billing_address => {
        :name => 'Georg Jetson',
        :phone => '555-555-5555',
        :address1 => '838 W Hastings St',
        :address2 => 'Apt 5737',
        :city => 'Vancouver',
        :state => 'BC',
        :country => 'CA',
        :zip => 'V6C0A6'
      },
      :email => 'georg@example.com',
      :ip => '127.0.0.1',
      :ref1 => 'reference one',
      :ref2 => 'reference two'
    }
  end

  def test_successful_purchase
    @gateway.expects(:raw_ssl_request).returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @token, @options)
    assert_success response
    assert_equal 'TEST', response.authorization
  end

  def test_unsuccessful_request
    @gateway.expects(:raw_ssl_request).returns(unsuccessful_purchase_response)

    assert response = @gateway.purchase(@amount, @token, @options)
    assert_failure response
  end

  private

  def successful_purchase_response
    OpenStruct.new body: %[{"id":"10000000","approved":"1","message_id":"1","message":"Approved","auth_code":"TEST","created":"2015-03-30T13:25:23","order_number":"c4ca5d458310cab35cc354fd98e52c","type":"P","payment_method":"CC","card":{"card_type":"AM","last_four":"0131","cvd_match":0,"address_match":0,"postal_result":0},"links":[{"rel":"void","href":"https://www.beanstream.com/api/v1/payments/10000000/void","method":"POST"},{"rel":"return","href":"https://www.beanstream.com/api/v1/payments/10000000/returns","method":"POST"}]}]
  end

  def unsuccessful_purchase_response
    OpenStruct.new body: %[{"code":7,"category":1,"message":"DECLINE","reference":null}]
  end

end
