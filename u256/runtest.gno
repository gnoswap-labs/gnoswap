package u256

func Hello() uint64 {
	x := NewInt(1)
	y := NewInt(2)
	return x.Add(x, y).Uint64()
}
