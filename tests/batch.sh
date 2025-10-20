#!/bin/bash

# Number of concurrent requests
CONCURRENT_REQUESTS=50

# Test result file
TEST_RESULT_FILE="test_results_$(date '+%Y%m%d_%H%M%S').txt"
TEMP_DIR="temp_responses"

# Create temp directory for individual responses
mkdir -p "$TEMP_DIR"

# Function to execute a single curl request
execute_curl() {
    local request_num=$1
    local temp_file="${TEMP_DIR}/response_${request_num}.txt"
    local rpc_url="http://localhost:26657/"
    local data='{"id":"'$request_num'","jsonrpc":"2.0","method":"abci_query","params":[".app/simulate","CpwBCgovdm0ubV9jYWxsEo0BCihnMTcyOTBjd3ZtcmFwdnA4Njl4Zm5oaGF3YThzbTllZHB1ZnphdDdkIhlnbm8ubGFuZC9yL2dub2xhbmQvd3Vnbm90KgdBcHByb3ZlMihnMTQ4dGphbWo4MHl5cm0zMDl6N3JrNjkwYW4yMnRoZDJsM3o4YW5rMhM5MjIzMzcyMDM2ODU0Nzc1ODA3CpwBCgovdm0ubV9jYWxsEo0BCihnMTcyOTBjd3ZtcmFwdnA4Njl4Zm5oaGF3YThzbTllZHB1ZnphdDdkIhlnbm8ubGFuZC9yL2dub2xhbmQvd3Vnbm90KgdBcHByb3ZlMihnMXE2NDZjdHpodm42MHY0OTJ4OHVjdnlxbnJqMnczMGN3aDZlZms1MhM5MjIzMzcyMDM2ODU0Nzc1ODA3CpkBCgovdm0ubV9jYWxsEooBCihnMTcyOTBjd3ZtcmFwdnA4Njl4Zm5oaGF3YThzbTllZHB1ZnphdDdkIhZnbm8ubGFuZC9yL2dub3N3YXAvZ25zKgdBcHByb3ZlMihnMTQ4dGphbWo4MHl5cm0zMDl6N3JrNjkwYW4yMnRoZDJsM3o4YW5rMhM5MjIzMzcyMDM2ODU0Nzc1ODA3CqcCCgovdm0ubV9jYWxsEpgCCihnMTcyOTBjd3ZtcmFwdnA4Njl4Zm5oaGF3YThzbTllZHB1ZnphdDdkEg0xMDAwMDAwMHVnbm90Ih5nbm8ubGFuZC9yL2dub3N3YXAvdjEvcG9zaXRpb24qBE1pbnQyBGdub3QyFmduby5sYW5kL3IvZ25vc3dhcC9nbnMyBDMwMDAyBS02ODQwMgQ3MDIwMggxMDAwMDAwMDIIMTAwMDgwNDMyBzk5NTAwMDAyBzk5NTgwMDMyCjcyODI1NzExNDAyKGcxNzI5MGN3dm1yYXB2cDg2OXhmbmhoYXdhOHNtOWVkcHVmemF0N2QyKGcxNzI5MGN3dm1yYXB2cDg2OXhmbmhoYXdhOHNtOWVkcHVmemF0N2QyABIOCIDQrPMOEgYxdWdub3Qafgo6ChMvdG0uUHViS2V5U2VjcDI1NmsxEiMKIQLRsgOpd1CK1Lqec+8l6PdG1w3F1Dpi4it+GD334EOqQBJAG13JBZkfE4VFOJLozNiHXTKjtwLjhGrMCDFurxPhn1ICm9sWSbO5uhakoPPXZshjaGZmkmF3Sc6PUXrLSq2rgQ==","0",false]}'
    
    # Record start time
    start_time=$(date +%s.%N)
    
    # Execute curl and capture response with status code
    response=$(curl "$rpc_url" \
        -w "\n==CURL_INFO==\nHTTP_CODE:%{http_code}\nTIME_TOTAL:%{time_total}\nTIME_NAMELOOKUP:%{time_namelookup}\nTIME_CONNECT:%{time_connect}\nTIME_APPCONNECT:%{time_appconnect}\nTIME_PRETRANSFER:%{time_pretransfer}\nTIME_REDIRECT:%{time_redirect}\nTIME_STARTTRANSFER:%{time_starttransfer}\nSIZE_DOWNLOAD:%{size_download}\nSPEED_DOWNLOAD:%{speed_download}\n" \
        -H 'accept: application/json, text/plain, */*' \
        -H 'cache-control: no-cache' \
        -H 'content-type: application/json' \
        -H 'pragma: no-cache' \
        -H 'priority: u=1, i' \
        --data-raw "$data" \
        -s 2>&1)
    
    # Record end time
    end_time=$(date +%s.%N)
    
    # Save response to temp file
    echo "$response" > "$temp_file"
    
    # Extract metrics
    http_code=$(echo "$response" | grep "HTTP_CODE:" | cut -d':' -f2)
    time_total=$(echo "$response" | grep "TIME_TOTAL:" | cut -d':' -f2)
    
    # Display progress
    echo "Request #${request_num} completed - HTTP: ${http_code} - Time: ${time_total}s"
}

