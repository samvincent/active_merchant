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
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @token, @options)
    assert_success response
    assert_equal '10000028;15.00;P', response.authorization
  end

  def test_unsuccessful_request
    @gateway.expects(:ssl_post).returns(unsuccessful_purchase_response)

    assert response = @gateway.purchase(@amount, @token, @options)
    assert_failure response
  end

  private

  def successful_purchase_response
    ""
  end

  def unsuccessful_purchase_response
    ""
  end

end
