class Invoice < ApplicationRecord
  validates :carrier_name, presence: true
  validates :amount_cents, numericality: { only_integer: true, greater_than: 0 }
  validates :currency, inclusion: { in: %w[USD CAD] }

  def amount
    amount_cents / 100.0
  end
end
