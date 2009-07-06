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
      :address => address,
    }
    
    @cards = {
      :visa => "4788250000028291",
      :mc => "5454545454545454",
      :amex => "371449635398431",
      :ds => "6011000995500000",
      :diners => "36438999960016",
      :jcb => "3566002020140006"}
    
    @test_suite = [
      {:card => :visa, :AVSzip => 11111, :CVD =>	111,  :amount => '3000'},
      {:card => :visa, :AVSzip => 33333, :CVD =>	nil,  :amount => '3801'},
      {:card => :mc,	 :AVSzip => 44444, :CVD =>	nil,  :amount => '4100'},
      {:card => :mc,	 :AVSzip => 88888, :CVD =>	666,  :amount => '1102'},
      {:card => :amex, :AVSzip => 55555, :CVD =>	nil,  :amount => '105500'},
      {:card => :amex, :AVSzip => 66666, :CVD =>	2222, :amount =>  '7500'},
      {:card => :ds,	 :AVSzip => 77777, :CVD =>	nil,  :amount => '1000'},
      {:card => :ds, 	 :AVSzip => 88888, :CVD =>	444,  :amount => '6303'},
      {:card => :jcb,  :AVSzip => 33333, :CVD =>	nil,  :amount => '2900'}]
    
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
  
  def test_connection_error_failover
    assert false, "Make sure to write test for this!"
  end

  # == Certification Tests
  
  # ==== Section A
  def test_auth_only_transactions
    for suite in test_suite do
      amount = suite[:amount]
      card = credit_card(@cards[suite[:card]], :verification_value => suite[:CVD])
      options = @options; options[:address].merge!(:zip => suite[:AVSzip])
      assert response = @gateway.authorize(amount, card, options)
      
      # Makes it easier to fill in cert sheet if you print these to the command line
      # puts "Auth/Resp Code => " + (response.params["auth_code"] || response.params["resp_code"])
      # puts "AVS Resp => " + response.params["avs_resp_code"]
      # puts "CVD Resp => " + response.params["cvv2_resp_code"]
      # puts "TxRefNum => " + response.params["tx_ref_num"]
      # puts
    end
  end
    
  # ==== Section B
  def test_auth_capture_transactions
    for suite in @test_suite do
      amount = suite[:amount]
      card = credit_card(@cards[suite[:card]], :verification_value => suite[:CVD])
      options = @options; options[:address].merge!(:zip => suite[:AVSzip])
      assert response = @gateway.purchase(amount, card, options)

      # Makes it easier to fill in cert sheet if you print these to the command line
      puts "Auth/Resp Code => " + (response.params["auth_code"] || response.params["resp_code"])
      puts "AVS Resp => " + response.params["avs_resp_code"]
      puts "CVD Resp => " + response.params["cvv2_resp_code"]
      puts "TxRefNum => " + response.params["tx_ref_num"]
      puts
    end
  end
  
  # ==== Section C
  def test_mark_for_capture_transactions    
    for suite in @test_suite do
      puts @gateway.test?
      amount = suite[:amount]
      card = credit_card(@cards[suite[:card]], :verification_value => suite[:CVD])
      options = @options; options[:address].merge!(:zip => suite[:AVSzip])
      assert auth_response = @gateway.authorize(amount, card, options)
      assert capt_response = @gateway.capture(amount, auth_response.authorization)
      
      # Makes it easier to fill in cert sheet if you print these to the command line
      puts "Proccess Status => " + (capt_response.params["proc_status"] )
      puts "TxRefNum => " + capt_response.params["tx_ref_num"]
      puts
    end
  end
  
end
