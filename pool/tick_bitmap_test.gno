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
		{"tick at beginning", 0, struct{ wordPos int16; bitPos uint8 }{0, 0}},
		{"tick at end of first word", 255, struct{ wordPos int16; bitPos uint8 }{0, 255}},
		{"tick at beginning of second word", 256, struct{ wordPos int16; bitPos uint8 }{1, 0}},
		{"negative tick", -1, struct{ wordPos int16; bitPos uint8 }{-1, 255}},
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
		{
			name:        "tick not multiple of tickSpacing",
			tick:        5,
			tickSpacing: 2,
			expectPanic: true,
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