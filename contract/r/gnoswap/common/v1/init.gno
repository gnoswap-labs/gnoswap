package common

import (
	"gno.land/r/gnoswap/common"
)

func init(cur realm) {
	registerCommonV1(cur)
}

func registerCommonV1(cur realm) {
	common.RegisterInitializer(cross(cur), func(_ int, rlm realm) common.ICommon {
		return NewCommonV1()
	})
}
