package v1

import (
	"testing"

	bptree "gno.land/p/nt/bptree/v0"
	uassert "gno.land/p/nt/uassert/v0"
)

// newTestUserDepositsResolver returns a fresh resolver with no entries.
func newTestUserDepositsResolver() *UserDepositsResolver {
	return NewUserDepositsResolver(bptree.NewBPTreeN(16))
}

// seedDeposits inserts (addr, depositId) pairs into the resolver.
func seedDeposits(r *UserDepositsResolver, entries map[address][]uint64) {
	for addr, ids := range entries {
		for _, id := range ids {
			r.addDeposit(addr, id)
		}
	}
}

// collectIterateAll returns the deposit ids visited by IterateAll for addr.
func collectIterateAll(r *UserDepositsResolver, addr address) []uint64 {
	got := make([]uint64, 0)
	r.IterateAll(addr, func(depositId uint64) bool {
		got = append(got, depositId)
		return false
	})
	return got
}

// TestUserDepositsResolver_AddDeposit covers add/has semantics.
func TestUserDepositsResolver_AddDeposit(t *testing.T) {
	tests := []struct {
		name       string
		addr       address
		depositIds []uint64
		expectSize int
	}{
		{
			name:       "add single deposit",
			addr:       addr01,
			depositIds: []uint64{1},
			expectSize: 1,
		},
		{
			name:       "add multiple deposits for one address",
			addr:       addr01,
			depositIds: []uint64{1, 2, 3, 5, 7},
			expectSize: 5,
		},
		{
			name:       "duplicate add overwrites silently",
			addr:       addr01,
			depositIds: []uint64{1, 1, 1},
			expectSize: 1,
		},
		{
			name:       "no add yields empty",
			addr:       addr01,
			depositIds: []uint64{},
			expectSize: 0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			r := newTestUserDepositsResolver()

			for _, id := range tt.depositIds {
				r.addDeposit(tt.addr, id)
			}

			uassert.Equal(t, tt.expectSize, r.Size())
		})
	}
}

// TestUserDepositsResolver_RemoveDeposit covers remove semantics.
func TestUserDepositsResolver_RemoveDeposit(t *testing.T) {
	tests := []struct {
		name       string
		seed       map[address][]uint64
		removeAddr address
		removeId   uint64
		expectSize int
		expectIds  []uint64 // remaining ids for removeAddr
	}{
		{
			name:       "remove existing entry",
			seed:       map[address][]uint64{addr01: {1, 2, 3}},
			removeAddr: addr01,
			removeId:   2,
			expectSize: 2,
			expectIds:  []uint64{1, 3},
		},
		{
			name:       "remove only entry",
			seed:       map[address][]uint64{addr01: {42}},
			removeAddr: addr01,
			removeId:   42,
			expectSize: 0,
			expectIds:  []uint64{},
		},
		{
			name:       "remove non-existent id is a no-op",
			seed:       map[address][]uint64{addr01: {1, 2}},
			removeAddr: addr01,
			removeId:   999,
			expectSize: 2,
			expectIds:  []uint64{1, 2},
		},
		{
			name:       "remove from empty tree is a no-op",
			seed:       map[address][]uint64{},
			removeAddr: addr01,
			removeId:   1,
			expectSize: 0,
			expectIds:  []uint64{},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			r := newTestUserDepositsResolver()
			seedDeposits(r, tt.seed)

			r.removeDeposit(tt.removeAddr, tt.removeId)

			uassert.Equal(t, tt.expectSize, r.Size())

			got := collectIterateAll(r, tt.removeAddr)
			uassert.Equal(t, len(tt.expectIds), len(got))
			for i, id := range tt.expectIds {
				uassert.Equal(t, id, got[i])
			}
		})
	}
}

// TestUserDepositsResolver_RemoveDoesNotAffectOtherAddresses verifies that
// removing under one address keeps other addresses' entries intact.
func TestUserDepositsResolver_RemoveDoesNotAffectOtherAddresses(t *testing.T) {
	r := newTestUserDepositsResolver()
	seedDeposits(r, map[address][]uint64{
		addr01: {1, 2, 3},
		addr02: {10, 20},
	})

	r.removeDeposit(addr01, 2)

	uassert.Equal(t, uint64(2), r.userPositionCount(addr01.String()))
	uassert.Equal(t, uint64(2), r.userPositionCount(addr02.String()))

	addr02Ids := collectIterateAll(r, addr02)
	uassert.Equal(t, 2, len(addr02Ids))
	uassert.Equal(t, uint64(10), addr02Ids[0])
	uassert.Equal(t, uint64(20), addr02Ids[1])
}

