package position

import (
	"testing"

	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/avl"
	"gno.land/p/nt/uassert"
)

func TestStoreInitialization(t *testing.T) {
	resetTestState(t)

	uassert.NotEqual(t, nil, kvStore, "kvStore should be initialized")
	domainAddr := kvStore.GetDomainAddress()
	uassert.NotEqual(t, address(""), domainAddr, "domain address should not be empty")
}

func TestStoreSetAndGetPositions(t *testing.T) {
	t.Run("SetAndGet", func(t *testing.T) {
		resetTestState(t)

		ps := NewPositionStore(kvStore)

		uassert.False(t, ps.HasPositionsStoreKey(), "should not have positions initially")

		positions := avl.NewTree()
		err := ps.SetPositions(positions)
		uassert.NoError(t, err)

		uassert.True(t, ps.HasPositionsStoreKey(), "should have positions after setting")

		retrieved := ps.GetPositions()
		uassert.NotEqual(t, nil, retrieved)
	})

	t.Run("NotInitializedPanic", func(t *testing.T) {
		resetTestState(t)

		ps := NewPositionStore(kvStore)

		defer func() {
			r := recover()
			uassert.NotEqual(t, nil, r, "should panic when getting uninitialized positions")
		}()

		ps.GetPositions()
	})
}

func TestStoreSetAndGetPositionNextID(t *testing.T) {
	t.Run("SetAndGet", func(t *testing.T) {
		resetTestState(t)

		ps := NewPositionStore(kvStore)

		uassert.False(t, ps.HasPositionNextIDStoreKey(), "should not have position next ID initially")

		err := ps.SetPositionNextID(100)
		uassert.NoError(t, err)

		uassert.True(t, ps.HasPositionNextIDStoreKey(), "should have position next ID after setting")

		retrieved := ps.GetPositionNextID()
		uassert.Equal(t, uint64(100), retrieved)
	})

	t.Run("NotInitializedPanic", func(t *testing.T) {
		resetTestState(t)

		ps := NewPositionStore(kvStore)

		defer func() {
			r := recover()
			uassert.NotEqual(t, nil, r, "should panic when getting uninitialized position next ID")
		}()

		ps.GetPositionNextID()
	})
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
		name   string
		testFn func(*testing.T)
	}{
		{
			name: "Has",
			testFn: func(t *testing.T) {
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
					liquidity: u256.Zero(),
				}

				err = ps.SetPosition(1, position)
				uassert.NoError(t, err)

				uassert.True(t, ps.HasPosition(1), "position 1 should exist after setting")
			},
		},
		{
			name: "Get",
			testFn: func(t *testing.T) {
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
					liquidity: u256.Zero(),
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
			testFn: func(t *testing.T) {
				resetTestState(t)
				ps := NewPositionStore(kvStore)

				position := Position{
					poolKey:   "gno.land/r/demo/pool1",
					operator:  "g1test",
					tickLower: -100,
					tickUpper: 100,
					liquidity: u256.Zero(),
				}

				err := ps.SetPosition(1, position)
				uassert.ErrorContains(t, err, "positions store key not found")
			},
		},
		{
			name: "Remove",
			testFn: func(t *testing.T) {
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
					liquidity: u256.Zero(),
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
			testFn: func(t *testing.T) {
				resetTestState(t)
				ps := NewPositionStore(kvStore)

				err := ps.RemovePosition(1)
				uassert.ErrorContains(t, err, "positions store key not found")
			},
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			tc.testFn(t)
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
		liquidity: u256.Zero(),
	}

	position2 := Position{
		poolKey:   "gno.land/r/demo/pool2",
		operator:  "g1test2",
		tickLower: -100,
		tickUpper: 100,
		liquidity: u256.Zero(),
	}

	position3 := Position{
		poolKey:   "gno.land/r/demo/pool3",
		operator:  "g1test3",
		tickLower: -100,
		tickUpper: 100,
		liquidity: u256.Zero(),
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
		liquidity: u256.Zero(),
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
		liquidity: u256.Zero(),
	}

	err = ps.SetPosition(1, updatedPosition)
	uassert.NoError(t, err)

	retrieved, _ = ps.GetPosition(1)
	uassert.Equal(t, "gno.land/r/demo/pool2", retrieved.poolKey)
}

