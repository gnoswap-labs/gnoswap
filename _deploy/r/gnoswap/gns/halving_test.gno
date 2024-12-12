package gns

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"

	"gno.land/r/gnoswap/v1/consts"
)

func TestGetHalvingYearByHeight(t *testing.T) {
	tests := []struct {
		name   string
		height int64
		want   int64
	}{
		{
			name:   "year 1, begin",
			height: startHeight + 1,
			want:   1,
		},
		{
			name:   "year 1, middle",
			height: startHeight + BLOCK_PER_YEAR/2,
			want:   1,
		},
		{
			name:   "year 1, end",
			height: startHeight + BLOCK_PER_YEAR*1,
			want:   1,
		},

		{
			name:   "year 2, begin",
			height: startHeight + BLOCK_PER_YEAR*1 + 1,
			want:   2,
		},
		{
			name:   "year 2, middle",
			height: startHeight + BLOCK_PER_YEAR*2 - 1,
			want:   2,
		},
		{
			name:   "year 2, end",
			height: startHeight + BLOCK_PER_YEAR*2,
			want:   2,
		},

		{
			name:   "year 3, begin",
			height: startHeight + BLOCK_PER_YEAR*2 + 1,
			want:   3,
		},
		{
			name:   "year 3, middle",
			height: startHeight + BLOCK_PER_YEAR*3 - 1,
			want:   3,
		},
		{
			name:   "year 3, end",
			height: startHeight + BLOCK_PER_YEAR*3,
			want:   3,
		},

		{
			name:   "year 4, begin",
			height: startHeight + BLOCK_PER_YEAR*3 + 1,
			want:   4,
		},
		{
			name:   "year 4, middle",
			height: startHeight + BLOCK_PER_YEAR*4 - 1,
			want:   4,
		},
		{
			name:   "year 4, end",
			height: startHeight + BLOCK_PER_YEAR*4,
			want:   4,
		},

		{
			name:   "year 5, begin",
			height: startHeight + BLOCK_PER_YEAR*4 + 1,
			want:   5,
		},
		{
			name:   "year 5, middle",
			height: startHeight + BLOCK_PER_YEAR*5 - 1,
			want:   5,
		},
		{
			name:   "year 5, end",
			height: startHeight + BLOCK_PER_YEAR*5,
			want:   5,
		},

		{name: "year 6, begin", height: startHeight + BLOCK_PER_YEAR*5 + 1, want: 6},
		{
			name:   "year 6, middle",
			height: startHeight + BLOCK_PER_YEAR*6 - 1,
			want:   6,
		},
		{
			name:   "year 6, end",
			height: startHeight + BLOCK_PER_YEAR*6,
			want:   6,
		},

		{
			name:   "year 7, begin",
			height: startHeight + BLOCK_PER_YEAR*6 + 1,
			want:   7,
		},
		{
			name:   "year 7, middle",
			height: startHeight + BLOCK_PER_YEAR*7 - 1,
			want:   7,
		},
		{
			name:   "year 7, end",
			height: startHeight + BLOCK_PER_YEAR*7,
			want:   7,
		},

		{
			name:   "year 8, begin",
			height: startHeight + BLOCK_PER_YEAR*7 + 1,
			want:   8,
		},
		{
			name:   "year 8, middle",
			height: startHeight + BLOCK_PER_YEAR*8 - 1,
			want:   8,
		},
		{
			name:   "year 8, end",
			height: startHeight + BLOCK_PER_YEAR*8,
			want:   8,
		},

		{
			name:   "year 9, begin",
			height: startHeight + BLOCK_PER_YEAR*8 + 1,
			want:   9,
		},
		{
			name:   "year 9, middle",
			height: startHeight + BLOCK_PER_YEAR*9 - 1,
			want:   9,
		},
		{
			name:   "year 9, end",
			height: startHeight + BLOCK_PER_YEAR*9,
			want:   9,
		},

		{
			name:   "year 10, begin",
			height: startHeight + BLOCK_PER_YEAR*9 + 1,
			want:   10,
		},
		{
			name:   "year 10, middle",
			height: startHeight + BLOCK_PER_YEAR*10 - 1,
			want:   10,
		},
		{
			name:   "year 10, end",
			height: startHeight + BLOCK_PER_YEAR*10,
			want:   10,
		},

		{
			name:   "year 11, begin",
			height: startHeight + BLOCK_PER_YEAR*10 + 1,
			want:   11,
		},
		{
			name:   "year 11, middle",
			height: startHeight + BLOCK_PER_YEAR*11 - 1,
			want:   11,
		},
		{
			name:   "year 11, end",
			height: startHeight + BLOCK_PER_YEAR*11,
			want:   11,
		},

		{
			name:   "year 12, begin",
			height: startHeight + BLOCK_PER_YEAR*11 + 1,
			want:   12,
		},
		{
			name:   "year 12, middle",
			height: startHeight + BLOCK_PER_YEAR*12 - 1,
			want:   12,
		},
		{
			name:   "year 12, end",
			height: startHeight + BLOCK_PER_YEAR*12,
			want:   12,
		},

		{
			name:   "after year 12",
			height: startHeight + BLOCK_PER_YEAR*12 + 1,
			want:   0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			uassert.Equal(t, tt.want, GetHalvingYearByHeight(tt.height))
		})
	}
}

