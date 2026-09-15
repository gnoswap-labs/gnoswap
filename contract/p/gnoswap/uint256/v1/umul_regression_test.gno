package uint256

import (
	"math/bits"
	"math/rand"
	"testing"
)

// umulBaseline mirrors the previous schoolbook implementation of umul to validate correctness of optimizations.
func umulBaseline(x, y *Uint) [8]uint64 {
	var (
		res                           [8]uint64
		carry, carry4, carry5, carry6 uint64
		res1, res2, res3, res4, res5  uint64
	)

	carry, res[0] = bits.Mul64(x[0], y[0])
	carry, res1 = umulHop(carry, x[1], y[0])
	carry, res2 = umulHop(carry, x[2], y[0])
	carry4, res3 = umulHop(carry, x[3], y[0])

	carry, res[1] = umulHop(res1, x[0], y[1])
	carry, res2 = umulStep(res2, x[1], y[1], carry)
	carry, res3 = umulStep(res3, x[2], y[1], carry)
	carry5, res4 = umulStep(carry4, x[3], y[1], carry)

	carry, res[2] = umulHop(res2, x[0], y[2])
	carry, res3 = umulStep(res3, x[1], y[2], carry)
	carry, res4 = umulStep(res4, x[2], y[2], carry)
	carry6, res5 = umulStep(carry5, x[3], y[2], carry)

	carry, res[3] = umulHop(res3, x[0], y[3])
	carry, res[4] = umulStep(res4, x[1], y[3], carry)
	carry, res[5] = umulStep(res5, x[2], y[3], carry)
	res[7], res[6] = umulStep(carry6, x[3], y[3], carry)

	return res
}

func TestUmulMatchesBaseline(t *testing.T) {
	samples := []struct {
		x string
		y string
	}{
		{"0", "0"},
		{"1", "1"},
		{"2", "3"},
		{"18446744073709551615", "2"},
		{MAX_UINT256, "1"},
		{MAX_UINT256, MAX_UINT256},
		{"1234567890123456789012345678901234567890", "98765432109876543210"},
	}

	for i, sample := range samples {
		x := MustFromDecimal(sample.x)
		y := MustFromDecimal(sample.y)
		assertUmulEqual(t, i, x, y)
	}

	// Additional random coverage
	rng := rand.New(rand.NewPCG(1, 2))
	for i := 0; i < 200; i++ {
		var x, y Uint
		for j := 0; j < 4; j++ {
			x[j] = rng.Uint64()
			y[j] = rng.Uint64()
		}
		assertUmulEqual(t, i+len(samples), &x, &y)
	}
}

func assertUmulEqual(t *testing.T, index int, x, y *Uint) {
	t.Helper()
	got := umul(x, y)
	want := umulBaseline(x, y)
	if got != want {
		t.Fatalf("umul mismatch at index %d\nx=%s\ny=%s\ngot=%v\nwant=%v", index, x.ToString(), y.ToString(), got, want)
	}
}
