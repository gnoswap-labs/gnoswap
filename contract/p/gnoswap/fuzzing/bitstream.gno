package fuzzing

import (
	"fmt"
	"math"
	"math/bits"
)

// bitStream is the core interface for generating and replaying random bits.
// It abstracts over randomBitStream (for generation) and bufBitStream (for replay).
type bitStream interface {
	drawBits(n int) uint64
	beginGroup(label string, standalone bool) int
	endGroup(i int, discard bool)
}

// randomBitStream generates random bits using JSF64 PRNG and records them.
type randomBitStream struct {
	ctx jsf64ctx
	recordedBits
}

// newRandomBitStream creates a new random bitstream initialized with seed.
// If persist is true, generated bits are recorded for later replay/shrinking.
func newRandomBitStream(seed uint64, persist bool) *randomBitStream {
	s := &randomBitStream{}
	s.init(seed)
	s.persist = persist
	return s
}

// init initializes the PRNG with the given seed.
func (s *randomBitStream) init(seed uint64) {
	s.ctx.init(seed)
}

// drawBits generates n random bits (0 <= n <= 64).
// For n > 64, returns MaxUint64.
func (s *randomBitStream) drawBits(n int) uint64 {
	assertf(n >= 0, "drawBits: n must be non-negative")

	var u uint64
	if n <= 64 {
		u = s.ctx.rand() & bitmask64(uint(n))
	} else {
		u = math.MaxUint64
	}
	s.record(u)

	return u
}

// bufBitStream replays bits from a pre-recorded buffer.
// Used for reproducing failing test cases.
type bufBitStream struct {
	buf []uint64
	recordedBits
}

// newBufBitStream creates a bitstream that replays from buf.
func newBufBitStream(buf []uint64, persist bool) *bufBitStream {
	s := &bufBitStream{
		buf: buf,
	}
	s.persist = persist
	return s
}

// drawBits returns the next bit from the buffer.
func (s *bufBitStream) drawBits(n int) uint64 {
	assertf(n >= 0, "drawBits: n must be non-negative")

	if len(s.buf) == 0 {
		panic(invalidData("bitstream buffer overrun"))
	}

	u := s.buf[0] & bitmask64(uint(n))
	s.record(u)
	s.buf = s.buf[1:]

	return u
}

// groupInfo tracks a generator's bit usage for shrinking.
type groupInfo struct {
	begin      int    // Start index in data
	end        int    // End index in data
	label      string // Generator label (e.g., "int", "action")
	standalone bool   // Can be independently removed during shrinking
	discard    bool   // Mark for removal
}

// recordedBits stores generated bits and groups for replay and shrinking.
type recordedBits struct {
	data    []uint64    // Recorded bits
	groups  []groupInfo // Hierarchical structure of generators
	dataLen int         // Length when not persisting
	persist bool        // Whether to record bits
}

// record stores a generated bit value.
func (rec *recordedBits) record(u uint64) {
	if rec.persist {
		rec.data = append(rec.data, u)
	} else {
		rec.dataLen++
	}
}

// beginGroup marks the start of a generator's bit usage.
// Returns the group index.
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

// endGroup marks the end of a generator's bit usage.
func (rec *recordedBits) endGroup(i int, discard bool) {
	assertf(discard || (!rec.persist && rec.dataLen > i) || (rec.persist && len(rec.data) > rec.groups[i].begin),
		"group did not use any data from bitstream")

	if !rec.persist {
		return
	}

	rec.groups[i].end = len(rec.data)
	rec.groups[i].discard = discard
}

// prune removes discarded groups from the recorded data.
// Used during shrinking to clean up failed generation attempts.
func (rec *recordedBits) prune() {
	assertf(rec.persist, "prune called on non-persisting recordedBits")

	for i := 0; i < len(rec.groups); {
		if rec.groups[i].discard {
			rec.removeGroup(i) // O(n^2) but necessary
		} else {
			i++
		}
	}

	for _, g := range rec.groups {
		assertf(g.begin != g.end, "group has no data")
	}
}

// removeGroup removes a group and its bits from the recording.
func (rec *recordedBits) removeGroup(i int) {
	g := rec.groups[i]
	assertf(g.end >= 0, "removeGroup: group not ended")

	// Find nested groups
	j := i + 1
	for j < len(rec.groups) && rec.groups[j].end <= g.end {
		j++
	}

	// Remove bits
	rec.data = append(rec.data[:g.begin], rec.data[g.end:]...)
	rec.groups = append(rec.groups[:i], rec.groups[j:]...)

	// Adjust indices
	n := g.end - g.begin
	for k := range rec.groups {
		if rec.groups[k].begin >= g.end {
			rec.groups[k].begin -= n
		}
		if rec.groups[k].end >= g.end {
			rec.groups[k].end -= n
		}
	}
}

// jsf64ctx implements Bob Jenkins' Small Fast (JSF) 64-bit PRNG.
// See http://www.pcg-random.org/posts/bob-jenkins-small-prng-passes-practrand.html
type jsf64ctx struct {
	a uint64
	b uint64
	c uint64
	d uint64
}

// init initializes the PRNG with the given seed.
func (x *jsf64ctx) init(seed uint64) {
	x.a = 0xf1ea5eed
	x.b = seed
	x.c = seed
	x.d = seed

	// Warm up
	for i := 0; i < 20; i++ {
		x.rand()
	}
}

// rand generates the next random uint64.
func (x *jsf64ctx) rand() uint64 {
	e := x.a - bits.RotateLeft64(x.b, 7)
	x.a = x.b ^ bits.RotateLeft64(x.c, 13)
	x.b = x.c + bits.RotateLeft64(x.d, 37)
	x.c = x.d + e
	x.d = e + x.a
	return x.d
}

// bitmask64 returns a mask with n lower bits set.
// For n >= 64, returns all bits set.
func bitmask64(n uint) uint64 {
	if n >= 64 {
		return math.MaxUint64
	}
	return (1 << n) - 1
}

// invalidData is a panic value indicating invalid bitstream data.
type invalidData string

// Error implements error interface.
func (e invalidData) Error() string {
	return string(e)
}

// assertf panics if condition is false.
func assertf(ok bool, format string, args ...interface{}) {
	if !ok {
		panic(sprintf(format, args...))
	}
}

// sprintf formats a string with arguments using fmt.Sprintf.
func sprintf(format string, args ...interface{}) string {
	return fmt.Sprintf(format, args...)
}
