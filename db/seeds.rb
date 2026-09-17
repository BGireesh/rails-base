Invoice.find_or_create_by!(carrier_name: "Ridgeline Freight") do |i|
  i.amount_cents = 148_000
  i.currency     = "USD"
end