func TestGetHalvingYearAndEndTimestamp(t *testing.T) {
	tests := []struct {
		name             string
		timestamp        int64
		wantYear         int64
		wantEndTimestamp int64
	}{
		{
			name:             "year 1, begin",
			timestamp:        startTimestamp + 1,
			wantYear:         1,
			wantEndTimestamp: startTimestamp + consts.TIMESTAMP_YEAR,
		},
		{
			name:             "year 1, middle",
			timestamp:        startTimestamp + consts.TIMESTAMP_YEAR/2,
			wantYear:         1,
			wantEndTimestamp: startTimestamp + consts.TIMESTAMP_YEAR,
		},
		{
			name:             "year 1, end",
			timestamp:        startTimestamp + consts.TIMESTAMP_YEAR*1,
			wantYear:         1,
			wantEndTimestamp: startTimestamp + consts.TIMESTAMP_YEAR,
		},

		{
			name:             "year 2, begin",
			timestamp:        startTimestamp + consts.TIMESTAMP_YEAR*1 + 1,
			wantYear:         2,
			wantEndTimestamp: startTimestamp + consts.TIMESTAMP_YEAR*2,
		},

		{
			name:             "year 2, middle",
			timestamp:        startTimestamp + consts.TIMESTAMP_YEAR*2 - 1,
			wantYear:         2,
			wantEndTimestamp: startTimestamp + consts.TIMESTAMP_YEAR*2,
		},

		{
			name:             "year 2, end",
			timestamp:        startTimestamp + consts.TIMESTAMP_YEAR*2,
			wantYear:         2,
			wantEndTimestamp: startTimestamp + consts.TIMESTAMP_YEAR*2,
		},

		{
			name:             "year 3, begin",
			timestamp:        startTimestamp + consts.TIMESTAMP_YEAR*2 + 1,
			wantYear:         3,
			wantEndTimestamp: startTimestamp + consts.TIMESTAMP_YEAR*3,
		},

		{
			name:             "year 3, middle",
			timestamp:        startTimestamp + consts.TIMESTAMP_YEAR*3 - 1,
			wantYear:         3,
			wantEndTimestamp: startTimestamp + consts.TIMESTAMP_YEAR*3,
		},

		{
			name:             "year 3, end",
			timestamp:        startTimestamp + consts.TIMESTAMP_YEAR*3,
			wantYear:         3,
			wantEndTimestamp: startTimestamp + consts.TIMESTAMP_YEAR*3,
		},

		{
			name:             "year 4, begin",
			timestamp:        startTimestamp + consts.TIMESTAMP_YEAR*3 + 1,
			wantYear:         4,
			wantEndTimestamp: startTimestamp + consts.TIMESTAMP_YEAR*4,
		},

		{
			name:             "year 4, middle",
			timestamp:        startTimestamp + consts.TIMESTAMP_YEAR*4 - 1,
			wantYear:         4,
			wantEndTimestamp: startTimestamp + consts.TIMESTAMP_YEAR*4,
		},

		{
			name:             "year 4, end",
			timestamp:        startTimestamp + consts.TIMESTAMP_YEAR*4,
			wantYear:         4,
			wantEndTimestamp: startTimestamp + consts.TIMESTAMP_YEAR*4,
		},

		{
			name:             "year 5, begin",
			timestamp:        startTimestamp + consts.TIMESTAMP_YEAR*4 + 1,
			wantYear:         5,
			wantEndTimestamp: startTimestamp + consts.TIMESTAMP_YEAR*5,
		},

		{
			name:             "year 5, middle",
			timestamp:        startTimestamp + consts.TIMESTAMP_YEAR*5 - 1,
			wantYear:         5,
			wantEndTimestamp: startTimestamp + consts.TIMESTAMP_YEAR*5,
		},

		{
			name:             "year 5, end",
			timestamp:        startTimestamp + consts.TIMESTAMP_YEAR*5,
			wantYear:         5,
			wantEndTimestamp: startTimestamp + consts.TIMESTAMP_YEAR*5,
		},

		{
			name:             "year 6, begin",
			timestamp:        startTimestamp + consts.TIMESTAMP_YEAR*5 + 1,
			wantYear:         6,
			wantEndTimestamp: startTimestamp + consts.TIMESTAMP_YEAR*6,
		},

		{
			name:             "year 6, middle",
			timestamp:        startTimestamp + consts.TIMESTAMP_YEAR*6 - 1,
			wantYear:         6,
			wantEndTimestamp: startTimestamp + consts.TIMESTAMP_YEAR*6,
		},

		{
			name:             "year 6, end",
			timestamp:        startTimestamp + consts.TIMESTAMP_YEAR*6,
			wantYear:         6,
			wantEndTimestamp: startTimestamp + consts.TIMESTAMP_YEAR*6,
		},

		{
			name:             "year 7, begin",
			timestamp:        startTimestamp + consts.TIMESTAMP_YEAR*6 + 1,
			wantYear:         7,
			wantEndTimestamp: startTimestamp + consts.TIMESTAMP_YEAR*7,
		},

		{
			name:             "year 7, middle",
			timestamp:        startTimestamp + consts.TIMESTAMP_YEAR*7 - 1,
			wantYear:         7,
			wantEndTimestamp: startTimestamp + consts.TIMESTAMP_YEAR*7,
		},

		{
			name:             "year 7, end",
			timestamp:        startTimestamp + consts.TIMESTAMP_YEAR*7,
			wantYear:         7,
			wantEndTimestamp: startTimestamp + consts.TIMESTAMP_YEAR*7,
		},

		{
			name:             "year 8, begin",
			timestamp:        startTimestamp + consts.TIMESTAMP_YEAR*7 + 1,
			wantYear:         8,
			wantEndTimestamp: startTimestamp + consts.TIMESTAMP_YEAR*8,
		},

		{
			name:             "year 8, middle",
			timestamp:        startTimestamp + consts.TIMESTAMP_YEAR*8 - 1,
			wantYear:         8,
			wantEndTimestamp: startTimestamp + consts.TIMESTAMP_YEAR*8,
		},

		{
			name:             "year 8, end",
			timestamp:        startTimestamp + consts.TIMESTAMP_YEAR*8,
			wantYear:         8,
			wantEndTimestamp: startTimestamp + consts.TIMESTAMP_YEAR*8,
		},

		{
			name:             "year 9, begin",
			timestamp:        startTimestamp + consts.TIMESTAMP_YEAR*8 + 1,
			wantYear:         9,
			wantEndTimestamp: startTimestamp + consts.TIMESTAMP_YEAR*9,
		},

		{
			name:             "year 9, middle",
			timestamp:        startTimestamp + consts.TIMESTAMP_YEAR*9 - 1,
			wantYear:         9,
			wantEndTimestamp: startTimestamp + consts.TIMESTAMP_YEAR*9,
		},

		{
			name:             "year 9, end",
			timestamp:        startTimestamp + consts.TIMESTAMP_YEAR*9,
			wantYear:         9,
			wantEndTimestamp: startTimestamp + consts.TIMESTAMP_YEAR*9,
		},

		{
			name:             "year 10, begin",
			timestamp:        startTimestamp + consts.TIMESTAMP_YEAR*9 + 1,
			wantYear:         10,
			wantEndTimestamp: startTimestamp + consts.TIMESTAMP_YEAR*10,
		},

		{
			name:             "year 10, middle",
			timestamp:        startTimestamp + consts.TIMESTAMP_YEAR*10 - 1,
			wantYear:         10,
			wantEndTimestamp: startTimestamp + consts.TIMESTAMP_YEAR*10,
		},

		{
			name:             "year 10, end",
			timestamp:        startTimestamp + consts.TIMESTAMP_YEAR*10,
			wantYear:         10,
			wantEndTimestamp: startTimestamp + consts.TIMESTAMP_YEAR*10,
		},

		{
			name:             "year 11, begin",
			timestamp:        startTimestamp + consts.TIMESTAMP_YEAR*10 + 1,
			wantYear:         11,
			wantEndTimestamp: startTimestamp + consts.TIMESTAMP_YEAR*11,
		},

		{
			name:             "year 11, middle",
			timestamp:        startTimestamp + consts.TIMESTAMP_YEAR*11 - 1,
			wantYear:         11,
			wantEndTimestamp: startTimestamp + consts.TIMESTAMP_YEAR*11,
		},

		{
			name:             "year 11, end",
			timestamp:        startTimestamp + consts.TIMESTAMP_YEAR*11,
			wantYear:         11,
			wantEndTimestamp: startTimestamp + consts.TIMESTAMP_YEAR*11,
		},

		{
			name:             "year 12, begin",
			timestamp:        startTimestamp + consts.TIMESTAMP_YEAR*11 + 1,
			wantYear:         12,
			wantEndTimestamp: startTimestamp + consts.TIMESTAMP_YEAR*12,
		},

		{
			name:             "year 12, middle",
			timestamp:        startTimestamp + consts.TIMESTAMP_YEAR*12 - 1,
			wantYear:         12,
			wantEndTimestamp: startTimestamp + consts.TIMESTAMP_YEAR*12,
		},

		{
			name:             "year 12, end",
			timestamp:        startTimestamp + consts.TIMESTAMP_YEAR*12,
			wantYear:         12,
			wantEndTimestamp: startTimestamp + consts.TIMESTAMP_YEAR*12,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			gotYear, gotEndTimestamp := getHalvingYearAndEndTimestamp(tt.timestamp)
			uassert.Equal(t, tt.wantYear, gotYear)
			uassert.Equal(t, tt.wantEndTimestamp, gotEndTimestamp)
		})
	}
}

