package main

import (
	"testing"

	"gno.land/p/demo/ufmt"

	u256 "gno.land/p/gnoswap/uint256"

	plp "gno.land/p/gnoswap/gnsmath"

	"gno.land/p/gnoswap/consts"
)

var (
	tickSpacing = int32(1)
	minTick     = (consts.MIN_TICK / tickSpacing) * tickSpacing
	maxTick     = (consts.MAX_TICK / tickSpacing) * tickSpacing
)

var t *testing.T

func BeforeEachTest(t *testing.T) {
	InitializeTickBitmaps_Helper()
}

func main() {
	TestTickFlip_1(t)
	TestTickFlip_2(t)
	TestTicknextInitializedTickWithinOneWord_1(t)
	TestTicknextInitializedTickWithinOneWord_2(t)
	TestTicknextInitializedTickWithinOneWord_3(t)
	TestTicknextInitializedTickWithinOneWord_4(t)
	TestTicknextInitializedTickWithinOneWord_5(t)
	TestTicknextInitializedTickWithinOneWord_6(t)
	TestTickLteEqTrue_1(t)
	TestTickLteEqTrue_2(t)
	TestTickLteEqTrue_3(t)
	TestTickLteEqTrue_4(t)
	TestTickLteEqTrue_5_1(t)
	TestTickLteEqTrue_5_2(t)
	TestTickLteEqTrue_6(t)
	TestTickLteEqTrue_7(t)
	TestTickNextInitializedTickWithinOneWordRight(t)
	TestTickNextInitializedTickWithinOneWordNextword(t)
	TestTickNextInitializedTickWithinOneWordBoundary(t)
	TestTickNextInitializedTickWithinOneWordSkipEntire(t)
	TestTickNextInitializedTickWithinOneWordHalfWayEmptyWord(t)

	println("[INFO] All tests passed")
}

func TestTickFlip_1(t *testing.T) {
	BeforeEachTest(t)
	println("[SCENARIO] TestTickFlip_1: flips only the specified tick")
	TickBitmapFlipTick_Helper(int32(-230), tickSpacing)
	_, bool_res_1 := IsInitialized_Helper(int32(-230), tickSpacing)
	println("[EXPECTED] Tick -230 initialized:", bool_res_1, "expected: true")
	_, bool_res_2 := IsInitialized_Helper(int32(-231), tickSpacing)
	println("[EXPECTED] Tick -231 initialized:", bool_res_2, "expected: false")
	_, bool_res_3 := IsInitialized_Helper(int32(-229), tickSpacing)
	println("[EXPECTED] Tick -229 initialized:", bool_res_3, "expected: false")
	_, bool_res_4 := IsInitialized_Helper(int32(-230+256), tickSpacing)
	println("[EXPECTED] Tick -230+256 initialized:", bool_res_4, "expected: false")
	_, bool_res_5 := IsInitialized_Helper(int32(-230-256), tickSpacing)
	println("[EXPECTED] Tick -230-256 initialized:", bool_res_5, "expected: false")

	TickBitmapFlipTick_Helper(int32(-230), tickSpacing)
	_, bool_res_6 := IsInitialized_Helper(int32(-230), tickSpacing)
	println("[EXPECTED] After flip back - Tick -230 initialized:", bool_res_6, "expected: false")
	println()
}

func TestTickFlip_2(t *testing.T) {
	BeforeEachTest(t)
	println("[SCENARIO] TestTickFlip_2: reverts only itself")
	TickBitmapFlipTick_Helper(int32(-230), tickSpacing)
	TickBitmapFlipTick_Helper(int32(-259), tickSpacing)
	TickBitmapFlipTick_Helper(int32(-229), tickSpacing)
	TickBitmapFlipTick_Helper(int32(500), tickSpacing)
	TickBitmapFlipTick_Helper(int32(-259), tickSpacing)
	TickBitmapFlipTick_Helper(int32(-229), tickSpacing)
	TickBitmapFlipTick_Helper(int32(-259), tickSpacing)
	_, bool_res_1 := IsInitialized_Helper(int32(-259), tickSpacing)
	println("[EXPECTED] Tick -259 initialized:", bool_res_1, "expected: true")
	_, bool_res_2 := IsInitialized_Helper(int32(-229), tickSpacing)
	println("[EXPECTED] Tick -229 initialized:", bool_res_2, "expected: false")
	println()
}

