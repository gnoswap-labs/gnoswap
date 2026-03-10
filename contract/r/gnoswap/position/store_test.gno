package position

import (
	"chain/runtime"
	"testing"

	u256 "gno.land/p/gnoswap/uint256"
	avl "gno.land/p/nt/avl/v0"
	testutils "gno.land/p/nt/testutils/v0"
	uassert "gno.land/p/nt/uassert/v0"
)

func TestStoreInitialization(t *testing.T) {
	tests := []struct {
		name     string
		verifyFn func(*testing.T)
	}{
		{
			name: "kvStore should be initialized",
			verifyFn: func(t *testing.T) {
				uassert.NotEqual(t, nil, kvStore, "kvStore should be initialized")
			},
		},
		{
			name: "domain address should not be empty",
			verifyFn: func(t *testing.T) {
				domainAddr := kvStore.GetDomainAddress()
				uassert.NotEqual(t, address(""), domainAddr, "domain address should not be empty")
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			tt.verifyFn(t)
		})
	}
}

func TestStore_AuthorizedCallers(t *testing.T) {
	tests := []struct {
		name                          string
		callerRealm                   runtime.Realm
		expectedErrorWithRead         bool
		expectedErrorWithWrite        bool
		expectedErrorMessageWithRead  string
		expectedErrorMessageWithWrite string
	}{
		{
			name:        "domain address",
			callerRealm: testing.NewCodeRealm("gno.land/r/gnoswap/position"),
		},
		{
			name:                          "domain implementation has no permission",
			callerRealm:                   testing.NewCodeRealm("gno.land/r/gnoswap/position/v2"),
			expectedErrorWithRead:         true,
			expectedErrorWithWrite:        true,
			expectedErrorMessageWithRead:  "read permission denied",
			expectedErrorMessageWithWrite: "write permission denied",
		},
		{
			name:                          "staker has read permission",
			callerRealm:                   testing.NewCodeRealm("gno.land/r/gnoswap/staker"),
			expectedErrorWithRead:         false,
			expectedErrorWithWrite:        true,
			expectedErrorMessageWithRead:  "",
			expectedErrorMessageWithWrite: "write permission denied",
		},
		{
			name:                          "panic with no permission realm",
			callerRealm:                   testing.NewCodeRealm("gno.land/r/gnoswap/gov/staker"),
			expectedErrorWithRead:         true,
			expectedErrorWithWrite:        true,
			expectedErrorMessageWithRead:  "read permission denied",
			expectedErrorMessageWithWrite: "write permission denied",
		},
		{
			name:                   "user has permission",
			callerRealm:            testing.NewUserRealm(testutils.TestAddress("bob")),
			expectedErrorWithRead:  false,
			expectedErrorWithWrite: false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			resetTestState(t)

			ps := NewPositionStore(kvStore)
			initRegisterReadableContract()

			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/position"))
			if !ps.HasPositionNextIDStoreKey() {
				ps.SetPositionNextID(1)
			}

			testing.SetRealm(tc.callerRealm)
			if tc.expectedErrorWithRead {
				uassert.PanicsContains(t, tc.expectedErrorMessageWithRead, func() {
					ps.GetPositionNextID()
				})
			} else {
				ps.GetPositionNextID()
			}

			err := ps.SetPositionNextID(2)
			if tc.expectedErrorWithWrite {
				uassert.ErrorContains(t, err, tc.expectedErrorMessageWithWrite)
			} else {
				uassert.NoError(t, err)
			}
		})
	}
}

