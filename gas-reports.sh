#!/bin/bash

# Exit on error
set -e

# Tests to exclude when running 'all'
EXCLUDE_TESTS=(
    # Add test names to exclude here
    "deploy"
    "gov_governance_cancel_active_proposal_should_fail"
    "gov_governance_execute_text_proposal_should_fail"
    "gov_governance_execute_unfinished_proposal_should_fail"
    "launchpad_collect_left_before_project_ended_should_fail"
    "launchpad_collect_protocol_fee_failure"
    "launchpad_deposit_gns_to_inactivated_project_should_fail"
    "staker_end_non_existent_external_incentive_fail"
    "upgradable_broken_version_recovery"
    "upgradable_data_consistency_after_ugrade"
    "upgradable_gov_staker_upgrade"
    "upgradable_governance_upgrade"
    "upgradable_initializer_security"
    "upgradable_launchpad_upgrade"
    "upgradable_pool_upgrade"
    "upgradable_position_upgrade"
    "upgradable_protocol_fee_upgrade"
    "upgradable_rich_state_preservation"
    "upgradable_router_upgrade"
    "upgradable_staker_upgrade"
    "upgradable_store_permission_enforcement"
)

# Get test name from argument
TEST="$1"

# Check if TEST argument is provided
if [ -z "$TEST" ]; then
    echo "❌ Error: Please provide a test name or 'all'"
    echo "Usage: $0 <test_name|all>"
    echo "Example: $0 all"
    echo "Example: $0 upgradable_router_upgrade"
    exit 1
fi

# Get commit hash for folder naming
COMMIT_HASH=$(git rev-parse --short HEAD)
REPORT_DIR="reports/${COMMIT_HASH}"

# Create report directory if it doesn't exist
if [ ! -d "$REPORT_DIR" ]; then
    echo "📁 Creating report directory: $REPORT_DIR"
    mkdir -p "$REPORT_DIR"
else
    echo "📁 Using existing report directory: $REPORT_DIR"
fi

# Check if TEST is "all"
if [ "$TEST" = "all" ]; then
    echo "🔍 Fetching all integration tests..."
    
    # Get all tests from make integration-test-list
    ALL_TESTS=$(make integration-test-list)
    
    # Filter out excluded tests
    FILTERED_TESTS=()
    for test in $ALL_TESTS; do
        skip=false
        for exclude in "${EXCLUDE_TESTS[@]}"; do
            if [ "$test" = "$exclude" ]; then
                skip=true
                break
            fi
        done
        
        if [ "$skip" = false ]; then
            FILTERED_TESTS+=("$test")
        fi
    done
    
    # Count total tests after filtering
    TOTAL=${#FILTERED_TESTS[@]}
    CURRENT=0
    
    echo "✅ Found $TOTAL tests to run (${#EXCLUDE_TESTS[@]} excluded)"
    echo ""
    
    # Run each filtered test
    for test in "${FILTERED_TESTS[@]}"; do
        CURRENT=$((CURRENT + 1))
        echo "[$CURRENT/$TOTAL] Running test: $test"
        
        /Users/onbloc/go/bin/txtar-bless -test "$test" \
            -integration-dir "/Users/onbloc/Workspace/gnoswap/gno/gno.land/pkg/integration" \
            -report \
            -tsv \
            -output "$REPORT_DIR/${test}.tsv"
        
        echo "  ✓ Saved: $REPORT_DIR/${test}.tsv"
        echo ""
    done
    
    echo "🎉 All tests completed!"
else
    # Run single test
    echo "🧪 Running single test: $TEST"
    
    /Users/onbloc/go/bin/txtar-bless -test "$TEST" \
        -integration-dir "/Users/onbloc/Workspace/gnoswap/gno/gno.land/pkg/integration" \
        -report \
        -tsv \
        -output "$REPORT_DIR/${TEST}.tsv"
    
    echo "✅ Test completed!"
    echo "  ✓ Saved: $REPORT_DIR/${TEST}.tsv"
fi

echo ""
echo "📊 Reports saved to: $REPORT_DIR"
