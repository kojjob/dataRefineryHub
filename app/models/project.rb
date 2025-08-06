class Project < ApplicationRecord
  belongs_to :organization
  belongs_to :user
  has_many :landing_pages, dependent: :destroy

  validates :name, presence: true, length: { maximum: 255 }
  validates :slug, presence: true, uniqueness: { scope: :organization_id }
  validates :status, inclusion: { in: %w[active inactive archived] }

  before_validation :generate_slug, if: -> { slug.blank? && name.present? }

  scope :active, -> { where(status: "active") }
  scope :for_organization, ->(org) { where(organization: org) }
  scope :recent, -> { order(created_at: :desc) }

  def to_param
    slug
  end

  def active?
    status == "active"
  end

  def published_landing_pages
    landing_pages.where(published: true)
  end

  def landing_pages_count
    landing_pages.count
  end

  private

  def generate_slug
    base_slug = name.parameterize
    counter = 1
    potential_slug = base_slug

    while organization.projects.where(slug: potential_slug).where.not(id: id).exists?
      potential_slug = "#{base_slug}-#{counter}"
      counter += 1
    end

    self.slug = potential_slug
  end
end