func TestStoreSetAndGetPositions(t *testing.T) {
	tests := []struct {
		name         string
		setupFn      func(IPositionStore)
		testFn       func(*testing.T, IPositionStore)
		shouldPanic  bool
		panicMessage string
	}{
		{
			name: "set and get positions successfully",
			setupFn: func(ps IPositionStore) {
				positions := avl.NewTree()
				ps.SetPositions(positions)
			},
			testFn: func(t *testing.T, ps IPositionStore) {
				uassert.True(t, ps.HasPositionsStoreKey(), "should have positions after setting")
				retrieved := ps.GetPositions()
				uassert.NotEqual(t, nil, retrieved)
			},
		},
		{
			name: "should not have positions initially",
			testFn: func(t *testing.T, ps IPositionStore) {
				uassert.False(t, ps.HasPositionsStoreKey(), "should not have positions initially")
			},
		},
		{
			name: "panic when getting uninitialized positions",
			testFn: func(t *testing.T, ps IPositionStore) {
				ps.GetPositions()
			},
			shouldPanic:  true,
			panicMessage: "should panic when getting uninitialized positions",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			ps := NewPositionStore(kvStore)

			if tt.setupFn != nil {
				tt.setupFn(ps)
			}

			if tt.shouldPanic {
				defer func() {
					r := recover()
					uassert.NotEqual(t, nil, r, tt.panicMessage)
				}()
			}

			tt.testFn(t, ps)
		})
	}
}

func TestStoreSetAndGetPositionNextID(t *testing.T) {
	tests := []struct {
		name         string
		setupFn      func(IPositionStore)
		testFn       func(*testing.T, IPositionStore)
		shouldPanic  bool
		panicMessage string
	}{
		{
			name: "set and get position next ID successfully",
			setupFn: func(ps IPositionStore) {
				ps.SetPositionNextID(100)
			},
			testFn: func(t *testing.T, ps IPositionStore) {
				uassert.True(t, ps.HasPositionNextIDStoreKey(), "should have position next ID after setting")
				retrieved := ps.GetPositionNextID()
				uassert.Equal(t, uint64(100), retrieved)
			},
		},
		{
			name: "should not have position next ID initially",
			testFn: func(t *testing.T, ps IPositionStore) {
				uassert.False(t, ps.HasPositionNextIDStoreKey(), "should not have position next ID initially")
			},
		},
		{
			name: "panic when getting uninitialized position next ID",
			testFn: func(t *testing.T, ps IPositionStore) {
				ps.GetPositionNextID()
			},
			shouldPanic:  true,
			panicMessage: "should panic when getting uninitialized position next ID",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			ps := NewPositionStore(kvStore)

			if tt.setupFn != nil {
				tt.setupFn(ps)
			}

			if tt.shouldPanic {
				defer func() {
					r := recover()
					uassert.NotEqual(t, nil, r, tt.panicMessage)
				}()
			}

			tt.testFn(t, ps)
		})
	}
}

func TestStoreUpdatePositionNextID(t *testing.T) {
	tests := []struct {
		name      string
		initialID uint64
		updatedID uint64
	}{
		{
			name:      "increment from 1 to 2",
			initialID: 1,
			updatedID: 2,
		},
		{
			name:      "jump from 2 to 1000",
			initialID: 2,
			updatedID: 1000,
		},
		{
			name:      "reset from 1000 to 0",
			initialID: 1000,
			updatedID: 0,
		},
		{
			name:      "set to max uint64",
			initialID: 0,
			updatedID: 18446744073709551615, // uint64 max
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)

			ps := NewPositionStore(kvStore)

			err := ps.SetPositionNextID(tt.initialID)
			uassert.NoError(t, err)
			uassert.Equal(t, tt.initialID, ps.GetPositionNextID())

			err = ps.SetPositionNextID(tt.updatedID)
			uassert.NoError(t, err)
			uassert.Equal(t, tt.updatedID, ps.GetPositionNextID())
		})
	}
}

