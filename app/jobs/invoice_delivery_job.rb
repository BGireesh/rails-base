class InvoiceDeliveryJob < ApplicationJob
  queue_as :default

  def perform(invoice_id)
    invoice = Invoice.find(invoice_id)
    Rails.logger.info("Delivering invoice #{invoice.id} to #{invoice.carrier_name}")
  end
end
