class CreateInvoices < ActiveRecord::Migration[7.0]
  def change
    create_table :invoices do |t|
      t.string  :carrier_name, null: false
      t.integer :amount_cents, null: false
      t.string  :currency, null: false, default: "USD"

      t.timestamps
    end

    add_index :invoices, :carrier_name
  end
end