// TestUserDepositsResolver_userPositionCount covers per-address counting.
func TestUserDepositsResolver_userPositionCount(t *testing.T) {
	tests := []struct {
		name       string
		seed       map[address][]uint64
		queryAddr  address
		expectSize uint64
	}{
		{
			name:       "address with multiple deposits",
			seed:       map[address][]uint64{addr01: {1, 2, 3, 4, 5}},
			queryAddr:  addr01,
			expectSize: 5,
		},
		{
			name:       "address with no deposits",
			seed:       map[address][]uint64{addr01: {1, 2}},
			queryAddr:  addr02,
			expectSize: 0,
		},
		{
			name: "isolates count to the queried address only",
			seed: map[address][]uint64{
				addr01: {1, 2, 3},
				addr02: {10, 20, 30, 40},
			},
			queryAddr:  addr01,
			expectSize: 3,
		},
		{
			name:       "empty tree returns zero",
			seed:       map[address][]uint64{},
			queryAddr:  addr01,
			expectSize: 0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			r := newTestUserDepositsResolver()
			seedDeposits(r, tt.seed)

			got := r.userPositionCount(tt.queryAddr.String())
			uassert.Equal(t, tt.expectSize, got)
		})
	}
}

// TestUserDepositsResolver_IterateAll covers per-address ascending iteration.
func TestUserDepositsResolver_IterateAll(t *testing.T) {
	tests := []struct {
		name      string
		seed      map[address][]uint64
		queryAddr address
		expectIds []uint64
	}{
		{
			name:      "empty tree yields nothing",
			seed:      map[address][]uint64{},
			queryAddr: addr01,
			expectIds: []uint64{},
		},
		{
			name:      "ids visited in ascending order",
			seed:      map[address][]uint64{addr01: {7, 1, 5, 3}},
			queryAddr: addr01,
			expectIds: []uint64{1, 3, 5, 7},
		},
		{
			name: "only target address ids are visited",
			seed: map[address][]uint64{
				addr01: {1, 2},
				addr02: {10, 20, 30},
			},
			queryAddr: addr02,
			expectIds: []uint64{10, 20, 30},
		},
		{
			name:      "non-existent address yields nothing",
			seed:      map[address][]uint64{addr01: {1, 2, 3}},
			queryAddr: addr02,
			expectIds: []uint64{},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			r := newTestUserDepositsResolver()
			seedDeposits(r, tt.seed)

			got := collectIterateAll(r, tt.queryAddr)
			uassert.Equal(t, len(tt.expectIds), len(got))
			for i, id := range tt.expectIds {
				uassert.Equal(t, id, got[i])
			}
		})
	}
}

// TestUserDepositsResolver_IterateAll_EarlyStop verifies the callback can stop iteration.
func TestUserDepositsResolver_IterateAll_EarlyStop(t *testing.T) {
	r := newTestUserDepositsResolver()
	seedDeposits(r, map[address][]uint64{addr01: {1, 2, 3, 4, 5}})

	visited := make([]uint64, 0)
	r.IterateAll(addr01, func(depositId uint64) bool {
		visited = append(visited, depositId)
		return depositId == 3 // stop after visiting id 3
	})

	uassert.Equal(t, 3, len(visited))
	uassert.Equal(t, uint64(1), visited[0])
	uassert.Equal(t, uint64(2), visited[1])
	uassert.Equal(t, uint64(3), visited[2])
}

