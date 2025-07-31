package emission

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"
	"gno.land/p/demo/ufmt"
)

var alice = testutils.TestAddress("alice")

func TestMintAndDistributeGns(t *testing.T) {
	tests := []struct {
		name        string
		setup       func()
		shouldPanic bool
		panicMsg    string
		verify      func(distributed int64)
	}{
		{
			name: "no block passed",
			verify: func(distributed int64) {
				uassert.Equal(t, int64(0), distributed)
			},
		},
		{
			name: "block passed",
			setup: func() {
				testing.SkipHeights(123)
			},
			verify: func(distributed int64) {
				uassert.True(t, distributed > 0)
			},
		},
		{
			name: "same block",
			verify: func(distributed int64) {
				uassert.Equal(t, int64(0), distributed)
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.setup != nil {
				tt.setup()
			}

			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.panicMsg, func() {
					MintAndDistributeGns(cross)
				})
			} else {
				distributed := MintAndDistributeGns(cross)
				if tt.verify != nil {
					tt.verify(distributed)
				}
			}
		})

		resetObject(t)
	}
}

func TestSetMinBlockHeight(t *testing.T) {
	tests := []struct {
		name        string
		setup       func()
		height      int64
		caller      std.Address
		shouldPanic bool
		panicMsg    string
		verify      func()
	}{
		{
			name:   "admin can set min block height",
			height: 1000,
			caller: adminAddr,
			verify: func() {
				uassert.Equal(t, int64(1000), GetMinBlockHeight())
			},
		},
		{
			name:   "governance can set min block height",
			height: 2000,
			caller: govAddr,
			verify: func() {
				uassert.Equal(t, int64(2000), GetMinBlockHeight())
			},
		},
		{
			name:        "non-admin/governance cannot set min block height",
			height:      3000,
			caller:      alice,
			shouldPanic: true,
			panicMsg:    ufmt.Sprintf("unauthorized: caller %s is not admin or governance", alice.String()),
		},
		{
			name:        "cannot set negative block height",
			height:      -100,
			caller:      adminAddr,
			shouldPanic: true,
			panicMsg:    "minimum block height cannot be negative",
		},
		{
			name:   "can set zero block height",
			height: 0,
			caller: adminAddr,
			verify: func() {
				uassert.Equal(t, int64(0), GetMinBlockHeight())
			},
		},
		{
			name: "update existing min block height",
			setup: func() {
				testing.SetOriginCaller(adminAddr)
				SetMinBlockHeight(cross, 5000)
			},
			height: 10000,
			caller: govAddr,
			verify: func() {
				uassert.Equal(t, int64(10000), GetMinBlockHeight())
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.setup != nil {
				tt.setup()
			}

			testing.SetRealm(std.NewUserRealm(tt.caller))

			if tt.shouldPanic {
				uassert.AbortsWithMessage(t, tt.panicMsg, func() {
					SetMinBlockHeight(cross, tt.height)
				})
			} else {
				SetMinBlockHeight(cross, tt.height)
				if tt.verify != nil {
					tt.verify()
				}
			}
		})

		resetObject(t)
	}
}

func TestMintAndDistributeGnsWithMinBlockHeight(t *testing.T) {
	tests := []struct {
		name          string
		setup         func()
		minHeight     int64
		currentHeight int64
		verify        func(distributed int64)
	}{
		{
			name:          "emission allowed when current height >= min height",
			minHeight:     100,
			currentHeight: 200,
			setup: func() {
				testing.SetOriginCaller(adminAddr)
				SetMinBlockHeight(cross, 100)
				testing.SkipHeights(200)
			},
			verify: func(distributed int64) {
				uassert.True(t, distributed > 0)
			},
		},
		{
			name:          "emission blocked when current height < min height",
			minHeight:     500,
			currentHeight: 100,
			setup: func() {
				testing.SetOriginCaller(adminAddr)
				SetMinBlockHeight(cross, 500)
				testing.SkipHeights(100)
			},
			verify: func(distributed int64) {
				uassert.Equal(t, int64(0), distributed)
			},
		},
		{
			name:          "emission allowed at exact min height",
			minHeight:     300,
			currentHeight: 300,
			setup: func() {
				testing.SetOriginCaller(adminAddr)
				SetMinBlockHeight(cross, 300)
				testing.SkipHeights(300)
			},
			verify: func(distributed int64) {
				uassert.True(t, distributed > 0)
			},
		},
		{
			name:          "default min height (0) allows emission from genesis",
			currentHeight: 1,
			setup: func() {
				testing.SkipHeights(1)
			},
			verify: func(distributed int64) {
				uassert.Equal(t, int64(0), GetMinBlockHeight())
				uassert.True(t, distributed > 0)
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.setup != nil {
				tt.setup()
			}

			distributed := MintAndDistributeGns(cross)
			if tt.verify != nil {
				tt.verify(distributed)
			}
		})

		resetObject(t)
	}
}
