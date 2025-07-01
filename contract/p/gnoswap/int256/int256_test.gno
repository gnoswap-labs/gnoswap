// ported from github.com/mempooler/int256
package int256

import (
	"testing"
)

func TestSign(t *testing.T) {
	tests := []struct {
		x    string
		want int
	}{
		{"0", 0},
		{"1", 1},
		{"-1", -1},
	}

	for _, tt := range tests {
		z := MustFromDecimal(tt.x)
		got := z.Sign()
		if got != tt.want {
			t.Errorf("Sign(%s) = %d, want %d", tt.x, got, tt.want)
		}
	}
}

func TestSetString(t *testing.T) {
	tests := []struct {
		input    string
		wantErr  bool
		wantVal  string
		wantSign bool
	}{
		{"123", false, "123", false},
		{"+123", false, "123", false},
		{"-123", false, "123", true},
		{"9223372036854775807", false, "9223372036854775807", false},
		{"-9223372036854775808", false, "9223372036854775808", true},

		{"++123", true, "", false},
		{"--123", true, "", false},
		{"+-123", true, "", false},
		{"-+123", true, "", false},
		{"+++123", true, "", false},
		{"---123", true, "", false},
		{"+-+-123", true, "", false},
		{"922337203-6854775807", true, "", false},

		{"1+23", true, "", false},
		{"1-23", true, "", false},
		{"12+3", true, "", false},

		// scientific notation not allowed
		{"-1e23", true, "", false},
		{"1e-23", true, "", false},
		{"1e+23", true, "", false},

		{"", true, "", false},
		{"+", true, "", false},
		{"-", true, "", false},
		{"+-", true, "", false},
	}

	for _, tt := range tests {
		z, err := new(Int).SetString(tt.input)

		if tt.wantErr {
			if err == nil {
				t.Errorf("SetString(%q) = %v, want error", tt.input, z)
			}
			continue
		}

		if err != nil {
			t.Errorf("SetString(%q) returned unexpected error: %v", tt.input, err)
			continue
		}

		if got := z.abs.ToString(); got != tt.wantVal {
			t.Errorf("SetString(%q).abs = %s, want %s", tt.input, got, tt.wantVal)
		}

		if got := z.neg; got != tt.wantSign {
			t.Errorf("SetString(%q).neg = %v, want %v", tt.input, got, tt.wantSign)
		}
	}
}

func TestInitiateAbs(t *testing.T) {
	tests := []struct {
		name     string
		input    *Int
		wantNil  bool
		wantZero bool
	}{
		{
			name:     "nil input returns new zero Int",
			input:    nil,
			wantNil:  false,
			wantZero: true,
		},
		{
			name:     "nil abs field gets initialized",
			input:    &Int{abs: nil, neg: false},
			wantNil:  false,
			wantZero: true,
		},
		{
			name:     "existing abs field remains unchanged",
			input:    NewInt(123),
			wantNil:  false,
			wantZero: false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			result := tc.input.initiateAbs()

			if result == nil {
				t.Error("initiateAbs returned nil")
				return
			}

			if (result.abs == nil) != tc.wantNil {
				t.Errorf("abs field nil status = %v, want %v", result.abs == nil, tc.wantNil)
			}

			isZero := result.abs != nil && result.abs.IsZero()
			if isZero != tc.wantZero {
				t.Errorf("IsZero() = %v, want %v", isZero, tc.wantZero)
			}
		})
	}
}

func TestInitiateAbsInOperation(t *testing.T) {
	tests := []struct {
		name  string
		setup func() *Int
		op    func(*Int) *Int
		want  string
	}{
		{
			name:  "Add with nil receiver",
			setup: func() *Int { return nil },
			op:    func(z *Int) *Int { return z.Add(NewInt(10), NewInt(20)) },
			want:  "30",
		},
		{
			name:  "Add with nil abs field",
			setup: func() *Int { return &Int{abs: nil} },
			op:    func(z *Int) *Int { return z.Add(NewInt(10), NewInt(20)) },
			want:  "30",
		},
		{
			name:  "Sub with nil receiver",
			setup: func() *Int { return nil },
			op:    func(z *Int) *Int { return z.Sub(NewInt(30), NewInt(20)) },
			want:  "10",
		},
		{
			name:  "Sub with nil abs field",
			setup: func() *Int { return &Int{abs: nil} },
			op:    func(z *Int) *Int { return z.Sub(NewInt(30), NewInt(20)) },
			want:  "10",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			z := tc.setup()
			result := tc.op(z)

			if result == nil {
				t.Error("operation returned nil")
				return
			}

			if got := result.ToString(); got != tc.want {
				t.Errorf("got %v, want %v", got, tc.want)
			}
		})
	}
}

