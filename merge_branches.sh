#\!/bin/bash

# List of branches to merge
branches=(
    "feature/api-endpoints"
    "feature/authentication-authorization"
    "feature/base-extractor-framework"
    "feature/comprehensive-theme-system"
    "feature/dashboard-redesign"
    "feature/data-quality-monitoring"
    "feature/data-sources-wizard-dynamic-config"
    "feature/enhanced-data-preview"
    "feature/enhanced-file-upload"
    "feature/enhanced-sidebar-navigation"
    "feature/etl-pipeline-monitoring"
    "feature/hybrid-task-execution"
    "feature/improve-data-source-selection-ux"
    "feature/modern-dashboard-ui"
    "feature/phase1-core-infrastructure"
    "feature/pipeline-dashboard"
    "feature/premium-landing-redesign"
    "feature/premium-visual-enhancements"
    "feature/real-time-processing-pipeline"
    "feature/real-time-processing-pipeline-enhancement"
    "feature/task-management-ui"
    "feature/task-templates"
    "fix/route-conflict-users-sign-out"
    "fix/sign-out-method-rails7"
)

echo "Starting branch merge process..."
echo "Current branch: $(git branch --show-current)"
echo ""

# Counter for successful merges
success_count=0
fail_count=0

# Merge each branch
for branch in "${branches[@]}"; do
    echo "================================================"
    echo "Merging branch: $branch"
    echo "================================================"
    
    if git merge --no-ff "$branch" -m "Merge branch '$branch' into dev"; then
        echo "✅ Successfully merged $branch"
        ((success_count++))
    else
        echo "❌ Failed to merge $branch - conflicts detected"
        echo "Please resolve conflicts and run: git commit"
        echo "Then continue with the next branch"
        ((fail_count++))
        exit 1
    fi
    echo ""
done

echo "================================================"
echo "Merge Summary:"
echo "✅ Successful merges: $success_count"
echo "❌ Failed merges: $fail_count"
echo "================================================"