// TestUserDepositsResolver_IterateByOffset covers paginated iteration.
func TestUserDepositsResolver_IterateByOffset(t *testing.T) {
	tests := []struct {
		name      string
		seed      map[address][]uint64
		queryAddr address
		offset    int
		count     int
		expectIds []uint64
	}{
		{
			name:      "first page",
			seed:      map[address][]uint64{addr01: {1, 2, 3, 4, 5}},
			queryAddr: addr01,
			offset:    0,
			count:     2,
			expectIds: []uint64{1, 2},
		},
		{
			name:      "middle page",
			seed:      map[address][]uint64{addr01: {1, 2, 3, 4, 5}},
			queryAddr: addr01,
			offset:    2,
			count:     2,
			expectIds: []uint64{3, 4},
		},
		{
			name:      "last page partial",
			seed:      map[address][]uint64{addr01: {1, 2, 3, 4, 5}},
			queryAddr: addr01,
			offset:    4,
			count:     10,
			expectIds: []uint64{5},
		},
		{
			name:      "offset past end yields nothing",
			seed:      map[address][]uint64{addr01: {1, 2, 3}},
			queryAddr: addr01,
			offset:    10,
			count:     5,
			expectIds: []uint64{},
		},
		{
			name:      "negative offset normalized to zero",
			seed:      map[address][]uint64{addr01: {1, 2, 3}},
			queryAddr: addr01,
			offset:    -5,
			count:     2,
			expectIds: []uint64{1, 2},
		},
		{
			name:      "non-positive count yields nothing",
			seed:      map[address][]uint64{addr01: {1, 2, 3}},
			queryAddr: addr01,
			offset:    0,
			count:     0,
			expectIds: []uint64{},
		},
		{
			name: "pagination ignores other addresses",
			seed: map[address][]uint64{
				addr01: {1, 2, 3},
				addr02: {10, 20, 30, 40},
			},
			queryAddr: addr02,
			offset:    1,
			count:     2,
			expectIds: []uint64{20, 30},
		},
		{
			name:      "non-existent address yields nothing",
			seed:      map[address][]uint64{addr01: {1, 2, 3}},
			queryAddr: addr02,
			offset:    0,
			count:     5,
			expectIds: []uint64{},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			r := newTestUserDepositsResolver()
			seedDeposits(r, tt.seed)

			got := make([]uint64, 0)
			r.IterateByOffset(tt.queryAddr, tt.offset, tt.count, func(depositId uint64) bool {
				got = append(got, depositId)
				return false
			})

			uassert.Equal(t, len(tt.expectIds), len(got))
			for i, id := range tt.expectIds {
				uassert.Equal(t, id, got[i])
			}
		})
	}
}

// TestUserDepositsResolver_Size covers the global entry count.
func TestUserDepositsResolver_Size(t *testing.T) {
	tests := []struct {
		name       string
		seed       map[address][]uint64
		expectSize int
	}{
		{
			name:       "empty",
			seed:       map[address][]uint64{},
			expectSize: 0,
		},
		{
			name:       "single address",
			seed:       map[address][]uint64{addr01: {1, 2, 3}},
			expectSize: 3,
		},
		{
			name: "multiple addresses sum",
			seed: map[address][]uint64{
				addr01: {1, 2},
				addr02: {10, 20, 30},
			},
			expectSize: 5,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			r := newTestUserDepositsResolver()
			seedDeposits(r, tt.seed)
			uassert.Equal(t, tt.expectSize, r.Size())
		})
	}
}

// TestUserDepositsResolver_AddressIsolation explicitly verifies that two
// addresses do not collide via prefix scans, even when their string
// representations share a prefix-like substring.
func TestUserDepositsResolver_AddressIsolation(t *testing.T) {
	r := newTestUserDepositsResolver()

	// Use addr01 and addr02 and additionally seed many cross-entries to
	// guard against accidental prefix bleed.
	seedDeposits(r, map[address][]uint64{
		addr01: {1, 2, 3, 100, 200},
		addr02: {1, 2, 3, 100, 200},
	})

	uassert.Equal(t, uint64(5), r.userPositionCount(addr01.String()))
	uassert.Equal(t, uint64(5), r.userPositionCount(addr02.String()))

	addr01Ids := collectIterateAll(r, addr01)
	addr02Ids := collectIterateAll(r, addr02)
	expected := []uint64{1, 2, 3, 100, 200}

	uassert.Equal(t, len(expected), len(addr01Ids))
	uassert.Equal(t, len(expected), len(addr02Ids))
	for i, id := range expected {
		uassert.Equal(t, id, addr01Ids[i])
		uassert.Equal(t, id, addr02Ids[i])
	}
}