func TestSetAvgBlockTimeInMs(t *testing.T) {
	// reset state
	resetObject(t)

	var (
		user01Addr  = testutils.TestAddress("user01Addr")
		user01Realm = std.NewUserRealm(user01Addr)
	)

	t.Run("skip 50 blocks", func(t *testing.T) {
		std.TestSkipHeights(50)
		uassert.Equal(t, int64(173), std.GetHeight())

		std.TestSetRealm(std.NewCodeRealm(consts.EMISSION_PATH))
		mintedAmount := Mint(a2u(user01Addr))
		uassert.Equal(t, mintedAmount, uint64(14269406*50))
		uassert.Equal(t, MintedEmissionAmount(), uint64(713470300))
	})

	t.Run("set avg block time in ms", func(t *testing.T) {
		std.TestSetRealm(std.NewUserRealm(consts.ADMIN))
		setAvgBlockTimeInMs(2500)

		// for block time 2.5s
		// amount per block is 17836757
		std.TestSetRealm(std.NewCodeRealm(consts.EMISSION_PATH))
		std.TestSkipHeights(1)
		mintedAmount := Mint(a2u(user01Addr))
		uassert.Equal(t, mintedAmount, uint64(17836757))
		uassert.Equal(t, MintedEmissionAmount(), uint64(713470300+17836757)) // 731307057
	})

	t.Run("reach almost first halving", func(t *testing.T) {
		// current height = 174
		// next halving = 12614533
		// 12614533 - 174 = 12614359

		std.TestSkipHeights(12614358)
		std.TestSetRealm(std.NewCodeRealm(consts.EMISSION_PATH))
		Mint(a2u(user01Addr))

		uassert.Equal(t, MintedEmissionAmount(), uint64(224999969664063))
		// 224999969664063 - 731307057 = 224999238357006
		// 224999238357006 / 12614358 = 17836757
	})

	t.Run("reach exact first halving", func(t *testing.T) {
		std.TestSkipHeights(1)
		uassert.Equal(t, std.GetHeight(), int64(12614533))

		std.TestSetRealm(std.NewCodeRealm(consts.EMISSION_PATH))
		Mint(a2u(user01Addr))

		// minted all amount for first halving year
		uassert.Equal(t, MintedEmissionAmount(), uint64(225000000000000))

		year := GetHalvingYearByHeight(std.GetHeight())
		uassert.Equal(t, int64(1), year) // year 1 ends

	})

	t.Run("start second halving", func(t *testing.T) {
		std.TestSkipHeights(1)

		year := GetHalvingYearByHeight(std.GetHeight())
		uassert.Equal(t, int64(2), year) // year 2 starts

		year2AmountPerBlock := GetAmountPerBlockPerHalvingYear(2)
		uassert.Equal(t, uint64(14269406), year2AmountPerBlock)

		std.TestSetRealm(std.NewCodeRealm(consts.EMISSION_PATH))
		Mint(a2u(user01Addr))
		uassert.Equal(t, MintedEmissionAmount(), uint64(225000000000000+14269406))
	})
}
