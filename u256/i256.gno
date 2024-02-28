package u256

// signed integer wrapper

type Int struct {
	v Uint
}

func NewInt(v int64) *Int {
	if v >= 0 {
		return &Int{v: *NewUint(uint64(v))}
	}
	return &Int{
		v: Uint{
			arr: [4]uint64{
				uint64(v), // bit preserving cast, little endian
				0xffffffffffffffff,
				0xffffffffffffffff,
				0xffffffffffffffff,
			},
		},
	}
}

func IntFromBigint(v bigint) *Int {
	if v > MaxUint256/2-1 {
		panic("I256 IntFromBigint overflow")
	}
	if v < -MaxUint256/2 {
		panic("I256 IntFromBigint underflow")
	}

	if v >= 0 {
		return &Int{v: *FromBigint(v)}
	}

	panic("I256 IntFromBigint not implemented")
}

func (x *Int) Bigint() bigint {
	if x.Signum() < 0 {
		return -x.Neg().v.Bigint()
	}
	return x.v.Bigint()

}

func (x *Int) IsNeg() bool {
	return x.Signum() < 0
}

func (x *Int) Add(y *Int, z *Int) *Int {
	x.v.Add(&y.v, &z.v)

	ys := y.Signum()
	zs := z.Signum()

	if ys > 0 && zs > 0 && x.Signum() < 0 {
		panic("I256 Add overflow")
	}

	if ys < 0 && zs < 0 && x.Signum() > 0 {
		panic("I256 Add underflow")
	}

	return x
}

func (x *Int) Sub(y *Int, z *Int) *Int {
	x.v.UnsafeSub(&y.v, &z.v)

	ys := y.Signum()
	zs := z.Signum()

	if ys > 0 && zs < 0 && x.Signum() < 0 {
		panic("I256 Sub overflow")
	}

	if ys < 0 && zs > 0 && x.Signum() > 0 {
		panic("I256 Sub underflow")
	}

	return x
}

func (x *Int) Mul(y *Int, z *Int) *Int {
	x.v.Mul(&y.v, &z.v)

	ys := y.Signum()
	zs := z.Signum()

	if ys > 0 && zs > 0 && x.Signum() < 0 {
		panic("I256 Mul overflow #1")
	}

	if ys < 0 && zs < 0 && x.Signum() < 0 {
		panic("I256 Mul overflow #2")
	}

	if ys > 0 && zs < 0 && x.Signum() > 0 {
		panic("I256 Mul underflow #1")
	}

	if ys < 0 && zs > 0 && x.Signum() > 0 {
		panic("I256 Mul underflow #2")
	}

	return x
}

func (x *Int) Lsh(y *Int, n uint) *Int {
	x.v.Lsh(&y.v, n)
	return x
}

func (x *Int) Rsh(y *Int, n uint) *Int {
	x.v.Rsh(&y.v, n)
	return x
}

func (x *Int) Eq(y *Int) bool {
	return x.v.Eq(&y.v)
}

func (x *Int) IsZero() bool {
	return x.v.IsZero()
}

func (x *Int) Signum() int {
	if x.v.arr[3] == 0 && x.v.arr[2] == 0 && x.v.arr[1] == 0 && x.v.arr[0] == 0 {
		return 0
	}
	if x.v.arr[3] < 0x8000000000000000 {
		return 1
	}
	return -1
}

func (x *Int) Gt(y *Int) bool {
	xs := x.Signum()
	ys := y.Signum()

	if xs != ys {
		return xs > ys
	}
	if xs == 0 {
		return false
	}
	if xs > 0 {
		return x.v.Gt(&y.v)
	}
	return y.v.Gt(&x.v)
}

func (x *Int) Lte(y *Int) bool {
	return !x.Gt(y)
}

func (x *Int) Gte(y *Int) bool {
	xs := x.Signum()
	ys := y.Signum()

	if xs != ys {
		return xs > ys
	}
	if xs == 0 {
		return true
	}
	if xs > 0 {
		return x.v.Gte(&y.v)
	}
	return y.v.Gte(&x.v)
}

func (x *Int) Int64() int64 {
	// TODO: overflow check
	if x.v.arr[3] < 0x8000000000000000 {
		return int64(x.v.arr[0])
	}
	// TODO: check if this is correct
	return -int64(^x.v.arr[0] + 1)
}

func (x *Int) Abs() *Uint {
	if x.Signum() > 0 {
		return &x.v
	}
	x1 := &Int{v: x.v} // so that we don't modify x
	return &x1.Neg().v
}

func (x *Int) Neg() *Int {
	if x.Signum() == 0 {
		return x
	}

	// twos complement
	x.v.Not(&x.v)
	x.v.Add(&x.v, &Uint{arr: [4]uint64{1, 0, 0, 0}})
	return x
}

func (x *Int) Dec() string {
	if x.Signum() < 0 {
		return "-" + x.Abs().Dec()
	}
	return x.Abs().Dec()
}

func (x *Int) Uint() *Uint {
	if x.Signum() < 0 {
		// panic("I256 Uint negative")
		return &x.Neg().v // r3v4_xxx: safe ??
	}
	return &x.v
}

func (z *Int) Or(x, y *Int) *Int {
	z.v.Or(&x.v, &y.v)
	return z
}

func (z *Int) NilToZero() *Int {
	if z == nil {
		z = NewInt(0)
	}

	return z
}

// Clone creates a new Int identical to z
func (z *Int) Clone() *Int {
	var x Int

	x.Sub(z, NewInt(0))
	return &x
}

// // Clone creates a new Int identical to z
// func (z *Uint) Clone() *Uint {
// 	var x Uint
// 	x.arr[0] = z.arr[0]
// 	x.arr[1] = z.arr[1]
// 	x.arr[2] = z.arr[2]
// 	x.arr[3] = z.arr[3]

// 	return &x
// }
