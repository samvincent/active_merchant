require "#{File.dirname(__FILE__)}/../../test_helper.rb"

class RemoteOrbitalGatewayTest < Test::Unit::TestCase
  def setup
    Base.mode = :test
    @gateway = OrbitalPaymentechGateway.new(fixtures(:orbital_paymentech))
    
    # Makes it easier to fill in cert sheet if you print these to the command line
    # @print_certifcation_helpers = true
    
    @amount = 100
    @credit_card   = credit_card('4111111111111111')
    @declined_card = credit_card('4000300011112220')
    
    @options = { 
      :order_id => '1',
      :address => address}
    
    @cards = {
      :visa   => "4788250000028291",
      :mc     => "5454545454545454",
      :amex   => "371449635398431",
      :ds     => "6011000995500000",
      :diners => "36438999960016",
      :jcb    => "3566002020140006"}
    
    @test_suite = [
      {:card => :visa, :AVSzip => '11111',  :CVD =>	111,  :amount => '3000',  :country => 'US'},
      {:card => :visa, :AVSzip => 'L6L2X9', :CVD =>	nil,  :amount => '3801',  :country => 'CA'},
      {:card => :visa, :AVSzip => '666666', :CVD =>	nil,  :amount => '0',     :country => 'US'},
      {:card => :mc,	 :AVSzip => 'L6L2X9', :CVD =>	nil,  :amount => '4100',  :country => 'CA'},
      {:card => :mc,	 :AVSzip => '88888',  :CVD =>	666,  :amount => '1102',  :country => 'US'},
      {:card => :mc,	 :AVSzip => '88888',  :CVD =>	nil,  :amount => '0',     :country => 'US'},
      {:card => :amex, :AVSzip => 'L6L2X9', :CVD =>	nil,  :amount => '105500',:country => 'CA'},
      {:card => :amex, :AVSzip => '66666',  :CVD =>	2222, :amount =>  '7500', :country => 'US'},
      {:card => :amex, :AVSzip => '22222',  :CVD =>	nil,  :amount =>  '0',    :country => 'US'},
      {:card => :ds,	 :AVSzip => '77777',  :CVD =>	nil,  :amount => '1000',  :country => 'US'},
      {:card => :ds,	 :AVSzip => 'L6L2X9', :CVD =>	444,  :amount => '6303',  :country => 'CA'},
      {:card => :ds, 	 :AVSzip => '11111',  :CVD =>	nil,  :amount => '0',     :country => 'US'},
      {:card => :jcb,  :AVSzip => 33333,    :CVD =>	nil,  :amount => '2900',  :country => 'US'}]
  end
  
  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options.merge(:order_id => rand(999999)))
    assert_success response
    assert_equal 'Approved', response.message
  end

  # Amounts of x.01 will fail
  def test_unsuccessful_purchase
    assert response = @gateway.purchase(101, @declined_card, @options.merge(:order_id => rand(999999)))
    assert_failure response
    assert_equal 'AUTH DECLINED                   12001', response.message
  end

  def test_authorize_and_capture
    order_id = rand(999999)
    amount = @amount
    assert auth = @gateway.authorize(amount, @credit_card, @options.merge(:order_id => order_id))
    assert_success auth
    assert_equal 'Approved', auth.message
    assert auth.authorization
    assert capture = @gateway.capture(amount, auth.authorization, :order_id => order_id)
    assert_success capture
  end
  
  def test_refund
    order_id = rand(999999)
    amount = @amount
    assert response = @gateway.purchase(amount, @credit_card, @options.merge(:order_id => order_id))
    assert_success response
    assert response.authorization
    assert refund = @gateway.refund(amount, response.authorization, @options.merge(:order_id => order_id))
    assert_success refund
  end

  def test_failed_capture
    assert response = @gateway.capture(@amount, '')
    assert_failure response
    assert_equal 'Bad data error', response.message
  end
  
  def test_soft_descriptor_acceptance
    soft_descriptors = OrbitalSoftDescriptors.new(
      :merchant_name       => "Acme Corp.",
      :product_description => "Thing",
      :merchant_phone      => "555-555-5555")
    response = @gateway.purchase(@amount, @credit_card, @options.merge(:soft_descriptors => soft_descriptors))
    assert_success response
  end
  
  def test_connection_error_failover
    begin 
      assert_equal @gateway.primary_test_url, @gateway.send(:remote_url)
      raise ActiveMerchant::ConnectionError
    rescue ActiveMerchant::ConnectionError
      assert_equal @gateway.secondary_test_url, @gateway.send(:remote_url)
    end
  end

  # == Certification Tests
  
  # Print helpers
  def print_avs_cvd_tx_ref(index, response)
    print "#{(index + 1).to_s}  "
    print "Auth/Resp Code: " + (response.params["auth_code"] || response.params["resp_code"]) + " "
    print "AVS Resp: " + response.params["avs_resp_code"] + " "
    print "CVD Resp: " + response.params["cvv2_resp_code"] + " "
    print "TxRefNum: " + response.params["tx_ref_num"]
    puts
  end
  
  # ==== Section A
  def test_auth_only_transactions
    @test_suite.each_with_index do |suite, index|
      amount = suite[:amount]
      card = credit_card(@cards[suite[:card]], :verification_value => suite[:CVD])
      
      options = @options.clone
      options[:address].merge!(:zip => suite[:AVSzip], :country => suite[:country])
      options[:order_id] = rand(999999)
      
      assert response = @gateway.authorize(amount, card, options)
      
      # Makes it easier to fill in cert sheet if you print these to the command line
      if @print_certifcation_helpers
        print_avs_cvd_tx_ref index, response
      end
    end
  end
    
  # ==== Section B
  def test_auth_capture_transactions
    @test_suite.reject {|suite| suite[:amount] == '0'}.each_with_index do |suite, index|
      amount = suite[:amount]
      card = credit_card(@cards[suite[:card]], :verification_value => suite[:CVD])
      
      options = @options.clone
      options[:address].merge!(:zip => suite[:AVSzip], :country => suite[:country])
      options[:order_id] = rand(999999)
      
      assert response = @gateway.purchase(amount, card, options)
      
      # Makes it easier to fill in cert sheet if you print these to the command line
      if @print_certifcation_helpers
        print_avs_cvd_tx_ref index, response
      end
    end
  end
  
  # ==== Section C
  def test_mark_for_capture_transactions    
    [[:mc, '4100'], [:amex, '50000'], [:amex, '7500'], [:ds, '1000'], [:jcb, '2900']].each_with_index do |suite, index|
      options = @options.clone
      options[:order_id] = rand(999999)
      
      amount = suite[1]
      card = credit_card(@cards[suite[0]])
      assert auth_response = @gateway.authorize(amount, card, options)
      assert capt_response = @gateway.capture(amount, auth_response.authorization, :order_id => options[:order_id])
      
      # Makes it easier to fill in cert sheet if you print these to the command line
      if @print_certifcation_helpers
        print "#{(index + 1).to_s}  "
        print "Auth/Resp Code: " + (auth_response.params["auth_code"] || auth_response.params["resp_code"]) + " "
        print "TxRefNum: " + capt_response.params["tx_ref_num"]
        puts
      end
    end
  end
  
  # ==== Section D
  def test_refund_transactions
    [[:visa, '1200'],[:mc, '1100'],[:amex, '105500'],[:ds, '1000'],[:jcb, '2900']].each_with_index do |suite, index|
      amount = suite[1]
      card = credit_card(@cards[suite[0]])
      
      options = @options.clone
      options[:order_id] = rand(999999)
      
      assert purchase_response = @gateway.purchase(amount, card, options)
      assert refund_response = @gateway.refund(amount, purchase_response.authorization, options)
      
      # Makes it easier to fill in cert sheet if you print these to the command line
      if @print_certifcation_helpers
        print "#{(index + 1).to_s}  "
        print "Auth/Resp Code: " + (purchase_response.params["auth_code"] || purchase_response.params["resp_code"]) + " "
        print "TxRefNum: " + refund_response.params["tx_ref_num"]
        puts
      end
    end
  end
  
  # ==== Section F
  def test_void_transactions
    ['3000', '55500', '1000', '7500'].each_with_index do |amount, index|
      options = @options.clone
      options[:order_id] = rand(999999)
      
      assert auth_response = @gateway.authorize(amount, @credit_card, options)
      assert void_response = @gateway.void(amount, auth_response.authorization, options)
      
      # Makes it easier to fill in cert sheet if you print these to the command line
      if @print_certifcation_helpers
        print "#{(index + 1).to_s}  "
        print "TxRefNum => " + void_response.params["tx_ref_num"]
        puts
      end
    end
  end
  
  
  # ==== Section J
  
  # print helpers
  def print_profile_and_eastern_time(title, responses = [])
    puts title
    responses.each_with_index do |response,index|
      print "#{(index + 1).to_s}  "
      print "Customer Profile Number: " + response.params['customer_ref_num'] + "  "
      puts "Time: " + Time.at(Time.now.utc + Time.zone_offset('EDT')).to_s
    end
    puts
  end
  
  # customer_ref_num isn't echoed when used. For the sake of filling out cert sheet, lets pass in the profile responses
  # so we can fill out the cert sheet easily
  def print_profile_and_tx_ref(title, profile_responses, responses = profile_responses)
    puts title
    responses.each_with_index do |response,index|
      print "#{(index + 1).to_s}  "
      print "Customer Profile Number: " + profile_responses[index].params['customer_ref_num'] + "  "
      puts "TxRefNum: " + response.params['tx_ref_num']
    end
    puts
  end
  
  
  def test_customer_profiles
    assert_success @response1 = @gateway.add_customer_profile(credit_card(@cards[:visa]), @options)
    assert_success @response2 = @gateway.add_customer_profile(credit_card(@cards[:mc]), {:address => {:zip => 'V6J1E7'}})
    assert_success @response3 = @gateway.add_customer_profile(credit_card(@cards[:visa]), @options)
    
    # Makes it easier to fill in cert sheet if you print these to the command line
    if @print_certifcation_helpers
      puts "SECTION J"
      print_profile_and_eastern_time "Add- Perform an add profile transaction", [@response1, @response2, @response3]
    end
    
    assert_success @update_response1 = @gateway.update_customer_profile(credit_card(@cards[:amex]), :customer_ref_num => @response1.params['customer_ref_num'])
    assert_success @update_response2 = @gateway.update_customer_profile(nil, :customer_ref_num => @response2.params['customer_ref_num'])
    
    if @print_certifcation_helpers
      print_profile_and_eastern_time "Update the customer profiles you created above", [@update_response1, @update_response2]
    end
    
    assert_success @retrieve_response1 = @gateway.retrieve_customer_profile(@update_response1.params['customer_ref_num'])
    
    if @print_certifcation_helpers
      print_profile_and_eastern_time "Retrieve- Retrieve the first customer profile created.", [@retrieve_response1]
    end
    
    assert_success @auth_response1 = @gateway.authorize(2500, nil, {:order_id => '1001', :customer_ref_num => @retrieve_response1.params['customer_ref_num']}, true)
    assert_success @auth_response2 = @gateway.authorize(3000, nil, {:order_id => '1002', :customer_ref_num => @response2.params['customer_ref_num']}, true)
    
    if @print_certifcation_helpers
      print_profile_and_tx_ref "Authorize using the customer profile from the corresponding number.", [@retrieve_response1, @response2], [@auth_response1, @auth_response2]
    end
    
    assert_success @auth_capture_response1 = @gateway.purchase(4500, nil, {:order_id => '1003', :customer_ref_num => @response1.params['customer_ref_num']}, true)
    assert_success @auth_capture_response2 = @gateway.purchase(5000, nil, {:order_id => '1004', :customer_ref_num => @response1.params['customer_ref_num']}, true)
    
    if @print_certifcation_helpers
      print_profile_and_tx_ref "Auth Capture- perform an auth capture utilizing the previously created profile.", [@response1, @response2], [@auth_capture_response1, @auth_capture_response2]
    end
    
    assert_success @refund_response1 = @gateway.refund(1000, nil, {:order_id => '1003', :customer_ref_num => @response1.params['customer_ref_num']}, true)
    assert_success @refund_response2 = @gateway.refund(1500, nil, {:order_id => '1004', :customer_ref_num => @response2.params['customer_ref_num']}, true)
    
    if @print_certifcation_helpers
      print_profile_and_tx_ref "Refund- Perform a refund transaction utilizing the previously created profile.", [@response1, @response2], [@refund_response1, @refund_response2]
    end

    assert_success @auth_add_response1 = @gateway.authorize(6500, credit_card(@cards[:amex]), @options.merge(:order_id => '1005'))
    assert_success @auth_add_response2 = @gateway.authorize(7000, credit_card(@cards[:mc]), {:order_id => '1006', :address => {:zip => 'V6J1E7', :phone => '555 123 1234'}})

    if @print_certifcation_helpers
      print_profile_and_tx_ref "Add Profile during authorization – Create a new profile during an authorization", [@auth_add_response1, @auth_add_response2]
    end
    
    assert_success @capture_add_response1 = @gateway.purchase(3000, credit_card(@cards[:amex]), @options.merge(:order_id => '1007'))
    assert_success @capture_add_response2 = @gateway.purchase(5000, credit_card(@cards[:mc]), @options.merge(:order_id => '1008', :address => address.reject {|k,v| k == :phone}))
    
    if @print_certifcation_helpers
      print_profile_and_tx_ref "Add Profile during auth/capture– Create a new profile during an auth capture.", [@capture_add_response1, @capture_add_response2]
    end
    
    assert_success @delete_response1 = @gateway.delete_customer_profile(@capture_add_response1.params['customer_ref_num'])
    assert_success @delete_response2 = @gateway.delete_customer_profile(@capture_add_response2.params['customer_ref_num'])
    
    if @print_certifcation_helpers
      print_profile_and_eastern_time "Delete Profile - Delete the Profiles created in the auth or auth capture above.", [@delete_response1, @delete_response2]
    end
    
    assert_failure @error_response = @gateway.authorize(1000, nil, {:order_id => '1234', :customer_ref_num => '45461SAAX'}, true)
    
    if @print_certifcation_helpers
      puts "Response: " + @error_response.params['proc_status']
      # puts "TxRefNum: " + @error_response.params['tx_ref_num']
    end
  end
  
end
