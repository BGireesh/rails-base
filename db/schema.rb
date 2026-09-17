ActiveRecord::Schema[7.0].define(version: 2024_02_11_094500) do
  enable_extension "plpgsql"

  create_table "invoices", force: :cascade do |t|
    t.string   "carrier_name",             null: false
    t.integer  "amount_cents",             null: false
    t.string   "currency",    default: "USD", null: false
    t.datetime "created_at",               null: false
    t.datetime "updated_at",               null: false
    t.index ["carrier_name"], name: "index_invoices_on_carrier_name"
  end
end
