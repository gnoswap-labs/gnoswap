package launchpad

import (
	b64 "encoding/base64"
	"std"
	"strconv"

	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/p/demo/json"
	"gno.land/p/demo/ufmt"

	pusers "gno.land/p/demo/users"
)

const (
	MaxUint64 = 1<<64 - 1
	uintSize  = 32 << (^uint(0) >> 63)
)

func lower(c byte) byte {
	return c | ('x' - 'X')
}

// TODO: Remove parseUint after gno supports strconv.ParseUint
func parseUint(s string, base int, bitSize int) uint64 {
	const fnParseUint = "ParseUint"

	if s == "" {
		panic(ufmt.Errorf("%s: parsing \"\": invalid syntax", fnParseUint))
	}

	base0 := base == 0

	s0 := s
	switch {
	case 2 <= base && base <= 36:
		// valid base; nothing to do

	case base == 0:
		// Look for octal, hex prefix.
		base = 10
		if s[0] == '0' {
			switch {
			case len(s) >= 3 && lower(s[1]) == 'b':
				base = 2
				s = s[2:]
			case len(s) >= 3 && lower(s[1]) == 'o':
				base = 8
				s = s[2:]
			case len(s) >= 3 && lower(s[1]) == 'x':
				base = 16
				s = s[2:]
			default:
				base = 8
				s = s[1:]
			}
		}

	default:
		panic(ufmt.Errorf("%s: invalid base %d", fnParseUint, base))
	}

	if bitSize == 0 {
		bitSize = uintSize
	} else if bitSize < 0 || bitSize > 64 {
		panic(ufmt.Errorf("%s: invalid bit size %d", fnParseUint, bitSize))
	}

	// Cutoff is the smallest number such that cutoff*base > maxUint64.
	// Use compile-time constants for common cases.
	var cutoff uint64
	switch base {
	case 10:
		cutoff = MaxUint64/10 + 1
	case 16:
		cutoff = MaxUint64/16 + 1
	default:
		cutoff = MaxUint64/uint64(base) + 1
	}

	maxVal := uint64(1)<<uint(bitSize) - 1

	underscores := false
	var n uint64
	for _, c := range []byte(s) {
		var d byte
		switch {
		case c == '_' && base0:
			underscores = true
			continue
		case '0' <= c && c <= '9':
			d = c - '0'
		case 'a' <= lower(c) && lower(c) <= 'z':
			d = lower(c) - 'a' + 10
		default:
			panic(ufmt.Errorf("%s: invalid character", fnParseUint))
		}

		if d >= byte(base) {
			panic(ufmt.Errorf("%s: invalid character", fnParseUint))
		}

		if n >= cutoff {
			// n*base overflows
			panic(ufmt.Errorf("%s: value out of range", fnParseUint))
			// return maxVal, ufmt.Errorf("%s: value out of range", fnParseUint)
		}
		n *= uint64(base)

		n1 := n + uint64(d)
		if n1 < n || n1 > maxVal {
			// n+d overflows
			panic(ufmt.Errorf("%s: value out of range", fnParseUint))
			// return maxVal, ufmt.Errorf("%s: value out of range", fnParseUint)
		}
		n = n1
	}

	if underscores && !underscoreOK(s0) {
		panic(ufmt.Errorf("%s: invalid underscore", fnParseUint))
	}

	return n
}

func underscoreOK(s string) bool {
	// saw tracks the last character (class) we saw:
	// ^ for beginning of number,
	// 0 for a digit or base prefix,
	// _ for an underscore,
	// ! for none of the above.
	saw := '^'
	i := 0

	// Optional sign.
	if len(s) >= 1 && (s[0] == '-' || s[0] == '+') {
		s = s[1:]
	}

	// Optional base prefix.
	hex := false
	if len(s) >= 2 && s[0] == '0' && (lower(s[1]) == 'b' || lower(s[1]) == 'o' || lower(s[1]) == 'x') {
		i = 2
		saw = '0' // base prefix counts as a digit for "underscore as digit separator"
		hex = lower(s[1]) == 'x'
	}

	// Number proper.
	for ; i < len(s); i++ {
		// Digits are always okay.
		if '0' <= s[i] && s[i] <= '9' || hex && 'a' <= lower(s[i]) && lower(s[i]) <= 'f' {
			saw = '0'
			continue
		}
		// Underscore must follow digit.
		if s[i] == '_' {
			if saw != '0' {
				return false
			}
			saw = '_'
			continue
		}
		// Underscore must also be followed by digit.
		if saw == '_' {
			return false
		}
		// Saw non-digit, non-underscore.
		saw = '!'
	}

	return saw != '_'
}

func strToInt(str string) int {
	res, err := strconv.Atoi(str)
	if err != nil {
		panic(err)
	}

	return res
}

func strToU256U64(str string) uint64 {
	strValue := u256.MustFromDecimal(str)
	return strValue.Uint64()
}

func contains(slice []string, str string) bool {
	for _, v := range slice {
		if v == str {
			return true
		}
	}
	return false
}

func marshal(data *json.Node) string {
	b, err := json.Marshal(data)
	if err != nil {
		panic(err.Error())
	}

	return string(b)
}

func b64Encode(data string) string {
	return string(b64.StdEncoding.EncodeToString([]byte(data)))
}

func prevRealm() string {
	return std.PrevRealm().PkgPath()
}

func a2u(addr std.Address) pusers.AddressOrName {
	return pusers.AddressOrName(addr)
}

func minU64(x, y uint64) uint64 {
	if x < y {
		return x
	}
	return y
}

func isUserCall() bool {
	return std.PrevRealm().IsUser()
}

func assertUserCall() {
	if !isUserCall() {
		panic("must be called by user")
	}
}

func getPrev() (string, string) {
	prev := std.PrevRealm()
	return prev.Addr().String(), prev.PkgPath()
}

func min(x, y uint64) uint64 {
	if x < y {
		return x
	}
	return y
}
