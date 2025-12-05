package v1

import (
	"chain/runtime"
	"testing"
	"time"

	"gno.land/p/nt/uassert"
	"gno.land/p/onbloc/json"

	sr "gno.land/r/gnoswap/staker"
)

func newTestStakerV1(t *testing.T) *stakerV1 {
	t.Helper()

	return &stakerV1{
		store:            newMockStakerStore(),
		poolAccessor:     newMockPoolAccessor(),
		emissionAccessor: newMockEmissionAccessor(),
		nftAccessor:      newMockNFTAccessor(),
	}
}

func TestApiGetRewardTokensByPoolPath_NoPool(t *testing.T) {
	staker := newTestStakerV1(t)

	result := staker.ApiGetRewardTokensByPoolPath("non-existent")

	uassert.Equal(t, "", result)
}

func TestApiGetRewardTokensByPoolPath_WithInternalAndExternal(t *testing.T) {
	staker := newTestStakerV1(t)
	poolPath := "gno.land/r/mock/pool"
	externalToken := "gno.land/r/mock/reward"
	now := time.Now().Unix()

	pools := staker.getPools()
	pool := sr.NewPool(poolPath, now)

	incentive := sr.NewExternalIncentive(
		"1",
		poolPath,
		externalToken,
		1000,
		now-10,
		now+1000,
		"",
		0,
		runtime.ChainHeight(),
		now,
		false,
	)
	pool.Incentives().SetIncentive(incentive.IncentiveId(), incentive)

	pools.set(poolPath, pool)
	staker.updatePools(pools)

	poolTier := staker.getPoolTier()
	poolTier.membership.Set(poolPath, uint64(1))
	poolTier.counts[1] = 1
	poolTier.tierRatio = sr.TierRatio{Tier1: 100}
	staker.updatePoolTier(poolTier)

	resp := staker.ApiGetRewardTokensByPoolPath(poolPath)
	root := json.Must(json.Unmarshal([]byte(resp)))

	responseNode, err := root.GetKey("response")
	uassert.Nil(t, err)

	items := responseNode.MustArray()
	uassert.Equal(t, 1, len(items))

	tokenNode, err := items[0].GetKey("tokens")
	uassert.Nil(t, err)

	tokens := tokenNode.MustArray()
	uassert.Equal(t, 2, len(tokens))

	tokenSet := map[string]bool{}
	for _, token := range tokens {
		tokenSet[token.MustString()] = true
	}

	uassert.True(t, tokenSet[GNS_PATH])
	uassert.True(t, tokenSet[externalToken])
}
