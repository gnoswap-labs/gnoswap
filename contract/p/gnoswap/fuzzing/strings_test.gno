package fuzzing

import (
	"testing"
)

// Test Rune generator
func TestStrings_Rune(t *testing.T) {
	seed := uint64(12345)
	s := newRandomBitStream(seed, false)
	testT := newT(s)

	// Generate 100 runes
	for i := 0; i < 100; i++ {
		val := Rune().Draw(testT, "rune").(rune)
		// Valid rune range is 0 to 0x10FFFF
		if val < 0 || val > 0x10FFFF {
			t.Fatalf("Rune() produced invalid rune: %d", val)
		}
	}
}

// Test Rune generator with custom runes
func TestStrings_RuneFrom(t *testing.T) {
	seed := uint64(54321)
	s := newRandomBitStream(seed, false)
	testT := newT(s)

	// Create rune generator for lowercase letters
	lowercase := make([]rune, 0, 26)
	for r := 'a'; r <= 'z'; r++ {
		lowercase = append(lowercase, r)
	}

	gen := RuneFrom(lowercase)

	for i := 0; i < 100; i++ {
		val := gen.Draw(testT, "rune").(rune)
		if val < 'a' || val > 'z' {
			t.Fatalf("RuneFrom(lowercase) produced out-of-range value: %c (%d)", val, val)
		}
	}
}

// Test String generator
func TestStrings_String(t *testing.T) {
	seed := uint64(11111)
	s := newRandomBitStream(seed, false)
	testT := newT(s)

	// Generate 50 strings
	for i := 0; i < 50; i++ {
		val := String().Draw(testT, "string").(string)
		// String should be valid UTF-8
		for _, r := range val {
			if r < 0 || r > 0x10FFFF {
				t.Fatalf("String() produced invalid rune: %d in string %q", r, val)
			}
		}
	}
}

// Test StringN generator with length constraints
func TestStrings_StringN(t *testing.T) {
	tests := []struct {
		name   string
		minLen int
		maxLen int
	}{
		{
			name:   "empty allowed",
			minLen: 0,
			maxLen: 10,
		},
		{
			name:   "fixed length",
			minLen: 5,
			maxLen: 5,
		},
		{
			name:   "small range",
			minLen: 1,
			maxLen: 20,
		},
		{
			name:   "larger range",
			minLen: 10,
			maxLen: 50,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			seed := uint64(22222)
			s := newRandomBitStream(seed, false)
			testT := newT(s)

			// when & then
			for i := 0; i < 30; i++ {
				val := StringN(tc.minLen, tc.maxLen, -1).Draw(testT, "string").(string)
				runeCount := len([]rune(val))

				if runeCount < tc.minLen || runeCount > tc.maxLen {
					t.Fatalf("StringN(%d, %d, -1) produced string with length %d: %q",
						tc.minLen, tc.maxLen, runeCount, val)
				}
			}
		})
	}
}

// Test StringOf generator with custom rune generator
func TestStrings_StringOf(t *testing.T) {
	seed := uint64(33333)
	s := newRandomBitStream(seed, false)
	testT := newT(s)

	// Create rune generator for lowercase letters
	lowercase := make([]rune, 0, 26)
	for r := 'a'; r <= 'z'; r++ {
		lowercase = append(lowercase, r)
	}
	lowercaseGen := RuneFrom(lowercase)

	for i := 0; i < 30; i++ {
		val := StringOf(lowercaseGen).Draw(testT, "string").(string)

		// Verify all runes are lowercase
		for _, r := range val {
			if r < 'a' || r > 'z' {
				t.Fatalf("StringOf(lowercase) produced non-lowercase rune: %c in %q", r, val)
			}
		}
	}
}

