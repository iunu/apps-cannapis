# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `rails
# db:schema:load`. When creating a new database, `rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2020_02_18_080141) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "pgcrypto"
  enable_extension "plpgsql"

  create_table "accounts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "artemis_id"
    t.string "name"
    t.string "access_token"
    t.string "refresh_token"
    t.integer "access_token_expires_in"
    t.datetime "access_token_created_at"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["artemis_id"], name: "index_accounts_on_artemis_id", unique: true
    t.index ["id"], name: "index_accounts_on_id", unique: true
  end

  create_table "integrations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.integer "facility_id"
    t.string "state"
    t.string "vendor"
    t.string "vendor_id"
    t.string "secret"
    t.datetime "deleted_at"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.time "eod", default: "2000-01-01 19:00:00", null: false
    t.string "timezone", default: "+00:00"
    t.index ["account_id"], name: "index_integrations_on_account_id"
    t.index ["facility_id"], name: "index_integrations_on_facility_id"
    t.index ["id"], name: "index_integrations_on_id", unique: true
  end

  create_table "papertrails", force: :cascade do |t|
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "schedulers", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "integration_id", null: false
    t.integer "facility_id", null: false
    t.integer "batch_id", null: false
    t.datetime "run_on", null: false
    t.datetime "received_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.integer "attempts", default: 0
    t.index ["batch_id", "facility_id"], name: "index_schedulers_on_batch_id_and_facility_id"
    t.index ["facility_id"], name: "index_schedulers_on_facility_id"
    t.index ["integration_id"], name: "index_schedulers_on_integration_id"
    t.index ["run_on"], name: "index_schedulers_on_run_on"
  end

  create_table "transactions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.uuid "integration_id", null: false
    t.integer "batch_id", null: false
    t.integer "completion_id", null: false
    t.string "type", null: false
    t.boolean "success", default: false, null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "vendor", null: false
    t.json "metadata"
    t.index ["account_id"], name: "index_transactions_on_account_id"
    t.index ["batch_id"], name: "index_transactions_on_batch_id"
    t.index ["completion_id"], name: "index_transactions_on_completion_id"
    t.index ["integration_id"], name: "index_transactions_on_integration_id"
    t.index ["success"], name: "index_transactions_on_success"
    t.index ["type"], name: "index_transactions_on_type"
  end

  add_foreign_key "integrations", "accounts"
  add_foreign_key "schedulers", "integrations"
  add_foreign_key "transactions", "accounts"
  add_foreign_key "transactions", "integrations"
end
