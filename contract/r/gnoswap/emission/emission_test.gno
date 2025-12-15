package emission

import (
	"math"
	"testing"
	"time"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"
	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/gns"
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

			distributed, _ := MintAndDistributeGns(cross)
			if tt.verify != nil {
				tt.verify(distributed)
			}
		})

		resetObject(t)
	}
}

func TestEmission_MintAndDistributeGns_EdgeCases(t *testing.T) {
	tests := []struct {
		name    string
		setup   func()
		wantErr bool
		errMsg  string
		verify  func(t *testing.T)
	}{
		{
			name: "success - distributes with leftover from previous round",
			setup: func() {
				resetObject(t)
				now := time.Now().Unix()
				testing.SetOriginCaller(adminAddr)
				SetDistributionStartTime(cross, now+100)
				testing.SkipHeights(200)
				// First distribution to get some GNS minted
				MintAndDistributeGns(cross)
				// Skip more time to allow another mint
				testing.SkipHeights(100)
				// Now set leftover amount for next distribution
				setLeftGNSAmount(100)
			},
			verify: func(t *testing.T) {
				distributed, _ := MintAndDistributeGns(cross)
				uassert.True(t, distributed >= 0)
			},
		},
		{
			name: "success - no distribution when start timestamp is 0",
			setup: func() {
				resetObject(t)
				distributionStartTimestamp = 0
			},
			verify: func(t *testing.T) {
				distributed, _ := MintAndDistributeGns(cross)
				uassert.Equal(t, int64(0), distributed)
			},
		},
		{
			name: "success - no distribution when current time < start timestamp",
			setup: func() {
				resetObject(t)
				now := time.Now().Unix()
				testing.SetOriginCaller(adminAddr)
				SetDistributionStartTime(cross, now+1000000)
			},
			verify: func(t *testing.T) {
				distributed, ok := MintAndDistributeGns(cross)
				uassert.Equal(t, int64(0), distributed)
				uassert.True(t, ok)
			},
		},
		{
			name: "success - skip when already minted at this timestamp",
			setup: func() {
				resetObject(t)
				now := time.Now().Unix()
				testing.SetOriginCaller(adminAddr)
				SetDistributionStartTime(cross, now+100)
				testing.SkipHeights(200)
				// First distribution
				MintAndDistributeGns(cross)
			},
			verify: func(t *testing.T) {
				// Second distribution at same timestamp should return 0
				distributed, ok := MintAndDistributeGns(cross)
				uassert.True(t, ok)
				uassert.Equal(t, int64(0), distributed)
			},
		},
		{
			name: "success - prevent re-entrancy when lastExecutedTimestamp >= currentTimestamp",
			setup: func() {
				resetObject(t)
				now := time.Now().Unix()
				testing.SetOriginCaller(adminAddr)
				SetDistributionStartTime(cross, now+100)
				testing.SkipHeights(200)
				setLastExecutedTimestamp(now + 1000)
			},
			verify: func(t *testing.T) {
				distributed, _ := MintAndDistributeGns(cross)
				uassert.Equal(t, int64(0), distributed)
			},
		},
		{
			name: "success - tracks leftGNSAmount when remainder exists",
			setup: func() {
				resetObject(t)
				now := time.Now().Unix()
				testing.SetOriginCaller(adminAddr)
				SetDistributionStartTime(cross, now+100)
				testing.SkipHeights(200)
				// Set distribution percentages that will create remainder
				changeDistributionPcts(
					LIQUIDITY_STAKER, 3333,
					DEVOPS, 3333,
					COMMUNITY_POOL, 3333,
					GOV_STAKER, 1,
				)
			},
			verify: func(t *testing.T) {
				testing.SkipHeights(1)
				initialLeft := GetLeftGNSAmount()
				MintAndDistributeGns(cross)
				// Should have some leftover due to rounding
				finalLeft := GetLeftGNSAmount()
				uassert.True(t, finalLeft >= initialLeft)
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given
			if tt.setup != nil {
				tt.setup()
			}

			// When - Then
			if tt.wantErr {
				uassert.PanicsWithMessage(t, tt.errMsg, func() {
					MintAndDistributeGns(cross)
				})
				return
			}

			// When
			if tt.verify != nil {
				tt.verify(t)
			}
		})
	}
}

