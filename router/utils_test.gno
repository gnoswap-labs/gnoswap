package router

import (
	"strings"
	"testing"
)

type poolPathWithFeeDivideTestCases struct {
	name        string
	input       string
	wantToken0  string
	wantToken1  string
	wantFee     int
	shouldPanic bool
}

func TestPoolPathWithFeeDivide(t *testing.T) {
	tests := []poolPathWithFeeDivideTestCases{
		{
			name:        "valid path",
			input:       "token0:token1:500",
			wantToken0:  "token0",
			wantToken1:  "token1",
			wantFee:     500,
			shouldPanic: false,
		},
		{
			name:        "valid path with special characters",
			input:       "r/token_a:r/token_b:3000",
			wantToken0:  "r/token_a",
			wantToken1:  "r/token_b",
			wantFee:     3000,
			shouldPanic: false,
		},
		{
			name:        "invalid fee format",
			input:       "token0:token1:abc",
			shouldPanic: true,
		},
		{
			name:        "missing parts",
			input:       "token0:token1",
			shouldPanic: true,
		},
		{
			name:        "empty string",
			input:       "",
			shouldPanic: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			defer func() {
				r := recover()
				if (r != nil) != tt.shouldPanic {
					t.Errorf("poolPathWithFeeDivide() panic = %v, shouldPanic = %v", r != nil, tt.shouldPanic)
				}
			}()

			token0, token1, fee := poolPathWithFeeDivide(tt.input)
			if !tt.shouldPanic {
				if token0 != tt.wantToken0 {
					t.Errorf("token0 = %v, want %v", token0, tt.wantToken0)
				}
				if token1 != tt.wantToken1 {
					t.Errorf("token1 = %v, want %v", token1, tt.wantToken1)
				}
				if fee != tt.wantFee {
					t.Errorf("fee = %v, want %v", fee, tt.wantFee)
				}
			}
		})
	}
}

func TestGetDataForSinglePath(t *testing.T) {
	tests := []poolPathWithFeeDivideTestCases{
		{
			name:        "valid path",
			input:       "tokenA:tokenB:500",
			wantToken0:  "tokenA",
			wantToken1:  "tokenB",
			wantFee:     int(500),
			shouldPanic: false,
		},
		{
			name:        "invalid path format",
			input:       "tokenA:tokenB",
			shouldPanic: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			defer func() {
				r := recover()
				if (r != nil) != tt.shouldPanic {
					t.Errorf("getDataForSinglePath() panic = %v, shouldPanic = %v", r != nil, tt.shouldPanic)
				}
			}()

			token0, token1, fee := getDataForSinglePath(tt.input)
			if !tt.shouldPanic {
				if token0 != tt.wantToken0 {
					t.Errorf("token0 = %v, want %v", token0, tt.wantToken0)
				}
				if token1 != tt.wantToken1 {
					t.Errorf("token1 = %v, want %v", token1, tt.wantToken1)
				}
				if int(fee) != tt.wantFee {
					t.Errorf("fee = %v, want %v", fee, tt.wantFee)
				}
			}
		})
	}
}

func TestGetDataForMultiPath(t *testing.T) {
	tests := []struct {
		name       string
		input      string
		poolIdx    int
		wantToken0 string
		wantToken1 string
		wantFee    uint32
	}{
		{
			name:       "first pool",
			input:      "tokenA:tokenB:500*POOL*tokenB:tokenC:3000*POOL*tokenC:tokenD:10000",
			poolIdx:    0,
			wantToken0: "tokenA",
			wantToken1: "tokenB",
			wantFee:    500,
		},
		{
			name:       "second pool",
			input:      "tokenA:tokenB:500*POOL*tokenB:tokenC:3000*POOL*tokenC:tokenD:10000",
			poolIdx:    1,
			wantToken0: "tokenB",
			wantToken1: "tokenC",
			wantFee:    3000,
		},
		{
			name:       "third pool",
			input:      "tokenA:tokenB:500*POOL*tokenB:tokenC:3000*POOL*tokenC:tokenD:10000",
			poolIdx:    2,
			wantToken0: "tokenC",
			wantToken1: "tokenD",
			wantFee:    10000,
		},
		{
			name:       "invalid pool index",
			input:      "tokenA:tokenB:500*POOL*tokenB:tokenC:3000",
			poolIdx:    3,
			wantToken0: "",
			wantToken1: "",
			wantFee:    0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			token0, token1, fee := getDataForMultiPath(tt.input, tt.poolIdx)

			if token0 != tt.wantToken0 {
				t.Errorf("token0 = %v, want %v", token0, tt.wantToken0)
			}
			if token1 != tt.wantToken1 {
				t.Errorf("token1 = %v, want %v", token1, tt.wantToken1)
			}
			if fee != tt.wantFee {
				t.Errorf("fee = %v, want %v", fee, tt.wantFee)
			}
		})
	}
}
