package gns

import (
	"fmt"
	"std"
	"testing"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"

	"gno.land/r/gnoswap/v1/consts"

	"gno.land/r/gnoswap/v1/gns"
)

const (
	GNO_VM_DEFAULT_HEIGHT = int64(123)
)

var (
	addr01        = testutils.TestAddress("addr01")
	addr01Realm   = std.NewUserRealm(addr01)
	emissionRealm = std.NewCodeRealm(consts.EMISSION_PATH)
)

func TestCalculateAmountToMint(t *testing.T) {
	// back up previous data
	prevHalvingYearAmount := halvingYearMintAmount

	t.Run("1 block for same year 01", func(t *testing.T) {
		amount := calculateAmountToMint(GetLastMintedHeight()+1, GetLastMintedHeight()+1)
		uassert.Equal(t, amountPerBlockPerHalvingYear[1], amount)
	})

	t.Run("entire block for year 01 + 1 block for year 02", func(t *testing.T) {
		calculateAmountToMint(halvingYearBlock[1], halvingYearBlock[1]+1)

		// minted all amount for year 01
		uassert.Equal(t, GetHalvingYearAmount(1), GetHalvingYearMintAmount(1))

		// minted 1 block for year 02
		uassert.Equal(t, amountPerBlockPerHalvingYear[2], GetHalvingYearMintAmount(2))
	})

	// restore previous data
	halvingYearMintAmount = prevHalvingYearAmount
}

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

func TestInitData(t *testing.T) {
	t.Run("total supply", func(t *testing.T) {
		uassert.Equal(t, INITIAL_MINT_AMOUNT, TotalSupply())
	})

	t.Run("balance of admin", func(t *testing.T) {
		uassert.Equal(t, INITIAL_MINT_AMOUNT, BalanceOf(a2u(consts.ADMIN)))
	})

	t.Run("last minted height", func(t *testing.T) {
		uassert.Equal(t, GNO_VM_DEFAULT_HEIGHT, lastMintedHeight) // gnoVM(in test) default height
	})
}

func TestMint(t *testing.T) {
	t.Run("panic if caller is not emission", func(t *testing.T) {
		std.TestSetRealm(addr01Realm)
		uassert.PanicsWithMessage(t,
			`caller(g1v9jxgu3sx9047h6lta047h6lta047h6l0js7st) has no permission`,
			func() { Mint(a2u(addr01)) })
	})

	t.Run("success mint", func(t *testing.T) {
		std.TestSkipHeights(1)

		uassert.Equal(t, uint64(0), gns.BalanceOf(a2u(consts.EMISSION_ADDR)))

		std.TestSetRealm(emissionRealm)
		uassert.Equal(t, amountPerBlockPerHalvingYear[1], Mint(a2u(consts.EMISSION_ADDR))) // 1 block for year 01

		uassert.Equal(t, std.GetHeight(), GetLastMintedHeight())
		uassert.Equal(t, MAX_EMISSION_AMOUNT-amountPerBlockPerHalvingYear[1], GetLeftEmissionAmount())

		uassert.Equal(t, amountPerBlockPerHalvingYear[1], gns.BalanceOf(a2u(consts.EMISSION_ADDR)))
	})
}

func TestSkipIfSameHeight(t *testing.T) {
	t.Run("should skip if height is same", func(t *testing.T) {
		uassert.True(t, skipIfSameHeight(1, 1))
	})

	t.Run("should not skip if height is different", func(t *testing.T) {
		uassert.False(t, skipIfSameHeight(1, 2))
	})
}