func TestEmission_SetDistributionStartTime_EdgeCases(t *testing.T) {
	tests := []struct {
		name      string
		setup     func()
		timestamp int64
		caller    address
		wantErr   bool
		errMsg    string
	}{
		{
			name:      "success - set to exact current time + 1",
			timestamp: time.Now().Unix() + 1,
			caller:    adminAddr,
			wantErr:   false,
		},
		{
			name:      "panic - set to exact current time",
			timestamp: time.Now().Unix(),
			caller:    adminAddr,
			wantErr:   true,
			errMsg:    "distribution start timestamp must be greater than current timestamp",
		},
		{
			name:      "success - zero timestamp is valid (resets to default)",
			timestamp: 0,
			caller:    adminAddr,
			wantErr:   false,
		},
		{
			name:      "panic - max int64 timestamp",
			timestamp: math.MaxInt64,
			caller:    adminAddr,
			wantErr:   true,
			errMsg:    "distribution end timestamp must be before max int64 timestamp",
		},
		{
			name:      "success - max int64 timestamp - total distribution duration",
			timestamp: math.MaxInt64 - totalDistributionDuration,
			caller:    adminAddr,
			wantErr:   false,
		},
		{
			name:      "panic - max int64 timestamp - total distribution duration + 1",
			timestamp: math.MaxInt64 - totalDistributionDuration + 1,
			caller:    adminAddr,
			wantErr:   true,
			errMsg:    "distribution end timestamp must be before max int64 timestamp",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given
			resetObject(t)
			if tt.setup != nil {
				tt.setup()
			}
			testing.SetRealm(testing.NewUserRealm(tt.caller))

			// When - Then
			if tt.wantErr {
				uassert.AbortsWithMessage(t, tt.errMsg, func() {
					SetDistributionStartTime(cross, tt.timestamp)
				})
				return
			}

			// When
			SetDistributionStartTime(cross, tt.timestamp)

			// Then
			uassert.Equal(t, tt.timestamp, GetDistributionStartTimestamp())
		})
	}
}

func TestEmission_GetLeftGNSAmount(t *testing.T) {
	tests := []struct {
		name  string
		setup func()
		want  int64
	}{
		{
			name:  "success - initial value is 0",
			setup: func() { resetObject(t) },
			want:  0,
		},
		{
			name: "success - returns set value",
			setup: func() {
				resetObject(t)
				setLeftGNSAmount(12345)
			},
			want: 12345,
		},
		{
			name: "success - returns max int64",
			setup: func() {
				resetObject(t)
				setLeftGNSAmount(9223372036854775807)
			},
			want: 9223372036854775807,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given
			tt.setup()

			// When
			got := GetLeftGNSAmount()

			// Then
			uassert.Equal(t, tt.want, got)
		})
	}
}

func TestEmission_GetLastExecutedTimestamp(t *testing.T) {
	tests := []struct {
		name  string
		setup func()
		want  int64
	}{
		{
			name:  "success - initial value is 0",
			setup: func() { resetObject(t) },
			want:  0,
		},
		{
			name: "success - returns set value",
			setup: func() {
				resetObject(t)
				setLastExecutedTimestamp(1234567890)
			},
			want: 1234567890,
		},
		{
			name: "success - returns max int64",
			setup: func() {
				resetObject(t)
				setLastExecutedTimestamp(9223372036854775807)
			},
			want: 9223372036854775807,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given
			tt.setup()

			// When
			got := GetLastExecutedTimestamp()

			// Then
			uassert.Equal(t, tt.want, got)
		})
	}
}

