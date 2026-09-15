package common

import (
	"gno.land/r/gnoswap/common"
)

// init registers this package's CommonV1 implementation during realm initialization.
//
// Parameters:
//   - cur: realm context supplied by the runtime during package initialization.
func init(cur realm) {
	registerCommonV1(cur)
}

// registerCommonV1 registers a CommonV1 initializer with the shared common package.
//
// Parameters:
//   - cur: realm context propagated from package initialization and used to register
//     this package's initializer in the common registry.
func registerCommonV1(cur realm) {
	common.RegisterInitializer(cross(cur), func(_ int, rlm realm) common.ICommon {
		return NewCommonV1()
	})
}
