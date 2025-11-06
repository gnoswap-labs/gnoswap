// Copyright 2019 Gregory Petrosyan <gregory.petrosyan@gmail.com>
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package fuzzing

import (
	"fmt"
	"math"
	"strings"
	"unicode"
	"unicode/utf8"
)

var (
	defaultRunes = []rune{
		'A', 'a', '?',
		'~', '!', '@', '#', '$', '%', '^', '&', '*', '_', '-', '+', '=',
		'.', ',', ':', ';',
		' ', '\t', '\r', '\n',
		'/', '\\', '|',
		'(', '[', '{', '<',
		'\'', '"', '`',
		'\x00', '\x0B', '\x1B', '\x7F', // NUL, VT, ESC, DEL
	}

	// Common unicode categories
	defaultTables = []*unicode.RangeTable{
		unicode.Lu, // Letter, uppercase
		unicode.Ll, // Letter, lowercase
		unicode.Nd, // Number, decimal digit
		unicode.P,  // Punctuation
		unicode.Sm, // Symbol, math
		unicode.Z,  // Separator
	}
)

// runeGen generates rune values
type runeGen struct {
	die      *loadedDie
	runes    []rune
	tables   [][]rune
	default_ bool
}

func (g *runeGen) String() string {
	if g.default_ {
		return "Rune()"
	}
	return fmt.Sprintf("Rune(%v runes, %v tables)", len(g.runes), len(g.tables))
}

func (g *runeGen) value(t *T) any {
	n := g.die.roll(t.s)

	runes := g.runes
	if len(g.runes) == 0 {
		runes = g.tables[n]
	} else if n > 0 {
		runes = g.tables[n-1]
	}

	return runes[genIndex(t.s, len(runes), true)]
}

// Rune creates a rune generator with default runes and tables
func Rune() *Generator {
	return runesFrom(true, defaultRunes, defaultTables...)
}

// RuneFrom creates a rune generator from provided runes and tables
func RuneFrom(runes []rune, tables ...*unicode.RangeTable) *Generator {
	return runesFrom(false, runes, tables...)
}

func runesFrom(default_ bool, runes []rune, tables ...*unicode.RangeTable) *Generator {
	if len(tables) == 0 {
		assertf(len(runes) > 0, "at least one rune should be specified")
	}
	if len(runes) == 0 {
		assertf(len(tables) > 0, "at least one *unicode.RangeTable should be specified")
	}

	var weights []int
	if len(runes) > 0 {
		weights = append(weights, len(tables))
	}
	for range tables {
		weights = append(weights, 1)
	}

	tables_ := make([][]rune, len(tables))
	for i := range tables {
		tables_[i] = expandRangeTable(tables[i])
		assertf(len(tables_[i]) > 0, "empty *unicode.RangeTable %v", i)
	}

	return newGenerator(&runeGen{
		die:      newLoadedDie(weights),
		runes:    runes,
		tables:   tables_,
		default_: default_,
	})
}

// stringGen generates string values
type stringGen struct {
	elem     *Generator
	minRunes int
	maxRunes int
	maxLen   int
}

func (g *stringGen) String() string {
	if g.minRunes < 0 && g.maxRunes < 0 && g.maxLen < 0 {
		return "String()"
	}
	return fmt.Sprintf("StringN(minRunes=%v, maxRunes=%v, maxLen=%v)", g.minRunes, g.maxRunes, g.maxLen)
}

func (g *stringGen) value(t *T) any {
	repeat := newRepeat(g.minRunes, g.maxRunes, -1, "rune")

	var b strings.Builder
	b.Grow(repeat.avg())

	maxLen := g.maxLen
	if maxLen < 0 {
		maxLen = math.MaxInt
	}

	for repeat.more(t.s) {
		r := g.elem.value(t).(rune)
		n := utf8.RuneLen(r)

		if n < 0 || b.Len()+n > maxLen {
			repeat.reject()
		} else {
			b.WriteRune(r)
		}
	}

	return b.String()
}

// String creates a UTF-8 string generator
func String() *Generator {
	return StringOfN(Rune(), -1, -1, -1)
}

// StringN creates a string generator with constraints on runes and length
func StringN(minRunes int, maxRunes int, maxLen int) *Generator {
	return StringOfN(Rune(), minRunes, maxRunes, maxLen)
}

// StringOf creates a string generator from a rune generator
func StringOf(elem *Generator) *Generator {
	return StringOfN(elem, -1, -1, -1)
}

// StringOfN creates a UTF-8 string generator with constraints
func StringOfN(elem *Generator, minRunes int, maxRunes int, maxLen int) *Generator {
	assertValidRange(minRunes, maxRunes)
	assertf(maxLen < 0 || maxLen >= maxRunes, "maximum length (%v) should not be less than maximum number of runes (%v)", maxLen, maxRunes)

	return newGenerator(&stringGen{
		elem:     elem,
		minRunes: minRunes,
		maxRunes: maxRunes,
		maxLen:   maxLen,
	})
}

func expandRangeTable(t *unicode.RangeTable) []rune {
	n := 0
	for _, r := range t.R16 {
		n += int(r.Hi-r.Lo)/int(r.Stride) + 1
	}
	for _, r := range t.R32 {
		n += int(r.Hi-r.Lo)/int(r.Stride) + 1
	}

	ret := make([]rune, 0, n)
	for _, r := range t.R16 {
		for i := uint32(r.Lo); i <= uint32(r.Hi); i += uint32(r.Stride) {
			ret = append(ret, rune(i))
		}
	}
	for _, r := range t.R32 {
		for i := uint64(r.Lo); i <= uint64(r.Hi); i += uint64(r.Stride) {
			ret = append(ret, rune(i))
		}
	}

	return ret
}
