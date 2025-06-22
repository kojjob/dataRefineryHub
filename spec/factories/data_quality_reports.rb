FactoryBot.define do
  factory :data_quality_report do
    association :data_source
    overall_score { 85.0 }
    completeness_score { 90.0 }
    accuracy_score { 85.0 }
    consistency_score { 80.0 }
    validity_score { 90.0 }
    timeliness_score { 75.0 }
    issues_count { 2 }
    total_records { 1000 }
    valid_records { 950 }
    run_at { 1.hour.ago }
    report_data { 
      {
        issues: [
          {
            type: 'presence',
            message: '25 presence validation errors found',
            severity: 'high',
            count: 25
          },
          {
            type: 'format',
            message: '15 format validation errors found',
            severity: 'medium',
            count: 15
          }
        ],
        recommendations: [
          {
            title: 'Fix Missing Data',
            description: 'Review data collection process to reduce missing fields',
            priority: 'high',
            impact: 'high'
          }
        ],
        validation_errors: [],
        quality_metrics: {}
      }
    }

    trait :excellent_quality do
      overall_score { 95.0 }
      completeness_score { 98.0 }
      accuracy_score { 96.0 }
      consistency_score { 92.0 }
      validity_score { 97.0 }
      timeliness_score { 90.0 }
      issues_count { 0 }
      valid_records { 1000 }
    end

    trait :poor_quality do
      overall_score { 65.0 }
      completeness_score { 70.0 }
      accuracy_score { 60.0 }
      consistency_score { 65.0 }
      validity_score { 68.0 }
      timeliness_score { 62.0 }
      issues_count { 15 }
      valid_records { 650 }
    end
  end
end
