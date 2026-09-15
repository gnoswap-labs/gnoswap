package pool

import (
	"gno.land/p/gnoswap/utils/v1"
	"gno.land/p/nt/bptree/v0"
)

type Observation struct {
	blockTimestamp                    int64  // timestamp of the observation
	tickCumulative                    int64  // cumulative tick up to this timestamp
	secondsPerLiquidityCumulativeX128 string // cumulative seconds per liquidity
	initialized                       bool   // whether this observation has been initialized
}

// Observation getter methods.
// BlockTimestamp returns the observation's block timestamp.
//
// Returns:
//   - blockTimestamp: Timestamp at which this observation was recorded.
func (o Observation) BlockTimestamp() int64 { return o.blockTimestamp }

// TickCumulative returns the signed cumulative tick recorded by the observation.
//
// Returns:
//   - tickCumulative: Cumulative tick value through the observation timestamp.
func (o Observation) TickCumulative() int64 { return o.tickCumulative }

// SecondsPerLiquidityCumulativeX128 returns the Q128-encoded cumulative
// seconds-per-liquidity value recorded by the observation.
//
// Returns:
//   - secondsPerLiquidityCumulativeX128: Decimal string containing the cumulative value scaled by 2^128.
func (o Observation) SecondsPerLiquidityCumulativeX128() string {
	return o.secondsPerLiquidityCumulativeX128
}

// Initialized reports whether the observation contains initialized oracle data.
//
// Returns:
//   - initialized: True when the observation slot has been initialized; false for an empty slot.
func (o Observation) Initialized() bool { return o.initialized }

// MakeObservation constructs an observation from its stored oracle accumulators.
//
// Parameters:
//   - blockTimestamp: Timestamp associated with the observation.
//   - tickCumulative: Signed cumulative tick at blockTimestamp.
//   - secondsPerLiquidityCumulativeX128: Decimal Q128-scaled cumulative seconds-per-liquidity value.
//   - initialized: Whether this observation slot is initialized and usable.
//
// Returns:
//   - observation: Observation containing the supplied timestamp, accumulators, and initialization flag.
func MakeObservation(
	blockTimestamp int64,
	tickCumulative int64,
	secondsPerLiquidityCumulativeX128 string,
	initialized bool,
) Observation {
	return Observation{
		blockTimestamp:                    blockTimestamp,
		tickCumulative:                    tickCumulative,
		secondsPerLiquidityCumulativeX128: secondsPerLiquidityCumulativeX128,
		initialized:                       initialized,
	}
}

// DefaultObservation returns the zero, uninitialized observation used for an empty slot.
//
// Returns:
//   - observation: Observation with zero timestamp and accumulators and Initialized false.
func DefaultObservation() Observation {
	return MakeObservation(
		0,
		0,
		"0",
		false,
	)
}

// ObservationTree is a pool-local oracle ring buffer keyed by index.
// It owns the B+tree key encoding so oracle code works with uint16 indices.
type ObservationTree struct {
	tree *bptree.BPTree
}

// NewObservationTree creates an empty pool-local observation tree keyed by uint16 index.
//
// Returns:
//   - tree: Initialized observation tree ready for Get, Set, and Has operations.
func NewObservationTree() *ObservationTree {
	return &ObservationTree{tree: bptree.NewBPTreeN(32)}
}

// Get looks up an observation by its circular-buffer index.
//
// Parameters:
//   - index: uint16 observation slot to read.
//
// Returns:
//   - observation: Stored observation when the tree contains a value of the expected type; otherwise the zero observation.
//   - ok: True when a stored value was found and decoded as an Observation; false for nil/uninitialized trees, missing slots, or a type mismatch.
func (t *ObservationTree) Get(index uint16) (Observation, bool) {
	if t == nil || t.tree == nil {
		return Observation{}, false
	}
	value := t.tree.Get(utils.EncodeUint16(index))
	if value == nil {
		return Observation{}, false
	}
	observation, ok := value.(Observation)
	return observation, ok
}

// Set stores an observation at a circular-buffer index.
//
// Parameters:
//   - index: uint16 observation slot to write.
//   - observation: Observation value to associate with index.
func (t *ObservationTree) Set(index uint16, observation Observation) {
	if t == nil || t.tree == nil {
		panic("observation tree is not initialized")
	}
	t.tree.Set(utils.EncodeUint16(index), observation)
}

// Has reports whether an observation slot exists in the tree.
//
// Parameters:
//   - index: uint16 observation slot to test.
//
// Returns:
//   - exists: True when the initialized tree contains index; false for nil/uninitialized trees or an absent slot.
func (t *ObservationTree) Has(index uint16) bool {
	if t == nil || t.tree == nil {
		return false
	}
	return t.tree.Has(utils.EncodeUint16(index))
}

// NewObservationsTree creates the top-level B+tree that indexes pool observation trees by pool path.
//
// Returns:
//   - tree: Empty B+tree suitable for storing pool-path observation trees.
func NewObservationsTree() *bptree.BPTree {
	return bptree.NewBPTreeN(32)
}

// NewPoolObservationsTree creates a circular observation buffer with slot zero initialized.
//
// Parameters:
//   - currentTime: Timestamp assigned to the initial observation at index zero.
//
// Returns:
//   - tree: Observation tree containing an initialized zero-index observation with zero cumulative values.
func NewPoolObservationsTree(currentTime int64) *ObservationTree {
	observations := NewObservationTree()
	observations.Set(0, MakeObservation(
		currentTime,
		0,
		"0",
		true,
	))
	return observations
}
