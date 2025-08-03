class LandingPage < ApplicationRecord
  belongs_to :project
  belongs_to :user

  validates :name, presence: true, length: { maximum: 255 }
  validates :slug, presence: true, uniqueness: { scope: :project_id }
  validates :template_type, inclusion: { in: %w[standard shopify_killer ecommerce saas marketing] }

  before_validation :generate_slug, if: -> { slug.blank? && name.present? }

  scope :published, -> { where(published: true) }
  scope :drafts, -> { where(published: false) }
  scope :by_template, ->(type) { where(template_type: type) }
  scope :recent, -> { order(created_at: :desc) }

  def to_param
    slug
  end

  def published?
    published && published_at.present?
  end

  def draft?
    !published?
  end

  def organization
    project.organization
  end

  def publish!
    update!(published: true, published_at: Time.current)
  end

  def unpublish!
    update!(published: false, published_at: nil)
  end

  def content_json
    return {} if content.blank?
    
    begin
      JSON.parse(content)
    rescue JSON::ParserError
      {}
    end
  end

  def content_json=(data)
    self.content = data.to_json
  end

  def preview_url
    Rails.application.routes.url_helpers.preview_project_landing_page_path(
      project_slug: project.slug,
      slug: slug
    )
  end

  def published_url
    # This would be the actual public URL when deployed
    if published?
      "#{Rails.application.config.action_mailer.default_url_options[:host]}/#{project.slug}/#{slug}"
    else
      nil
    end
  end

  private

  def generate_slug
    base_slug = name.parameterize
    counter = 1
    potential_slug = base_slug

    while project.landing_pages.where(slug: potential_slug).where.not(id: id).exists?
      potential_slug = "#{base_slug}-#{counter}"
      counter += 1
    end

    self.slug = potential_slug
  end
end
