class RemoteBeanstreamRestTest < Test::Unit::TestCase

  def setup
    @gateway = BeanstreamRestGateway.new(fixtures(:beanstream_rest))

    # Beanstream test cards. Cards require a CVV of 123, which is the default of the credit card helper
    @visa                = credit_card('4030000010001234')
    @declined_visa       = credit_card('4003050500040005')

    @mastercard          = credit_card('5100000010001004')
    @declined_mastercard = credit_card('5100000020002000')

    @amex                = credit_card('371100001000131', {:verification_value => 1234})
    @declined_amex       = credit_card('342400001000180')

    @amount = 15

    @options = {
      :order_id => generate_unique_id[0,30], # 30 char limit
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
      :ref1 => 'reference one'
    }
  end

  def test_successful_visa_purchase
    response = @gateway.purchase(@amount, generate_single_use_token(@visa), @options)
    assert response = @gateway.purchase(@amount, 'token', @options)
    assert_success response
    assert_false response.authorization.blank?
    assert_equal "Approved", response.message
  end

  def test_unsuccessful_visa_purchase
    assert response = @gateway.purchase(@amount, @declined_visa, @options)
    assert_failure response
    assert_equal 'DECLINE', response.message
  end

  def test_successful_mastercard_purchase
    assert response = @gateway.purchase(@amount, @mastercard, @options)
    assert_success response
    assert_false response.authorization.blank?
    assert_equal "Approved", response.message
  end

  def test_unsuccessful_mastercard_purchase
    assert response = @gateway.purchase(@amount, @declined_mastercard, @options)
    assert_failure response
    assert_equal 'DECLINE', response.message
  end

  def test_successful_amex_purchase
    assert response = @gateway.purchase(@amount, @amex, @options)
    assert_success response
    assert_false response.authorization.blank?
    assert_equal "Approved", response.message
  end

  def test_unsuccessful_amex_purchase
    assert response = @gateway.purchase(@amount, @declined_amex, @options)
    assert_failure response
    assert_equal 'DECLINE', response.message
  end

  def test_authorize_and_capture
    assert auth = @gateway.authorize(@amount, @visa, @options)
    assert_success auth
    assert_equal "Approved", auth.message
    assert_false auth.authorization.blank?

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
    assert_false capture.authorization.blank?
  end

  def test_failed_capture
    assert response = @gateway.capture(@amount, '')
    assert_failure response
    assert_no_match %r{You are not authorized}, response.message, "You need to enable username/password validation"
    assert_match %r{Missing or invalid adjustment id.}, response.message
  end

  private

  def generate_single_use_token(credit_card)
    uri = URI.parse('https://www.beanstream.com/scripts/tokenization/tokens')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE

    request = Net::HTTP::Post.new(uri.path)
    request.content_type = "application/json"
    request.body = {
      "number"       => credit_card.number,
      "expiry_month" => "01",
      "expiry_year"  => (Time.now.year + 1) % 100,
      "cvd"          => credit_card.verification_value,
    }.to_json

    response = http.request(request)
    JSON.parse(response.body)["token"]
  end
end
