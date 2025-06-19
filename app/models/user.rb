class User < ApplicationRecord
  belongs_to :organization
  belongs_to :invited_by, class_name: 'User', optional: true

  ROLES = %w[owner admin member viewer].freeze

  has_many :audit_logs, dependent: :destroy
  has_many :sent_invitations, class_name: 'User', foreign_key: 'invited_by_id', dependent: :nullify

  validates :email, presence: true, uniqueness: { scope: :organization_id },
            format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :first_name, presence: true, length: { minimum: 1, maximum: 50 }
  validates :last_name, presence: true, length: { minimum: 1, maximum: 50 }
  validates :role, inclusion: { in: ROLES }

  scope :by_role, ->(role) { where(role: role) }
  scope :confirmed, -> { where.not(confirmed_at: nil) }
  scope :pending_confirmation, -> { where(confirmed_at: nil) }
  scope :invited, -> { where.not(invitation_token: nil, invitation_accepted_at: nil) }

  before_validation :set_default_role, on: :create
  before_validation :normalize_email

  def full_name
    "#{first_name} #{last_name}".strip
  end

  def initials
    "#{first_name&.first}#{last_name&.first}".upcase
  end

  def owner?
    role == 'owner'
  end

  def admin?
    role == 'admin'
  end

  def member?
    role == 'member'
  end

  def viewer?
    role == 'viewer'
  end

  def confirmed?
    confirmed_at.present?
  end

  def invited?
    invitation_token.present? && invitation_accepted_at.nil?
  end

  def can_manage_organization?
    owner? || admin?
  end

  def can_manage_users?
    owner? || admin?
  end

  def can_manage_data_sources?
    owner? || admin? || member?
  end

  def can_view_analytics?
    true # All users can view analytics
  end

  def can_export_data?
    owner? || admin? || member?
  end

  def can_manage_api_keys?
    owner? || admin?
  end

  def role_hierarchy_level
    case role
    when 'owner' then 4
    when 'admin' then 3
    when 'member' then 2
    when 'viewer' then 1
    else 0
    end
  end

  def can_manage_user?(target_user)
    return false if target_user == self
    return false unless can_manage_users?
    return false if target_user.organization != organization
    
    role_hierarchy_level > target_user.role_hierarchy_level
  end

  private

  def set_default_role
    self.role ||= 'member'
    
    # First user in organization becomes owner
    if organization&.users&.empty?
      self.role = 'owner'
    end
  end

  def normalize_email
    self.email = email&.downcase&.strip
  end
end
