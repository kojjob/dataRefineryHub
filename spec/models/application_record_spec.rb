require 'rails_helper'

RSpec.describe ApplicationRecord, type: :model do
  describe 'base model functionality' do
    it 'is an abstract class' do
      expect(described_class).to be_abstract_class
    end

    it 'inherits from ActiveRecord::Base' do
      expect(described_class.superclass).to eq(ActiveRecord::Base)
    end
  end
end
