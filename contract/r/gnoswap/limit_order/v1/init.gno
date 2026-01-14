package v1

import (
	lo "gno.land/r/gnoswap/limit_order"
)

func init() {
	impl := NewLimitOrderV1(lo.GetStore(), lo.GetContractAddress())
	lo.RegisterImplementation(cross, impl)
}
