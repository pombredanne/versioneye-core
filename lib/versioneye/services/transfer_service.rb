class TransferService < Versioneye::Service

  require 'pdfkit'


  def self.process limit = 10000
    transfers = Stripe::Transfer.all(:limit => limit)
    transfers.each do |tr|

      currency = tr.currency.upcase
      gross = tr.summary.charge_gross.to_f / 100
      fees  = tr.summary.charge_fees.to_f / 100
      net   = tr.amount.to_f / 100
      datef = Time.at(tr.date).strftime("%d.%m.%Y")

      p ""
      p "#{datef} Charged: #{'%.02f' % gross} #{currency} - Fee: #{'%.02f' % fees} #{currency} - Transfered: #{'%.02f' % net} #{currency}"
      tr.transactions.each do |tx|
        charge = Stripe::Charge.retrieve(tx.id)
        receipt_nr = ''
        receipt = Receipt.where(:invoice_id => charge.invoice).first
        if receipt
          receipt_nr = receipt.receipt_nr # Rechnungsnummer
        end
        amount = tx.amount.to_f / 100
        fee = tx.fee.to_f / 100
        net = tx.net.to_f / 100
        p " -> #{tx.customer_details} (#{receipt_nr}) - Charged: #{amount} #{currency} - Fee: #{fee} #{currency} - Net: #{net} #{currency}"
      end
    end
    nil
  end


  def self.download_receipts
    bucket_name = 'veye-prod-receipt'
    s3 = Aws::S3::Client.new
    s3.list_objects(bucket: bucket_name).each do |response|
      response.contents.each do |content|
        obj_key = content.key
        download obj_key
      end
    end
  end


  private


    def self.download obj_key
      filename = "/Users/reiz/stripe/#{obj_key}"
      File.open(filename, 'wb') do |file|
        reap = s3.get_object({ bucket: bucket_name, key: obj_key }, target: file)
      end
      p "downloaded file to #{filename}"
    end

end
