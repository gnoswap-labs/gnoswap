package uint256

import (
	"testing"

	"gno.land/p/nt/uassert"
)

type logicOpTest struct {
	name string
	x    Uint
	y    Uint
	want Uint
}

func TestOr(t *testing.T) {
	tests := []logicOpTest{
		{
			name: "all zeros",
			x:    Uint{arr: [4]uint64{0, 0, 0, 0}},
			y:    Uint{arr: [4]uint64{0, 0, 0, 0}},
			want: Uint{arr: [4]uint64{0, 0, 0, 0}},
		},
		{
			name: "all ones",
			x:    Uint{arr: [4]uint64{^uint64(0), ^uint64(0), ^uint64(0), ^uint64(0)}},
			y:    Uint{arr: [4]uint64{^uint64(0), ^uint64(0), ^uint64(0), ^uint64(0)}},
			want: Uint{arr: [4]uint64{^uint64(0), ^uint64(0), ^uint64(0), ^uint64(0)}},
		},
		{
			name: "mixed",
			x:    Uint{arr: [4]uint64{^uint64(0), ^uint64(0), 0, 0}},
			y:    Uint{arr: [4]uint64{0, 0, ^uint64(0), ^uint64(0)}},
			want: Uint{arr: [4]uint64{^uint64(0), ^uint64(0), ^uint64(0), ^uint64(0)}},
		},
		{
			name: "one operand all ones",
			x:    Uint{arr: [4]uint64{^uint64(0), ^uint64(0), ^uint64(0), ^uint64(0)}},
			y:    Uint{arr: [4]uint64{0x5555555555555555, 0xAAAAAAAAAAAAAAAA, 0xFFFFFFFFFFFFFFFF, 0x0000000000000000}},
			want: Uint{arr: [4]uint64{^uint64(0), ^uint64(0), ^uint64(0), ^uint64(0)}},
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			res := new(Uint).Or(&tc.x, &tc.y)
			if *res != tc.want {
				t.Errorf("Or(%s, %s) = %s, want %s", tc.x.ToString(), tc.y.ToString(), res.ToString(), (tc.want).ToString())
			}
		})
	}
}

func TestAnd(t *testing.T) {
	tests := []logicOpTest{
		{
			name: "all zeros",
			x:    Uint{arr: [4]uint64{0, 0, 0, 0}},
			y:    Uint{arr: [4]uint64{0, 0, 0, 0}},
			want: Uint{arr: [4]uint64{0, 0, 0, 0}},
		},
		{
			name: "all ones",
			x:    Uint{arr: [4]uint64{^uint64(0), ^uint64(0), ^uint64(0), ^uint64(0)}},
			y:    Uint{arr: [4]uint64{^uint64(0), ^uint64(0), ^uint64(0), ^uint64(0)}},
			want: Uint{arr: [4]uint64{^uint64(0), ^uint64(0), ^uint64(0), ^uint64(0)}},
		},
		{
			name: "mixed",
			x:    Uint{arr: [4]uint64{0, 0, 0, 0}},
			y:    Uint{arr: [4]uint64{^uint64(0), ^uint64(0), ^uint64(0), ^uint64(0)}},
			want: Uint{arr: [4]uint64{0, 0, 0, 0}},
		},
		{
			name: "mixed 2",
			x:    Uint{arr: [4]uint64{^uint64(0), ^uint64(0), ^uint64(0), ^uint64(0)}},
			y:    Uint{arr: [4]uint64{0, 0, 0, 0}},
			want: Uint{arr: [4]uint64{0, 0, 0, 0}},
		},
		{
			name: "mixed 3",
			x:    Uint{arr: [4]uint64{^uint64(0), ^uint64(0), 0, 0}},
			y:    Uint{arr: [4]uint64{0, 0, ^uint64(0), ^uint64(0)}},
			want: Uint{arr: [4]uint64{0, 0, 0, 0}},
		},
		{
			name: "one operand zero",
			x:    Uint{arr: [4]uint64{0, 0, 0, 0}},
			y:    Uint{arr: [4]uint64{0xFFFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFF}},
			want: Uint{arr: [4]uint64{0, 0, 0, 0}},
		},
		{
			name: "one operand all ones",
			x:    Uint{arr: [4]uint64{^uint64(0), ^uint64(0), ^uint64(0), ^uint64(0)}},
			y:    Uint{arr: [4]uint64{0x5555555555555555, 0xAAAAAAAAAAAAAAAA, 0xFFFFFFFFFFFFFFFF, 0x0000000000000000}},
			want: Uint{arr: [4]uint64{0x5555555555555555, 0xAAAAAAAAAAAAAAAA, 0xFFFFFFFFFFFFFFFF, 0x0000000000000000}},
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			res := new(Uint).And(&tc.x, &tc.y)
			if *res != tc.want {
				t.Errorf("And(%s, %s) = %s, want %s", tc.x.ToString(), tc.y.ToString(), res.ToString(), (tc.want).ToString())
			}
		})
	}
}

