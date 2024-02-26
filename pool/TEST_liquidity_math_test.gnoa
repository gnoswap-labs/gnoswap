package pool

import (
    "testing"
    "gno.land/p/demo/ufmt"
)

func TestLiquidityMathAddDelta(t *testing.T) {
    testCases := []struct {
        x bigint
        y bigint
        expected bigint
		isErr bool
    }{
		{-1000, -500, -1500, true},
		{-1000, 500, -500, true},
		{-200, -100, -300, true},
		{-200, 100, -100, true},
		{-100, -50, -150, true},
		{-100, 50, -50, true},
		{0, -100, -100, true},
		{0, 0, 0, false},
		{10, -5, 5, false},
		{10, 5, 15, false},
		{100, -50, 50, false},
		{100, 50, 150, false},
		{200, -100, 100, false},
		{200, 100, 300, false},
		{1000, -500, 500, false},
		{1000, 500, 1500, false},
	}

    for i, tc := range testCases {
        func() {
            defer func() {
                if r := recover(); r != nil {
                    if !tc.isErr {
                        t.Errorf("Test case %d failed: x=%d, y=%d, expected=%d, got panic but didn't expect one", i+1, tc.x, tc.y, tc.expected)
                    }
                } else {
                    if tc.isErr {
                        t.Errorf("Test case %d failed: x=%d, y=%d, expected panic but didn't get one", i+1, tc.x, tc.y)
                    }
                }
            }()

            result := liquidityMathAddDelta(tc.x, tc.y)
            if result != tc.expected && !tc.isErr {
                t.Errorf("Test case %d failed: x=%d, y=%d, expected=%d, got=%d", i+1, tc.x, tc.y, tc.expected, result)
            }
        }()
    }
}