func TestStorePosition(t *testing.T) {
	testCases := []struct {
		name     string
		verifyFn func(*testing.T)
	}{
		{
			name: "Has",
			verifyFn: func(t *testing.T) {
				resetTestState(t)
				ps := NewPositionStore(kvStore)

				positions := avl.NewTree()
				err := ps.SetPositions(positions)
				uassert.NoError(t, err)

				uassert.False(t, ps.HasPosition(1), "position 1 should not exist")

				position := Position{
					poolKey:   "gno.land/r/demo/pool1",
					operator:  "g1test",
					tickLower: -100,
					tickUpper: 100,
					liquidity: *u256.Zero(),
				}

				err = ps.SetPosition(1, position)
				uassert.NoError(t, err)

				uassert.True(t, ps.HasPosition(1), "position 1 should exist after setting")
			},
		},
		{
			name: "Get",
			verifyFn: func(t *testing.T) {
				resetTestState(t)
				ps := NewPositionStore(kvStore)

				positions := avl.NewTree()
				err := ps.SetPositions(positions)
				uassert.NoError(t, err)

				_, exists := ps.GetPosition(1)
				uassert.False(t, exists, "position 1 should not exist")

				position := Position{
					poolKey:   "gno.land/r/demo/pool1",
					operator:  "g1test",
					tickLower: -100,
					tickUpper: 100,
					liquidity: *u256.Zero(),
				}

				err = ps.SetPosition(1, position)
				uassert.NoError(t, err)

				retrieved, exists := ps.GetPosition(1)
				uassert.True(t, exists, "position 1 should exist")
				uassert.Equal(t, "gno.land/r/demo/pool1", retrieved.poolKey)
				uassert.Equal(t, address("g1test"), retrieved.operator)
			},
		},
		{
			name: "SetNotInitializedError",
			verifyFn: func(t *testing.T) {
				resetTestState(t)
				ps := NewPositionStore(kvStore)

				position := Position{
					poolKey:   "gno.land/r/demo/pool1",
					operator:  "g1test",
					tickLower: -100,
					tickUpper: 100,
					liquidity: *u256.Zero(),
				}

				err := ps.SetPosition(1, position)
				uassert.ErrorContains(t, err, "positions store key not found")
			},
		},
		{
			name: "Remove",
			verifyFn: func(t *testing.T) {
				resetTestState(t)
				ps := NewPositionStore(kvStore)

				positions := avl.NewTree()
				err := ps.SetPositions(positions)
				uassert.NoError(t, err)

				position := Position{
					poolKey:   "gno.land/r/demo/pool1",
					operator:  "g1test",
					tickLower: -100,
					tickUpper: 100,
					liquidity: *u256.Zero(),
				}

				err = ps.SetPosition(1, position)
				uassert.NoError(t, err)
				uassert.True(t, ps.HasPosition(1), "position 1 should exist")

				err = ps.RemovePosition(1)
				uassert.NoError(t, err)
				uassert.False(t, ps.HasPosition(1), "position 1 should be removed")
			},
		},
		{
			name: "RemoveNotInitializedError",
			verifyFn: func(t *testing.T) {
				resetTestState(t)
				ps := NewPositionStore(kvStore)

				err := ps.RemovePosition(1)
				uassert.ErrorContains(t, err, "positions store key not found")
			},
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			tc.verifyFn(t)
		})
	}
}

func TestStoreMultiplePositions(t *testing.T) {
	resetTestState(t)

	ps := NewPositionStore(kvStore)

	positions := avl.NewTree()
	err := ps.SetPositions(positions)
	uassert.NoError(t, err)

	position1 := Position{
		poolKey:   "gno.land/r/demo/pool1",
		operator:  "g1test1",
		tickLower: -100,
		tickUpper: 100,
		liquidity: *u256.Zero(),
	}

	position2 := Position{
		poolKey:   "gno.land/r/demo/pool2",
		operator:  "g1test2",
		tickLower: -100,
		tickUpper: 100,
		liquidity: *u256.Zero(),
	}

	position3 := Position{
		poolKey:   "gno.land/r/demo/pool3",
		operator:  "g1test3",
		tickLower: -100,
		tickUpper: 100,
		liquidity: *u256.Zero(),
	}

	err = ps.SetPosition(1, position1)
	uassert.NoError(t, err)
	err = ps.SetPosition(2, position2)
	uassert.NoError(t, err)
	err = ps.SetPosition(3, position3)
	uassert.NoError(t, err)

	uassert.True(t, ps.HasPosition(1))
	uassert.True(t, ps.HasPosition(2))
	uassert.True(t, ps.HasPosition(3))

	retrieved1, _ := ps.GetPosition(1)
	retrieved2, _ := ps.GetPosition(2)
	retrieved3, _ := ps.GetPosition(3)

	uassert.Equal(t, "gno.land/r/demo/pool1", retrieved1.poolKey)
	uassert.Equal(t, "gno.land/r/demo/pool2", retrieved2.poolKey)
	uassert.Equal(t, "gno.land/r/demo/pool3", retrieved3.poolKey)
}

