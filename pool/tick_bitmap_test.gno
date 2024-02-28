package pool

import (
	"testing"

	"gno.land/p/demo/ufmt"
	"gno.land/r/demo/consts"
)

func TestTickBitmapPosition(t *testing.T) {
	tests := []struct {
		name     string
		tick     int32
		expected struct {
			wordPos int16
			bitPos  uint8
		}
	}{
		{"tick at beginning", 0, struct {
			wordPos int16
			bitPos  uint8
		}{0, 0}},
		{"tick at end of first word", 255, struct {
			wordPos int16
			bitPos  uint8
		}{0, 255}},
		{"tick at beginning of second word", 256, struct {
			wordPos int16
			bitPos  uint8
		}{1, 0}},
		{"negative tick", -1, struct {
			wordPos int16
			bitPos  uint8
		}{-1, 255}},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			wordPos, bitPos := tickBitmapPosition(tt.tick)
			if wordPos != tt.expected.wordPos || bitPos != tt.expected.bitPos {
				t.Errorf("tickBitmapPosition(%d) = %d, %d; expected %d, %d",
					tt.tick, wordPos, bitPos, tt.expected.wordPos, tt.expected.bitPos)
			}
		})
	}
}

func TestPool_tickBitmapFlipTick(t *testing.T) {
	// Initialize a Pool instance for testing
	pool := &Pool{
		tickBitmaps: make(TickBitmaps),
	}

	tests := []struct {
		name        string
		tick        int32
		tickSpacing int32
		setup       func()
		verify      func() bool
		expectPanic bool
	}{
		{
			name:        "flip tick within range",
			tick:        0,
			tickSpacing: 1,
			setup:       func() {},
			verify: func() bool {
				// Check if the bit at position 0 has been flipped
				return pool.tickBitmaps[0]&1 == 1
			},
		},
		{
			name:        "flip tick out of range",
			tick:        256,
			tickSpacing: 1,
			setup:       func() {},
			verify: func() bool {
				// Check if the bit at position 1 (word 0, bit 256) has been flipped
				return pool.tickBitmaps[1]&1 == 1
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.expectPanic {
				defer func() {
					if r := recover(); r == nil {
						t.Errorf("The code did not panic")
					}
				}()
			}

			tt.setup()
			pool.tickBitmapFlipTick(tt.tick, tt.tickSpacing)

			if !tt.expectPanic {
				if !tt.verify() {
					t.Errorf("Failed to verify test: %s", tt.name)
				}
			}
		})
	}
}

func TestPool_tickBitmapNextInitializedTickWithInOneWord(t *testing.T) {
	pool := &Pool{
		tickBitmaps: make(TickBitmaps),
		tickSpacing: 1, // Assuming tickSpacing is 1 for simplicity
	}

	// Setup: Initialize the tickBitmaps for testing
	// For simplicity, let's assume we're working with a single word (int16) and we initialize it directly.
	// Example: Initialize the bitmap with some bits set. Adjust this based on your specific test scenario.
	// Let's say we initialize the bitmap such that ticks at positions 3, 5, and 8 are initialized.
	wordPos := int16(0)
	pool.tickBitmaps[wordPos] = 0b0000000100101000 // Binary representation for simplicity

	tests := []struct {
		name     string
		tick     int32
		lte      bool
		expected struct {
			nextTick    int32
			initialized bool
		}
	}{
		{
			name: "Find next initialized tick, lte true, tick before first initialized",
			tick: 2, // Tick before the first initialized tick
			lte:  true,
			expected: struct {
				nextTick    int32
				initialized bool
			}{0, false}, // The next initialized tick is 3
		},
		{
			name: "Find next initialized tick, lte false, tick before first initialized",
			tick: 2, // Tick before the first initialized tick
			lte:  false,
			expected: struct {
				nextTick    int32
				initialized bool
			}{3, true}, // The next initialized tick is 3
		},
		{
			name: "Find next initialized tick, lte true, tick after last initialized",
			tick: 9, // Tick after the last initialized tick
			lte:  true,
			expected: struct {
				nextTick    int32
				initialized bool
			}{8, true}, // The last initialized tick is 8
		},
		{
			name: "No next initialized tick, lte false, tick after last initialized",
			tick: 9, // Tick after the last initialized tick
			lte:  false,
			expected: struct {
				nextTick    int32
				initialized bool
			}{255, false}, // No next initialized tick
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			nextTick, initialized := pool.tickBitmapNextInitializedTickWithInOneWord(tt.tick, pool.tickSpacing, tt.lte)
			if nextTick != tt.expected.nextTick || initialized != tt.expected.initialized {
				t.Errorf("(%s) tickBitmapNextInitializedTickWithInOneWord(%d, %d, %t) = %d, %t; expected %d, %t",
					tt.name, tt.tick, pool.tickSpacing, tt.lte, nextTick, initialized, tt.expected.nextTick, tt.expected.initialized)
			}
		})
	}
}
