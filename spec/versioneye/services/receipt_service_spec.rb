require 'spec_helper'

describe ReceiptService do

  before(:each) do
    Plan.create_defaults
    region = 'eu-west-1'
    creds = Aws::Credentials.new(ENV['AWS_ACCESS_KEY_ID'], ENV['AWS_SECRET_ACCESS_KEY'])
    Aws.config[:credentials] = creds
  end

  describe "process_receipts" do

    it "returns nil because db is empty" do
      customer = described_class.process_receipts
    end

    it 'iterates' do
      token      = StripeFactory.token
      token_id   = token[:id]
      small_plan = Plan.small
      email      = 'hans@wur.st'
      customer   = StripeService.create_customer token_id, small_plan.name_id, email

      user                    = UserFactory.create_new 1
      user.plan               = Plan.small
      user.billing_address    = BillingAddressFactory.create_new
      user.stripe_customer_id = customer.id
      user.stripe_token       = token_id
      user.save

      expect( Receipt.count ).to eq( 0 )
      described_class.process_receipts
      expect( Receipt.count ).to eq( 1 )
      rec = Receipt.first
      rec.plan_id = Plan.small.name_id
      rec.total.should eq('1200')
      rec.currency.should eq('eur')

      described_class.process_receipts
      Receipt.count.should == 1
    end

  end

  describe 'compile_html_invoice' do
    it 'compiles for German dude' do
      user = UserFactory.create_new
      receipt = ReceiptFactory.create_new
      receipt.user = user
      receipt.type = Receipt::A_TYPE_CORPORATE
      html = described_class.compile_html_invoice receipt, true
      html.match("5,04 EUR").should_not be_nil
      html.match("0,96 EUR").should_not be_nil
      html.match("6,00 EUR").should_not be_nil
      html.match('Reverse Charge -').should be_nil
      html.match('Non EU customers - Not taxable in Germany.').should be_nil
    end
    it 'compiles for German corp dude' do
      user = UserFactory.create_new
      receipt = ReceiptFactory.create_new
      receipt.user = user
      html = described_class.compile_html_invoice receipt, true
      html.match("5,04 EUR").should_not be_nil
      html.match("0,96 EUR").should_not be_nil
      html.match("6,00 EUR").should_not be_nil
      html.match('Reverse Charge -').should be_nil
      html.match('Non EU customers - Not taxable in Germany.').should be_nil
    end
    it 'compiles for Franch corporate dude' do
      user         = UserFactory.create_new
      receipt      = ReceiptFactory.create_new
      receipt.user = user
      receipt.type = Receipt::A_TYPE_CORPORATE
      receipt.country = 'FR'
      html = described_class.compile_html_invoice receipt, true
      html.match("5,04 EUR").should be_nil
      html.match("0,96 EUR").should be_nil
      html.match("6,00 EUR").should_not be_nil
      html.match('Reverse Charge -').should_not be_nil
      html.match('Non EU customers - Not taxable in Germany.').should be_nil
    end
    it 'compiles for Franch individual dude' do
      user = UserFactory.create_new
      receipt = ReceiptFactory.create_new
      receipt.user = user
      receipt.type = Receipt::A_TYPE_INDIVIDUAL
      receipt.country = 'FR'
      html = described_class.compile_html_invoice receipt, true
      p html
      html.match("5,04 EUR").should_not be_nil
      html.match("0,96 EUR").should_not be_nil
      html.match("6,00 EUR").should_not be_nil
      html.match('Reverse Charge -').should be_nil
      html.match('Non EU customers - Not taxable in Germany.').should be_nil
    end
    it 'compiles for US corporate dude' do
      user = UserFactory.create_new
      receipt = ReceiptFactory.create_new
      receipt.user = user
      receipt.type = Receipt::A_TYPE_CORPORATE
      receipt.country = 'US'
      html = described_class.compile_html_invoice receipt, true
      html.match("5,04 EUR").should be_nil
      html.match("0,96 EUR").should be_nil
      html.match("6,00 EUR").should_not be_nil
      html.match('Reverse Charge -').should be_nil
      html.match('Non EU customers - Not taxable in Germany.').should_not be_nil
    end
    it 'compiles for US individual dude' do
      user = UserFactory.create_new
      receipt = ReceiptFactory.create_new
      receipt.user = user
      receipt.type = Receipt::A_TYPE_INDIVIDUAL
      receipt.country = 'US'
      html = described_class.compile_html_invoice receipt, true
      html.match("5,04 EUR").should be_nil
      html.match("0,96 EUR").should be_nil
      html.match("6,00 EUR").should_not be_nil
      html.match('Reverse Charge -').should be_nil
      html.match('Non EU customers - Not taxable in Germany.').should_not be_nil
    end
  end

  describe 'next_receipt_nr' do
    it 'returns 1001' do
      described_class.next_receipt_nr.should == 1001
    end
    it 'returns 1002' do
      user = UserFactory.create_new
      nr = described_class.next_receipt_nr
      ba = BillingAddressFactory.create_new
      invoice = StripeInvoiceFactory.create_new
      receipt = Receipt.new
      receipt.update_from_billing_address ba
      receipt.update_from_invoice invoice
      receipt.invoice_id = 'tx_1'
      receipt.receipt_nr = nr
      result = receipt.save
      result.should be_truthy
      nr = described_class.next_receipt_nr
      nr.should == 1002
    end
  end

end