func TestStoreUpdatePosition(t *testing.T) {
	resetTestState(t)

	ps := NewPositionStore(kvStore)

	positions := avl.NewTree()
	err := ps.SetPositions(positions)
	uassert.NoError(t, err)

	position := Position{
		poolKey:   "gno.land/r/demo/pool1",
		operator:  "g1test",
		tickLower: -100,
		tickUpper: 100,
		liquidity: *u256.Zero(),
	}

	err = ps.SetPosition(1, position)
	uassert.NoError(t, err)

	retrieved, _ := ps.GetPosition(1)
	uassert.Equal(t, "gno.land/r/demo/pool1", retrieved.poolKey)

	updatedPosition := Position{
		poolKey:   "gno.land/r/demo/pool2",
		operator:  "g1test",
		tickLower: -100,
		tickUpper: 100,
		liquidity: *u256.Zero(),
	}

	err = ps.SetPosition(1, updatedPosition)
	uassert.NoError(t, err)

	retrieved, _ = ps.GetPosition(1)
	uassert.Equal(t, "gno.land/r/demo/pool2", retrieved.poolKey)
}

func makeCanonicalPosition() Position {
	return Position{
		poolKey:                  "gno.land/r/demo/pool1",
		operator:                 "g1test",
		tickLower:                -100,
		tickUpper:                100,
		liquidity:                *u256.MustFromDecimal("5000"),
		feeGrowthInside0LastX128: *u256.MustFromDecimal("100"),
		feeGrowthInside1LastX128: *u256.MustFromDecimal("200"),
		tokensOwed0:              *u256.MustFromDecimal("50"),
		tokensOwed1:              *u256.MustFromDecimal("60"),
		token0Balance:            *u256.MustFromDecimal("1000"),
		token1Balance:            *u256.MustFromDecimal("2000"),
		burned:                   false,
	}
}

func verifyCanonicalPosition(t *testing.T, pos Position) {
	t.Helper()
	uassert.Equal(t, "gno.land/r/demo/pool1", pos.poolKey)
	uassert.Equal(t, int32(-100), pos.tickLower)
	uassert.Equal(t, int32(100), pos.tickUpper)
	uassert.Equal(t, "5000", pos.Liquidity().ToString())
	uassert.Equal(t, "100", pos.FeeGrowthInside0LastX128().ToString())
	uassert.Equal(t, "200", pos.FeeGrowthInside1LastX128().ToString())
	uassert.Equal(t, "50", pos.TokensOwed0().ToString())
	uassert.Equal(t, "60", pos.TokensOwed1().ToString())
	uassert.Equal(t, "1000", pos.Token0Balance().ToString())
	uassert.Equal(t, "2000", pos.Token1Balance().ToString())
	uassert.False(t, pos.Burned())
}

// initStoreWithCanonicalPosition sets up a positionStore with a single
// canonical position at the given ID.
func initStoreWithCanonicalPosition(t *testing.T, positionId uint64) IPositionStore {
	t.Helper()
	resetTestState(t)
	ps := NewPositionStore(kvStore)
	err := ps.SetPositions(avl.NewTree())
	uassert.NoError(t, err)
	err = ps.SetPosition(positionId, makeCanonicalPosition())
	uassert.NoError(t, err)
	return ps
}

