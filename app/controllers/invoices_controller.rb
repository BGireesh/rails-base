class InvoicesController < ApplicationController
  def index
    @invoices = Invoice.order(created_at: :desc).limit(50)
  end

  def show
    @invoice = Invoice.find(params[:id])
  end

  def create
    @invoice = Invoice.new(invoice_params)

    if @invoice.save
      InvoiceDeliveryJob.perform_later(@invoice.id)
      redirect_to @invoice, notice: "Invoice queued for delivery."
    else
      render :index, status: :unprocessable_entity
    end
  end

  private

  def invoice_params
    params.require(:invoice).permit(:carrier_name, :amount_cents, :currency)
  end
end
