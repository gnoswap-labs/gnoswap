package fuzzing

import (
	"testing"
)

func TestJsf64_Determinism(t *testing.T) {
	// Test that JSF64 produces deterministic sequences
	ctx1 := jsf64ctx{}
	ctx1.init(12345)

	ctx2 := jsf64ctx{}
	ctx2.init(12345)

	for i := 0; i < 100; i++ {
		r1 := ctx1.rand()
		r2 := ctx2.rand()
		if r1 != r2 {
			t.Fatalf("JSF64 not deterministic at iteration %d: %d != %d", i, r1, r2)
		}
	}
}

func TestJsf64_DifferentSeeds(t *testing.T) {
	// Test that different seeds produce different sequences
	ctx1 := jsf64ctx{}
	ctx1.init(12345)

	ctx2 := jsf64ctx{}
	ctx2.init(54321)

	r1 := ctx1.rand()
	r2 := ctx2.rand()

	if r1 == r2 {
		t.Fatal("Different seeds produced same first value")
	}
}

func TestRandomBitStream_DrawBits(t *testing.T) {
	tests := []struct {
		name     string
		seed     uint64
		n        int
		checkMax bool
	}{
		{
			name:     "Draw 0 bits",
			seed:     1,
			n:        0,
			checkMax: false,
		},
		{
			name:     "Draw 1 bit",
			seed:     1,
			n:        1,
			checkMax: false,
		},
		{
			name:     "Draw 8 bits",
			seed:     1,
			n:        8,
			checkMax: false,
		},
		{
			name:     "Draw 32 bits",
			seed:     1,
			n:        32,
			checkMax: false,
		},
		{
			name:     "Draw 64 bits",
			seed:     1,
			n:        64,
			checkMax: false,
		},
		{
			name:     "Draw > 64 bits returns MaxUint64",
			seed:     1,
			n:        100,
			checkMax: true,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			s := newRandomBitStream(tc.seed, true)
			v := s.drawBits(tc.n)

			if tc.checkMax {
				if v != 18446744073709551615 { // MaxUint64
					t.Fatalf("Expected MaxUint64, got %d", v)
				}
			} else if tc.n < 64 {
				// Check that only n bits are set
				maxVal := uint64((1 << tc.n) - 1)
				if tc.n == 0 {
					maxVal = 0
				}
				if v > maxVal {
					t.Fatalf("Drew %d bits but got value %d > max %d", tc.n, v, maxVal)
				}
			}
		})
	}
}

func TestRandomBitStream_Recording(t *testing.T) {
	// Test that bits are recorded correctly
	s := newRandomBitStream(12345, true)

	v1 := s.drawBits(8)
	v2 := s.drawBits(16)
	v3 := s.drawBits(32)

	if len(s.data) != 3 {
		t.Fatalf("Expected 3 recorded values, got %d", len(s.data))
	}

	if s.data[0] != v1 || s.data[1] != v2 || s.data[2] != v3 {
		t.Fatal("Recorded values don't match drawn values")
	}
}

func TestRandomBitStream_NoPersist(t *testing.T) {
	// Test that bits are not recorded when persist=false
	s := newRandomBitStream(12345, false)

	s.drawBits(8)
	s.drawBits(16)

	if len(s.data) != 0 {
		t.Fatalf("Expected no recorded data, got %d values", len(s.data))
	}

	if s.dataLen != 2 {
		t.Fatalf("Expected dataLen=2, got %d", s.dataLen)
	}
}

func TestBufBitStream_Replay(t *testing.T) {
	// Test that bufBitStream replays recorded bits correctly
	buf := []uint64{42, 123, 255}
	s := newBufBitStream(buf, true)

	v1 := s.drawBits(8)
	v2 := s.drawBits(16)
	v3 := s.drawBits(32)

	if v1 != 42 || v2 != 123 || v3 != 255 {
		t.Fatalf("Replay values incorrect: got %d, %d, %d", v1, v2, v3)
	}
}

func TestBufBitStream_Overrun(t *testing.T) {
	// Test that buffer overrun panics
	buf := []uint64{42}
	s := newBufBitStream(buf, true)

	s.drawBits(8) // OK

	defer func() {
		if r := recover(); r == nil {
			t.Fatal("Expected panic on buffer overrun")
		} else if _, ok := r.(invalidData); !ok {
			t.Fatalf("Expected invalidData panic, got %T: %v", r, r)
		}
	}()

	s.drawBits(8) // Should panic
}

func TestRecordedBits_Groups(t *testing.T) {
	// Test group tracking
	s := newRandomBitStream(12345, true)

	i1 := s.beginGroup("outer", false)
	s.drawBits(8)

	i2 := s.beginGroup("inner", false)
	s.drawBits(16)
	s.endGroup(i2, false)

	s.drawBits(8)
	s.endGroup(i1, false)

	if len(s.groups) != 2 {
		t.Fatalf("Expected 2 groups, got %d", len(s.groups))
	}

	if s.groups[0].label != "outer" {
		t.Fatalf("Expected outer group, got %s", s.groups[0].label)
	}

	if s.groups[1].label != "inner" {
		t.Fatalf("Expected inner group, got %s", s.groups[1].label)
	}
}

func TestRecordedBits_Discard(t *testing.T) {
	// Test that discarded groups are tracked
	s := newRandomBitStream(12345, true)

	i := s.beginGroup("test", false)
	s.drawBits(8)
	s.endGroup(i, true) // Discard

	if !s.groups[0].discard {
		t.Fatal("Expected group to be marked as discarded")
	}
}

func TestRecordedBits_Prune(t *testing.T) {
	// Test pruning of discarded groups
	s := newRandomBitStream(12345, true)

	// Group 1: keep
	i1 := s.beginGroup("keep", false)
	s.drawBits(8)
	s.endGroup(i1, false)

	// Group 2: discard
	i2 := s.beginGroup("discard", false)
	s.drawBits(16)
	s.endGroup(i2, true)

	// Group 3: keep
	i3 := s.beginGroup("keep2", false)
	s.drawBits(8)
	s.endGroup(i3, false)

	originalDataLen := len(s.data)
	s.prune()

	// Should have removed the middle group
	if len(s.groups) != 2 {
		t.Fatalf("Expected 2 groups after prune, got %d", len(s.groups))
	}

	if len(s.data) != originalDataLen-1 {
		t.Fatalf("Expected data length %d after prune, got %d", originalDataLen-1, len(s.data))
	}

	if s.groups[0].label != "keep" || s.groups[1].label != "keep2" {
		t.Fatal("Wrong groups remained after prune")
	}
}

func TestBitmask64(t *testing.T) {
	tests := []struct {
		n        uint
		expected uint64
	}{
		{0, 0},
		{1, 1},
		{2, 3},
		{3, 7},
		{8, 255},
		{16, 65535},
		{32, 4294967295},
		{64, 18446744073709551615}, // MaxUint64
		{100, 18446744073709551615}, // MaxUint64
	}

	for _, tc := range tests {
		result := bitmask64(tc.n)
		if result != tc.expected {
			t.Errorf("bitmask64(%d) = %d, want %d", tc.n, result, tc.expected)
		}
	}
}
