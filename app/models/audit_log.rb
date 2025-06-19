class AuditLog < ApplicationRecord
  belongs_to :organization
  belongs_to :user, optional: true # System actions may not have a user

  ACTIONS = %w[
    create update delete
    login logout password_change
    invite_user accept_invitation revoke_invitation
    data_source_connect data_source_disconnect data_source_sync
    dashboard_create dashboard_update dashboard_delete dashboard_view
    api_key_create api_key_revoke
    export_data import_data
    plan_upgrade plan_downgrade
    payment_success payment_failed
    organization_suspend organization_activate
  ].freeze

  validates :action, presence: true, inclusion: { in: ACTIONS }
  validates :resource_type, presence: true
  validates :performed_at, presence: true

  scope :by_action, ->(action) { where(action: action) }
  scope :by_resource_type, ->(type) { where(resource_type: type) }
  scope :by_user, ->(user) { where(user: user) }
  scope :recent, -> { order(performed_at: :desc) }
  scope :for_date_range, ->(start_date, end_date) { where(performed_at: start_date..end_date) }

  before_validation :set_performed_at, on: :create

  def self.log_action(organization:, user: nil, action:, resource: nil, details: {}, ip_address: nil, user_agent: nil)
    create!(
      organization: organization,
      user: user,
      action: action.to_s,
      resource_type: resource&.class&.name,
      resource_id: resource&.id&.to_s,
      details: details,
      ip_address: ip_address,
      user_agent: user_agent
    )
  end

  def resource
    return nil unless resource_type && resource_id
    
    resource_type.constantize.find_by(id: resource_id)
  rescue NameError, ActiveRecord::RecordNotFound
    nil
  end

  def user_description
    user&.full_name || 'System'
  end

  def action_description
    case action
    when 'create' then "created #{resource_type&.humanize&.downcase}"
    when 'update' then "updated #{resource_type&.humanize&.downcase}"
    when 'delete' then "deleted #{resource_type&.humanize&.downcase}"
    when 'login' then 'signed in'
    when 'logout' then 'signed out'
    when 'password_change' then 'changed password'
    when 'invite_user' then 'invited user'
    when 'accept_invitation' then 'accepted invitation'
    when 'revoke_invitation' then 'revoked invitation'
    when 'data_source_connect' then 'connected data source'
    when 'data_source_disconnect' then 'disconnected data source'
    when 'data_source_sync' then 'synchronized data source'
    when 'dashboard_create' then 'created dashboard'
    when 'dashboard_update' then 'updated dashboard'
    when 'dashboard_delete' then 'deleted dashboard'
    when 'dashboard_view' then 'viewed dashboard'
    when 'api_key_create' then 'created API key'
    when 'api_key_revoke' then 'revoked API key'
    when 'export_data' then 'exported data'
    when 'import_data' then 'imported data'
    when 'plan_upgrade' then 'upgraded plan'
    when 'plan_downgrade' then 'downgraded plan'
    when 'payment_success' then 'successful payment'
    when 'payment_failed' then 'failed payment'
    when 'organization_suspend' then 'suspended organization'
    when 'organization_activate' then 'activated organization'
    else action.humanize.downcase
    end
  end

  def full_description
    "#{user_description} #{action_description}"
  end

  private

  def set_performed_at
    self.performed_at ||= Time.current
  end
end
