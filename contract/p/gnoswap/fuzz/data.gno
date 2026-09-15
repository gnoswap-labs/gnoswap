// Copyright 2019 Gregory Petrosyan <gregory.petrosyan@gmail.com>
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package fuzz

import (
	"math"
	"math/bits"
)

type bitStream interface {
	// drawBits obtains the requested number of bits from the stream.
	//
	// Parameters:
	//   - n: Number of low-order bits to draw; implementations require a non-negative count.
	//
	// Returns:
	//   - bits: A uint64 containing the sampled bits, masked to the requested width.
	drawBits(n int) uint64
	// beginGroup starts recording a named generator group.
	//
	// Parameters:
	//   - label: Human-readable label identifying the group in recorded metadata.
	//   - standalone: Whether the group is treated as an independent recording unit.
	//
	// Returns:
	//   - index: Group identifier used to close the group with endGroup.
	beginGroup(label string, standalone bool) int
	// endGroup closes a previously opened recording group.
	//
	// Parameters:
	//   - i: Group identifier returned by beginGroup.
	//   - discard: Whether the group's recorded bits should be marked for removal.
	endGroup(i int, discard bool)
}

type randomBitStream struct {
	ctx jsf64ctx
	recordedBits
}

// newRandomBitStream creates a bit stream backed by the seeded JSF64 generator.
//
// Parameters:
//   - seed: Initial seed copied into the PRNG state before its warm-up rounds.
//   - persist: Whether drawn values and group metadata are retained instead of only counting entropy.
//
// Returns:
//   - stream: Initialized random bit stream using seed and the requested persistence mode.
func newRandomBitStream(seed uint64, persist bool) *randomBitStream {
	s := &randomBitStream{}
	s.init(seed)
	s.persist = persist
	return s
}

// init resets the PRNG state from seed and performs its fixed warm-up sequence.
//
// Parameters:
//   - seed: Seed value used to initialize all JSF64 state words.
func (s *randomBitStream) init(seed uint64) {
	s.ctx.init(seed)
}

// drawBits generates n random bits (0 <= n <= 64).
// For n > 64, returns MaxUint64.
//
// Parameters:
//   - n: Number of random low-order bits to request; must be non-negative.
//
// Returns:
//   - bits: Random bits masked to n bits, or math.MaxUint64 when n exceeds 64.
func (s *randomBitStream) drawBits(n int) uint64 {
	assert(n >= 0)

	var u uint64
	if n <= 64 {
		u = s.ctx.rand() & bitmask64(uint(n))
	} else {
		u = math.MaxUint64
	}
	s.record(u)

	return u
}

type bufBitStream struct {
	buf []uint64
	recordedBits
}

// newBufBitStream creates a bit stream that consumes values from buf in order.
//
// Parameters:
//   - buf: Buffered uint64 words used as the source of successive draws; the stream removes each consumed word.
//   - persist: Whether drawn values and group metadata are retained instead of only counting entropy.
//
// Returns:
//   - stream: Initialized buffered bit stream using buf and the requested persistence mode.
func newBufBitStream(buf []uint64, persist bool) *bufBitStream {
	s := &bufBitStream{
		buf: buf,
	}
	s.persist = persist
	return s
}

// drawBits consumes the next buffered word and masks it to the requested width.
//
// Parameters:
//   - n: Number of low-order bits to request; must be non-negative.
//
// Returns:
//   - bits: The next buffered word masked to n bits; panics with invalidData when the buffer is exhausted.
func (s *bufBitStream) drawBits(n int) uint64 {
	assert(n >= 0)

	if len(s.buf) == 0 {
		panic(invalidData("overrun"))
	}

	u := s.buf[0] & bitmask64(uint(n))
	s.record(u)
	s.buf = s.buf[1:]

	return u
}

type groupInfo struct {
	begin      int
	end        int
	label      string
	standalone bool
	discard    bool
}

type recordedBits struct {
	data    []uint64
	groups  []groupInfo
	dataLen int
	persist bool
}