func TestTicknextInitializedTickWithinOneWord_1(t *testing.T) {
	BeforeEachTest(t)
	println("[SCENARIO] TestTicknextInitializedTickWithinOneWord_1: returns tick to right if at initialized tick")
	TickBitmapFlipTick_Helper(int32(-200), tickSpacing)
	TickBitmapFlipTick_Helper(int32(-55), tickSpacing)
	TickBitmapFlipTick_Helper(int32(-4), tickSpacing)
	TickBitmapFlipTick_Helper(int32(70), tickSpacing)
	TickBitmapFlipTick_Helper(int32(78), tickSpacing)
	TickBitmapFlipTick_Helper(int32(84), tickSpacing)
	TickBitmapFlipTick_Helper(int32(139), tickSpacing)
	TickBitmapFlipTick_Helper(int32(240), tickSpacing)
	TickBitmapFlipTick_Helper(int32(535), tickSpacing)
	next, initialized := TickBitmapNextInitializedTickWithInOneWord_Helper(int32(78), tickSpacing, false)
	println("[EXPECTED] Next tick from 78:", next, "expected: 84")
	println("[EXPECTED] Initialized:", initialized, "expected: true")
	println()
}

func TestTicknextInitializedTickWithinOneWord_2(t *testing.T) {
	BeforeEachTest(t)
	println("[SCENARIO] TestTicknextInitializedTickWithinOneWord_2: returns tick to right if at initialized tick")
	TickBitmapFlipTick_Helper(int32(-200), tickSpacing)
	TickBitmapFlipTick_Helper(int32(-55), tickSpacing)
	TickBitmapFlipTick_Helper(int32(-4), tickSpacing)
	TickBitmapFlipTick_Helper(int32(70), tickSpacing)
	TickBitmapFlipTick_Helper(int32(78), tickSpacing)
	TickBitmapFlipTick_Helper(int32(84), tickSpacing)
	TickBitmapFlipTick_Helper(int32(139), tickSpacing)
	TickBitmapFlipTick_Helper(int32(240), tickSpacing)
	TickBitmapFlipTick_Helper(int32(535), tickSpacing)
	next, initialized := TickBitmapNextInitializedTickWithInOneWord_Helper(int32(-55), tickSpacing, false)
	println("[EXPECTED] Next tick from -55:", next, "expected: -4")
	println("[EXPECTED] Initialized:", initialized, "expected: true")
	println()
}

func TestTicknextInitializedTickWithinOneWord_3(t *testing.T) {
	BeforeEachTest(t)
	println("[SCENARIO] TestTicknextInitializedTickWithinOneWord_3: returns the tick directly to the right")
	TickBitmapFlipTick_Helper(int32(-200), tickSpacing)
	TickBitmapFlipTick_Helper(int32(-55), tickSpacing)
	TickBitmapFlipTick_Helper(int32(-4), tickSpacing)
	TickBitmapFlipTick_Helper(int32(70), tickSpacing)
	TickBitmapFlipTick_Helper(int32(78), tickSpacing)
	TickBitmapFlipTick_Helper(int32(84), tickSpacing)
	TickBitmapFlipTick_Helper(int32(139), tickSpacing)
	TickBitmapFlipTick_Helper(int32(240), tickSpacing)
	TickBitmapFlipTick_Helper(int32(535), tickSpacing)
	next, initialized := TickBitmapNextInitializedTickWithInOneWord_Helper(int32(77), tickSpacing, false)
	println("[EXPECTED] Next tick from 77:", next, "expected: 78")
	println("[EXPECTED] Initialized:", initialized, "expected: true")
	println()
}

func TestTicknextInitializedTickWithinOneWord_4(t *testing.T) {
	BeforeEachTest(t)
	TickBitmapFlipTick_Helper(int32(-200), tickSpacing)
	TickBitmapFlipTick_Helper(int32(-55), tickSpacing)
	TickBitmapFlipTick_Helper(int32(-4), tickSpacing)
	TickBitmapFlipTick_Helper(int32(70), tickSpacing)
	TickBitmapFlipTick_Helper(int32(78), tickSpacing)
	TickBitmapFlipTick_Helper(int32(84), tickSpacing)
	TickBitmapFlipTick_Helper(int32(139), tickSpacing)
	TickBitmapFlipTick_Helper(int32(240), tickSpacing)
	TickBitmapFlipTick_Helper(int32(535), tickSpacing)

	println("[SCENARIO] 4. Returns the tick directly to the right")
	next, initialized := TickBitmapNextInitializedTickWithInOneWord_Helper(int32(-56), tickSpacing, false)
	println("[EXPECTED] Next tick from -56:", next, "expected: -55")
	println("[EXPECTED] Initialized:", initialized, "expected: true")
	println()
}

