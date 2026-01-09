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

func TestGetLeftGNSAmount(t *testing.T) {
	resetObject(t)

	leftGNSAmount = 12345
	uassert.Equal(t, int64(12345), GetLeftGNSAmount())
}

func TestGetDistributionStartTimestamp(t *testing.T) {
	resetObject(t)

	uassert.Equal(t, int64(0), GetDistributionStartTimestamp())

	distributionStartTimestamp = 1000
	uassert.Equal(t, int64(1000), GetDistributionStartTimestamp())
}

func TestGetLastExecutedTimestamp(t *testing.T) {
	resetObject(t)

	uassert.Equal(t, int64(0), GetLastExecutedTimestamp())

	lastExecutedTimestamp = 2000
	uassert.Equal(t, int64(2000), GetLastExecutedTimestamp())
}

func TestGetAllDistributionBpsPct(t *testing.T) {
	resetObject(t)

	all := GetAllDistributionBpsPct()
	uassert.Equal(t, int64(7500), all[LIQUIDITY_STAKER])
	uassert.Equal(t, int64(2000), all[DEVOPS])
	uassert.Equal(t, int64(500), all[COMMUNITY_POOL])
	uassert.Equal(t, int64(0), all[GOV_STAKER])

	all[LIQUIDITY_STAKER] = 9999
	uassert.Equal(t, int64(7500), distributionBpsPct[LIQUIDITY_STAKER])

	distributionBpsPct = nil
	empty := GetAllDistributionBpsPct()
	uassert.Equal(t, 0, len(empty))
}

func TestGetTotalAccuDistributed(t *testing.T) {
	resetObject(t)

	accuDistributedToStaker = 10
	accuDistributedToDevOps = 20
	accuDistributedToCommunityPool = 30
	accuDistributedToGovStaker = 40

	uassert.Equal(t, int64(100), GetTotalAccuDistributed())
}

func TestGetTotalDistributed(t *testing.T) {
	resetObject(t)

	distributedToStaker = 1
	distributedToDevOps = 2
	distributedToCommunityPool = 3
	distributedToGovStaker = 4

	uassert.Equal(t, int64(10), GetTotalDistributed())
}

func TestGetDistributionEndTimestamp(t *testing.T) {
	resetObject(t)

	uassert.Equal(t, int64(0), GetDistributionEndTimestamp())

	distributionStartTimestamp = 1000
	expected := int64(1000 + totalDistributionDuration - 1)
	uassert.Equal(t, expected, GetDistributionEndTimestamp())
}