func TestPosition_ValueTypeImmutability(t *testing.T) {
	const posID = uint64(1)

	mutationTests := []struct {
		name   string
		mutate func(pos Position)
	}{
		{
			"setter mutation does not affect store",
			func(pos Position) {
				pos.SetLiquidity(u256.MustFromDecimal("0"))
				pos.SetFeeGrowthInside0LastX128(u256.MustFromDecimal("99999"))
				pos.SetFeeGrowthInside1LastX128(u256.MustFromDecimal("88888"))
				pos.SetTokensOwed0(u256.MustFromDecimal("77777"))
				pos.SetTokensOwed1(u256.MustFromDecimal("66666"))
				pos.SetToken0Balance(u256.MustFromDecimal("55555"))
				pos.SetToken1Balance(u256.MustFromDecimal("44444"))
				pos.SetBurned(true)
				pos.SetPoolKey("modified/pool")
				pos.SetTickLower(-999)
				pos.SetTickUpper(999)
				pos.SetOperator("g1attacker")
			},
		},
		{
			"accessor pointer arithmetic does not affect store",
			func(pos Position) {
				pos.Liquidity().Add(pos.Liquidity(), u256.MustFromDecimal("9000"))
				pos.FeeGrowthInside0LastX128().Set(u256.MustFromDecimal("99999"))
				pos.TokensOwed0().Set(u256.MustFromDecimal("99999"))
				pos.Token0Balance().Set(u256.MustFromDecimal("99999"))
			},
		},
	}

	for _, tt := range mutationTests {
		t.Run(tt.name, func(t *testing.T) {
			ps := initStoreWithCanonicalPosition(t, posID)
			retrieved, ok := ps.GetPosition(posID)
			uassert.True(t, ok)
			tt.mutate(retrieved)

			stored, ok := ps.GetPosition(posID)
			uassert.True(t, ok)
			verifyCanonicalPosition(t, stored)
		})
	}

	t.Run("two retrievals are independent copies", func(t *testing.T) {
		ps := initStoreWithCanonicalPosition(t, posID)

		copy1, _ := ps.GetPosition(posID)
		copy2, _ := ps.GetPosition(posID)

		copy1.SetLiquidity(u256.MustFromDecimal("0"))
		copy1.SetPoolKey("modified")

		uassert.Equal(t, "5000", copy2.Liquidity().ToString())
		uassert.Equal(t, "gno.land/r/demo/pool1", copy2.poolKey)
	})

	t.Run("changes require explicit SetPosition", func(t *testing.T) {
		ps := initStoreWithCanonicalPosition(t, posID)

		modified, _ := ps.GetPosition(posID)
		modified.SetLiquidity(u256.MustFromDecimal("9999"))

		// without SetPosition → store unchanged
		stored, _ := ps.GetPosition(posID)
		uassert.Equal(t, "5000", stored.Liquidity().ToString())

		// with SetPosition → store updated
		err := ps.SetPosition(posID, modified)
		uassert.NoError(t, err)
		stored2, _ := ps.GetPosition(posID)
		uassert.Equal(t, "9999", stored2.Liquidity().ToString())
	})

	t.Run("cross-position isolation", func(t *testing.T) {
		resetTestState(t)
		ps := NewPositionStore(kvStore)
		err := ps.SetPositions(avl.NewTree())
		uassert.NoError(t, err)

		pos1 := makeCanonicalPosition()
		pos2 := makeCanonicalPosition()
		pos2.SetLiquidity(u256.MustFromDecimal("8000"))
		pos2.SetPoolKey("gno.land/r/demo/pool2")

		ps.SetPosition(1, pos1)
		ps.SetPosition(2, pos2)

		// mutate retrieved position 1
		r1, _ := ps.GetPosition(1)
		r1.SetLiquidity(u256.MustFromDecimal("0"))
		r1.Token0Balance().Set(u256.MustFromDecimal("0"))

		// both positions retain their original values
		s1, _ := ps.GetPosition(1)
		s2, _ := ps.GetPosition(2)
		uassert.Equal(t, "5000", s1.Liquidity().ToString())
		uassert.Equal(t, "1000", s1.Token0Balance().ToString())
		uassert.Equal(t, "8000", s2.Liquidity().ToString())
		uassert.Equal(t, "gno.land/r/demo/pool2", s2.poolKey)
	})
}