// record stores one consumed entropy word or increments the entropy count.
//
// Parameters:
//   - u: Entropy word to retain when persistence is enabled.
func (rec *recordedBits) record(u uint64) {
	if rec.persist {
		rec.data = append(rec.data, u)
	} else {
		rec.dataLen++
	}
}

// beginGroup records the start of a generator group when persistence is enabled.
//
// Parameters:
//   - label: Human-readable label stored with the group metadata.
//   - standalone: Whether the group is marked as a standalone recording unit.
//
// Returns:
//   - index: Group index when persisting, or the current entropy count when only counting draws.
func (rec *recordedBits) beginGroup(label string, standalone bool) int {
	if !rec.persist {
		return rec.dataLen
	}

	rec.groups = append(rec.groups, groupInfo{
		begin:      len(rec.data),
		end:        -1,
		label:      label,
		standalone: standalone,
	})

	return len(rec.groups) - 1
}

// endGroup finalizes a recorded group and optionally marks it for pruning.
//
// Parameters:
//   - i: Group index returned by beginGroup when persistence is enabled.
//   - discard: Whether the group's data should be removed by a later prune call.
func (rec *recordedBits) endGroup(i int, discard bool) {
	assertf(discard || (!rec.persist && rec.dataLen > i) || (rec.persist && len(rec.data) > rec.groups[i].begin),
		"group did not use any data from bitstream; this is likely a result of Custom generator not calling any of the built-in generators")

	if !rec.persist {
		return
	}

	rec.groups[i].end = len(rec.data)
	rec.groups[i].discard = discard
}

// prune removes groups marked for discard and compacts the retained bit data.
func (rec *recordedBits) prune() {
	assert(rec.persist)

	for i := 0; i < len(rec.groups); {
		if rec.groups[i].discard {
			rec.removeGroup(i) // O(n^2)
		} else {
			i++
		}
	}

	for _, g := range rec.groups {
		assert(g.begin != g.end)
	}
}

// removeGroup removes one recorded group, including nested groups, and adjusts later offsets.
//
// Parameters:
//   - i: Index of the recorded group to remove; the group must have been closed.
func (rec *recordedBits) removeGroup(i int) {
	g := rec.groups[i]
	assert(g.end >= 0)

	j := i + 1
	for j < len(rec.groups) && rec.groups[j].end <= g.end {
		j++
	}

	rec.data = append(rec.data[:g.begin], rec.data[g.end:]...)
	rec.groups = append(rec.groups[:i], rec.groups[j:]...)

	n := g.end - g.begin
	for j := range rec.groups {
		if rec.groups[j].begin >= g.end {
			rec.groups[j].begin -= n
		}
		if rec.groups[j].end >= g.end {
			rec.groups[j].end -= n
		}
	}
}

// "A Small Noncryptographic PRNG" by Bob Jenkins
// See http://www.pcg-random.org/posts/bob-jenkins-small-prng-passes-practrand.html for some recent analysis.
type jsf64ctx struct {
	a uint64
	b uint64
	c uint64
	d uint64
}

// init seeds the JSF64 state and advances it through the fixed 20-round warm-up.
//
// Parameters:
//   - seed: Initial value assigned to the three seed-derived state words.
func (x *jsf64ctx) init(seed uint64) {
	x.a = 0xf1ea5eed
	x.b = seed
	x.c = seed
	x.d = seed

	for i := 0; i < 20; i++ {
		x.rand()
	}
}

// rand advances the JSF64 state and returns its next pseudorandom word.
//
// Returns:
//   - value: Next uint64 output from the Jenkins small fast PRNG state.
func (x *jsf64ctx) rand() uint64 {
	e := x.a - bits.RotateLeft64(x.b, 7)
	x.a = x.b ^ bits.RotateLeft64(x.c, 13)
	x.b = x.c + bits.RotateLeft64(x.d, 37)
	x.c = x.d + e
	x.d = e + x.a
	return x.d
}