func TestNot(t *testing.T) {
	tests := []struct {
		name string
		x    Uint
		want Uint
	}{
		{
			name: "all zeros",
			x:    Uint{arr: [4]uint64{0, 0, 0, 0}},
			want: Uint{arr: [4]uint64{^uint64(0), ^uint64(0), ^uint64(0), ^uint64(0)}},
		},
		{
			name: "all ones",
			x:    Uint{arr: [4]uint64{^uint64(0), ^uint64(0), ^uint64(0), ^uint64(0)}},
			want: Uint{arr: [4]uint64{0, 0, 0, 0}},
		},
		{
			name: "mixed",
			x:    Uint{arr: [4]uint64{^uint64(0), ^uint64(0), 0, 0}},
			want: Uint{arr: [4]uint64{0, 0, ^uint64(0), ^uint64(0)}},
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			res := new(Uint).Not(&tc.x)
			if *res != tc.want {
				t.Errorf("Not(%s) = %s, want %s", tc.x.ToString(), res.ToString(), (tc.want).ToString())
			}
		})
	}
}

func TestAndNot(t *testing.T) {
	tests := []logicOpTest{
		{
			name: "all zeros",
			x:    Uint{arr: [4]uint64{0, 0, 0, 0}},
			y:    Uint{arr: [4]uint64{0, 0, 0, 0}},
			want: Uint{arr: [4]uint64{0, 0, 0, 0}},
		},
		{
			name: "all ones",
			x:    Uint{arr: [4]uint64{^uint64(0), ^uint64(0), ^uint64(0), ^uint64(0)}},
			y:    Uint{arr: [4]uint64{^uint64(0), ^uint64(0), ^uint64(0), ^uint64(0)}},
			want: Uint{arr: [4]uint64{0, 0, 0, 0}},
		},
		{
			name: "mixed",
			x:    Uint{arr: [4]uint64{0, 0, 0, 0}},
			y:    Uint{arr: [4]uint64{^uint64(0), ^uint64(0), ^uint64(0), ^uint64(0)}},
			want: Uint{arr: [4]uint64{0, 0, 0, 0}},
		},
		{
			name: "mixed 2",
			x:    Uint{arr: [4]uint64{^uint64(0), ^uint64(0), ^uint64(0), ^uint64(0)}},
			y:    Uint{arr: [4]uint64{0, 0, 0, 0}},
			want: Uint{arr: [4]uint64{^uint64(0), ^uint64(0), ^uint64(0), ^uint64(0)}},
		},
		{
			name: "mixed 3",
			x:    Uint{arr: [4]uint64{^uint64(0), ^uint64(0), 0, 0}},
			y:    Uint{arr: [4]uint64{0, 0, ^uint64(0), ^uint64(0)}},
			want: Uint{arr: [4]uint64{^uint64(0), ^uint64(0), 0, 0}},
		},
		{
			name: "one operand zero",
			x:    Uint{arr: [4]uint64{0, 0, 0, 0}},
			y:    Uint{arr: [4]uint64{0xFFFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFF}},
			want: Uint{arr: [4]uint64{0, 0, 0, 0}},
		},
		{
			name: "one operand all ones",
			x:    Uint{arr: [4]uint64{^uint64(0), ^uint64(0), ^uint64(0), ^uint64(0)}},
			y:    Uint{arr: [4]uint64{0x5555555555555555, 0xAAAAAAAAAAAAAAAA, 0xFFFFFFFFFFFFFFFF, 0x0000000000000000}},
			want: Uint{arr: [4]uint64{0xAAAAAAAAAAAAAAAA, 0x5555555555555555, 0x0000000000000000, ^uint64(0)}},
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			res := new(Uint).AndNot(&tc.x, &tc.y)
			if *res != tc.want {
				t.Errorf("AndNot(%s, %s) = %s, want %s", tc.x.ToString(), tc.y.ToString(), res.ToString(), (tc.want).ToString())
			}
		})
	}
}

