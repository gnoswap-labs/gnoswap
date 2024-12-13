package gns

import (
	"fmt"
	"std"
	"testing"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"

	"gno.land/r/gnoswap/v1/consts"
)

const (
	// gnoVM test context default height
	// ref: https://github.com/gnolang/gno/blob/a85a53d5b38f0a21d66262a823a8b07f4f836b68/gnovm/pkg/test/test.go#L31-L32
	GNO_VM_DEFAULT_HEIGHT = int64(123)
)

var (
	emissionRealm = std.NewCodeRealm(consts.EMISSION_PATH)
	adminRealm    = std.NewUserRealm(consts.ADMIN)
)

var (
	alice = testutils.TestAddress("alice")
	bob   = testutils.TestAddress("bob")
)

func TestIsLastBlockOfHalvingYear(t *testing.T) {
	tests := make([]struct {
		name   string
		height int64
		want   bool
	}, 0, 24)

	for i := int64(1); i <= 12; i++ {
		tests = append(tests, struct {
			name   string
			height int64
			want   bool
		}{
			name:   fmt.Sprintf("last block of halving year %d", i),
			height: halvingYearBlock[i],
			want:   true,
		})

		tests = append(tests, struct {
			name   string
			height int64
			want   bool
		}{
			name:   fmt.Sprintf("not last block of halving year %d", i),
			height: halvingYearBlock[i] - 1,
			want:   false,
		})
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			uassert.Equal(t, tt.want, isLastBlockOfHalvingYear(tt.height))
		})
	}
}

func TestHandleLeftEmissionAmount(t *testing.T) {
	tests := make([]struct {
		name   string
		year   int64
		amount uint64
		want   uint64
	}, 0, 24)

	for i := int64(1); i <= 12; i++ {
		tests = append(tests, struct {
			name   string
			year   int64
			amount uint64
			want   uint64
		}{
			name:   fmt.Sprintf("handle left emission amount for year %d, non minted", i),
			year:   i,
			amount: 0,
			want:   halvingYearAmount[i],
		})

		tests = append(tests, struct {
			name   string
			year   int64
			amount uint64
			want   uint64
		}{
			name:   fmt.Sprintf("handle left emission amount for year %d, minted", i),
			year:   i,
			amount: uint64(123456),
			want:   halvingYearAmount[i] - uint64(123456),
		})
	}
}

func TestSkipIfSameHeight(t *testing.T) {
	t.Run("should skip if height is same", func(t *testing.T) {
		uassert.True(t, skipIfSameHeight(1, 1))
	})

	t.Run("should not skip if height is different", func(t *testing.T) {
		uassert.False(t, skipIfSameHeight(1, 2))
	})
}

func TestGetterSetter(t *testing.T) {
	t.Run("last minted height", func(t *testing.T) {
		value := int64(1234)
		setLastMintedHeight(value)
		uassert.Equal(t, value, GetLastMintedHeight())
	})

	t.Run("left emission amount", func(t *testing.T) {
		value := uint64(123456)
		setLeftEmissionAmount(value)
		uassert.Equal(t, value, GetLeftEmissionAmount())
	})
}

func TestGrc20Methods(t *testing.T) {
	tests := []struct {
		name        string
		fn          func()
		shouldPanic bool
		panicMsg    string
	}{
		{
			name: "TotalSupply",
			fn: func() {
				uassert.Equal(t, INITIAL_MINT_AMOUNT, TotalSupply())
			},
		},
		{
			name: "BalanceOf(admin)",
			fn: func() {
				uassert.Equal(t, INITIAL_MINT_AMOUNT, BalanceOf(a2u(consts.ADMIN)))
			},
		},
		{
			name: "BalanceOf(alice)",
			fn: func() {
				uassert.Equal(t, uint64(0), BalanceOf(a2u(alice)))
			},
		},
		{
			name: "Allowance(admin, alice)",
			fn: func() {
				uassert.Equal(t, uint64(0), Allowance(a2u(consts.ADMIN), a2u(alice)))
			},
		},
		{
			name: "MintGns success",
			fn: func() {
				std.TestSetRealm(emissionRealm)
				MintGns(a2u(consts.ADMIN))
			},
		},
		{
			name: "MintGns without permission should panic",
			fn: func() {
				std.TestSkipHeights(1)
				MintGns(a2u(consts.ADMIN))
			},
			shouldPanic: true,
			panicMsg:    `caller(g1wymu47drhr0kuq2098m792lytgtj2nyx77yrsm) has no permission`,
		},
		{
			name: "Burn success",
			fn: func() {
				std.TestSetRealm(adminRealm)
				Burn(a2u(consts.ADMIN), uint64(1))
			},
		},
		{
			name: "Burn without permission should panic",
			fn: func() {
				Burn(a2u(consts.ADMIN), uint64(1))
			},
			shouldPanic: true,
			panicMsg:    `ownable: caller is not owner`,
		},
		{
			name: "Transfer success",
			fn: func() {
				std.TestSetRealm(adminRealm)
				Transfer(a2u(alice), uint64(1))
			},
		},
		{
			name: "Transfer without enough balance should panic",
			fn: func() {
				std.TestSetRealm(std.NewUserRealm(alice))
				Transfer(a2u(bob), uint64(1))
			},
			shouldPanic: true,
			panicMsg:    `insufficient balance`,
		},
		{
			name: "Transfer to self should panic",
			fn: func() {
				std.TestSetRealm(adminRealm)
				Transfer(a2u(consts.ADMIN), uint64(1))
			},
			shouldPanic: true,
			panicMsg:    `cannot send transfer to self`,
		},
		{
			name: "TransferFrom success",
			fn: func() {
				// approve first
				std.TestSetRealm(adminRealm)
				Approve(a2u(alice), uint64(1))

				// alice transfer admin's balance to bob
				std.TestSetRealm(std.NewUserRealm(alice))
				TransferFrom(a2u(consts.ADMIN), a2u(bob), uint64(1))
			},
		},
		{
			name: "TransferFrom without enough allowance should panic",
			fn: func() {
				std.TestSetRealm(adminRealm)
				Approve(a2u(alice), uint64(1))

				std.TestSetRealm(std.NewUserRealm(alice))
				TransferFrom(a2u(consts.ADMIN), a2u(bob), uint64(2))
			},
			shouldPanic: true,
			panicMsg:    `insufficient allowance`,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			testResetGnsTokenObject(t)

			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.panicMsg, tt.fn)
			} else {
				uassert.NotPanics(t, func() { tt.fn() })
			}
		})
	}
}
