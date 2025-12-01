package int256

import (
	"testing"

	"gno.land/p/nt/uassert"
	"gno.land/p/nt/ufmt"
)

func pack32to64(words []uint32) []uint64 {
	var out []uint64
	for i := 0; i < len(words); i += 2 {
		lo := uint64(words[i])
		hi := uint64(0)
		if i+1 < len(words) {
			hi = uint64(words[i+1])
		}
		out = append(out, (hi<<32)|lo)
	}
	return out
}

func toInt(xs []uint64) Int {
	var z Int
	for i := 0; i < len(xs) && i < len(z); i++ {
		z[i] = xs[i]
	}
	return z
}

// Source: https://skanthak.hier-im-netz.de/division.html#proper (Section: Generic Implementation in Hacker’s Delight)
var tests = []uint32{
	// m, n, u...,          v...,          cq...,  cr....
	1, 1, 3, 0, 1, 1, // Error, divide by 0.
	1, 2, 7, 1, 3, 0, 7, 0,
	2, 2, 0, 0, 1, 0, 0, 0, 0,
	1, 1, 3, 2, 1, 1,
	1, 1, 3, 3, 1, 0,
	1, 1, 3, 4, 0, 3,
	1, 1, 0, 0xffffffff, 0, 0,
	1, 1, 0xffffffff, 1, 0xffffffff, 0,
	1, 1, 0xffffffff, 0xffffffff, 1, 0,
	1, 1, 0xffffffff, 3, 0x55555555, 0,
	2, 1, 0xffffffff, 0xffffffff, 1, 0xffffffff, 0xffffffff, 0,
	2, 1, 0xffffffff, 0xffffffff, 0xffffffff, 1, 1, 0,
	2, 1, 0xffffffff, 0xfffffffe, 0xffffffff, 0xffffffff, 0, 0xfffffffe,
	2, 1, 0x00005678, 0x00001234, 0x00009abc, 0x1e1dba76, 0, 0x6bd0,
	2, 2, 0, 0, 0, 1, 0, 0, 0,
	2, 2, 0, 7, 0, 3, 2, 0, 1,
	2, 2, 5, 7, 0, 3, 2, 5, 1,
	2, 2, 0, 6, 0, 2, 3, 0, 0,
	1, 1, 0x80000000, 0x40000001, 0x00000001, 0x3fffffff,
	2, 1, 0x00000000, 0x80000000, 0x40000001, 0xfffffff8, 0x00000001, 0x00000008,
	2, 2, 0x00000000, 0x80000000, 0x00000001, 0x40000000, 0x00000001, 0xffffffff, 0x3fffffff,
	2, 2, 0x0000789a, 0x0000bcde, 0x0000789a, 0x0000bcde, 1, 0, 0,
	2, 2, 0x0000789b, 0x0000bcde, 0x0000789a, 0x0000bcde, 1, 1, 0,
	2, 2, 0x00007899, 0x0000bcde, 0x0000789a, 0x0000bcde, 0, 0x00007899, 0x0000bcde,
	2, 2, 0x0000ffff, 0x0000ffff, 0x0000ffff, 0x0000ffff, 1, 0, 0,
	2, 2, 0x0000ffff, 0x0000ffff, 0x00000000, 0x00000001, 0x0000ffff, 0x0000ffff, 0,
	3, 2, 0x000089ab, 0x00004567, 0x00000123, 0x00000000, 0x00000001, 0x00004567, 0x00000123, 0x000089ab, 0,
	3, 2, 0x00000000, 0x0000fffe, 0x00008000, 0x0000ffff, 0x00008000, 0xffffffff, 0x00000000, 0x0000ffff, 0x00007fff, // Shows that first qhat can = b + 1.
	3, 3, 0x00000003, 0x00000000, 0x80000000, 0x00000001, 0x00000000, 0x20000000, 0x00000003, 0, 0, 0x20000000, // Adding back step req'd.
	3, 3, 0x00000003, 0x00000000, 0x00008000, 0x00000001, 0x00000000, 0x00002000, 0x00000003, 0, 0, 0x00002000, // Adding back step req'd.
	4, 3, 0, 0, 0x00008000, 0x00007fff, 1, 0, 0x00008000, 0xfffe0000, 0, 0x00020000, 0xffffffff, 0x00007fff, // Add back req'd.
	4, 3, 0, 0x0000fffe, 0, 0x00008000, 0x0000ffff, 0, 0x00008000, 0xffffffff, 0, 0x0000ffff, 0xffffffff, 0x00007fff, // Shows that mult-sub quantity cannot be treated as signed.
	4, 3, 0, 0xfffffffe, 0, 0x80000000, 0x0000ffff, 0, 0x80000000, 0x00000000, 1, 0x00000000, 0xfffeffff, 0x00000000, // Shows that mult-sub quantity cannot be treated as signed.
	4, 3, 0, 0xfffffffe, 0, 0x80000000, 0xffffffff, 0, 0x80000000, 0xffffffff, 0, 0xffffffff, 0xffffffff, 0x7fffffff, // Shows that mult-sub quantity cannot be treated as signed.
}

func TestUdivrem(t *testing.T) {
	i := 0
	caseNo := 0

	for i < len(tests) {
		caseNo++

		m := int(tests[i])
		n := int(tests[i+1])

		u32 := tests[i+2 : i+2+m]
		v32 := tests[i+2+m : i+2+m+n]

		qlen := max(m-n+1, 1)
		cq32 := tests[i+2+m+n : i+2+m+n+qlen]
		cr32 := tests[i+2+m+n+qlen : i+2+m+n+qlen+n]

		// transform
		u := toInt(pack32to64(u32))
		v := toInt(pack32to64(v32))
		cq := toInt(pack32to64(cq32))
		cr := toInt(pack32to64(cr32))

		shouldError := false

		// Division by zero case
		isZero := true
		for i := 0; i < len(v32); i++ {
			if v32[i] != 0 {
				isZero = false
				break
			}
		}
		if isZero {
			shouldError = true
		}

		if shouldError {
			mustPanic(t, func() {
				var q [4]uint64
				_ = udivrem(q[:], u[:], &v)
			})
		} else {
			var quot [4]uint64

			mustNotPanic(t, func() {
				rem := udivrem(quot[:], u[:], &v)
				q := toInt(quot[:])

				uassert.Equal(t, cq.ToString(), q.ToString(), ufmt.Sprintf("[case %d] quotient mismatch:\n got=%v\n want=%v\n", caseNo, q, cq))
				uassert.Equal(t, cr.ToString(), rem.ToString(), ufmt.Sprintf("[case %d] remainder mismatch:\n got=%v\n want=%v\n", caseNo, rem, cr))
			})
		}

		i += 2 + m + n + qlen + n
	}
}

func mustPanic(t *testing.T, f func()) {
	t.Helper()
	defer func() {
		if r := recover(); r == nil {
			t.Fatalf("expected panic but did not panic")
		}
	}()
	f()
}

func mustNotPanic(t *testing.T, f func()) {
	t.Helper()
	defer func() {
		if r := recover(); r != nil {
			t.Fatalf("unexpected panic: %v", r)
		}
	}()
	f()
}

func max(a, b int) int {
	if a > b {
		return a
	}
	return b
}
