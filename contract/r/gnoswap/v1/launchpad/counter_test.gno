package launchpad

import (
	"testing"

	"gno.land/p/demo/uassert"
)

// Test for NewCounter, next, and Get methods.
func TestCounter_Behavior(t *testing.T) {
	tests := []struct {
		name string
		initValue int64
		callNextTimes int
		expectedId int64
	}{
		{
			name: "Initial value is zero",
			initValue: 0,
			callNextTimes: 0,
			expectedId: 0,
		},
		{
			name: "Call next once",
			initValue: 0,
			callNextTimes: 1,
			expectedId: 1,
		},
		{
			name: "Call next multiple times",
			initValue: 0,
			callNextTimes: 5,
			expectedId: 5,
		},
		{
			name: "Start from non-zero, call next",
			initValue: 10,
			callNextTimes: 3,
			expectedId: 13,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given: create counter and set initial value if needed
			c := NewCounter()
			if tc.initValue > 0 {
				c.id = tc.initValue
			}

			// when: call next() as many times as needed
			for i := 0; i < tc.callNextTimes; i++ {
				c.next()
			}

			// then: check id value
			uassert.Equal(t, c.Get(), tc.expectedId)
		})
	}
} 