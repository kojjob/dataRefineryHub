class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable,
         :confirmable, :trackable
  belongs_to :organization
  belongs_to :invited_by, class_name: 'User', optional: true

  ROLES = %w[owner admin member viewer].freeze

  has_many :audit_logs, dependent: :destroy
  has_many :sent_invitations, class_name: 'User', foreign_key: 'invited_by_id', dependent: :nullify
  
  # Active Storage associations
  has_one_attached :avatar do |attachable|
    attachable.variant :thumb, resize_to_limit: [100, 100]
    attachable.variant :medium, resize_to_limit: [300, 300]
  end

  # Devise validations with organization scope
  validates :email, presence: true, uniqueness: { scope: :organization_id, case_sensitive: false },
            format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, presence: true, length: { minimum: 6 }, confirmation: true, if: :password_required?
  
  # Override Devise's find_for_authentication to support organization-scoped email
  def self.find_for_authentication(warden_conditions)
    conditions = warden_conditions.dup
    if (email = conditions.delete(:email))
      # For now, just use the standard Devise behavior
      # In production, you might want to add organization context here
      where(conditions.to_h).where(["lower(email) = :value", { value: email.downcase }]).first
    else
      where(conditions.to_h).first
    end
  end
  validates :first_name, presence: true, length: { minimum: 1, maximum: 50 }
  validates :last_name, presence: true, length: { minimum: 1, maximum: 50 }
  validates :role, inclusion: { in: ROLES }
  
  # Avatar validations
  validate :acceptable_avatar

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

  def avatar_url(variant = :thumb)
    return nil unless avatar.attached?
    
    if variant == :original
      Rails.application.routes.url_helpers.rails_blob_url(avatar, only_path: true)
    else
      Rails.application.routes.url_helpers.rails_representation_url(avatar.variant(variant), only_path: true)
    end
  rescue => e
    Rails.logger.error "Error generating avatar URL: #{e.message}"
    nil
  end

  def has_avatar?
    avatar.attached?
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

  def password_required?
    !persisted? || !password.nil? || !password_confirmation.nil?
  end

  def set_default_role
    # Only set default role if role is blank/nil or explicitly 'member'
    # This allows for explicit role assignment while still handling first user logic
    if role.blank?
      self.role = 'member'
    end
    
    # Check if this is the first user in the organization and should be owner
    if organization_id.present? && (role.blank? || role == 'member')
      existing_users_count = User.where(organization_id: organization_id).count
      if existing_users_count == 0
        self.role = 'owner'
      end
    end
  end

  def normalize_email
    self.email = email&.downcase&.strip
  end

  def acceptable_avatar
    return unless avatar.attached?

    acceptable_types = ["image/jpeg", "image/jpg", "image/png", "image/gif"]
    unless acceptable_types.include?(avatar.blob.content_type)
      errors.add(:avatar, "must be a JPEG, PNG, or GIF")
    end

    unless avatar.blob.byte_size <= 5.megabytes
      errors.add(:avatar, "must be less than 5MB")
    end
  end
end