func TestPosition_SetterDereferencesInput(t *testing.T) {
	tests := []struct {
		name     string
		set      func(pos *Position, val *u256.Uint)
		get      func(pos *Position) string
		initial  string
		mutated  string
		expected string
	}{
		{
			"Liquidity",
			func(pos *Position, val *u256.Uint) { pos.SetLiquidity(val) },
			func(pos *Position) string { return pos.Liquidity().ToString() },
			"5000", "9999", "5000",
		},
		{
			"FeeGrowthInside0LastX128",
			func(pos *Position, val *u256.Uint) { pos.SetFeeGrowthInside0LastX128(val) },
			func(pos *Position) string { return pos.FeeGrowthInside0LastX128().ToString() },
			"100", "9999", "100",
		},
		{
			"FeeGrowthInside1LastX128",
			func(pos *Position, val *u256.Uint) { pos.SetFeeGrowthInside1LastX128(val) },
			func(pos *Position) string { return pos.FeeGrowthInside1LastX128().ToString() },
			"200", "9999", "200",
		},
		{
			"TokensOwed0",
			func(pos *Position, val *u256.Uint) { pos.SetTokensOwed0(val) },
			func(pos *Position) string { return pos.TokensOwed0().ToString() },
			"50", "9999", "50",
		},
		{
			"TokensOwed1",
			func(pos *Position, val *u256.Uint) { pos.SetTokensOwed1(val) },
			func(pos *Position) string { return pos.TokensOwed1().ToString() },
			"60", "9999", "60",
		},
		{
			"Token0Balance",
			func(pos *Position, val *u256.Uint) { pos.SetToken0Balance(val) },
			func(pos *Position) string { return pos.Token0Balance().ToString() },
			"1000", "9999", "1000",
		},
		{
			"Token1Balance",
			func(pos *Position, val *u256.Uint) { pos.SetToken1Balance(val) },
			func(pos *Position) string { return pos.Token1Balance().ToString() },
			"2000", "9999", "2000",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			pos := makeCanonicalPosition()
			val := u256.MustFromDecimal(tt.initial)
			tt.set(&pos, val)

			// mutate the original pointer after setting
			val.Set(u256.MustFromDecimal(tt.mutated))

			// position must still hold the initial value
			uassert.Equal(t, tt.expected, tt.get(&pos))
		})
	}
}

// TestPosition_ZeroInitialization verifies that a zero-value Position
// has properly initialized value type fields.
func TestPosition_ZeroInitialization(t *testing.T) {
	pos := Position{}

	uassert.Equal(t, "0", pos.Liquidity().ToString())
	uassert.Equal(t, "0", pos.FeeGrowthInside0LastX128().ToString())
	uassert.Equal(t, "0", pos.FeeGrowthInside1LastX128().ToString())
	uassert.Equal(t, "0", pos.TokensOwed0().ToString())
	uassert.Equal(t, "0", pos.TokensOwed1().ToString())
	uassert.Equal(t, "0", pos.Token0Balance().ToString())
	uassert.Equal(t, "0", pos.Token1Balance().ToString())
	uassert.False(t, pos.Burned())
	uassert.True(t, pos.IsClear())
}

// TestPosition_IsClearWithValueTypes verifies that IsClear works
// correctly with value type fields.
func TestPosition_IsClearWithValueTypes(t *testing.T) {
	tests := []struct {
		name      string
		liquidity string
		owed0     string
		owed1     string
		expected  bool
	}{
		{"all zero", "0", "0", "0", true},
		{"has liquidity", "1000", "0", "0", false},
		{"has owed0", "0", "100", "0", false},
		{"has owed1", "0", "0", "100", false},
		{"all non-zero", "1000", "100", "200", false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			pos := Position{}
			pos.SetLiquidity(u256.MustFromDecimal(tt.liquidity))
			pos.SetTokensOwed0(u256.MustFromDecimal(tt.owed0))
			pos.SetTokensOwed1(u256.MustFromDecimal(tt.owed1))
			uassert.Equal(t, tt.expected, pos.IsClear())
		})
	}
}
