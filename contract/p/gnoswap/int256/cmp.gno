package int256

// Eq returns true if z equals x.
// Panics if either z or x is nil.
func (z *Int) Eq(x *Int) bool {
	if z == nil || x == nil {
		panic("int256: comparing with nil")
	}
	return (z.neg == x.neg) && z.abs.Eq(x.abs)
}

// Neq returns true if z does not equal x.
// Panics if either z or x is nil.
func (z *Int) Neq(x *Int) bool {
	if z == nil || x == nil {
		panic("int256: comparing with nil")
	}
	return !z.Eq(x)
}

// Cmp compares z and x and returns -1 if z < x, 0 if z == x, or +1 if z > x.
// Panics if either z or x is nil.
func (z *Int) Cmp(x *Int) (r int) {
	if z == nil || x == nil {
		panic("int256: comparing with nil")
	}
	// x cmp y == x cmp y
	// x cmp (-y) == x
	// (-x) cmp y == y
	// (-x) cmp (-y) == -(x cmp y)
	switch {
	case z == x:
		// nothing to do
	case z.neg == x.neg:
		r = z.abs.Cmp(x.abs)
		if z.neg {
			r = -r
		}
	case z.neg:
		r = -1
	default:
		r = 1
	}
	return
}

// IsZero returns true if z equals 0.
func (z *Int) IsZero() bool {
	return z.abs.IsZero()
}

// IsNeg returns true if z is negative.
func (z *Int) IsNeg() bool {
	return z.neg
}

// Lt returns true if z is less than x.
// Panics if either z or x is nil.
func (z *Int) Lt(x *Int) bool {
	if z == nil || x == nil {
		panic("int256: comparing with nil")
	}
	if z.neg {
		if x.neg {
			return z.abs.Gt(x.abs)
		} else {
			return true
		}
	} else {
		if x.neg {
			return false
		} else {
			return z.abs.Lt(x.abs)
		}
	}
}

// Lte returns true if z is less than or equal to x.
func (z *Int) Lte(x *Int) bool {
	return z.Lt(x) || z.Eq(x)
}

// Gt returns true if z is greater than x.
// Panics if either z or x is nil.
func (z *Int) Gt(x *Int) bool {
	if z == nil || x == nil {
		panic("int256: comparing with nil")
	}
	if z.neg {
		if x.neg {
			return z.abs.Lt(x.abs)
		} else {
			return false
		}
	} else {
		if x.neg {
			return true
		} else {
			return z.abs.Gt(x.abs)
		}
	}
}

// Gte returns true if z is greater than or equal to x.
func (z *Int) Gte(x *Int) bool {
	return z.Gt(x) || z.Eq(x)
}

// Clone creates a new Int identical to z.
func (z *Int) Clone() *Int {
	return &Int{z.abs.Clone(), z.neg}
}

// IsOverflow returns true if z's absolute value has overflowed.
func (z *Int) IsOverflow() bool {
	return z.abs.IsOverflow()
}