func TestTicknextInitializedTickWithinOneWord_5(t *testing.T) {
	BeforeEachTest(t)
	TickBitmapFlipTick_Helper(int32(-200), tickSpacing)
	TickBitmapFlipTick_Helper(int32(-55), tickSpacing)
	TickBitmapFlipTick_Helper(int32(-4), tickSpacing)
	TickBitmapFlipTick_Helper(int32(70), tickSpacing)
	TickBitmapFlipTick_Helper(int32(78), tickSpacing)
	TickBitmapFlipTick_Helper(int32(84), tickSpacing)
	TickBitmapFlipTick_Helper(int32(139), tickSpacing)
	TickBitmapFlipTick_Helper(int32(240), tickSpacing)
	TickBitmapFlipTick_Helper(int32(535), tickSpacing)
	println("[SCENARIO] 5. Skips half word")
	next, initialized := TickBitmapNextInitializedTickWithInOneWord_Helper(int32(255), tickSpacing, false)
	println("[EXPECTED] Next tick from 255:", next, "expected: 511")
	println("[EXPECTED] Initialized:", initialized, "expected: false")
	println()
}

func TestTicknextInitializedTickWithinOneWord_6(t *testing.T) {
	BeforeEachTest(t)
	TickBitmapFlipTick_Helper(int32(-200), tickSpacing)
	TickBitmapFlipTick_Helper(int32(-55), tickSpacing)
	TickBitmapFlipTick_Helper(int32(-4), tickSpacing)
	TickBitmapFlipTick_Helper(int32(70), tickSpacing)
	TickBitmapFlipTick_Helper(int32(78), tickSpacing)
	TickBitmapFlipTick_Helper(int32(84), tickSpacing)
	TickBitmapFlipTick_Helper(int32(139), tickSpacing)
	TickBitmapFlipTick_Helper(int32(240), tickSpacing)
	TickBitmapFlipTick_Helper(int32(535), tickSpacing)

	println("[SCENARIO] 6. Skips half word #2")
	next, initialized := TickBitmapNextInitializedTickWithInOneWord_Helper(int32(383), tickSpacing, false)
	println("[EXPECTED] Next tick from 383:", next, "expected: 511")
	println("[EXPECTED] Initialized:", initialized, "expected: false")
	println()
}

func TestTickLteEqTrue_1(t *testing.T) {
	BeforeEachTest(t)
	TickBitmapFlipTick_Helper(int32(-200), tickSpacing)
	TickBitmapFlipTick_Helper(int32(-55), tickSpacing)
	TickBitmapFlipTick_Helper(int32(-4), tickSpacing)
	TickBitmapFlipTick_Helper(int32(70), tickSpacing)
	TickBitmapFlipTick_Helper(int32(78), tickSpacing)
	TickBitmapFlipTick_Helper(int32(84), tickSpacing)
	TickBitmapFlipTick_Helper(int32(139), tickSpacing)
	TickBitmapFlipTick_Helper(int32(240), tickSpacing)
	TickBitmapFlipTick_Helper(int32(535), tickSpacing)

	println("[SCENARIO] 1. Returns same tick if initialized")
	next, initialized := TickBitmapNextInitializedTickWithInOneWord_Helper(int32(78), tickSpacing, true)
	println("[EXPECTED] Next tick from 78:", next, "expected: 78")
	println("[EXPECTED] Initialized:", initialized, "expected: true")
	println()
}

func TestTickLteEqTrue_2(t *testing.T) {
	BeforeEachTest(t)
	TickBitmapFlipTick_Helper(int32(-200), tickSpacing)
	TickBitmapFlipTick_Helper(int32(-55), tickSpacing)
	TickBitmapFlipTick_Helper(int32(-4), tickSpacing)
	TickBitmapFlipTick_Helper(int32(70), tickSpacing)
	TickBitmapFlipTick_Helper(int32(78), tickSpacing)
	TickBitmapFlipTick_Helper(int32(84), tickSpacing)
	TickBitmapFlipTick_Helper(int32(139), tickSpacing)
	TickBitmapFlipTick_Helper(int32(240), tickSpacing)
	TickBitmapFlipTick_Helper(int32(535), tickSpacing)

	println("[SCENARIO] 2. Returns tick directly to the left of input tick if not initialized")
	next, initialized := TickBitmapNextInitializedTickWithInOneWord_Helper(int32(79), tickSpacing, true)
	println("[EXPECTED] Next tick from 79:", next, "expected: 78")
	println("[EXPECTED] Initialized:", initialized, "expected: true")
	println()
}

