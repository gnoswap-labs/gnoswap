package emission

import (
	"testing"
	"time"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"
	"gno.land/p/nt/ufmt"
)

var alice = testutils.TestAddress("alice")

func TestSetDistributionStartTime(t *testing.T) {
	now := time.Now().Unix()

	tests := []struct {
		name        string
		setup       func()
		timestamp   int64
		caller      address
		shouldPanic bool
		panicMsg    string
	}{
		{
			name:      "admin can set distribution start time",
			timestamp: 1000 + now,
			caller:    adminAddr,
		},
		{
			name:      "governance can set distribution start time",
			timestamp: 2000 + now,
			caller:    govAddr,
		},
		{
			name:        "non-admin/governance cannot set distribution start time",
			timestamp:   3000 + now,
			caller:      alice,
			shouldPanic: true,
			panicMsg:    ufmt.Sprintf("unauthorized: caller %s is not admin or governance", alice.String()),
		},
		{
			name:        "cannot set negative timestamp",
			timestamp:   -100,
			caller:      adminAddr,
			shouldPanic: true,
			panicMsg:    "distribution start timestamp cannot be negative",
		},
		{
			name: "update existing distribution start time",
			setup: func() {
				testing.SetOriginCaller(adminAddr)
				SetDistributionStartTime(cross, 5000+now)
			},
			timestamp: 10000 + now,
			caller:    govAddr,
		},
		{
			name: "cannot change start time after distribution has started",
			setup: func() {
				// Set initial distribution start time to 100
				testing.SetOriginCaller(adminAddr)
				SetDistributionStartTime(cross, 100+now)
				testing.SkipHeights(21) // skip to 21 to simulate time advancing to 105 (past start time)
			},
			timestamp:   200 + now,
			caller:      adminAddr,
			shouldPanic: true,
			panicMsg:    "distribution has already started, cannot change start timestamp",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			testing.SetHeight(123)
			if tt.setup != nil {
				tt.setup()
			}

			testing.SetRealm(testing.NewUserRealm(tt.caller))

			if tt.shouldPanic {
				uassert.AbortsWithMessage(t, tt.panicMsg, func() {
					SetDistributionStartTime(cross, tt.timestamp)
				})
			} else {
				SetDistributionStartTime(cross, tt.timestamp)
				uassert.Equal(t, tt.timestamp, GetDistributionStartTimestamp())
			}
		})

		resetObject(t)
	}
}

func TestMintAndDistributeGnsWithDistributionStartTime(t *testing.T) {
	tests := []struct {
		name         string
		startTime    int64
		skipHeight   int64
		simulateTime bool
		verify       func(distributed int64)
	}{
		{
			name:         "emission allowed when current time >= start time",
			startTime:    100,
			skipHeight:   200,
			simulateTime: true,
			verify: func(distributed int64) {
				uassert.True(t, distributed > 0)
			},
		},
		{
			name:         "emission blocked when current time < start time",
			startTime:    500,
			skipHeight:   100,
			simulateTime: true,
			verify: func(distributed int64) {
				uassert.Equal(t, int64(0), distributed)
			},
		},
		{
			name:         "emission allowed at exact start time",
			startTime:    300,
			skipHeight:   300,
			simulateTime: true,
			verify: func(distributed int64) {
				uassert.True(t, distributed > 0)
			},
		},
		{
			name:         "default start time (0) blocks emission until set",
			skipHeight:   1,
			simulateTime: true,
			verify: func(distributed int64) {
				uassert.Equal(t, int64(0), distributed)
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetObject(t)

			now := time.Now().Unix()

			testing.SetOriginCaller(adminAddr)
			SetDistributionStartTime(cross, 100+now)

			testing.SkipHeights(tt.skipHeight)
			defer func() {
				testing.SkipHeights(-tt.skipHeight)
			}()

			distributed := MintAndDistributeGns(cross)
			if tt.verify != nil {
				tt.verify(distributed)
			}
		})

		resetObject(t)
	}
}
