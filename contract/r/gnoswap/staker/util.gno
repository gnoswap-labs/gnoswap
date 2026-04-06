package staker

func safeConvertInt64ToUint64(value int64) uint64 {
	if value < 0 {
		panic("value must be non-negative")
	}

	return uint64(value)
}
