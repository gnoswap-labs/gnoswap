package v1

import (
	"gno.land/r/gnoswap/pool"
)

func init() {
	registerPoolV1()
}

func registerPoolV1() {
	pool.RegisterInitializer(cross, func(poolStore pool.IPoolStore) pool.IPool {
		return NewPoolV1(poolStore)
	})
}