# Initialize test result file
{
    echo "=================================================="
    echo "           LOAD TEST RESULTS SUMMARY              "
    echo "=================================================="
    echo ""
    echo "Test Configuration:"
    echo "  - Target URL: https://test8.onbloc.xyz/"
    echo "  - Concurrent Requests: ${CONCURRENT_REQUESTS}"
    echo "  - Test Start Time: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
} > "$TEST_RESULT_FILE"

echo "Starting ${CONCURRENT_REQUESTS} concurrent requests..."
echo "Results will be saved to: ${TEST_RESULT_FILE}"
echo ""

# Record overall start time
overall_start=$(date +%s.%N)

# Launch all requests in background
for i in $(seq 1 $CONCURRENT_REQUESTS); do
    execute_curl $i &
done

# Wait for all background jobs to complete
wait

# Record overall end time
overall_end=$(date +%s.%N)
overall_duration=$(echo "$overall_end - $overall_start" | bc)

echo ""
echo "All requests completed!"
echo "Processing results..."

# Process results and generate summary
{
    echo "Test End Time: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "Total Test Duration: ${overall_duration}s"
    
    # Variables for statistics
    total_time=0
    min_time=999999
    max_time=0
    success_count=0
    fail_count=0
    
    # CSV header for detailed results
    for i in $(seq 1 $CONCURRENT_REQUESTS); do
        temp_file="${TEMP_DIR}/response_${i}.txt"
        if [ -f "$temp_file" ]; then
            # Extract all metrics
            http_code=$(grep "HTTP_CODE:" "$temp_file" | cut -d':' -f2)
            time_total=$(grep "TIME_TOTAL:" "$temp_file" | cut -d':' -f2)
            time_namelookup=$(grep "TIME_NAMELOOKUP:" "$temp_file" | cut -d':' -f2)
            time_connect=$(grep "TIME_CONNECT:" "$temp_file" | cut -d':' -f2)
            time_appconnect=$(grep "TIME_APPCONNECT:" "$temp_file" | cut -d':' -f2)
            time_pretransfer=$(grep "TIME_PRETRANSFER:" "$temp_file" | cut -d':' -f2)
            time_starttransfer=$(grep "TIME_STARTTRANSFER:" "$temp_file" | cut -d':' -f2)
            size_download=$(grep "SIZE_DOWNLOAD:" "$temp_file" | cut -d':' -f2)
            speed_download=$(grep "SPEED_DOWNLOAD:" "$temp_file" | cut -d':' -f2)
                        
            # Update statistics
            if [ "$http_code" = "200" ]; then
                success_count=$((success_count + 1))
            else
                fail_count=$((fail_count + 1))
            fi
            
            # Calculate min/max/total using bc
            if command -v bc &> /dev/null; then
                total_time=$(echo "$total_time + $time_total" | bc)
                if (( $(echo "$time_total < $min_time" | bc -l) )); then
                    min_time=$time_total
                fi
                if (( $(echo "$time_total > $max_time" | bc -l) )); then
                    max_time=$time_total
                fi
            fi
        fi
    done
    
    echo ""
    echo "=================================================="
    echo "                   STATISTICS                     "
    echo "=================================================="
    echo ""
    echo "Response Summary:"
    echo "  - Successful Requests (200): ${success_count}"
    echo "  - Failed Requests: ${fail_count}"
    echo "  - Total Requests: ${CONCURRENT_REQUESTS}"
    echo "  - Success Rate: $(echo "scale=2; $success_count * 100 / $CONCURRENT_REQUESTS" | bc)%"
    echo ""
    
    if command -v bc &> /dev/null && [ $CONCURRENT_REQUESTS -gt 0 ]; then
        average_time=$(echo "scale=3; $total_time / $CONCURRENT_REQUESTS" | bc)
        echo "Response Time Statistics:"
        echo "  - Min Response Time: ${min_time}s"
        echo "  - Max Response Time: ${max_time}s"
        echo "  - Average Response Time: ${average_time}s"
        echo ""
        
        # Calculate requests per second
        rps=$(echo "scale=2; $CONCURRENT_REQUESTS / $overall_duration" | bc)
        echo "Performance Metrics:"
        echo "  - Requests per Second: ${rps}"
        echo "  - Total Test Duration: ${overall_duration}s"
    fi
    
    echo ""
    echo "=================================================="
    echo "                  TEST COMPLETED                  "
    echo "=================================================="
    
} >> "$TEST_RESULT_FILE"

# Display summary on console
echo ""
echo "Test Summary:"
echo "-------------"
grep -A 20 "STATISTICS" "$TEST_RESULT_FILE" | tail -n +2

# Clean up temp directory
rm -rf "$TEMP_DIR"

echo ""
echo "Full test results saved to: ${TEST_RESULT_FILE}"
echo ""
