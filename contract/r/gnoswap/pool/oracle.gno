package pool

import bptree "gno.land/p/nt/bptree/v0"

type Observation struct {
	blockTimestamp                    int64  // timestamp of the observation
	tickCumulative                    int64  // cumulative tick up to this timestamp
	secondsPerLiquidityCumulativeX128 string // cumulative seconds per liquidity
	initialized                       bool   // whether this observation has been initialized
}

// Observation Getters methods
func (o *Observation) BlockTimestamp() int64 { return o.blockTimestamp }
func (o *Observation) TickCumulative() int64 { return o.tickCumulative }
func (o *Observation) SecondsPerLiquidityCumulativeX128() string {
	return o.secondsPerLiquidityCumulativeX128
}
func (o *Observation) Initialized() bool { return o.initialized }

// Observation Setters methods
func (o *Observation) SetBlockTimestamp(blockTimestamp int64) {
	o.blockTimestamp = blockTimestamp
}

func (o *Observation) SetTickCumulative(tickCumulative int64) {
	o.tickCumulative = tickCumulative
}

func (o *Observation) SetSecondsPerLiquidityCumulativeX128(secondsPerLiquidityCumulativeX128 string) {
	o.secondsPerLiquidityCumulativeX128 = secondsPerLiquidityCumulativeX128
}

func (o *Observation) SetInitialized(initialized bool) {
	o.initialized = initialized
}

func (o *Observation) Clone() *Observation {
	return &Observation{
		blockTimestamp:                    o.blockTimestamp,
		tickCumulative:                    o.tickCumulative,
		secondsPerLiquidityCumulativeX128: o.secondsPerLiquidityCumulativeX128,
		initialized:                       o.initialized,
	}
}

func NewObservation(
	blockTimestamp int64,
	tickCumulative int64,
	secondsPerLiquidityCumulativeX128 string,
	initialized bool,
) *Observation {
	return &Observation{
		blockTimestamp:                    blockTimestamp,
		tickCumulative:                    tickCumulative,
		secondsPerLiquidityCumulativeX128: secondsPerLiquidityCumulativeX128,
		initialized:                       initialized,
	}
}

func NewDefaultObservation() *Observation {
	return NewObservation(
		0,
		0,
		"0",
		false,
	)
}

// ObservationTree is a pool-local, sparse oracle ring buffer keyed by index.
// It owns the B+tree key encoding so oracle code works with uint16 indices.
type ObservationTree struct {
	tree *bptree.BPTree
}

func NewObservationTree() *ObservationTree {
	return &ObservationTree{tree: bptree.NewBPTreeN(32)}
}

func (t *ObservationTree) Get(index uint16) (*Observation, bool) {
	value := t.tree.Get(EncodeObservationKey(index))
	if value == nil {
		return nil, false
	}
	observation, ok := value.(*Observation)
	return observation, ok
}

func (t *ObservationTree) Set(index uint16, observation *Observation) {
	t.tree.Set(EncodeObservationKey(index), observation)
}

func (t *ObservationTree) Has(index uint16) bool {
	return t.tree.Has(EncodeObservationKey(index))
}

// NewObservationsTree creates the pool-path index for oracle observation trees.
func NewObservationsTree() *bptree.BPTree {
	return bptree.NewBPTreeN(32)
}

// NewPoolObservationsTree creates a pool's circular observation buffer.
func NewPoolObservationsTree(currentTime int64) *ObservationTree {
	observations := NewObservationTree()
	observations.Set(0, NewObservation(
		currentTime,
		0,
		"0",
		true,
	))
	return observations
}
