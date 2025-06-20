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

ActiveRecord::Schema[8.0].define(version: 2025_06_19_222500) do
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

  create_table "data_sources", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.string "name", null: false
    t.string "source_type", null: false
    t.json "config", default: {}
    t.text "credentials"
    t.string "status", default: "disconnected", null: false
    t.datetime "last_sync_at"
    t.datetime "next_sync_at"
    t.string "sync_frequency", default: "daily", null: false
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["next_sync_at"], name: "index_data_sources_on_next_sync_at"
    t.index ["organization_id", "name"], name: "index_data_sources_on_organization_id_and_name", unique: true
    t.index ["organization_id"], name: "index_data_sources_on_organization_id"
    t.index ["source_type"], name: "index_data_sources_on_source_type"
    t.index ["status", "next_sync_at"], name: "index_data_sources_on_status_and_next_sync_at"
    t.index ["status"], name: "index_data_sources_on_status"
  end

  create_table "extraction_jobs", force: :cascade do |t|
    t.bigint "data_source_id", null: false
    t.string "job_id", null: false
    t.string "status", default: "queued", null: false
    t.string "priority", default: "normal", null: false
    t.datetime "started_at"
    t.datetime "completed_at"
    t.integer "records_processed", default: 0
    t.integer "records_failed", default: 0
    t.json "error_details", default: {}
    t.integer "retry_count", default: 0
    t.integer "max_retries", default: 3
    t.datetime "next_retry_at"
    t.json "extraction_metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["data_source_id", "status"], name: "index_extraction_jobs_on_data_source_id_and_status"
    t.index ["data_source_id"], name: "index_extraction_jobs_on_data_source_id"
    t.index ["job_id"], name: "index_extraction_jobs_on_job_id", unique: true
    t.index ["next_retry_at"], name: "index_extraction_jobs_on_next_retry_at"
    t.index ["priority"], name: "index_extraction_jobs_on_priority"
    t.index ["status", "priority"], name: "index_extraction_jobs_on_status_and_priority"
    t.index ["status"], name: "index_extraction_jobs_on_status"
  end

  create_table "organizations", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug"
    t.string "plan", default: "free_trial", null: false
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

  create_table "raw_data_records", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "data_source_id", null: false
    t.bigint "extraction_job_id", null: false
    t.string "record_type", null: false
    t.string "external_id", null: false
    t.text "raw_data"
    t.text "encrypted_payload"
    t.string "checksum", null: false
    t.string "processing_status", default: "pending", null: false
    t.datetime "processed_at"
    t.json "validation_errors", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["data_source_id", "external_id", "checksum"], name: "index_raw_data_records_on_source_id_checksum", unique: true
    t.index ["data_source_id"], name: "index_raw_data_records_on_data_source_id"
    t.index ["extraction_job_id", "processing_status"], name: "idx_on_extraction_job_id_processing_status_8bea689c27"
    t.index ["extraction_job_id"], name: "index_raw_data_records_on_extraction_job_id"
    t.index ["organization_id", "record_type"], name: "index_raw_data_records_on_organization_id_and_record_type"
    t.index ["organization_id"], name: "index_raw_data_records_on_organization_id"
    t.index ["processed_at"], name: "index_raw_data_records_on_processed_at"
    t.index ["processing_status"], name: "index_raw_data_records_on_processing_status"
    t.index ["record_type"], name: "index_raw_data_records_on_record_type"
  end

  create_table "transformation_jobs", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.string "job_id", null: false
    t.string "transformation_type", null: false
    t.integer "input_records_count", default: 0
    t.integer "output_records_count", default: 0
    t.string "status", default: "queued", null: false
    t.datetime "started_at"
    t.datetime "completed_at"
    t.json "error_details", default: {}
    t.json "transformation_rules", default: {}
    t.json "data_quality_metrics", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["completed_at"], name: "index_transformation_jobs_on_completed_at"
    t.index ["job_id"], name: "index_transformation_jobs_on_job_id", unique: true
    t.index ["organization_id", "transformation_type"], name: "idx_on_organization_id_transformation_type_665202abc7"
    t.index ["organization_id"], name: "index_transformation_jobs_on_organization_id"
    t.index ["status", "started_at"], name: "index_transformation_jobs_on_status_and_started_at"
    t.index ["status"], name: "index_transformation_jobs_on_status"
    t.index ["transformation_type"], name: "index_transformation_jobs_on_transformation_type"
  end

  create_table "users", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.string "email", null: false
    t.string "encrypted_password", null: false
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
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.string "confirmation_token"
    t.datetime "confirmation_sent_at"
    t.string "unconfirmed_email"
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["confirmed_at"], name: "index_users_on_confirmed_at"
    t.index ["invitation_token"], name: "index_users_on_invitation_token", unique: true
    t.index ["invited_by_id"], name: "index_users_on_invited_by_id"
    t.index ["organization_id", "email"], name: "index_users_on_organization_id_and_email", unique: true
    t.index ["organization_id"], name: "index_users_on_organization_id"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["role"], name: "index_users_on_role"
  end

  add_foreign_key "audit_logs", "organizations"
  add_foreign_key "audit_logs", "users"
  add_foreign_key "data_sources", "organizations"
  add_foreign_key "extraction_jobs", "data_sources"
  add_foreign_key "raw_data_records", "data_sources"
  add_foreign_key "raw_data_records", "extraction_jobs"
  add_foreign_key "raw_data_records", "organizations"
  add_foreign_key "transformation_jobs", "organizations"
  add_foreign_key "users", "organizations"
  add_foreign_key "users", "users", column: "invited_by_id"
end