func TestTickLteEqTrue_3(t *testing.T) {
	BeforeEachTest(t)
	TickBitmapFlipTick_Helper(int32(-200), tickSpacing)
	TickBitmapFlipTick_Helper(int32(-55), tickSpacing)
	TickBitmapFlipTick_Helper(int32(-4), tickSpacing)
	TickBitmapFlipTick_Helper(int32(70), tickSpacing)
	TickBitmapFlipTick_Helper(int32(78), tickSpacing)
	TickBitmapFlipTick_Helper(int32(84), tickSpacing)
	TickBitmapFlipTick_Helper(int32(139), tickSpacing)
	TickBitmapFlipTick_Helper(int32(240), tickSpacing)
	TickBitmapFlipTick_Helper(int32(535), tickSpacing)

	println("[SCENARIO] 3. Will not exceed the word boundary")
	next, initialized := TickBitmapNextInitializedTickWithInOneWord_Helper(int32(258), tickSpacing, true)
	println("[EXPECTED] Next tick from 258:", next, "expected: 256")
	println("[EXPECTED] Initialized:", initialized, "expected: false")
	println()
}

func TestTickLteEqTrue_4(t *testing.T) {
	BeforeEachTest(t)
	TickBitmapFlipTick_Helper(int32(-200), tickSpacing)
	TickBitmapFlipTick_Helper(int32(-55), tickSpacing)
	TickBitmapFlipTick_Helper(int32(-4), tickSpacing)
	TickBitmapFlipTick_Helper(int32(70), tickSpacing)
	TickBitmapFlipTick_Helper(int32(78), tickSpacing)
	TickBitmapFlipTick_Helper(int32(84), tickSpacing)
	TickBitmapFlipTick_Helper(int32(139), tickSpacing)
	TickBitmapFlipTick_Helper(int32(240), tickSpacing)
	TickBitmapFlipTick_Helper(int32(535), tickSpacing)

	println("[SCENARIO] 4. At the word boundary")
	next, initialized := TickBitmapNextInitializedTickWithInOneWord_Helper(int32(256), tickSpacing, true)
	println("[EXPECTED] Next tick from 256:", next, "expected: 256")
	println("[EXPECTED] Initialized:", initialized, "expected: false")
	println()
}

func TestTickLteEqTrue_5_1(t *testing.T) {
	BeforeEachTest(t)
	TickBitmapFlipTick_Helper(int32(-200), tickSpacing)
	TickBitmapFlipTick_Helper(int32(-55), tickSpacing)
	TickBitmapFlipTick_Helper(int32(-4), tickSpacing)
	TickBitmapFlipTick_Helper(int32(70), tickSpacing)
	TickBitmapFlipTick_Helper(int32(78), tickSpacing)
	TickBitmapFlipTick_Helper(int32(84), tickSpacing)
	TickBitmapFlipTick_Helper(int32(139), tickSpacing)
	TickBitmapFlipTick_Helper(int32(240), tickSpacing)
	TickBitmapFlipTick_Helper(int32(535), tickSpacing)

	println("[SCENARIO] 5. Word boundary less 1 (next initialized tick in next word")
	next, initialized := TickBitmapNextInitializedTickWithInOneWord_Helper(int32(72), tickSpacing, true)
	println("[EXPECTED] Next tick from 72:", next, "expected: 70")
	println("[EXPECTED] Initialized:", initialized, "expected: true")
	println()
}

func TestTickLteEqTrue_5_2(t *testing.T) {
	BeforeEachTest(t)
	TickBitmapFlipTick_Helper(int32(-200), tickSpacing)
	TickBitmapFlipTick_Helper(int32(-55), tickSpacing)
	TickBitmapFlipTick_Helper(int32(-4), tickSpacing)
	TickBitmapFlipTick_Helper(int32(70), tickSpacing)
	TickBitmapFlipTick_Helper(int32(78), tickSpacing)
	TickBitmapFlipTick_Helper(int32(84), tickSpacing)
	TickBitmapFlipTick_Helper(int32(139), tickSpacing)
	TickBitmapFlipTick_Helper(int32(240), tickSpacing)
	TickBitmapFlipTick_Helper(int32(535), tickSpacing)

	println("[SCENARIO] 5. Word boundary")
	next, initialized := TickBitmapNextInitializedTickWithInOneWord_Helper(int32(-257), tickSpacing, true)
	println("[EXPECTED] Next tick from -257:", next, "expected: -512")
	println("[EXPECTED] Initialized:", initialized, "expected: false")
	println()
}

