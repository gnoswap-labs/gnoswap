package factory

func requireUnsigned(x bigint, msg string) {
	if x < 0 {
		panic(msg)
	}
}
