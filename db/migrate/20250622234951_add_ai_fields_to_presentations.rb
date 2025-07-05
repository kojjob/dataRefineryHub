class AddAiFieldsToPresentations < ActiveRecord::Migration[8.0]
  def change
    add_column :presentations, :configuration, :text
    add_column :presentations, :metadata, :text
    add_column :presentations, :interactive_elements, :text
    add_column :presentations, :presentation_type, :string
    add_column :presentations, :engagement_score, :decimal, precision: 5, scale: 2, default: 0.0
    add_column :presentations, :views_count, :integer, default: 0
    add_column :presentations, :live_data_enabled, :boolean, default: false
    add_column :presentations, :shared, :boolean, default: false
    add_column :presentations, :published_at, :datetime

    add_index :presentations, :presentation_type
    add_index :presentations, :engagement_score
    add_index :presentations, :published_at
    add_index :presentations, [ :shared, :published_at ]
  end
end