func TestTickLteEqTrue_6(t *testing.T) {
	BeforeEachTest(t)
	TickBitmapFlipTick_Helper(int32(-200), tickSpacing)
	TickBitmapFlipTick_Helper(int32(-55), tickSpacing)
	TickBitmapFlipTick_Helper(int32(-4), tickSpacing)
	TickBitmapFlipTick_Helper(int32(70), tickSpacing)
	TickBitmapFlipTick_Helper(int32(78), tickSpacing)
	TickBitmapFlipTick_Helper(int32(84), tickSpacing)
	TickBitmapFlipTick_Helper(int32(139), tickSpacing)
	TickBitmapFlipTick_Helper(int32(240), tickSpacing)
	TickBitmapFlipTick_Helper(int32(535), tickSpacing)

	println("[SCENARIO] 6. Entire empty word")
	next, initialized := TickBitmapNextInitializedTickWithInOneWord_Helper(int32(1023), tickSpacing, true)
	println("[EXPECTED] Next tick from 1023:", next, "expected: 768")
	println("[EXPECTED] Initialized:", initialized, "expected: false")
	println()
}

func TestTickLteEqTrue_7(t *testing.T) {
	BeforeEachTest(t)
	TickBitmapFlipTick_Helper(int32(-200), tickSpacing)
	TickBitmapFlipTick_Helper(int32(-55), tickSpacing)
	TickBitmapFlipTick_Helper(int32(-4), tickSpacing)
	TickBitmapFlipTick_Helper(int32(70), tickSpacing)
	TickBitmapFlipTick_Helper(int32(78), tickSpacing)
	TickBitmapFlipTick_Helper(int32(84), tickSpacing)
	TickBitmapFlipTick_Helper(int32(139), tickSpacing)
	TickBitmapFlipTick_Helper(int32(240), tickSpacing)
	TickBitmapFlipTick_Helper(int32(535), tickSpacing)
	TickBitmapFlipTick_Helper(int32(329), tickSpacing)

	println("[SCENARIO] 7. Boundary is initialized")
	next, initialized := TickBitmapNextInitializedTickWithInOneWord_Helper(int32(456), tickSpacing, true)
	println("[EXPECTED] Next tick from 456:", next, "expected: 329")
	println("[EXPECTED] Initialized:", initialized, "expected: true")
	println()
}

func TestTickNextInitializedTickWithinOneWordRight(t *testing.T) {
	// t.Run("returns the next words initialized tick if on the right boundary_255", func(t *testing.T) {

	// })
	println("[SCENARIO] 1. Returns the next words initialized tick if on the right boundary_255")
	BeforeEachTest(t)
	next, initialized := TickBitmapNextInitializedTickWithInOneWord_Helper(int32(255), tickSpacing, false)
	println("[EXPECTED] Next tick from 255:", next, "expected: 511")
	println("[EXPECTED] Initialized:", initialized, "expected: false")
	println()

	println("[SCENARIO] 2. Returns the next words initialized tick if on the right boundary_-257")
	BeforeEachTest(t)
	TickBitmapFlipTick_Helper(int32(-200), tickSpacing)
	TickBitmapFlipTick_Helper(int32(-55), tickSpacing)
	TickBitmapFlipTick_Helper(int32(-4), tickSpacing)
	TickBitmapFlipTick_Helper(int32(70), tickSpacing)
	TickBitmapFlipTick_Helper(int32(78), tickSpacing)
	TickBitmapFlipTick_Helper(int32(84), tickSpacing)
	TickBitmapFlipTick_Helper(int32(139), tickSpacing)
	TickBitmapFlipTick_Helper(int32(240), tickSpacing)
	TickBitmapFlipTick_Helper(int32(535), tickSpacing)

	next, initialized = TickBitmapNextInitializedTickWithInOneWord_Helper(int32(-257), tickSpacing, false)
	println("[EXPECTED] Next tick from -257:", next, "expected: -200")
	println("[EXPECTED] Initialized:", initialized, "expected: true")
	println()
}

