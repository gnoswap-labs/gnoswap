package staker

import (
	"testing"

	"gno.land/p/nt/uassert"
)

// TestCounter_NewCounter tests the Counter constructor
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

// TestCounter_Next tests incrementing counter
func TestCounter_Next(t *testing.T) {
	tests := []struct {
		name          string
		callCount     int
		expectedValue int64
	}{
		{
			name:          "Next once",
			callCount:     1,
			expectedValue: 1,
		},
		{
			name:          "Next twice",
			callCount:     2,
			expectedValue: 2,
		},
		{
			name:          "Next multiple times",
			callCount:     10,
			expectedValue: 10,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			counter := NewCounter()

			// when
			var result int64
			for i := 0; i < tc.callCount; i++ {
				result = counter.Next()
			}

			// then
			uassert.Equal(t, result, tc.expectedValue)
			uassert.Equal(t, counter.Get(), tc.expectedValue)
		})
	}
}

// TestCounter_Get tests getting counter value
func TestCounter_Get(t *testing.T) {
	tests := []struct {
		name          string
		setup         func(*Counter)
		expectedValue int64
	}{
		{
			name: "Get initial value",
			setup: func(c *Counter) {
				// no setup
			},
			expectedValue: 0,
		},
		{
			name: "Get after increment",
			setup: func(c *Counter) {
				c.Next()
				c.Next()
				c.Next()
			},
			expectedValue: 3,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			counter := NewCounter()
			tc.setup(counter)

			// when
			result := counter.Get()

			// then
			uassert.Equal(t, result, tc.expectedValue)
		})
	}
}
