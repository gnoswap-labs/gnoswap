package staker

import (
	"testing"

	"gno.land/p/demo/uassert"
)

// TestCounter_NewCounter tests the creation of new Counter instances
func TestCounter_NewCounter(t *testing.T) {
	tests := []struct {
		name        string
		expectedID  int64
	}{
		{
			name:       "Create new counter",
			expectedID: 0,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// when
			counter := NewCounter()

			// then
			uassert.NotNil(t, counter)
			uassert.Equal(t, counter.Get(), tc.expectedID)
		})
	}
}

// TestCounter_Next tests the next functionality
func TestCounter_Next(t *testing.T) {
	tests := []struct {
		name         string
		callCount    int
		expectedLast int64
	}{
		{
			name:         "Single next call",
			callCount:    1,
			expectedLast: 1,
		},
		{
			name:         "Multiple next calls",
			callCount:    5,
			expectedLast: 5,
		},
		{
			name:         "Ten next calls",
			callCount:    10,
			expectedLast: 10,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			counter := NewCounter()

			// when
			var lastID int64
			for i := 0; i < tc.callCount; i++ {
				lastID = counter.next()
			}

			// then
			uassert.Equal(t, lastID, tc.expectedLast)
			uassert.Equal(t, counter.Get(), tc.expectedLast)
		})
	}
}

// TestCounter_Get tests the get functionality
func TestCounter_Get(t *testing.T) {
	tests := []struct {
		name          string
		nextCalls     int
		expectedValue int64
	}{
		{
			name:          "Get initial value",
			nextCalls:     0,
			expectedValue: 0,
		},
		{
			name:          "Get after one increment",
			nextCalls:     1,
			expectedValue: 1,
		},
		{
			name:          "Get after multiple increments",
			nextCalls:     3,
			expectedValue: 3,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			counter := NewCounter()
			for i := 0; i < tc.nextCalls; i++ {
				counter.next()
			}

			// when
			value := counter.Get()

			// then
			uassert.Equal(t, value, tc.expectedValue)
		})
	}
} 