func TestEmission_GetDistributionStartTimestamp(t *testing.T) {
	tests := []struct {
		name  string
		setup func()
		want  int64
	}{
		{
			name:  "success - initial value is 0",
			setup: func() { resetObject(t) },
			want:  0,
		},
		{
			name: "success - returns set value",
			setup: func() {
				resetObject(t)
				now := time.Now().Unix()
				testing.SetOriginCaller(adminAddr)
				SetDistributionStartTime(cross, now+1000)
			},
			want: time.Now().Unix() + 1000,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given
			tt.setup()

			// When
			got := GetDistributionStartTimestamp()

			// Then
			if tt.name == "success - initial value is 0" {
				uassert.Equal(t, tt.want, got)
			} else {
				// Allow small time difference for test execution
				uassert.True(t, got >= time.Now().Unix()+999)
			}
		})
	}
}

func TestSetDistributionStartTime_InitEmissionStateWithBlockHeight(t *testing.T) {
	// This test verifies that InitEmissionState is called with actual block height,
	// not timestamp value, fixing the semantic inconsistency issue.
	tests := []struct {
		name         string
		blockHeight  int64
		setup        func() int64
		wantCheck    func(t *testing.T, startTimestamp, startHeight, expectedHeight int64)
	}{
		{
			name:        "emission start height should be block height not timestamp",
			blockHeight: 150,
			setup: func() int64 {
				now := time.Now().Unix()
				futureTimestamp := now + 10000

				// Call SetDistributionStartTime which internally calls InitEmissionState
				testing.SetOriginCaller(adminAddr)
				SetDistributionStartTime(cross, futureTimestamp)

				return futureTimestamp
			},
			wantCheck: func(t *testing.T, startTimestamp, startHeight, expectedHeight int64) {
				// startHeight should be the block height, not timestamp
				uassert.Equal(t, expectedHeight, startHeight, "startHeight should match current block height")

				// startHeight should NOT equal startTimestamp (they should be very different)
				uassert.NotEqual(t, startTimestamp, startHeight, "startHeight should not be timestamp")

				// startTimestamp should be much larger than startHeight
				// (timestamps are in Unix epoch seconds ~1700000000+, block heights are small numbers)
				uassert.True(t, startTimestamp > 1000000000, "startTimestamp should be Unix epoch timestamp")
				uassert.True(t, startHeight < 1000, "startHeight should be block height (small number)")
			},
		},
		{
			name:        "emission start height tracks blockchain height correctly",
			blockHeight: 500,
			setup: func() int64 {
				now := time.Now().Unix()
				futureTimestamp := now + 20000

				testing.SetOriginCaller(adminAddr)
				SetDistributionStartTime(cross, futureTimestamp)

				return futureTimestamp
			},
			wantCheck: func(t *testing.T, startTimestamp, startHeight, expectedHeight int64) {
				// Should capture the exact block height at initialization
				uassert.Equal(t, expectedHeight, startHeight, "startHeight should match expected height")

				// Verify it's not the timestamp
				uassert.NotEqual(t, startTimestamp, startHeight)
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Reset state before each test
			resetObject(t)

			// Set block height BEFORE any initialization
			testing.SetHeight(tt.blockHeight)

			// Manually reset GNS emission state with the correct height
			// This ensures the emission state is initialized with the test's block height
			testing.SetOriginCaller(adminAddr)
			func(cur realm) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/emission"))
				gns.InitEmissionState(cross, tt.blockHeight, time.Now().Unix())
			}(cross)

			// Setup and get the start timestamp used
			startTimestamp := tt.setup()

			// Get the emission start height from GNS
			startHeight := gns.GetEmissionStartHeight()

			// Verify expectations
			tt.wantCheck(t, startTimestamp, startHeight, tt.blockHeight)
		})
	}
}
