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

func (x *Int) Eq(y *Int) bool {
	return x.v.Eq(&y.v)
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