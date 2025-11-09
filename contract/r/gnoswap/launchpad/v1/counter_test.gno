package v1

import (
	"testing"
	"math"

	"gno.land/p/nt/uassert"
)

// Test for NewCounter, next, and Get methods.
func TestCounter_NewCounter(t *testing.T) {
	tests := []struct {
		name          string
		initValue     int64
		callNextTimes int
		expectedId    int64
	}{
		{
			name:          "Initial value is zero",
			callNextTimes: 0,
			expectedId:    0,
		},
		{
			name:          "Call next once",
			callNextTimes: 1,
			expectedId:    1,
		},
		{
			name:          "Call next multiple times",
			callNextTimes: 5,
			expectedId:    5,
		},
		{
			name:          "Start from non-zero, call next",
			initValue:     10,
			callNextTimes: 3,
			expectedId:    13,
		},
		{
			name:          "Large initial value near MaxInt64",
			initValue:     math.MaxInt64 - 5,
			callNextTimes: 5,
			expectedId:    math.MaxInt64,
		},
		{
			name:          "Call next many times",
			callNextTimes: 1000,
			expectedId:    1000,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given: create counter and set initial value if needed
			c := NewCounter()
			if tc.initValue != 0 {
				c.id = tc.initValue
			}

			// when: call Next() as many times as needed
			for i := 0; i < tc.callNextTimes; i++ {
				c.Next()
			}

			// then: check id value
			uassert.Equal(t, c.Get(), tc.expectedId)
		})
	}
}