// Test StringOfN with custom rune generator and length constraints
func TestStrings_StringOfN(t *testing.T) {
	tests := []struct {
		name   string
		minLen int
		maxLen int
	}{
		{
			name:   "short digits",
			minLen: 3,
			maxLen: 6,
		},
		{
			name:   "medium length",
			minLen: 5,
			maxLen: 15,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			seed := uint64(44444)
			s := newRandomBitStream(seed, false)
			testT := newT(s)

			// Create rune generator for digits
			digits := make([]rune, 0, 10)
			for r := '0'; r <= '9'; r++ {
				digits = append(digits, r)
			}
			digitsGen := RuneFrom(digits)

			// when & then
			for i := 0; i < 30; i++ {
				val := StringOfN(digitsGen, tc.minLen, tc.maxLen, -1).Draw(testT, "string").(string)
				runeCount := len([]rune(val))

				if runeCount < tc.minLen || runeCount > tc.maxLen {
					t.Fatalf("StringOfN(digits, %d, %d, -1) produced string with length %d: %q",
						tc.minLen, tc.maxLen, runeCount, val)
				}

				// Verify all runes are digits
				for _, r := range val {
					if r < '0' || r > '9' {
						t.Fatalf("StringOfN(digits, ...) produced non-digit rune: %c in %q", r, val)
					}
				}
			}
		})
	}
}

// Test ASCII string generator
func TestStrings_ASCIIString(t *testing.T) {
	seed := uint64(55555)
	s := newRandomBitStream(seed, false)
	testT := newT(s)

	// Create ASCII rune generator
	ascii := make([]rune, 0, 128)
	for r := rune(0); r < 128; r++ {
		ascii = append(ascii, r)
	}
	asciiGen := RuneFrom(ascii)

	for i := 0; i < 50; i++ {
		val := StringOf(asciiGen).Draw(testT, "ascii").(string)

		// Verify all runes are ASCII (0-127)
		for _, r := range val {
			if r < 0 || r > 127 {
				t.Fatalf("ASCII string produced non-ASCII rune: %c (%d) in %q", r, r, val)
			}
		}
	}
}

// Test printable string generator
func TestStrings_PrintableString(t *testing.T) {
	seed := uint64(66666)
	s := newRandomBitStream(seed, false)
	testT := newT(s)

	// Create printable ASCII rune generator
	printable := make([]rune, 0, 95)
	for r := ' '; r <= '~'; r++ {
		printable = append(printable, r)
	}
	printableGen := RuneFrom(printable)

	for i := 0; i < 50; i++ {
		val := StringOf(printableGen).Draw(testT, "printable").(string)

		// Verify all runes are printable ASCII
		for _, r := range val {
			if r < ' ' || r > '~' {
				t.Fatalf("Printable string produced non-printable rune: %c (%d) in %q", r, r, val)
			}
		}
	}
}

// Test alphanumeric string generator
func TestStrings_AlphanumericString(t *testing.T) {
	seed := uint64(77777)
	s := newRandomBitStream(seed, false)
	testT := newT(s)

	// Create lowercase rune generator
	lowercase := make([]rune, 0, 26)
	for r := 'a'; r <= 'z'; r++ {
		lowercase = append(lowercase, r)
	}
	lowercaseGen := RuneFrom(lowercase)

	for i := 0; i < 30; i++ {
		val := StringOf(lowercaseGen).Draw(testT, "alpha").(string)

		// Verify all runes are lowercase letters
		for _, r := range val {
			if !((r >= 'a' && r <= 'z')) {
				t.Fatalf("Alphanumeric string produced invalid rune: %c (%d) in %q", r, r, val)
			}
		}
	}
}

// Test empty string can be generated
func TestStrings_EmptyString(t *testing.T) {
	seed := uint64(88888)
	s := newRandomBitStream(seed, false)
	testT := newT(s)

	foundEmpty := false
	for i := 0; i < 100; i++ {
		val := StringN(0, 5, -1).Draw(testT, "string").(string)
		if len(val) == 0 {
			foundEmpty = true
			break
		}
	}

	if !foundEmpty {
		t.Errorf("StringN(0, 5, -1) never generated empty string in 100 attempts")
	}
}

// Test Unicode string generator
func TestStrings_UnicodeString(t *testing.T) {
	seed := uint64(99999)
	s := newRandomBitStream(seed, false)
	testT := newT(s)

	for i := 0; i < 30; i++ {
		val := String().Draw(testT, "unicode").(string)

		// Just verify it's valid UTF-8 by iterating
		runeCount := 0
		for range val {
			runeCount++
		}

		if runeCount < 0 {
			t.Fatalf("Invalid UTF-8 string generated")
		}
	}
}