func TestTickNextInitializedTickWithinOneWordNextword(t *testing.T) {
	println("[SCENARIO] 3. Returns the next initialized tick from the next word")
	BeforeEachTest(t)
	TickBitmapFlipTick_Helper(int32(-200), tickSpacing)
	TickBitmapFlipTick_Helper(int32(-55), tickSpacing)
	TickBitmapFlipTick_Helper(int32(-4), tickSpacing)
	TickBitmapFlipTick_Helper(int32(70), tickSpacing)
	TickBitmapFlipTick_Helper(int32(78), tickSpacing)
	TickBitmapFlipTick_Helper(int32(84), tickSpacing)
	TickBitmapFlipTick_Helper(int32(139), tickSpacing)
	TickBitmapFlipTick_Helper(int32(240), tickSpacing)
	TickBitmapFlipTick_Helper(int32(535), tickSpacing)

	TickBitmapFlipTick_Helper(int32(340), tickSpacing)

	next, initialized := TickBitmapNextInitializedTickWithInOneWord_Helper(int32(328), tickSpacing, false)
	println("[EXPECTED] Next tick from 328:", next, "expected: 340")
	println("[EXPECTED] Initialized:", initialized, "expected: true")
	println()
}

func TestTickNextInitializedTickWithinOneWordBoundary(t *testing.T) {
	println("[SCENARIO] 4. Does not exceed boundary")
	BeforeEachTest(t)
	TickBitmapFlipTick_Helper(int32(-200), tickSpacing)
	TickBitmapFlipTick_Helper(int32(-55), tickSpacing)
	TickBitmapFlipTick_Helper(int32(-4), tickSpacing)
	TickBitmapFlipTick_Helper(int32(70), tickSpacing)
	TickBitmapFlipTick_Helper(int32(78), tickSpacing)
	TickBitmapFlipTick_Helper(int32(84), tickSpacing)
	TickBitmapFlipTick_Helper(int32(139), tickSpacing)
	TickBitmapFlipTick_Helper(int32(240), tickSpacing)
	TickBitmapFlipTick_Helper(int32(535), tickSpacing)

	next, initialized := TickBitmapNextInitializedTickWithInOneWord_Helper(int32(508), tickSpacing, false)
	println("[EXPECTED] Next tick from 508:", next, "expected: 511")
	println("[EXPECTED] Initialized:", initialized, "expected: false")
	println()
}

func TestTickNextInitializedTickWithinOneWordSkipEntire(t *testing.T) {
	println("[SCENARIO] 5. Skips entire word")
	BeforeEachTest(t)
	TickBitmapFlipTick_Helper(int32(-200), tickSpacing)
	TickBitmapFlipTick_Helper(int32(-55), tickSpacing)
	TickBitmapFlipTick_Helper(int32(-4), tickSpacing)
	TickBitmapFlipTick_Helper(int32(70), tickSpacing)
	TickBitmapFlipTick_Helper(int32(78), tickSpacing)
	TickBitmapFlipTick_Helper(int32(84), tickSpacing)
	TickBitmapFlipTick_Helper(int32(139), tickSpacing)
	TickBitmapFlipTick_Helper(int32(240), tickSpacing)
	TickBitmapFlipTick_Helper(int32(535), tickSpacing)

	next, initialized := TickBitmapNextInitializedTickWithInOneWord_Helper(int32(255), tickSpacing, false)
	println("[EXPECTED] Next tick from 255:", next, "expected: 511")
	println("[EXPECTED] Initialized:", initialized, "expected: false")
	println()
}

func TestTickNextInitializedTickWithinOneWordHalfWayEmptyWord(t *testing.T) {
	println("[SCENARIO] 6. Halfway through empty word")
	BeforeEachTest(t)

	next, initialized := TickBitmapNextInitializedTickWithInOneWord_Helper(int32(900), tickSpacing, true)
	println("[EXPECTED] Next tick from 900:", next, "expected: 768")
	println("[EXPECTED] Initialized:", initialized, "expected: false")
	println()
}

// HELPERs
var (
	tickBitmaps map[int16]*u256.Uint = make(map[int16]*u256.Uint)
)

// tickBitmapPosition calculates the word and bit position for a given tick
func TickBitmapPosition_Helper(tick int32) (int16, uint8) {
	wordPos := int16(tick >> 8) // tick / 256
	bitPos := uint8(tick % 256)

	return wordPos, bitPos
}

