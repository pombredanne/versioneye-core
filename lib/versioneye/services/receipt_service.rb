class ReceiptService < Versioneye::Service


  require 'pdfkit'


  def self.process_receipts
    return nil if Settings.instance.environment.eql?("enterprise")

    count = User.where(:plan_id.ne => nil).count
    return nil if count == 0

    per_page = 10
    skip = 0
    iterations = count / per_page
    iterations += 1

    (0..iterations).each do
      users = User.where(:plan_id.ne => nil).skip(skip).limit(per_page)
      handle_users( users )
      skip += per_page
    end
  rescue => e
    log.error e.message
    log.error e.backtrace.join("\n")
  end


  def self.handle_users( users )
    return nil if users.nil? || users.empty?

    users.each do |user|
      next if user.nil?
      next if user.deleted_user == true
      next if user.plan.name_id.eql?(Plan::A_PLAN_FREE)
      next if user.plan.name_id.eql?('01_free')
      next if user.plan.name_id.eql?('02_free')
      next if user.plan.name_id.eql?('03_free')
      next if user.plan.name_id.eql?('03_trial_0')
      next if user.plan.name_id.eql?('04_free')
      next if user.plan.name.match(/Free\Z/i)
      next if user.plan.name.match(/Starter\Z/i)
      next if user.stripe_token.to_s.empty?
      next if user.stripe_customer_id.to_s.empty?

      handle_user( user )
    end
  end


  def self.handle_user( user )
    customer = StripeService.fetch_customer user.stripe_customer_id
    return nil if customer.nil?

    invoices = customer.invoices
    return nil if invoices.nil? || invoices.count == 0

    invoices.each do |invoice|
      handle_invoice user, invoice
    end
  rescue => e
    log.error e.message
    log.error e.backtrace.join("\n")
  end


  def self.handle_invoice user, invoice
    return nil if invoice[:paid].to_s.casecmp('true')   != 0 # return if paid   = false
    return nil if invoice[:closed].to_s.casecmp('true') != 0 # return if closed = false

    # Early exit if receipt exist already in db
    receipt = Receipt.where(:invoice_id => invoice[:id]).shift
    return nil if !receipt.nil?

    receipt = new_receipt user, invoice

    html    = compile_html_invoice receipt
    pdf     = compile_pdf_invoice html
    upload( receipt, pdf )
    if receipt.save
      email receipt, pdf
    else
      log.error "Could not persist receipt for user '#{user.id}' and invoice '#{invoice[:id]}' - #{receipt.errors.full_messages}"
    end

    receipt
  rescue => e
    log.error "ERROR for user #{user.username} - #{e.message}"
    log.error e.backtrace.join("\n")
  end


  def self.new_receipt user, invoice
    receipt = Receipt.new
    receipt.update_from_billing_address user.billing_address
    receipt.update_from_invoice invoice
    receipt.receipt_nr = next_receipt_nr
    receipt.user = user
    receipt
  end


  def self.next_receipt_nr
    nr = Receipt.max(:receipt_nr)
    nr = 1000 if nr.nil?
    nr += 1
    nr
  end


  def self.compile_html_invoice receipt, compile_pdf = false
    content_file = Settings.instance.receipt_content
    erb = ERB.new(File.read(content_file))
    html = erb.result(receipt.get_binding)
    html = html.force_encoding(Encoding::UTF_8)

    if compile_pdf
      compile_pdf_invoice html, receipt
    end

    html
  end


  # Note for me.. kit.to_file('/Users/robertreiz/invoice.pdf')
  def self.compile_pdf_invoice html, receipt = nil
    footer_file = Settings.instance.receipt_footer
    kit = PDFKit.new(html, :footer_html => footer_file, :page_size => 'A4')

    raise "PDFKit.new returned nil!" if kit.nil?

    if receipt
      kit.to_file("#{ENV['HOME']}/#{receipt.filename}")
    end

    kit.to_pdf
  end


  def self.upload receipt, pdf
    S3.store_in_receipt_bucket receipt.filename, pdf
  end


  def self.email receipt, pdf
    ReceiptMailer.receipt_email(receipt, pdf).deliver_now
  end


end
