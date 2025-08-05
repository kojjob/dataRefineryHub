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

ActiveRecord::Schema[8.0].define(version: 2025_08_03_223631) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "ai_agent_configurations", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.string "agent_type", null: false
    t.boolean "enabled", default: true
    t.json "settings"
    t.json "learning_data"
    t.float "performance_score"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["agent_type"], name: "index_ai_agent_configurations_on_agent_type"
    t.index ["organization_id", "agent_type"], name: "idx_on_organization_id_agent_type_587471fea7", unique: true
    t.index ["organization_id"], name: "index_ai_agent_configurations_on_organization_id"
  end

  create_table "ai_automated_actions", force: :cascade do |t|
    t.bigint "insight_id"
    t.bigint "organization_id", null: false
    t.string "action_type", null: false
    t.json "parameters"
    t.integer "status", default: 0
    t.datetime "executed_at"
    t.datetime "approved_at"
    t.datetime "completed_at"
    t.bigint "approved_by_id"
    t.json "result"
    t.string "suggested_by", default: "bi_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["action_type"], name: "index_ai_automated_actions_on_action_type"
    t.index ["approved_by_id"], name: "index_ai_automated_actions_on_approved_by_id"
    t.index ["executed_at"], name: "index_ai_automated_actions_on_executed_at"
    t.index ["insight_id"], name: "index_ai_automated_actions_on_insight_id"
    t.index ["organization_id", "status"], name: "index_ai_automated_actions_on_organization_id_and_status"
    t.index ["organization_id"], name: "index_ai_automated_actions_on_organization_id"
    t.index ["status"], name: "index_ai_automated_actions_on_status"
  end

  create_table "ai_insights", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "user_id"
    t.bigint "presentation_id"
    t.bigint "data_source_id"
    t.string "insight_type", null: false
    t.string "title", null: false
    t.text "description", null: false
    t.decimal "confidence_score", precision: 3, scale: 2, null: false
    t.string "impact_level", null: false
    t.boolean "actionable", default: false, null: false
    t.json "metadata", default: {}
    t.json "recommendations", default: []
    t.datetime "read_at"
    t.bigint "read_by"
    t.datetime "acknowledged_at"
    t.bigint "acknowledged_by"
    t.datetime "dismissed_at"
    t.text "dismissal_reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["acknowledged_at"], name: "index_ai_insights_on_acknowledged_at"
    t.index ["acknowledged_by"], name: "idx_ai_insights_acknowledged_by"
    t.index ["actionable", "impact_level"], name: "index_ai_insights_on_actionable_and_impact_level"
    t.index ["actionable"], name: "index_ai_insights_on_actionable"
    t.index ["confidence_score"], name: "index_ai_insights_on_confidence_score", where: "(confidence_score > 0.7)"
    t.index ["data_source_id"], name: "index_ai_insights_on_data_source_id"
    t.index ["dismissed_at"], name: "index_ai_insights_on_dismissed_at"
    t.index ["impact_level"], name: "index_ai_insights_on_impact_level"
    t.index ["insight_type"], name: "index_ai_insights_on_insight_type"
    t.index ["organization_id", "created_at"], name: "index_ai_insights_on_organization_id_and_created_at"
    t.index ["organization_id", "impact_level"], name: "index_ai_insights_on_organization_id_and_impact_level"
    t.index ["organization_id", "insight_type"], name: "index_ai_insights_on_organization_id_and_insight_type"
    t.index ["organization_id"], name: "index_ai_insights_on_organization_id"
    t.index ["presentation_id"], name: "index_ai_insights_on_presentation_id"
    t.index ["read_at"], name: "index_ai_insights_on_read_at"
    t.index ["read_by"], name: "idx_ai_insights_read_by"
    t.index ["user_id"], name: "index_ai_insights_on_user_id"
  end

  create_table "ai_presentation_interactions", force: :cascade do |t|
    t.bigint "presentation_id", null: false
    t.bigint "user_id"
    t.bigint "organization_id", null: false
    t.string "interaction_type", null: false
    t.string "element_id"
    t.string "element_type"
    t.text "coordinates"
    t.text "metadata"
    t.text "form_data"
    t.datetime "timestamp"
    t.string "session_id"
    t.string "ip_address"
    t.text "user_agent"
    t.string "page_url"
    t.string "referrer"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["interaction_type"], name: "index_ai_presentation_interactions_on_interaction_type"
    t.index ["organization_id", "created_at"], name: "idx_on_organization_id_created_at_9ffea752e8"
    t.index ["organization_id", "timestamp"], name: "idx_ai_presentation_interactions_org_timestamp"
    t.index ["organization_id"], name: "index_ai_presentation_interactions_on_organization_id"
    t.index ["presentation_id", "created_at"], name: "idx_on_presentation_id_created_at_00cdb8309d"
    t.index ["presentation_id"], name: "index_ai_presentation_interactions_on_presentation_id"
    t.index ["session_id"], name: "index_ai_presentation_interactions_on_session_id"
    t.index ["timestamp"], name: "index_ai_presentation_interactions_on_timestamp"
    t.index ["user_id", "created_at"], name: "index_ai_presentation_interactions_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_ai_presentation_interactions_on_user_id"
  end

  create_table "ai_presentation_views", force: :cascade do |t|
    t.bigint "presentation_id", null: false
    t.bigint "user_id"
    t.bigint "organization_id", null: false
    t.string "session_id", null: false
    t.string "ip_address", null: false
    t.text "user_agent"
    t.datetime "started_at"
    t.datetime "ended_at"
    t.integer "duration"
    t.boolean "completed", default: false
    t.string "referrer"
    t.string "device_type"
    t.string "browser"
    t.string "os"
    t.string "country"
    t.string "city"
    t.string "utm_source"
    t.string "utm_medium"
    t.string "utm_campaign"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["completed"], name: "index_ai_presentation_views_on_completed"
    t.index ["organization_id", "created_at"], name: "index_ai_presentation_views_on_organization_id_and_created_at"
    t.index ["organization_id", "started_at"], name: "idx_ai_presentation_views_org_started"
    t.index ["organization_id"], name: "index_ai_presentation_views_on_organization_id"
    t.index ["presentation_id", "created_at"], name: "index_ai_presentation_views_on_presentation_id_and_created_at"
    t.index ["presentation_id"], name: "index_ai_presentation_views_on_presentation_id"
    t.index ["session_id"], name: "index_ai_presentation_views_on_session_id"
    t.index ["user_id", "created_at"], name: "index_ai_presentation_views_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_ai_presentation_views_on_user_id"
  end

  create_table "ai_queries", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "user_id", null: false
    t.text "query", null: false
    t.text "response"
    t.json "context"
    t.json "entities"
    t.string "intent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_ai_queries_on_created_at"
    t.index ["intent"], name: "index_ai_queries_on_intent"
    t.index ["organization_id", "user_id", "created_at"], name: "index_ai_queries_on_organization_id_and_user_id_and_created_at"
    t.index ["organization_id"], name: "index_ai_queries_on_organization_id"
    t.index ["user_id"], name: "index_ai_queries_on_user_id"
  end

  create_table "alerts", force: :cascade do |t|
    t.string "alert_type", null: false
    t.string "title", null: false
    t.text "message", null: false
    t.string "severity", default: "medium", null: false
    t.string "status", default: "active", null: false
    t.bigint "organization_id", null: false
    t.bigint "user_id"
    t.bigint "data_source_id"
    t.bigint "pipeline_execution_id"
    t.datetime "resolved_at"
    t.datetime "acknowledged_at"
    t.datetime "dismissed_at"
    t.string "resolved_by"
    t.string "acknowledged_by"
    t.string "dismissed_by"
    t.json "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["alert_type", "status"], name: "index_alerts_on_alert_type_and_status"
    t.index ["alert_type"], name: "index_alerts_on_alert_type"
    t.index ["created_at"], name: "index_alerts_on_created_at"
    t.index ["data_source_id"], name: "index_alerts_on_data_source_id"
    t.index ["organization_id", "alert_type"], name: "index_alerts_on_organization_id_and_alert_type"
    t.index ["organization_id", "severity"], name: "index_alerts_on_organization_id_and_severity"
    t.index ["organization_id", "status"], name: "index_alerts_on_organization_id_and_status"
    t.index ["organization_id"], name: "index_alerts_on_organization_id"
    t.index ["pipeline_execution_id"], name: "index_alerts_on_pipeline_execution_id"
    t.index ["severity", "status"], name: "index_alerts_on_severity_and_status"
    t.index ["severity"], name: "index_alerts_on_severity"
    t.index ["status"], name: "index_alerts_on_status"
    t.index ["user_id"], name: "index_alerts_on_user_id"
  end

  create_table "api_keys", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "user_id", null: false
    t.string "name"
    t.string "key"
    t.boolean "active"
    t.datetime "last_used_at"
    t.integer "usage_count"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id"], name: "index_api_keys_on_organization_id"
    t.index ["user_id"], name: "index_api_keys_on_user_id"
  end

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
    t.index ["resource_type", "resource_id", "performed_at"], name: "idx_audit_logs_resource_performed"
    t.index ["resource_type"], name: "index_audit_logs_on_resource_type"
    t.index ["user_id", "action", "performed_at"], name: "idx_audit_logs_user_action_performed"
    t.index ["user_id"], name: "index_audit_logs_on_user_id"
  end

  create_table "dashboards", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.string "name", null: false
    t.string "dashboard_type"
    t.jsonb "configuration", default: {}
    t.boolean "active", default: true
    t.integer "position"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_dashboards_on_active"
    t.index ["dashboard_type"], name: "index_dashboards_on_dashboard_type"
    t.index ["organization_id", "active"], name: "index_dashboards_on_organization_id_and_active"
    t.index ["organization_id"], name: "index_dashboards_on_organization_id"
  end

  create_table "data_quality_reports", force: :cascade do |t|
    t.bigint "data_source_id", null: false
    t.decimal "overall_score", precision: 5, scale: 2, default: "0.0"
    t.decimal "completeness_score", precision: 5, scale: 2, default: "0.0"
    t.decimal "accuracy_score", precision: 5, scale: 2, default: "0.0"
    t.decimal "consistency_score", precision: 5, scale: 2, default: "0.0"
    t.decimal "validity_score", precision: 5, scale: 2, default: "0.0"
    t.decimal "timeliness_score", precision: 5, scale: 2, default: "0.0"
    t.integer "issues_count", default: 0
    t.integer "total_records", default: 0
    t.integer "valid_records", default: 0
    t.json "report_data", default: {}
    t.datetime "run_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.string "status", default: "pending"
    t.string "validation_type", default: "full"
    t.datetime "started_at"
    t.datetime "completed_at"
    t.text "error_message"
    t.json "quality_metrics", default: {}
    t.json "metadata", default: {}
    t.integer "records_analyzed", default: 0
    t.decimal "uniqueness_score", precision: 5, scale: 2, default: "0.0"
    t.decimal "freshness_score", precision: 5, scale: 2, default: "0.0"
    t.index ["data_source_id", "overall_score"], name: "idx_data_quality_reports_source_score"
    t.index ["data_source_id", "run_at"], name: "index_data_quality_reports_on_data_source_id_and_run_at"
    t.index ["data_source_id", "status"], name: "index_data_quality_reports_on_data_source_id_and_status"
    t.index ["data_source_id"], name: "index_data_quality_reports_on_data_source_id"
    t.index ["overall_score"], name: "index_data_quality_reports_on_overall_score"
    t.index ["run_at"], name: "index_data_quality_reports_on_run_at"
    t.index ["status"], name: "index_data_quality_reports_on_status"
    t.index ["user_id"], name: "index_data_quality_reports_on_user_id"
    t.index ["validation_type"], name: "index_data_quality_reports_on_validation_type"
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
    t.index ["organization_id", "source_type"], name: "idx_data_sources_org_type"
    t.index ["organization_id", "status", "created_at"], name: "idx_data_sources_org_status_created"
    t.index ["organization_id", "status", "source_type"], name: "idx_data_sources_org_status_type"
    t.index ["organization_id"], name: "index_data_sources_on_organization_id"
    t.index ["source_type"], name: "index_data_sources_on_source_type"
    t.index ["status", "next_sync_at"], name: "index_data_sources_on_status_and_next_sync_at"
    t.index ["status", "updated_at"], name: "idx_data_sources_status_updated"
    t.index ["status"], name: "index_data_sources_on_status"
    t.check_constraint "source_type::text = ANY (ARRAY['shopify'::character varying, 'quickbooks'::character varying, 'google_analytics'::character varying, 'stripe'::character varying, 'mailchimp'::character varying, 'zendesk'::character varying, 'hubspot'::character varying, 'google_ads'::character varying, 'facebook_ads'::character varying, 'woocommerce'::character varying, 'salesforce'::character varying, 'amazon_seller_central'::character varying, 'custom_api'::character varying, 'file_upload'::character varying, 'postgresql'::character varying, 'mysql'::character varying, 'csv'::character varying, 'api'::character varying, 'google_sheets'::character varying]::text[])", name: "check_valid_source_type"
  end

  create_table "delivery_logs", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "organization_id", null: false
    t.string "channel"
    t.string "status"
    t.string "report_type"
    t.jsonb "metadata"
    t.datetime "delivered_at"
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id"], name: "index_delivery_logs_on_organization_id"
    t.index ["user_id"], name: "index_delivery_logs_on_user_id"
  end

  create_table "delivery_preferences", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "organization_id", null: false
    t.string "report_type"
    t.string "channel"
    t.string "format"
    t.jsonb "schedule"
    t.jsonb "options"
    t.boolean "active"
    t.string "delivery_time"
    t.string "timezone"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id"], name: "index_delivery_preferences_on_organization_id"
    t.index ["user_id"], name: "index_delivery_preferences_on_user_id"
  end

  create_table "event_timelines", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.string "event_type", null: false
    t.string "event_category", null: false
    t.string "title", null: false
    t.text "description"
    t.string "resource_type"
    t.bigint "resource_id"
    t.json "metadata", default: {}
    t.datetime "occurred_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_category"], name: "index_event_timelines_on_event_category"
    t.index ["event_type"], name: "index_event_timelines_on_event_type"
    t.index ["occurred_at"], name: "index_event_timelines_on_occurred_at"
    t.index ["organization_id", "occurred_at"], name: "index_event_timelines_on_organization_id_and_occurred_at"
    t.index ["organization_id"], name: "index_event_timelines_on_organization_id"
    t.index ["resource_type", "resource_id"], name: "index_event_timelines_on_resource_type_and_resource_id"
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
    t.string "job_type", default: "manual_sync"
    t.index ["created_at"], name: "idx_extraction_jobs_active", where: "((status)::text = ANY ((ARRAY['running'::character varying, 'queued'::character varying])::text[]))"
    t.index ["data_source_id", "status", "updated_at"], name: "idx_extraction_jobs_source_status_updated"
    t.index ["data_source_id", "status"], name: "index_extraction_jobs_on_data_source_id_and_status"
    t.index ["data_source_id"], name: "index_extraction_jobs_on_data_source_id"
    t.index ["job_id"], name: "index_extraction_jobs_on_job_id", unique: true
    t.index ["next_retry_at"], name: "index_extraction_jobs_on_next_retry_at"
    t.index ["priority"], name: "index_extraction_jobs_on_priority"
    t.index ["status", "created_at"], name: "idx_extraction_jobs_status_created"
    t.index ["status", "priority"], name: "index_extraction_jobs_on_status_and_priority"
    t.index ["status"], name: "index_extraction_jobs_on_status"
    t.check_constraint "status::text = ANY (ARRAY['queued'::character varying, 'running'::character varying, 'completed'::character varying, 'failed'::character varying, 'cancelled'::character varying, 'retrying'::character varying]::text[])", name: "check_valid_status"
  end

  create_table "landing_page_contents", force: :cascade do |t|
    t.string "section", null: false
    t.string "title", null: false
    t.text "content", null: false
    t.json "metadata", default: {}
    t.boolean "active", default: true, null: false
    t.integer "display_order", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_landing_page_contents_on_active"
    t.index ["display_order"], name: "index_landing_page_contents_on_display_order"
    t.index ["section", "active", "display_order"], name: "index_landing_contents_on_section_active_order"
    t.index ["section"], name: "index_landing_page_contents_on_section"
  end

  create_table "landing_pages", force: :cascade do |t|
    t.bigint "project_id", null: false
    t.bigint "user_id", null: false
    t.string "name", null: false
    t.string "slug", null: false
    t.string "title"
    t.text "description"
    t.text "content"
    t.string "meta_description"
    t.jsonb "settings", default: {}
    t.string "template_type", default: "standard"
    t.boolean "published", default: false
    t.datetime "published_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id", "slug"], name: "idx_landing_pages_project_slug_unique", unique: true
    t.index ["project_id"], name: "index_landing_pages_on_project_id"
    t.index ["published"], name: "index_landing_pages_on_published"
    t.index ["slug"], name: "index_landing_pages_on_slug", unique: true
    t.index ["template_type"], name: "index_landing_pages_on_template_type"
    t.index ["user_id"], name: "index_landing_pages_on_user_id"
  end

  create_table "notifications", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "organization_id", null: false
    t.string "title", null: false
    t.text "message", null: false
    t.string "notification_type", null: false
    t.datetime "read_at"
    t.integer "priority", default: 0
    t.json "metadata", default: {}
    t.string "notifiable_type"
    t.bigint "notifiable_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["notifiable_type", "notifiable_id"], name: "index_notifications_on_notifiable_type_and_notifiable_id"
    t.index ["notification_type"], name: "index_notifications_on_notification_type"
    t.index ["organization_id", "created_at"], name: "index_notifications_on_organization_id_and_created_at"
    t.index ["organization_id", "notification_type"], name: "idx_notifications_org_type"
    t.index ["organization_id"], name: "index_notifications_on_organization_id"
    t.index ["priority"], name: "index_notifications_on_priority"
    t.index ["user_id", "created_at"], name: "idx_notifications_user_created"
    t.index ["user_id", "organization_id", "created_at"], name: "idx_notifications_unread", where: "(read_at IS NULL)"
    t.index ["user_id", "read_at"], name: "index_notifications_on_user_id_and_read_at"
    t.index ["user_id"], name: "index_notifications_on_user_id"
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
    t.string "timezone", default: "UTC"
    t.string "phone"
    t.text "address"
    t.string "applied_template"
    t.datetime "template_applied_at"
    t.string "subscription_tier", default: "free", null: false
    t.index ["created_at"], name: "idx_organizations_created"
    t.index ["plan"], name: "index_organizations_on_plan"
    t.index ["slug"], name: "index_organizations_on_slug", unique: true
    t.index ["status"], name: "index_organizations_on_status"
    t.index ["stripe_customer_id"], name: "index_organizations_on_stripe_customer_id", unique: true
    t.index ["subscription_tier"], name: "index_organizations_on_subscription_tier"
  end

  create_table "pipeline_executions", force: :cascade do |t|
    t.string "execution_id", null: false
    t.string "pipeline_name", null: false
    t.bigint "data_source_id"
    t.bigint "user_id"
    t.string "status", default: "pending", null: false
    t.decimal "progress", precision: 5, scale: 2, default: "0.0"
    t.string "current_stage"
    t.datetime "started_at", null: false
    t.datetime "completed_at"
    t.text "error_message"
    t.text "parameters"
    t.text "result_summary"
    t.text "error_details"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "execution_mode", default: "automatic"
    t.boolean "manual_intervention_required", default: false
    t.string "approval_status"
    t.bigint "approved_by_id"
    t.datetime "last_manual_task_at"
    t.bigint "organization_id", null: false
    t.integer "priority", default: 0
    t.json "configuration", default: {}
    t.json "metadata", default: {}
    t.integer "retry_count", default: 0
    t.integer "records_processed", default: 0
    t.integer "records_failed", default: 0
    t.integer "average_speed", default: 0
    t.datetime "estimated_completion_at"
    t.decimal "cpu_usage", precision: 5, scale: 2
    t.decimal "memory_usage_gb", precision: 8, scale: 2
    t.index ["approved_by_id"], name: "index_pipeline_executions_on_approved_by_id"
    t.index ["data_source_id", "status"], name: "index_pipeline_executions_on_data_source_id_and_status"
    t.index ["data_source_id"], name: "index_pipeline_executions_on_data_source_id"
    t.index ["execution_id"], name: "index_pipeline_executions_on_execution_id", unique: true
    t.index ["execution_mode", "status"], name: "index_pipeline_executions_on_execution_mode_and_status"
    t.index ["execution_mode"], name: "index_pipeline_executions_on_execution_mode"
    t.index ["manual_intervention_required"], name: "index_pipeline_executions_on_manual_intervention_required"
    t.index ["organization_id", "started_at"], name: "idx_pipeline_executions_running", where: "((status)::text = 'running'::text)"
    t.index ["organization_id"], name: "index_pipeline_executions_on_organization_id"
    t.index ["pipeline_name", "status"], name: "index_pipeline_executions_on_pipeline_name_and_status"
    t.index ["pipeline_name"], name: "index_pipeline_executions_on_pipeline_name"
    t.index ["started_at", "status"], name: "index_pipeline_executions_on_started_at_and_status"
    t.index ["started_at"], name: "index_pipeline_executions_on_started_at"
    t.index ["status"], name: "index_pipeline_executions_on_status"
    t.index ["user_id"], name: "index_pipeline_executions_on_user_id"
  end

  create_table "pipeline_metrics", force: :cascade do |t|
    t.bigint "pipeline_execution_id", null: false
    t.bigint "organization_id", null: false
    t.integer "records_per_second", default: 0
    t.decimal "cpu_usage", precision: 5, scale: 2
    t.decimal "memory_usage_gb", precision: 8, scale: 2
    t.integer "active_threads", default: 0
    t.integer "queue_size", default: 0
    t.datetime "recorded_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id"], name: "index_pipeline_metrics_on_organization_id"
    t.index ["pipeline_execution_id", "recorded_at"], name: "idx_on_pipeline_execution_id_recorded_at_4868b4fad1"
    t.index ["pipeline_execution_id"], name: "index_pipeline_metrics_on_pipeline_execution_id"
    t.index ["recorded_at"], name: "index_pipeline_metrics_on_recorded_at"
  end

  create_table "pipelines", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "created_by_id", null: false
    t.bigint "last_executed_by_id"
    t.string "name", null: false
    t.text "description"
    t.string "pipeline_type", default: "etl", null: false
    t.string "status", default: "draft", null: false
    t.jsonb "source_config", default: {}, null: false
    t.jsonb "destination_config", default: {}, null: false
    t.jsonb "transformation_rules", default: []
    t.jsonb "schedule_config", default: {}
    t.jsonb "dependencies", default: []
    t.jsonb "retry_policy", default: {}
    t.jsonb "notification_settings", default: {}
    t.string "error_handling_strategy", default: "circuit_breaker"
    t.datetime "last_executed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "schedule_type"
    t.string "schedule_expression"
    t.string "schedule_timezone", default: "UTC"
    t.jsonb "tags", default: []
    t.integer "aggregate_version", default: 0
    t.integer "retry_max_attempts"
    t.string "retry_backoff_strategy"
    t.integer "retry_initial_delay"
    t.integer "retry_max_delay"
    t.float "retry_multiplier"
    t.index ["created_at"], name: "index_pipelines_on_created_at"
    t.index ["created_by_id"], name: "index_pipelines_on_created_by_id"
    t.index ["last_executed_by_id"], name: "index_pipelines_on_last_executed_by_id"
    t.index ["organization_id", "name"], name: "index_pipelines_on_organization_id_and_name", unique: true
    t.index ["organization_id", "status"], name: "idx_pipeline_configs_org_status"
    t.index ["organization_id"], name: "index_pipelines_on_organization_id"
    t.index ["pipeline_type"], name: "index_pipelines_on_pipeline_type"
    t.index ["schedule_config"], name: "idx_pipeline_configs_schedule_gin", using: :gin
    t.index ["status"], name: "index_pipelines_on_status"
    t.index ["tags"], name: "index_pipelines_on_tags", using: :gin
  end

  create_table "presentations", force: :cascade do |t|
    t.string "title", null: false
    t.string "template_type", null: false
    t.string "output_format", null: false
    t.string "status", default: "generating", null: false
    t.string "file_path"
    t.string "download_url"
    t.text "content"
    t.integer "progress_percentage", default: 0
    t.text "error_message"
    t.datetime "generated_at"
    t.datetime "failed_at"
    t.bigint "organization_id", null: false
    t.bigint "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "configuration"
    t.text "metadata"
    t.text "interactive_elements"
    t.string "presentation_type"
    t.decimal "engagement_score", precision: 5, scale: 2, default: "0.0"
    t.integer "views_count", default: 0
    t.boolean "live_data_enabled", default: false
    t.boolean "shared", default: false
    t.datetime "published_at"
    t.index ["engagement_score"], name: "index_presentations_on_engagement_score"
    t.index ["organization_id", "created_at"], name: "index_presentations_on_organization_id_and_created_at"
    t.index ["organization_id"], name: "index_presentations_on_organization_id"
    t.index ["presentation_type"], name: "index_presentations_on_presentation_type"
    t.index ["published_at"], name: "index_presentations_on_published_at"
    t.index ["shared", "published_at"], name: "index_presentations_on_shared_and_published_at"
    t.index ["status", "created_at"], name: "index_presentations_on_status_and_created_at"
    t.index ["template_type"], name: "index_presentations_on_template_type"
    t.index ["user_id"], name: "index_presentations_on_user_id"
  end

  create_table "projects", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "user_id", null: false
    t.string "name", null: false
    t.text "description"
    t.string "slug", null: false
    t.string "status", default: "active"
    t.jsonb "settings", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "slug"], name: "idx_projects_org_slug_unique", unique: true
    t.index ["organization_id"], name: "index_projects_on_organization_id"
    t.index ["slug"], name: "index_projects_on_slug", unique: true
    t.index ["status"], name: "index_projects_on_status"
    t.index ["user_id"], name: "index_projects_on_user_id"
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
    t.jsonb "data"
    t.index ["data_source_id", "external_id", "checksum"], name: "index_raw_data_records_on_source_id_checksum", unique: true
    t.index ["data_source_id"], name: "index_raw_data_records_on_data_source_id"
    t.index ["extraction_job_id", "processing_status"], name: "idx_on_extraction_job_id_processing_status_8bea689c27"
    t.index ["extraction_job_id"], name: "index_raw_data_records_on_extraction_job_id"
    t.index ["organization_id", "processing_status", "created_at"], name: "idx_raw_data_records_org_status_created"
    t.index ["organization_id", "record_type"], name: "index_raw_data_records_on_organization_id_and_record_type"
    t.index ["organization_id"], name: "index_raw_data_records_on_organization_id"
    t.index ["processed_at"], name: "index_raw_data_records_on_processed_at"
    t.index ["processing_status"], name: "index_raw_data_records_on_processing_status"
    t.index ["record_type"], name: "index_raw_data_records_on_record_type"
  end

  create_table "report_components", force: :cascade do |t|
    t.bigint "report_template_id", null: false
    t.string "component_type", null: false
    t.string "component_id", null: false
    t.jsonb "properties", default: {}
    t.jsonb "data_source", default: {}
    t.jsonb "styling", default: {}
    t.integer "position_x", default: 0
    t.integer "position_y", default: 0
    t.integer "width", default: 6
    t.integer "height", default: 4
    t.integer "z_index", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["component_type"], name: "index_report_components_on_component_type"
    t.index ["report_template_id", "component_id"], name: "idx_report_components_unique", unique: true
    t.index ["report_template_id"], name: "index_report_components_on_report_template_id"
  end

  create_table "report_templates", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "user_id", null: false
    t.string "name", null: false
    t.text "description"
    t.string "template_type"
    t.jsonb "configuration", default: {}
    t.jsonb "query_definition", default: {}
    t.jsonb "layout", default: {}
    t.boolean "is_public", default: false
    t.boolean "is_featured", default: false
    t.integer "usage_count", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["is_featured"], name: "index_report_templates_on_is_featured"
    t.index ["is_public"], name: "index_report_templates_on_is_public"
    t.index ["name"], name: "index_report_templates_on_name"
    t.index ["organization_id"], name: "index_report_templates_on_organization_id"
    t.index ["template_type"], name: "index_report_templates_on_template_type"
    t.index ["user_id"], name: "index_report_templates_on_user_id"
  end

  create_table "scheduled_task_runs", force: :cascade do |t|
    t.bigint "scheduled_task_id", null: false
    t.bigint "pipeline_execution_id"
    t.bigint "task_id"
    t.string "status", default: "pending", null: false
    t.datetime "started_at", null: false
    t.datetime "completed_at"
    t.integer "duration_seconds"
    t.text "error_message"
    t.jsonb "output", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["pipeline_execution_id"], name: "index_scheduled_task_runs_on_pipeline_execution_id"
    t.index ["scheduled_task_id", "started_at"], name: "index_scheduled_task_runs_on_scheduled_task_id_and_started_at"
    t.index ["scheduled_task_id"], name: "index_scheduled_task_runs_on_scheduled_task_id"
    t.index ["started_at"], name: "index_scheduled_task_runs_on_started_at"
    t.index ["status"], name: "index_scheduled_task_runs_on_status"
    t.index ["task_id"], name: "index_scheduled_task_runs_on_task_id"
  end

  create_table "scheduled_tasks", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "task_template_id", null: false
    t.bigint "created_by_id", null: false
    t.string "name", null: false
    t.text "description"
    t.string "status", default: "active", null: false
    t.string "schedule_type", null: false
    t.datetime "scheduled_at"
    t.time "time_of_day"
    t.string "days_of_week", default: [], array: true
    t.integer "day_of_month"
    t.string "cron_expression"
    t.date "start_date"
    t.date "end_date"
    t.integer "max_runs"
    t.integer "run_count", default: 0
    t.datetime "next_run_at"
    t.jsonb "configuration", default: {}
    t.jsonb "task_overrides", default: {}
    t.datetime "paused_at"
    t.datetime "resumed_at"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_scheduled_tasks_on_created_by_id"
    t.index ["next_run_at"], name: "index_scheduled_tasks_on_next_run_at"
    t.index ["organization_id", "status"], name: "index_scheduled_tasks_on_organization_id_and_status"
    t.index ["organization_id"], name: "index_scheduled_tasks_on_organization_id"
    t.index ["schedule_type"], name: "index_scheduled_tasks_on_schedule_type"
    t.index ["status"], name: "index_scheduled_tasks_on_status"
    t.index ["task_template_id"], name: "index_scheduled_tasks_on_task_template_id"
  end

  create_table "scheduled_uploads", force: :cascade do |t|
    t.bigint "data_source_id", null: false
    t.bigint "user_id", null: false
    t.string "name", null: false
    t.text "description"
    t.string "frequency", default: "daily", null: false
    t.boolean "active", default: true
    t.datetime "next_run_at"
    t.datetime "last_run_at"
    t.string "file_pattern"
    t.text "notification_emails"
    t.string "webhook_url"
    t.integer "max_file_age_hours"
    t.boolean "delete_after_processing", default: false
    t.boolean "retry_failed_files", default: true
    t.json "configuration"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["data_source_id", "active"], name: "index_scheduled_uploads_on_data_source_id_and_active"
    t.index ["data_source_id"], name: "index_scheduled_uploads_on_data_source_id"
    t.index ["frequency"], name: "index_scheduled_uploads_on_frequency"
    t.index ["next_run_at"], name: "index_scheduled_uploads_on_next_run_at"
    t.index ["user_id", "active"], name: "index_scheduled_uploads_on_user_id_and_active"
    t.index ["user_id"], name: "index_scheduled_uploads_on_user_id"
  end

  create_table "system_health_checks", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.string "check_type", null: false
    t.string "status", null: false
    t.decimal "response_time_ms", precision: 10, scale: 2
    t.decimal "uptime_percentage", precision: 5, scale: 2
    t.text "error_message"
    t.json "metadata", default: {}
    t.datetime "checked_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["check_type"], name: "index_system_health_checks_on_check_type"
    t.index ["checked_at"], name: "index_system_health_checks_on_checked_at"
    t.index ["organization_id", "check_type", "checked_at"], name: "idx_health_checks_org_type_checked"
    t.index ["organization_id"], name: "index_system_health_checks_on_organization_id"
    t.index ["status"], name: "index_system_health_checks_on_status"
  end

  create_table "system_metrics", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.decimal "cpu_usage", precision: 5, scale: 2
    t.decimal "memory_usage", precision: 5, scale: 2
    t.decimal "storage_usage", precision: 5, scale: 2
    t.decimal "network_io_read", precision: 10, scale: 2
    t.decimal "network_io_write", precision: 10, scale: 2
    t.integer "active_connections", default: 0
    t.integer "queue_depth", default: 0
    t.datetime "recorded_at", null: false
    t.json "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "recorded_at"], name: "index_system_metrics_on_organization_id_and_recorded_at"
    t.index ["organization_id"], name: "index_system_metrics_on_organization_id"
    t.index ["recorded_at"], name: "index_system_metrics_on_recorded_at"
  end

  create_table "task_executions", force: :cascade do |t|
    t.bigint "task_id", null: false
    t.uuid "execution_id", null: false
    t.string "status", default: "pending", null: false
    t.datetime "started_at"
    t.datetime "completed_at"
    t.jsonb "result", default: {}
    t.text "error_message"
    t.jsonb "error_details", default: {}
    t.bigint "executed_by_id"
    t.integer "duration_seconds"
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["executed_by_id"], name: "index_task_executions_on_executed_by_id"
    t.index ["execution_id"], name: "index_task_executions_on_execution_id", unique: true
    t.index ["started_at"], name: "index_task_executions_on_started_at"
    t.index ["status"], name: "index_task_executions_on_status"
    t.index ["task_id", "created_at"], name: "index_task_executions_on_task_id_and_created_at"
    t.index ["task_id"], name: "index_task_executions_on_task_id"
  end

  create_table "task_templates", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.string "name"
    t.text "description"
    t.string "task_type"
    t.string "execution_mode"
    t.jsonb "template_config"
    t.integer "default_timeout"
    t.integer "default_priority"
    t.integer "default_weight"
    t.string "category"
    t.string "tags"
    t.boolean "active"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_task_templates_on_active"
    t.index ["organization_id"], name: "index_task_templates_on_organization_id"
  end

  create_table "tasks", force: :cascade do |t|
    t.bigint "pipeline_execution_id", null: false
    t.string "name", null: false
    t.text "description"
    t.string "task_type", null: false
    t.string "execution_mode", default: "automated", null: false
    t.string "status", default: "pending", null: false
    t.integer "priority", default: 0
    t.integer "position"
    t.jsonb "configuration", default: {}
    t.jsonb "metadata", default: {}
    t.text "error_message"
    t.datetime "started_at"
    t.datetime "completed_at"
    t.integer "retry_count", default: 0
    t.integer "max_retries", default: 3
    t.integer "timeout_seconds", default: 300
    t.bigint "assignee_id"
    t.uuid "execution_id"
    t.string "depends_on", default: [], array: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "task_template_id"
    t.index ["assignee_id"], name: "index_tasks_on_assignee_id"
    t.index ["created_at"], name: "index_tasks_on_created_at"
    t.index ["execution_id"], name: "index_tasks_on_execution_id", unique: true
    t.index ["execution_mode"], name: "index_tasks_on_execution_mode"
    t.index ["pipeline_execution_id", "position"], name: "index_tasks_on_pipeline_execution_id_and_position"
    t.index ["pipeline_execution_id", "status"], name: "index_tasks_on_pipeline_execution_id_and_status"
    t.index ["pipeline_execution_id"], name: "index_tasks_on_pipeline_execution_id"
    t.index ["priority"], name: "index_tasks_on_priority"
    t.index ["status", "execution_mode"], name: "index_tasks_on_status_and_execution_mode"
    t.index ["status"], name: "index_tasks_on_status"
    t.index ["task_template_id"], name: "index_tasks_on_task_template_id"
  end

  create_table "testimonials", force: :cascade do |t|
    t.string "name", null: false
    t.string "company", null: false
    t.string "role", null: false
    t.text "quote", null: false
    t.integer "rating", null: false
    t.string "highlight", null: false
    t.string "ai_feature", null: false
    t.boolean "active", default: true, null: false
    t.integer "display_order", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active", "display_order"], name: "index_testimonials_on_active_and_display_order"
    t.index ["active"], name: "index_testimonials_on_active"
    t.index ["display_order"], name: "index_testimonials_on_display_order"
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

  create_table "upload_logs", force: :cascade do |t|
    t.bigint "scheduled_upload_id", null: false
    t.string "status", default: "running", null: false
    t.datetime "started_at", null: false
    t.datetime "completed_at"
    t.integer "files_processed", default: 0
    t.integer "files_failed", default: 0
    t.json "details"
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["scheduled_upload_id", "started_at"], name: "index_upload_logs_on_scheduled_upload_id_and_started_at"
    t.index ["scheduled_upload_id"], name: "index_upload_logs_on_scheduled_upload_id"
    t.index ["started_at"], name: "index_upload_logs_on_started_at"
    t.index ["status", "started_at"], name: "index_upload_logs_on_status_and_started_at"
    t.index ["status"], name: "index_upload_logs_on_status"
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
    t.string "dashboard_template"
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["confirmed_at"], name: "index_users_on_confirmed_at"
    t.index ["invitation_token"], name: "index_users_on_invitation_token", unique: true
    t.index ["invited_by_id"], name: "index_users_on_invited_by_id"
    t.index ["organization_id", "email"], name: "index_users_on_organization_id_and_email", unique: true
    t.index ["organization_id"], name: "index_users_on_organization_id"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["role"], name: "index_users_on_role"
  end

  create_table "visualizations", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "data_source_id", null: false
    t.bigint "user_id", null: false
    t.string "title", null: false
    t.string "chart_type", null: false
    t.string "x_column", null: false
    t.string "y_column", null: false
    t.string "aggregation", default: "sum", null: false
    t.string "filter_column"
    t.string "filter_value"
    t.json "config", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["data_source_id", "created_at"], name: "index_visualizations_on_data_source_id_and_created_at"
    t.index ["data_source_id"], name: "index_visualizations_on_data_source_id"
    t.index ["organization_id", "created_at"], name: "index_visualizations_on_organization_id_and_created_at"
    t.index ["organization_id"], name: "index_visualizations_on_organization_id"
    t.index ["user_id", "created_at"], name: "index_visualizations_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_visualizations_on_user_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "ai_agent_configurations", "organizations"
  add_foreign_key "ai_automated_actions", "ai_insights", column: "insight_id"
  add_foreign_key "ai_automated_actions", "organizations"
  add_foreign_key "ai_automated_actions", "users", column: "approved_by_id"
  add_foreign_key "ai_insights", "data_sources"
  add_foreign_key "ai_insights", "organizations"
  add_foreign_key "ai_insights", "presentations"
  add_foreign_key "ai_insights", "users"
  add_foreign_key "ai_presentation_interactions", "organizations"
  add_foreign_key "ai_presentation_interactions", "presentations"
  add_foreign_key "ai_presentation_interactions", "users"
  add_foreign_key "ai_presentation_views", "organizations"
  add_foreign_key "ai_presentation_views", "presentations"
  add_foreign_key "ai_presentation_views", "users"
  add_foreign_key "ai_queries", "organizations"
  add_foreign_key "ai_queries", "users"
  add_foreign_key "alerts", "data_sources"
  add_foreign_key "alerts", "organizations"
  add_foreign_key "alerts", "pipeline_executions"
  add_foreign_key "alerts", "users"
  add_foreign_key "api_keys", "organizations"
  add_foreign_key "api_keys", "users"
  add_foreign_key "audit_logs", "organizations"
  add_foreign_key "audit_logs", "users"
  add_foreign_key "dashboards", "organizations"
  add_foreign_key "data_quality_reports", "data_sources"
  add_foreign_key "data_quality_reports", "users"
  add_foreign_key "data_sources", "organizations"
  add_foreign_key "delivery_logs", "organizations"
  add_foreign_key "delivery_logs", "users"
  add_foreign_key "delivery_preferences", "organizations"
  add_foreign_key "delivery_preferences", "users"
  add_foreign_key "event_timelines", "organizations"
  add_foreign_key "extraction_jobs", "data_sources"
  add_foreign_key "landing_pages", "projects"
  add_foreign_key "landing_pages", "users"
  add_foreign_key "notifications", "organizations"
  add_foreign_key "notifications", "users"
  add_foreign_key "pipeline_executions", "data_sources"
  add_foreign_key "pipeline_executions", "organizations"
  add_foreign_key "pipeline_executions", "users"
  add_foreign_key "pipeline_executions", "users", column: "approved_by_id"
  add_foreign_key "pipeline_metrics", "organizations"
  add_foreign_key "pipeline_metrics", "pipeline_executions"
  add_foreign_key "pipelines", "organizations"
  add_foreign_key "pipelines", "users", column: "created_by_id"
  add_foreign_key "pipelines", "users", column: "last_executed_by_id"
  add_foreign_key "presentations", "organizations"
  add_foreign_key "presentations", "users"
  add_foreign_key "projects", "organizations"
  add_foreign_key "projects", "users"
  add_foreign_key "raw_data_records", "data_sources"
  add_foreign_key "raw_data_records", "extraction_jobs"
  add_foreign_key "raw_data_records", "organizations"
  add_foreign_key "report_components", "report_templates"
  add_foreign_key "report_templates", "organizations"
  add_foreign_key "report_templates", "users"
  add_foreign_key "scheduled_task_runs", "pipeline_executions"
  add_foreign_key "scheduled_task_runs", "scheduled_tasks"
  add_foreign_key "scheduled_task_runs", "tasks"
  add_foreign_key "scheduled_tasks", "organizations"
  add_foreign_key "scheduled_tasks", "task_templates"
  add_foreign_key "scheduled_tasks", "users", column: "created_by_id"
  add_foreign_key "scheduled_uploads", "data_sources"
  add_foreign_key "scheduled_uploads", "users"
  add_foreign_key "system_health_checks", "organizations"
  add_foreign_key "system_metrics", "organizations"
  add_foreign_key "task_executions", "tasks"
  add_foreign_key "task_executions", "users", column: "executed_by_id"
  add_foreign_key "task_templates", "organizations"
  add_foreign_key "tasks", "pipeline_executions"
  add_foreign_key "tasks", "task_templates"
  add_foreign_key "tasks", "users", column: "assignee_id"
  add_foreign_key "transformation_jobs", "organizations"
  add_foreign_key "upload_logs", "scheduled_uploads"
  add_foreign_key "users", "organizations"
  add_foreign_key "users", "users", column: "invited_by_id"
  add_foreign_key "visualizations", "data_sources"
  add_foreign_key "visualizations", "organizations"
  add_foreign_key "visualizations", "users"
end