// tickBitmapFlipTick flips tthe bit corresponding to the given tick
// in the pool's tick bitmap.
//
// Panics:
//   - If tick % tickSpacing != 0
func TickBitmapFlipTick_Helper(
	tick int32,
	tickSpacing int32,
) {
	if tick%tickSpacing != 0 {
		panic(ufmt.Sprintf("[POOL] tick_bitmap.gno__tickBitmapFlipTick() || tick(%d) MOD tickSpacing(%d) != 0(%d)", tick, tickSpacing, tick%tickSpacing))
	}

	wordPos, bitPos := TickBitmapPosition_Helper(tick / tickSpacing)

	// 1 << bitPos
	mask := new(u256.Uint).Lsh(u256.NewUint(1), uint(bitPos))

	tickBitmaps[wordPos] = tickBitmaps[wordPos].NilToZero()
	tickBitmaps[wordPos] = new(u256.Uint).Xor(tickBitmaps[wordPos], mask)
}

// tickBitmapNextInitializedTickWithInOneWord finds the next initialized tick within
// one word of the bitmap.
func TickBitmapNextInitializedTickWithInOneWord_Helper(
	tick int32,
	tickSpacing int32,
	lte bool,
) (int32, bool) {
	compress := tick / tickSpacing

	if tick < 0 && tick%tickSpacing != 0 {
		compress--
	}

	if lte {

		wordPos, bitPos := TickBitmapPosition_Helper(compress)

		// mask := (1 << bitPos) - 1 + (1 << bitPos)
		shift1LeftByBitPos := new(u256.Uint).Lsh(u256.NewUint(1), uint(bitPos))

		mask := shift1LeftByBitPos.Clone()
		mask = new(u256.Uint).Sub(mask, u256.NewUint(1))

		mask = new(u256.Uint).Add(mask, shift1LeftByBitPos.Clone())

		tickBitmaps[wordPos] = tickBitmaps[wordPos].NilToZero()

		masked := new(u256.Uint).And(tickBitmaps[wordPos], mask)

		initialized := !(masked.IsZero())

		if initialized {
			next := compress - int32(bitPos-plp.BitMathMostSignificantBit(masked))*tickSpacing
			return next, initialized
		}

		next := (compress - int32(bitPos)) * tickSpacing
		return next, initialized

	}

	wordPos, bitPos := TickBitmapPosition_Helper(compress + 1)

	shift1LeftByBitPos := new(u256.Uint).Lsh(u256.NewUint(1), uint(bitPos))
	_mask := shift1LeftByBitPos.Clone()
	_mask = new(u256.Uint).Sub(_mask, u256.NewUint(1))
	mask := BitwiseNotForUint256BitmapIndexing_Helper(_mask)

	tickBitmaps[wordPos] = tickBitmaps[wordPos].NilToZero()
	masked := new(u256.Uint).And(tickBitmaps[wordPos], mask)

	initialized := !(masked.IsZero())
	if initialized {
		next := (compress + 1 + int32(plp.BitMathLeastSignificantBit(masked)-bitPos)) * tickSpacing
		return next, initialized
	}
	next := (compress + 1 + int32(255-bitPos)) * tickSpacing
	return next, initialized
}

// bitwiseNotForUint256BitmapIndexing performs a bitwise NsOT operation on the uint256 value.
// This function is designed for use in bitmap indexing
func BitwiseNotForUint256BitmapIndexing_Helper(x *u256.Uint) *u256.Uint {
	// REF: https://stackoverflow.com/a/77071037

	// Create a mask with all bits set to 1
	mask := u256.MustFromDecimal(consts.MAX_UINT256)
	// mask = new(u256.Uint).Sub(mask, u256.NewUint(1))

	// XOR with mask to perform bitwise NOT
	// result := x ^ mask

	result := new(u256.Uint).Xor(x, mask)
	return result
}

func InitializeTickBitmaps_Helper() {
	tickBitmaps = make(map[int16]*u256.Uint)
}

func GetTickBitmaps_Helper() map[int16]*u256.Uint {
	return tickBitmaps
}

func IsInitialized_Helper(tick int32, ts int32) (int32, bool) {
	nextTick, init := TickBitmapNextInitializedTickWithInOneWord_Helper(tick, ts, true)
	if nextTick == tick {
		return nextTick, init
	}
	return nextTick, false
}

