# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_06_19_113737) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "audit_logs", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "user_id"
    t.string "action", null: false
    t.string "resource_type"
    t.string "resource_id"
    t.json "details", default: {}
    t.string "ip_address"
    t.text "user_agent"
    t.datetime "performed_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["action"], name: "index_audit_logs_on_action"
    t.index ["organization_id", "performed_at"], name: "index_audit_logs_on_organization_id_and_performed_at"
    t.index ["organization_id"], name: "index_audit_logs_on_organization_id"
    t.index ["performed_at"], name: "index_audit_logs_on_performed_at"
    t.index ["resource_type"], name: "index_audit_logs_on_resource_type"
    t.index ["user_id"], name: "index_audit_logs_on_user_id"
  end

  create_table "organizations", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug"
    t.string "plan", default: "trial", null: false
    t.json "plan_limits", default: {}
    t.json "settings", default: {}
    t.string "stripe_customer_id"
    t.string "status", default: "trial", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["plan"], name: "index_organizations_on_plan"
    t.index ["slug"], name: "index_organizations_on_slug", unique: true
    t.index ["status"], name: "index_organizations_on_status"
    t.index ["stripe_customer_id"], name: "index_organizations_on_stripe_customer_id", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.string "email", null: false
    t.string "encrypted_password"
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.string "role", default: "member", null: false
    t.datetime "last_sign_in_at"
    t.datetime "current_sign_in_at"
    t.integer "sign_in_count", default: 0
    t.datetime "confirmed_at"
    t.string "invitation_token"
    t.bigint "invited_by_id"
    t.datetime "invitation_accepted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["confirmed_at"], name: "index_users_on_confirmed_at"
    t.index ["invitation_token"], name: "index_users_on_invitation_token", unique: true
    t.index ["invited_by_id"], name: "index_users_on_invited_by_id"
    t.index ["organization_id", "email"], name: "index_users_on_organization_id_and_email", unique: true
    t.index ["organization_id"], name: "index_users_on_organization_id"
    t.index ["role"], name: "index_users_on_role"
  end

  add_foreign_key "audit_logs", "organizations"
  add_foreign_key "audit_logs", "users"
  add_foreign_key "users", "organizations"
  add_foreign_key "users", "users", column: "invited_by_id"
end