func TestXor(t *testing.T) {
	tests := []logicOpTest{
		{
			name: "all zeros",
			x:    Uint{arr: [4]uint64{0, 0, 0, 0}},
			y:    Uint{arr: [4]uint64{0, 0, 0, 0}},
			want: Uint{arr: [4]uint64{0, 0, 0, 0}},
		},
		{
			name: "all ones",
			x:    Uint{arr: [4]uint64{^uint64(0), ^uint64(0), ^uint64(0), ^uint64(0)}},
			y:    Uint{arr: [4]uint64{^uint64(0), ^uint64(0), ^uint64(0), ^uint64(0)}},
			want: Uint{arr: [4]uint64{0, 0, 0, 0}},
		},
		{
			name: "mixed",
			x:    Uint{arr: [4]uint64{0, 0, 0, 0}},
			y:    Uint{arr: [4]uint64{^uint64(0), ^uint64(0), ^uint64(0), ^uint64(0)}},
			want: Uint{arr: [4]uint64{^uint64(0), ^uint64(0), ^uint64(0), ^uint64(0)}},
		},
		{
			name: "mixed 2",
			x:    Uint{arr: [4]uint64{^uint64(0), ^uint64(0), ^uint64(0), ^uint64(0)}},
			y:    Uint{arr: [4]uint64{0, 0, 0, 0}},
			want: Uint{arr: [4]uint64{^uint64(0), ^uint64(0), ^uint64(0), ^uint64(0)}},
		},
		{
			name: "mixed 3",
			x:    Uint{arr: [4]uint64{^uint64(0), ^uint64(0), 0, 0}},
			y:    Uint{arr: [4]uint64{0, 0, ^uint64(0), ^uint64(0)}},
			want: Uint{arr: [4]uint64{^uint64(0), ^uint64(0), ^uint64(0), ^uint64(0)}},
		},
		{
			name: "one operand zero",
			x:    Uint{arr: [4]uint64{0, 0, 0, 0}},
			y:    Uint{arr: [4]uint64{0xFFFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFF}},
			want: Uint{arr: [4]uint64{0xFFFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFF}},
		},
		{
			name: "one operand all ones",
			x:    Uint{arr: [4]uint64{^uint64(0), ^uint64(0), ^uint64(0), ^uint64(0)}},
			y:    Uint{arr: [4]uint64{0x5555555555555555, 0xAAAAAAAAAAAAAAAA, 0xFFFFFFFFFFFFFFFF, 0x0000000000000000}},
			want: Uint{arr: [4]uint64{0xAAAAAAAAAAAAAAAA, 0x5555555555555555, 0x0000000000000000, ^uint64(0)}},
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			res := new(Uint).Xor(&tc.x, &tc.y)
			if *res != tc.want {
				t.Errorf("Xor(%s, %s) = %s, want %s", tc.x.ToString(), tc.y.ToString(), res.ToString(), (tc.want).ToString())
			}
		})
	}
}

func TestLsh(t *testing.T) {
	tests := []struct {
		x        string
		y        uint
		want     string
		overflow bool
	}{
		{"0", 0, "0", false},
		{"0", 1, "0", false},
		{"0", 64, "0", false},
		{"1", 0, "1", false},
		{"1", 1, "2", false},
		{"1", 64, "18446744073709551616", false},
		{"1", 128, "340282366920938463463374607431768211456", false},
		{"1", 192, "6277101735386680763835789423207666416102355444464034512896", false},
		{"1", 255, "57896044618658097711785492504343953926634992332820282019728792003956564819968", false},
		{"1", 256, "0", true},

		{"31337", 0, "31337", false},
		{"31337", 1, "62674", false},
		{"31337", 64, "578065619037836218990592", false},
		{"31337", 128, "10663428532201448629551770073089320442396672", false},
		{"31337", 192, "196705537081812415096322133155058642481399512563169449530621952", false},
		{"31337", 193, "393411074163624830192644266310117284962799025126338899061243904", false},
		// 31337 requires 15 bits (binary: 111101001101001). When shifted left by 255 bits,
		// it would require 15 + 255 = 270 bits total, which exceeds the 256-bit capacity.
		// The maximum safe left shift for 31337 is 241 bits (256 - 15 = 241).
		{"31337", 255, "0", true},
		{"31337", 256, "0", true},
	}

	for _, tc := range tests {
		x, err := FromDecimal(tc.x)
		if err != nil {
			t.Error(err)
			continue
		}

		want, err := FromDecimal(tc.want)
		if err != nil {
			t.Error(err)
			continue
		}

		if tc.overflow {
			uassert.PanicsWithMessage(t, "Lsh: overflow", func() {
				new(Uint).Lsh(x, tc.y)
			})
		} else {
			got := new(Uint).Lsh(x, tc.y)
			uassert.Equal(t, want.ToString(), got.ToString())
		}
	}
}

func TestRsh(t *testing.T) {
	tests := []struct {
		x    string
		y    uint
		want string
	}{
		{"0", 0, "0"},
		{"0", 1, "0"},
		{"0", 64, "0"},
		{"1", 0, "1"},
		{"1", 1, "0"},
		{"1", 64, "0"},
		{"1", 128, "0"},
		{"1", 192, "0"},
		{"1", 255, "0"},
		{"57896044618658097711785492504343953926634992332820282019728792003956564819968", 255, "1"},
		{"6277101735386680763835789423207666416102355444464034512896", 192, "1"},
		{"340282366920938463463374607431768211456", 128, "1"},
		{"18446744073709551616", 64, "1"},
		{"393411074163624830192644266310117284962799025126338899061243904", 193, "31337"},
		{"196705537081812415096322133155058642481399512563169449530621952", 192, "31337"},
		{"10663428532201448629551770073089320442396672", 128, "31337"},
		{"578065619037836218990592", 64, "31337"},
	}

	for _, tc := range tests {
		x, err := FromDecimal(tc.x)
		if err != nil {
			t.Error(err)
			continue
		}

		want, err := FromDecimal(tc.want)
		if err != nil {
			t.Error(err)
			continue
		}

		got := &Uint{}
		got.Rsh(x, tc.y)

		if got.Neq(want) {
			t.Errorf("Rsh(%s, %d) = %s, want %s", tc.x, tc.y, got.ToString(), want.ToString())
		}
	}
}
