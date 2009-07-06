require "#{File.dirname(__FILE__)}/../../test_helper.rb"

class RemoteOrbitalGatewayTest < Test::Unit::TestCase
  def setup
    Base.mode = :test
    @gateway = OrbitalGateway.new(fixtures(:orbital_gateway))
    
    @amount = 100
    @credit_card = credit_card('4111111111111111')
    @declined_card = credit_card('4000300011112220')
    
    @options = { 
      :order_id => '1',
      :billing_address => address,
    }
  end
  
  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'APPROVED', response.message
  end

  def test_unsuccessful_purchase
    # Amounts of x.01 will fail
    assert response = @gateway.purchase(101, @declined_card, @options)
    assert_failure response
    assert_equal 'AUTH DECLINED                   12001', response.message
  end

  def test_authorize_and_capture
    amount = @amount
    assert auth = @gateway.authorize(amount, @credit_card, @options.merge(:order_id => '2'))
    assert_success auth
    assert_equal 'APPROVED', auth.message
    assert auth.authorization
    assert capture = @gateway.capture(amount, auth.authorization, :order_id => '2')
    assert_success capture
  end
  
  def test_refund
    amount = @amount
    assert response = @gateway.purchase(amount, @credit_card, @options)
    assert_success response
    assert response.authorization
    assert refund = @gateway.refund(amount, response.authorization, @options)
    assert_success refund
  end

  def test_failed_capture
    assert response = @gateway.capture(@amount, '')
    assert_failure response
    assert_equal 'Bad data error', response.message
  end

end