// Output:
// [SCENARIO] TestTickFlip_1: flips only the specified tick
// [EXPECTED] Tick -230 initialized: true expected: true
// [EXPECTED] Tick -231 initialized: false expected: false
// [EXPECTED] Tick -229 initialized: false expected: false
// [EXPECTED] Tick -230+256 initialized: false expected: false
// [EXPECTED] Tick -230-256 initialized: false expected: false
// [EXPECTED] After flip back - Tick -230 initialized: false expected: false
//
// [SCENARIO] TestTickFlip_2: reverts only itself
// [EXPECTED] Tick -259 initialized: true expected: true
// [EXPECTED] Tick -229 initialized: false expected: false
//
// [SCENARIO] TestTicknextInitializedTickWithinOneWord_1: returns tick to right if at initialized tick
// [EXPECTED] Next tick from 78: 84 expected: 84
// [EXPECTED] Initialized: true expected: true
//
// [SCENARIO] TestTicknextInitializedTickWithinOneWord_2: returns tick to right if at initialized tick
// [EXPECTED] Next tick from -55: -4 expected: -4
// [EXPECTED] Initialized: true expected: true
//
// [SCENARIO] TestTicknextInitializedTickWithinOneWord_3: returns the tick directly to the right
// [EXPECTED] Next tick from 77: 78 expected: 78
// [EXPECTED] Initialized: true expected: true
//
// [SCENARIO] 4. Returns the tick directly to the right
// [EXPECTED] Next tick from -56: -55 expected: -55
// [EXPECTED] Initialized: true expected: true
//
// [SCENARIO] 5. Skips half word
// [EXPECTED] Next tick from 255: 511 expected: 511
// [EXPECTED] Initialized: false expected: false
//
// [SCENARIO] 6. Skips half word #2
// [EXPECTED] Next tick from 383: 511 expected: 511
// [EXPECTED] Initialized: false expected: false
//
// [SCENARIO] 1. Returns same tick if initialized
// [EXPECTED] Next tick from 78: 78 expected: 78
// [EXPECTED] Initialized: true expected: true
//
// [SCENARIO] 2. Returns tick directly to the left of input tick if not initialized
// [EXPECTED] Next tick from 79: 78 expected: 78
// [EXPECTED] Initialized: true expected: true
//
// [SCENARIO] 3. Will not exceed the word boundary
// [EXPECTED] Next tick from 258: 256 expected: 256
// [EXPECTED] Initialized: false expected: false
//
// [SCENARIO] 4. At the word boundary
// [EXPECTED] Next tick from 256: 256 expected: 256
// [EXPECTED] Initialized: false expected: false
//
// [SCENARIO] 5. Word boundary less 1 (next initialized tick in next word
// [EXPECTED] Next tick from 72: 70 expected: 70
// [EXPECTED] Initialized: true expected: true
//
// [SCENARIO] 5. Word boundary
// [EXPECTED] Next tick from -257: -512 expected: -512
// [EXPECTED] Initialized: false expected: false
//
// [SCENARIO] 6. Entire empty word
// [EXPECTED] Next tick from 1023: 768 expected: 768
// [EXPECTED] Initialized: false expected: false
//
// [SCENARIO] 7. Boundary is initialized
// [EXPECTED] Next tick from 456: 329 expected: 329
// [EXPECTED] Initialized: true expected: true
//
// [SCENARIO] 1. Returns the next words initialized tick if on the right boundary_255
// [EXPECTED] Next tick from 255: 511 expected: 511
// [EXPECTED] Initialized: false expected: false
//
// [SCENARIO] 2. Returns the next words initialized tick if on the right boundary_-257
// [EXPECTED] Next tick from -257: -200 expected: -200
// [EXPECTED] Initialized: true expected: true
//
// [SCENARIO] 3. Returns the next initialized tick from the next word
// [EXPECTED] Next tick from 328: 340 expected: 340
// [EXPECTED] Initialized: true expected: true
//
// [SCENARIO] 4. Does not exceed boundary
// [EXPECTED] Next tick from 508: 511 expected: 511
// [EXPECTED] Initialized: false expected: false
//
// [SCENARIO] 5. Skips entire word
// [EXPECTED] Next tick from 255: 511 expected: 511
// [EXPECTED] Initialized: false expected: false
//
// [SCENARIO] 6. Halfway through empty word
// [EXPECTED] Next tick from 900: 768 expected: 768
// [EXPECTED] Initialized: false expected: false
//
// [INFO] All tests passed