func TestSetInt64NilReceiver(t *testing.T) {
	tests := []struct {
		name string
		x    int64
		want string
	}{
		{"nil receiver positive", 42, "42"},
		{"nil receiver negative", -42, "-42"},
		{"nil receiver zero", 0, "0"},
		{"nil receiver int64 max", 9223372036854775807, "9223372036854775807"},
		{"nil receiver int64 min", -9223372036854775808, "-9223372036854775808"},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			var z *Int
			result := z.SetInt64(tc.x)

			if result == nil {
				t.Fatal("SetInt64 returned nil")
			}

			got := result.ToString()
			if got != tc.want {
				t.Errorf("SetInt64(%d) = %s, want %s", tc.x, got, tc.want)
			}

			// should be nil
			if z != nil {
				t.Error("original receiver should remain nil")
			}
		})
	}
}

func TestSetUint64NilReceiver(t *testing.T) {
	tests := []struct {
		name string
		x    uint64
		want string
	}{
		{"nil receiver zero", 0, "0"},
		{"nil receiver positive", 42, "42"},
		{"nil receiver uint64 max", 18446744073709551615, "18446744073709551615"},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			var z *Int
			result := z.SetUint64(tc.x)

			if result == nil {
				t.Fatal("SetUint64 returned nil")
			}

			got := result.ToString()
			if got != tc.want {
				t.Errorf("SetUint64(%d) = %s, want %s", tc.x, got, tc.want)
			}

			// should be nil
			if z != nil {
				t.Error("original receiver should remain nil")
			}
		})
	}
}

func TestSetInt64NilAbs(t *testing.T) {
	tests := []struct {
		name string
		x    int64
		want string
	}{
		{"nil abs positive", 123, "123"},
		{"nil abs negative", -456, "-456"},
		{"nil abs zero", 0, "0"},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			z := &Int{abs: nil, neg: false}
			z.SetInt64(tc.x)

			if z.abs == nil {
				t.Error("abs should be initialized")
			}

			got := z.ToString()
			if got != tc.want {
				t.Errorf("SetInt64(%d) = %s, want %s", tc.x, got, tc.want)
			}
		})
	}
}

func TestSetInt64ConsecutiveCalls(t *testing.T) {
	z := new(Int)

	values := []int64{0, 1, -1, 100, -100, 9223372036854775807, -9223372036854775808}

	for _, v := range values {
		z.SetInt64(v)
		got := z.Int64()
		if got != v {
			t.Errorf("SetInt64(%d) roundtrip failed, got %d", v, got)
		}
	}
}

func TestMethodChaining(t *testing.T) {
	tests := []struct {
		name string
		ops  func() *Int
		want string
	}{
		{
			name: "chain SetInt64",
			ops: func() *Int {
				return new(Int).SetInt64(-42).Neg(new(Int).SetInt64(-42))
			},
			want: "42",
		},
		{
			name: "chain SetUint64",
			ops: func() *Int {
				return new(Int).SetUint64(100).Add(new(Int).SetUint64(200), new(Int).SetUint64(300))
			},
			want: "500",
		},
		{
			name: "chain on nil receiver",
			ops: func() *Int {
				var z *Int
				return z.SetInt64(10).Neg(z.SetInt64(10))
			},
			want: "-10",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			result := tc.ops()
			if result.ToString() != tc.want {
				t.Errorf("got %s, want %s", result.ToString(), tc.want)
			}
		})
	}
}
