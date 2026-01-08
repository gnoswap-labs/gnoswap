package emission

import (
	"testing"

	"gno.land/p/nt/uassert"
)

func TestGetDistributableAmount(t *testing.T) {
	resetObject(t)

	distributionStartTimestamp = 1000

	distributed, left := GetDistributableAmount(10000, 1000)

	uassert.Equal(t, int64(0), left)
	uassert.Equal(t, int64(7500), distributed[LIQUIDITY_STAKER])
	uassert.Equal(t, int64(2000), distributed[DEVOPS])
	uassert.Equal(t, int64(500), distributed[COMMUNITY_POOL])
	uassert.Equal(t, int64(0), distributed[GOV_STAKER])
}

func TestGetDistributableAmount_WithRemainder(t *testing.T) {
	resetObject(t)

	distributionStartTimestamp = 1000

	distributed, left := GetDistributableAmount(10001, 1000)

	uassert.Equal(t, int64(1), left)
	uassert.Equal(t, int64(7500), distributed[LIQUIDITY_STAKER])
	uassert.Equal(t, int64(2000), distributed[DEVOPS])
	uassert.Equal(t, int64(500), distributed[COMMUNITY_POOL])
	uassert.Equal(t, int64(0), distributed[GOV_STAKER])
}

func TestGetDistributableAmount_OutsideWindow(t *testing.T) {
	resetObject(t)

	distributionStartTimestamp = 1000
	endTimestamp := GetDistributionEndTimestamp()

	distributedBefore, leftBefore := GetDistributableAmount(10000, 999)
	uassert.Equal(t, int64(10000), leftBefore)
	uassert.Equal(t, 0, len(distributedBefore))

	distributedAfter, leftAfter := GetDistributableAmount(10000, endTimestamp+1)
	uassert.Equal(t, int64(10000), leftAfter)
	uassert.Equal(t, 0, len(distributedAfter))
}
