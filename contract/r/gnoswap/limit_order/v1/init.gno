package v1

import (
	lo "gno.land/r/gnoswap/limit_order"
)

func init(cur realm) {
	impl := NewLimitOrderV1(lo.GetStore(cross(cur)), lo.GetContractAddress())
	lo.RegisterImplementation(cross(cur), impl)
}
