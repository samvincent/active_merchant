require 'test/helper'

class OrbitalGatewayTest < Test::Unit::TestCase
  def setup
    @gateway = OrbitalGateway.new(
      :login => 'login',
      :password => 'password'
    )
  end  
  
  def test_successful_authorization
    @gateway.expects(:ssl_post).returns(successful_authorization_response)
    
    assert response = @gateway.authorize('', credit_card)
    assert_instance_of Response, response
    assert_success response
    assert_equal '00', response.authorization
  end
  
  def test_authorization_responses
    auth_responses.each do |expectation|
      assert response = @gateway.authorize(expectation[:amount], credit_card)
      assert_equal expectation[:auth_response], response.code
      assert_equal expectation[:response], response.message
    end
  end
  
  def test_unauthenticated_response
  end
  
  private
  
  # Place raw successful response from gateway here
  def successful_purchase_response
  end
  
  # Place raw failed response from gateway here
  def failed_purcahse_response
  end

  
  def auth_responses
    [{:amount => "1.00", :auth_response => "00", :response => "Approved"},
    {:amount => "1.01", :auth_response => "05", :response => "Do Not Honor"},
    {:amount => "1.02", :auth_response => "01", :response => "Call/Refer to Card Issuer"},
    {:amount => "1.03", :auth_response => "04", :response => "Pickup"},
    {:amount => "1.04", :auth_response => "19", :response => "Re-enter Transaction"},
    {:amount => "1.05", :auth_response => "14", :response => "Invalid Credit Card Number"},
    {:amount => "1.06", :auth_response => "74", :response => "Invalid Expiration Date"},
    {:amount => "1.07", :auth_response => "L5", :response => "Invalid Issuer"},
    {:amount => "1.10", :auth_response => "03", :response => "Invalid Merchant Number"},
    {:amount => "1.12", :auth_response => "13", :response => "Bad Amount"},
    {:amount => "1.13", :auth_response => "12", :response => "Invalid Transaction Type"},
    {:amount => "1.16", :auth_response => "43", :response => "Lost / Stolen Card"},
    {:amount => "1.21", :auth_response => "06", :response => "Other Error"}]
  end
  
  def avs_response
    [{:avs_zip => "55555", :avs_response => "7", :response => "Address information unavailable"},
    {:avs_zip => "66666", :avs_response => "H", :response => "Zip Match / Locale match"},
    {:avs_zip => "77777", :avs_response => "X", :response => "Zip Match / Locale no match"},
    {:avs_zip => "77777", :avs_response => "Z", :response => "Zip Match / Locale no match"}, 
    {:avs_zip => "88888", :avs_response => "4", :response => "Issuer does not participate in AVS"}] 
  end
  
  def cvv2_responses
    [{:cvv2_value => "111", :cvv_response => "M", :response => "CVV Match"},
    {:cvv2_value => "222", :cvv_response => "N", :response => "CVV No Match"},
    {:cvv2_value => "333", :cvv_response => "P", :response => "Not processed"},
    {:cvv2_value => "444", :cvv_response => "S", :response => "Should have been present"},
    {:cvv2_value => "555", :cvv_response => "U", :response => "Unsupported by issuer"},
    {:cvv2_value => "666", :cvv_response => "spaces", :response => "Not present when issuer"}]
  end
  
  def card_numbers
    [{"Visa" => '4012888888881'},
    {"Visa Purchasing Card II" => '4055011111111111'},
    {"MasterCard" => '5454545454545454'},
    {"MasterCard Purchasing Card II" => '5405222222222226'},
    {"American Express" => '371449635398431'}, 
    {"Discover" => '6011000995500000'}, 
    {"Diners" => '36438999960016'}, 
    {"JCB" => '3566002020140006'}]
  end
end