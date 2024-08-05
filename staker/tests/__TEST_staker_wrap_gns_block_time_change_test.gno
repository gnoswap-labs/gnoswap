package staker

import (
	"testing"

	"gno.land/r/gnoswap/consts"
)

func TestGnsSetAvgBlockTimeInMsr(t *testing.T) {
	std.TestSetOrigCaller(consts.GNOSWAP_ADMIN)
	GnsSetAvgBlockTimeInMs(2500)
}
