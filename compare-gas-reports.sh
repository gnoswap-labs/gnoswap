#!/bin/bash

# Exit on error
set -e

# Get commit hashes from arguments
LATEST="$1"
PREVIOUS="$2"

# Check if arguments are provided
if [ -z "$LATEST" ] || [ -z "$PREVIOUS" ]; then
    echo "❌ Error: Please provide latest and previous commit hashes"
    echo "Usage: $0 <latest_commit> <previous_commit>"
    echo "Example: $0 3267d134 bd411f6e"
    exit 1
fi

# Define directories
REPORTS_DIR="reports"
LATEST_DIR="$REPORTS_DIR/$LATEST"
PREVIOUS_DIR="$REPORTS_DIR/$PREVIOUS"
DIFF_DIR="$REPORTS_DIR/compare_${LATEST}_${PREVIOUS}"

# Check if directories exist
if [ ! -d "$LATEST_DIR" ]; then
    echo "❌ Error: Latest commit directory not found: $LATEST_DIR"
    exit 1
fi

if [ ! -d "$PREVIOUS_DIR" ]; then
    echo "❌ Error: Previous commit directory not found: $PREVIOUS_DIR"
    exit 1
fi

# Create output directory
mkdir -p "$DIFF_DIR"

echo "📊 Comparing reports:"
echo "  Latest:   $LATEST_DIR"
echo "  Previous: $PREVIOUS_DIR"
echo "  Output:   $DIFF_DIR"
echo ""

# Get all TSV files from latest directory
TSV_FILES=("$LATEST_DIR"/*.tsv)

if [ ! -e "${TSV_FILES[0]}" ]; then
    echo "❌ No TSV files found in $LATEST_DIR"
    exit 1
fi

TOTAL=${#TSV_FILES[@]}
PROCESSED=0
SKIPPED=0
CURRENT=0

# Process each TSV file
for latest_file in "${TSV_FILES[@]}"; do
    CURRENT=$((CURRENT + 1))
    
    # Get test name
    test_name=$(basename "$latest_file")
    previous_file="$PREVIOUS_DIR/$test_name"
    output_file="$DIFF_DIR/$test_name"
    
    echo "[$CURRENT/$TOTAL] Processing: $test_name"
    
    # Check if previous file exists
    if [ ! -f "$previous_file" ]; then
        echo "  ⏭️  Skipped: Previous file not found"
        SKIPPED=$((SKIPPED + 1))
        echo ""
        continue
    fi
    
    # Count rows (excluding header)
    latest_rows=$(tail -n +2 "$latest_file" | wc -l | tr -d ' ')
    previous_rows=$(tail -n +2 "$previous_file" | wc -l | tr -d ' ')
    
    # Check if row counts match
    if [ "$latest_rows" != "$previous_rows" ]; then
        echo "  ⚠️  Row count mismatch: $latest_rows vs $previous_rows"
        SKIPPED=$((SKIPPED + 1))
        echo ""
        continue
    fi
    
    # Generate comparison TSV using awk
    {
        # Write header
        echo -e "Name\tTotal Gas Used (Latest)\tTotal Gas Used (Previous)\tStorage (Latest)\tStorage (Previous)\tGas Changes\tStorage Changes"
        
        # Process data rows
        awk -F'\t' '
        NR == 1 { next }  # Skip header in latest file
        FNR == NR {
            # Store latest file data
            latest_gas[NR] = $3     # Total Gas Used
            latest_storage[NR] = $5  # Storage (bytes)
            name[NR] = $1           # Name
            next
        }
        FNR == 1 { next }  # Skip header in previous file
        {
            # Compare with previous file
            row = FNR
            prev_gas = $3
            prev_storage = $5
            
            # Calculate changes
            gas_diff = latest_gas[row] - prev_gas
            storage_diff = latest_storage[row] - prev_storage
            
            # Format changes with +/- sign
            gas_change = gas_diff
            if (gas_diff > 0) gas_change = "+" gas_diff
            
            storage_change = storage_diff
            if (storage_diff > 0) storage_change = "+" storage_diff
            
            # Output comparison row
            print name[row] "\t" latest_gas[row] "\t" prev_gas "\t" latest_storage[row] "\t" prev_storage "\t" gas_change "\t" storage_change
        }
        ' "$latest_file" "$previous_file"
    } > "$output_file"
    
    echo "  ✓ Generated: $output_file"
    PROCESSED=$((PROCESSED + 1))
    echo ""
done

echo "🎉 Comparison completed!"
echo "  Processed: $PROCESSED files"
echo "  Skipped:   $SKIPPED files"
echo "  Output:    $DIFF_DIR"

