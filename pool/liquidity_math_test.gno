package pool

import (
	"testing"

	"gno.land/p/demo/uassert"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
)

func TestAddDeltaBasicCases(t *testing.T) {
    tests := []struct {
        name        string
        x           string
        y           string
        want        string
        shouldPanic bool
    }{
        {
            name:        "1 + 0",
            x:           "1",
            y:           "0",
            want:        "1",
            shouldPanic: false,
        },
        {
            name:        "1 + -1",
            x:           "1",
            y:           "-1",
            want:        "0",
            shouldPanic: false,
        },
        {
            name:        "1 + 1",
            x:           "1",
            y:           "1",
            want:        "2",
            shouldPanic: false,
        },
        {
            name:        "2**128-15 + 15",
            x:           "340282366920938463463374607431768211441",
            y:           "15",
            want:        "340282366920938463463374607431768211456",
            shouldPanic: false,
        },
        {
            name:        "0 + -1 (underflow)",
            x:           "0",
            y:           "-1",
            shouldPanic: true,
        },
        {
            name:        "3 + -4 (underflow)",
            x:           "3",
            y:           "-4",
            shouldPanic: true,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            x := u256.MustFromDecimal(tt.x)
            y := i256.MustFromDecimal(tt.y)

            if tt.shouldPanic {
                defer func() {
                    if r := recover(); r == nil {
                        t.Errorf("%s: expected panic but got none", tt.name)
                    }
                }()
                liquidityMathAddDelta(x, y)
                return
            }

            got := liquidityMathAddDelta(x, y)
            want := u256.MustFromDecimal(tt.want)
            
            if !got.Eq(want) {
                t.Errorf("%s: got %s, want %s", tt.name, got.ToString(), want.ToString())
            }
        })
    }
}

func TestLiquidityMathAddDelta(t *testing.T) {
	tests := []struct {
		name        string
		x           string
		y           string
		want        string
		shouldPanic bool
	}{
		{
			name:        "positive delta - normal case",
			x:           "1000",
			y:           "500",
			want:        "1500",
			shouldPanic: false,
		},
		{
			name:        "negative delta - normal case",
			x:           "1000",
			y:           "-500",
			want:        "500",
			shouldPanic: false,
		},
		{
			name:        "zero delta",
			x:           "1000",
			y:           "0",
			want:        "1000",
			shouldPanic: false,
		},
		{
			name:        "subtract near total amount",
			x:           "1000",
			y:           "-999",
			want:        "1",
			shouldPanic: false,
		},
		{
			name:        "panic - subtract more than available",
			x:           "1000",
			y:           "-1001",
			shouldPanic: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			x := u256.MustFromDecimal(tt.x)

			y := i256.MustFromDecimal(tt.y)

			if tt.shouldPanic {
				defer func() {
					if r := recover(); r == nil {
						t.Errorf("expected panic but got none")
					}
				}()
			}

			result := liquidityMathAddDelta(x, y)

			if !tt.shouldPanic {
				want := u256.MustFromDecimal(tt.want)

				if result.Cmp(want) != 0 {
					t.Errorf("got %s, want %s", result.ToString(), want.ToString())
				}
			}
		})
	}
}

func TestLiquidityMathAddDeltaEdgeCases(t *testing.T) {
	tests := []struct {
		name        string
		x           string
		y           string
		shouldPanic bool
	}{
		{
			name:        "max uint256 + positive delta should panic",
			x:           "115792089237316195423570985008687907853269984665640564039457584007913129639935", // 2^256 - 1
			y:           "1",
			shouldPanic: true,
		},
		{
			name:        "subtract zero from zero",
			x:           "0",
			y:           "0",
			shouldPanic: false,
		},
		{
			name:        "add to zero",
			x:           "0",
			y:           "1000",
			shouldPanic: false,
		},
		{
			name:        "subtract from zero should panic",
			x:           "0",
			y:           "-1",
			shouldPanic: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			x := u256.MustFromDecimal(tt.x)
			y := i256.MustFromDecimal(tt.y)

			if tt.shouldPanic {
				defer func() {
					if r := recover(); r == nil {
						t.Errorf("expected panic but got none")
					}
				}()
			}

			liquidityMathAddDelta(x, y)
		})
	}
}
