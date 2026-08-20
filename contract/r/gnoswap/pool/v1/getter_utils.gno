package pool

import (
	pl "gno.land/r/gnoswap/pool"
)

// The functions below are makeEntrySafeFn transformations handed to
// rotree.Wrap. They run on every read through a read-only view, so each one
// returns a value the caller may hold without reaching realm-owned state.

// clonePoolEntry is the transformation for the pool tree. Pool is mutable and
// its setters are declared in /r/gnoswap/pool, so an external holder of the
// stored pointer could write realm state through it.
func clonePoolEntry(value any) any {
	pool, ok := value.(*pl.Pool)
	if !ok {
		return nil
	}

	return pool.Clone()
}
