package staker

import (
	"testing"
	"time"

	"gno.land/p/demo/testutils"
)

func TestGetAverageDelegated(t *testing.T) {
	delegateAddr := testutils.TestAddress("delegate")
	delegate := delegateAddr.String()

	defer func() {
		if r := recover(); r != nil {
			t.Fatalf("GetAverageDelegated panicked: %v", r)
		}
	}()

	// simulate time passing and additional stakes
	currentTime := uint64(1000)
	delegationHistory[delegateAddr] = []DelegationHistory{
		{amount: 1000, timestamp: currentTime},
		{amount: 1500, timestamp: currentTime + 100},
		{amount: 2000, timestamp: currentTime + 200},
	}

	tests := []struct {
		name           string
		start          uint64
		end            uint64
		expectedResult string
	}{
		{
			name:           "Full period average",
			start:          currentTime,
			end:            currentTime + 200,
			expectedResult: "1250", // (1000*100 + 1500*100 + 2000*0) / 200
		},
		{
			name:           "Partial period average",
			start:          currentTime + 50,
			end:            currentTime + 150,
			expectedResult: "1250", // (1000*50 + 1500*50) / 100
		},
		{
			name:           "Single point in time",
			start:          currentTime + 100,
			end:            currentTime + 100,
			expectedResult: "1500",
		},
		{
			name:           "Period before any stakes",
			start:          currentTime - 100,
			end:            currentTime - 50,
			expectedResult: "0",
		},
		{
			name:           "Period after all recorded stakes",
			start:          currentTime + 300,
			end:            currentTime + 400,
			expectedResult: "2000",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := GetAverageDelegated(delegate, tt.start, tt.end)
			if result != tt.expectedResult {
				t.Errorf("Expected %s, got %s", tt.expectedResult, result)
			}
		})
	}
}

func TestGetAverageDelegatedOverLast(t *testing.T) {
	delegateAddr := testutils.TestAddress("delegate")
	delegate := delegateAddr.String()

	defer func() {
		if r := recover(); r != nil {
			t.Fatalf("GetAverageDelegatedOverLast panicked: %v", r)
		}
	}()

	// Set up delegation history
	now := uint64(time.Now().Unix())
	delegationHistory[delegateAddr] = []DelegationHistory{
		{amount: 1000, timestamp: now - 100},
		{amount: 2000, timestamp: now - 50},
		{amount: 3000, timestamp: now},
	}

	avg := GetAverageDelegatedOverLast(delegate, uint64(100))
	if avg != "1500" { // (1000*50 + 2000*50) / 100
		t.Errorf("Expected 1500, got %s", avg)
	}
}

func TestGetCurrentDelegated(t *testing.T) {
	delegate1 := testutils.TestAddress("delegate1")
	delegate2 := testutils.TestAddress("delegate2")

	// Set up delegation history for delegate1
	delegationHistory[delegate1] = []DelegationHistory{
		{amount: 1000, timestamp: 100},
		{amount: 1500, timestamp: 200},
		{amount: 2000, timestamp: 300},
	}

	tests := []struct {
		name           string
		delegate       string
		expectedResult string
	}{
		{
			name:           "Delegate with history",
			delegate:       delegate1.String(),
			expectedResult: "2000",
		},
		{
			name:           "Delegate without history",
			delegate:       delegate2.String(),
			expectedResult: "0",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := GetCurrentDelegated(tt.delegate)
			if result != tt.expectedResult {
				t.Errorf("Expected %s, got %s", tt.expectedResult, result)
			}
		})
	}
}

func TestGetDelegatedAt(t *testing.T) {
	delegateAddr := testutils.TestAddress("delegate")
	delegate := delegateAddr.String()

	delegationHistory[delegateAddr] = []DelegationHistory{
		{amount: 1000, timestamp: 100},
		{amount: 1500, timestamp: 200},
		{amount: 2000, timestamp: 300},
	}

	tests := []struct {
		name           string
		timestamp      uint64
		expectedResult string
	}{
		{
			name:           "Before first delegation",
			timestamp:      50,
			expectedResult: "0",
		},
		{
			name:           "At first delegation",
			timestamp:      100,
			expectedResult: "1000",
		},
		{
			name:           "Between first and second delegation",
			timestamp:      150,
			expectedResult: "1000",
		},
		{
			name:           "At second delegation",
			timestamp:      200,
			expectedResult: "1500",
		},
		{
			name:           "At last delegation",
			timestamp:      300,
			expectedResult: "2000",
		},
		{
			name:           "After last delegation",
			timestamp:      400,
			expectedResult: "2000",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := GetDelegatedAt(delegate, tt.timestamp)
			if result != tt.expectedResult {
				t.Errorf("Expected %s, got %s", tt.expectedResult, result)
			}
		})
	}

	t.Run("Non-existent delegate", func(t *testing.T) {
		dummy := testutils.TestAddress("dummy").String()
		result := GetDelegatedAt(dummy, uint64(200))
		if result != "0" {
			t.Errorf("Expected 0, got %s", result)
		}
	})
}
