# require 'test_helper'
require "#{File.dirname(__FILE__)}/../../test_helper.rb"


class OrbitalPaymentechTest < Test::Unit::TestCase
  def setup
    @gateway = OrbitalPaymentechGateway.new(
      :login => 'login',
      :password => 'password',
      :merchant_id => 'merchant_id'
    )
    
    @options = { 
      :order_id => '1',
      :address => address,
    }
  end  
  
  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    
    assert response = @gateway.purchase('', credit_card)
    assert_instance_of Response, response
    assert_success response
    assert_equal '4A5398CF9B87744GG84A1D30F2F2321C66249416', response.authorization
  end
    
  def test_unauthenticated_response
    @gateway.expects(:ssl_post).returns(failed_purchase_response)
    
    assert response = @gateway.purchase('101', credit_card)
    assert_instance_of Response, response
    assert_failure response
    assert_equal "AUTH DECLINED                   12001", response.message
  end
  
  def test_profile_add
    @gateway.expects(:ssl_post).returns(successful_customer_profile_add_response)
    
    assert response = @gateway.add_customer_profile(credit_card, @options)
    assert_instance_of Response, response
    assert_success response
    assert_equal 'Profile Request Processed', response.message
  end
  
  def test_recurring_order_ind
    @gateway.stubs(:commit).with {|order| @order = order}
    @gateway.authorize(0, credit_card, @options.merge(:recurring_ind => "RF"))
    assert_equal(Hash.from_xml(@order)['Request']['NewOrder']['RecurringInd'], "RF")
  end
    
  private
  
  # Place raw successful response from gateway here
  def successful_purchase_response
    %q{<?xml version="1.0" encoding="UTF-8"?><Response><NewOrderResp><IndustryType></IndustryType><MessageType>AC</MessageType><MerchantID>700000000000</MerchantID><TerminalID>001</TerminalID><CardBrand>VI</CardBrand><AccountNum>4111111111111111</AccountNum><OrderID>1</OrderID><TxRefNum>4A5398CF9B87744GG84A1D30F2F2321C66249416</TxRefNum><TxRefIdx>1</TxRefIdx><ProcStatus>0</ProcStatus><ApprovalStatus>1</ApprovalStatus><RespCode>00</RespCode><AVSRespCode>H </AVSRespCode><CVV2RespCode>N</CVV2RespCode><AuthCode>091922</AuthCode><RecurringAdviceCd></RecurringAdviceCd><CAVVRespCode></CAVVRespCode><StatusMsg>Approved</StatusMsg><RespMsg></RespMsg><HostRespCode>00</HostRespCode><HostAVSRespCode>Y</HostAVSRespCode><HostCVV2RespCode>N</HostCVV2RespCode><CustomerRefNum></CustomerRefNum><CustomerName></CustomerName><ProfileProcStatus></ProfileProcStatus><CustomerProfileMessage></CustomerProfileMessage><RespTime>144951</RespTime></NewOrderResp></Response>}
  end
  
  # Place raw failed response from gateway here
  def failed_purchase_response
    %q{<?xml version="1.0" encoding="UTF-8"?><Response><NewOrderResp><IndustryType></IndustryType><MessageType>AC</MessageType><MerchantID>700000000000</MerchantID><TerminalID>001</TerminalID><CardBrand>VI</CardBrand><AccountNum>4000300011112220</AccountNum><OrderID>1</OrderID><TxRefNum>4A5398CF9B87744GG84A1D30F2F2321C66249416</TxRefNum><TxRefIdx>0</TxRefIdx><ProcStatus>0</ProcStatus><ApprovalStatus>0</ApprovalStatus><RespCode>05</RespCode><AVSRespCode>G </AVSRespCode><CVV2RespCode>N</CVV2RespCode><AuthCode></AuthCode><RecurringAdviceCd></RecurringAdviceCd><CAVVRespCode></CAVVRespCode><StatusMsg>Do Not Honor</StatusMsg><RespMsg>AUTH DECLINED                   12001</RespMsg><HostRespCode>05</HostRespCode><HostAVSRespCode>N</HostAVSRespCode><HostCVV2RespCode>N</HostCVV2RespCode><CustomerRefNum></CustomerRefNum><CustomerName></CustomerName><ProfileProcStatus></ProfileProcStatus><CustomerProfileMessage></CustomerProfileMessage><RespTime>150214</RespTime></NewOrderResp></Response>}
  end
  
  def successful_customer_profile_add_response
    %q{<?xml version="1.0" encoding="UTF-8"?><Response><ProfileResp><CustomerBin>000002</CustomerBin><CustomerMerchantID>700000208597</CustomerMerchantID><CustomerName>LONGBOB LONGSEN</CustomerName><CustomerRefNum>3975934</CustomerRefNum><CustomerProfileAction>CREATE</CustomerProfileAction><ProfileProcStatus>0</ProfileProcStatus><CustomerProfileMessage>Profile Request Processed</CustomerProfileMessage><CustomerAddress1>1234 MY STREET</CustomerAddress1><CustomerAddress2>APT 1</CustomerAddress2><CustomerCity>OTTAWA</CustomerCity><CustomerState>ON</CustomerState><CustomerZIP>K1C2N6</CustomerZIP><CustomerEmail></CustomerEmail><CustomerPhone>5555555555</CustomerPhone><CustomerCountryCode>CA</CustomerCountryCode><CustomerProfileOrderOverrideInd>NO</CustomerProfileOrderOverrideInd><OrderDefaultDescription></OrderDefaultDescription><OrderDefaultAmount></OrderDefaultAmount><CustomerAccountType>CC</CustomerAccountType><Status>A</Status><CCAccountNum>4111111111111111</CCAccountNum><CCExpireDate>0911</CCExpireDate><ECPAccountDDA></ECPAccountDDA><ECPAccountType></ECPAccountType><ECPAccountRT></ECPAccountRT><ECPBankPmtDlv></ECPBankPmtDlv><SwitchSoloStartDate></SwitchSoloStartDate><SwitchSoloIssueNum></SwitchSoloIssueNum><RespTime></RespTime></ProfileResp></Response>}
  end
  
end