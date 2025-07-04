require 'rails_helper'

RSpec.describe TaskTemplate, type: :model do
  let(:organization) { create(:organization) }
  
  describe 'associations' do
    it { should belong_to(:organization) }
    it { should have_many(:tasks) }
  end
  
  describe 'validations' do
    subject { build(:task_template, organization: organization) }
    
    it { should validate_presence_of(:name) }
    it { should validate_uniqueness_of(:name).scoped_to(:organization_id) }
    it { should validate_presence_of(:task_type) }
    it { should validate_inclusion_of(:task_type).in_array(Task::TASK_TYPES) }
    it { should validate_presence_of(:execution_mode) }
    it { should validate_inclusion_of(:execution_mode).in_array(Task::EXECUTION_MODES) }
    it { should validate_presence_of(:category) }
    it { should validate_inclusion_of(:category).in_array(TaskTemplate::CATEGORIES) }
    it { should validate_numericality_of(:default_timeout).is_greater_than(0).allow_nil }
    it { should validate_numericality_of(:default_priority).is_greater_than_or_equal_to(0).allow_nil }
    it { should validate_numericality_of(:default_weight).is_greater_than_or_equal_to(0).allow_nil }
  end
  
  describe 'scopes' do
    let!(:active_template) { create(:task_template, organization: organization, active: true) }
    let!(:inactive_template) { create(:task_template, organization: organization, active: false) }
    let!(:extraction_template) { create(:task_template, organization: organization, category: 'extraction') }
    let!(:validation_template) { create(:task_template, organization: organization, category: 'validation') }
    
    describe '.active' do
      it 'returns only active templates' do
        expect(TaskTemplate.active).to include(active_template)
        expect(TaskTemplate.active).not_to include(inactive_template)
      end
    end
    
    describe '.by_category' do
      it 'returns templates by category' do
        expect(TaskTemplate.by_category('extraction')).to include(extraction_template)
        expect(TaskTemplate.by_category('extraction')).not_to include(validation_template)
      end
    end
    
    describe '.search' do
      let!(:api_template) { create(:task_template, 
        organization: organization, 
        name: 'API Extraction',
        description: 'Extract data from APIs'
      ) }
      
      it 'searches by name' do
        expect(TaskTemplate.search('API')).to include(api_template)
      end
      
      it 'searches by description' do
        expect(TaskTemplate.search('Extract')).to include(api_template)
      end
    end
  end
  
  describe '#create_task_from_template' do
    let(:template) { create(:task_template, 
      organization: organization,
      name: 'Test Template',
      task_type: 'extraction',
      execution_mode: 'automated',
      template_config: { api_key: 'default_key' },
      default_timeout: 600
    ) }
    let(:pipeline_execution) { create(:pipeline_execution, organization: organization) }
    
    it 'creates a task with template attributes' do
      task = template.create_task_from_template(pipeline_execution)
      
      expect(task).to be_persisted
      expect(task.name).to eq('Test Template')
      expect(task.task_type).to eq('extraction')
      expect(task.execution_mode).to eq('automated')
      expect(task.timeout_seconds).to eq(600)
    end
    
    it 'allows overriding attributes' do
      task = template.create_task_from_template(pipeline_execution, 
        name: 'Custom Name',
        timeout_seconds: 300
      )
      
      expect(task.name).to eq('Custom Name')
      expect(task.timeout_seconds).to eq(300)
    end
    
    it 'merges configurations' do
      task = template.create_task_from_template(pipeline_execution,
        configuration: { endpoint: '/users' }
      )
      
      expect(task.configuration['api_key']).to eq('default_key')
      expect(task.configuration['endpoint']).to eq('/users')
    end
    
    it 'adds template metadata' do
      task = template.create_task_from_template(pipeline_execution)
      
      expect(task.metadata['template_id']).to eq(template.id)
      expect(task.metadata['template_name']).to eq('Test Template')
      expect(task.metadata['created_from_template']).to be true
    end
  end
  
  describe '#duplicate_template' do
    let(:template) { create(:task_template, 
      organization: organization,
      name: 'Original Template',
      active: true
    ) }
    
    it 'creates a copy with modified name' do
      copy = template.duplicate_template
      
      expect(copy).to be_persisted
      expect(copy.name).to eq('Original Template (Copy)')
      expect(copy.active).to be false
    end
    
    it 'accepts custom name' do
      copy = template.duplicate_template('New Template')
      
      expect(copy.name).to eq('New Template')
    end
  end
  
  describe '#tag_list' do
    let(:template) { create(:task_template, organization: organization, tags: 'shopify, E-commerce, API') }
    
    it 'returns lowercase tag array' do
      expect(template.tag_list).to eq(['shopify', 'e-commerce', 'api'])
    end
  end
  
  describe '#add_tag' do
    let(:template) { create(:task_template, organization: organization, tags: 'shopify') }
    
    it 'adds new tag' do
      template.add_tag('API')
      expect(template.tag_list).to include('api')
    end
    
    it 'prevents duplicates' do
      template.add_tag('shopify')
      expect(template.tag_list.count('shopify')).to eq(1)
    end
  end
  
  describe '#remove_tag' do
    let(:template) { create(:task_template, organization: organization, tags: 'shopify, api') }
    
    it 'removes tag' do
      template.remove_tag('API')
      expect(template.tag_list).not_to include('api')
      expect(template.tag_list).to include('shopify')
    end
  end
  
  describe '#applicable_for?' do
    let(:template) { create(:task_template, organization: organization, tags: 'shopify, ecommerce') }
    
    it 'returns true for matching pipeline type' do
      expect(template.applicable_for?('shopify')).to be true
      expect(template.applicable_for?('Ecommerce')).to be true
    end
    
    it 'returns false for non-matching type' do
      expect(template.applicable_for?('amazon')).to be false
    end
    
    it 'returns true if no tags' do
      template.update(tags: '')
      expect(template.applicable_for?('anything')).to be true
    end
  end
  
  describe '.common_templates' do
    it 'returns hash of template categories' do
      templates = TaskTemplate.common_templates
      
      expect(templates).to have_key(:extraction)
      expect(templates).to have_key(:transformation)
      expect(templates).to have_key(:validation)
      expect(templates).to have_key(:notification)
      expect(templates).to have_key(:approval)
    end
    
    it 'includes valid template attributes' do
      template = TaskTemplate.common_templates[:extraction].first
      
      expect(template).to have_key(:name)
      expect(template).to have_key(:description)
      expect(template).to have_key(:task_type)
      expect(template).to have_key(:execution_mode)
      expect(template).to have_key(:category)
      expect(template).to have_key(:template_config)
    end
  end
  
  describe '.create_default_templates_for' do
    it 'creates all common templates for organization' do
      expect {
        TaskTemplate.create_default_templates_for(organization)
      }.to change { organization.task_templates.count }.by_at_least(10)
    end
    
    it 'creates active templates with defaults' do
      TaskTemplate.create_default_templates_for(organization)
      
      template = organization.task_templates.first
      expect(template.active).to be true
      expect(template.default_timeout).to eq(300)
      expect(template.default_priority).to eq(0)
      expect(template.default_weight).to eq(1)
    end
  end
end