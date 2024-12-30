package staker

import (
	"testing"

	u256 "gno.land/p/gnoswap/uint256"
)

func TestRemoveInRangePosition(t *testing.T) {
	tests := []struct {
		name     string
		poolPath string
		tokenId  uint64
		setup    func() *InternalEmissionReward
		verify   func(*InternalEmissionReward)
	}{
		{
			name:     "Normal position removal",
			poolPath: "test/pool/path",
			tokenId:  1,
			setup: func() *InternalEmissionReward {
				r := NewInternalEmissionReward()
				recipientsMap := NewRewardRecipientMap()
				poolLiquidity := NewPoolLiquidity()

				// Initial liquidity setup
				inRangeLiquidity := NewInRangeLiquidity()
				inRangeLiquidity.SetLiquidity(u256.NewUint(1000))
				poolLiquidity.AddInRangePosition(1, inRangeLiquidity)

				recipientsMap.SetPoolLiquidity("test/pool/path", poolLiquidity)
				r.SetRewardRecipientsMap(recipientsMap)
				return r
			},
			verify: func(r *InternalEmissionReward) {
				recipientsMap := r.GetRewardRecipientsMap()
				poolLiquidity := recipientsMap.GetPoolLiquidity("test/pool/path")

				// Check if position is removed
				position := poolLiquidity.GetInRangeLiquidity(1)
				if !position.GetLiquidity().IsZero() {
					t.Errorf("Liquidity should be 0, but it is %s", position.GetLiquidity().ToString())
				}
				if !position.GetLiquidityRatio().IsZero() {
					t.Errorf("Liquidity ratio should be 0, but it is %s", position.GetLiquidityRatio().ToString())
				}
				if position.GetStakedHeight() != 0 {
					t.Errorf("Staking height should be 0, but it is %d", position.GetStakedHeight())
				}
			},
		},
		{
			name:     "Non-existent pool path",
			poolPath: "non/existent/path",
			tokenId:  1,
			setup: func() *InternalEmissionReward {
				return NewInternalEmissionReward()
			},
			verify: func(r *InternalEmissionReward) {
				// No Error
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			r := tt.setup()
			r.RemoveInRangePosition(tt.poolPath, tt.tokenId)
			tt.verify(r)
		})
	}
}

func TestSelectRewardPools(t *testing.T) {
	tests := []struct {
		name   string
		pools  map[string]InternalTier
		setup  func() *InternalEmissionReward
		verify func(*InternalEmissionReward)
	}{
		{
			name: "Normal pool selection",
			pools: map[string]InternalTier{
				"pool/1": {tier: TIER1_INDEX},
				"pool/2": {tier: TIER2_INDEX},
				"pool/3": {tier: TIER3_INDEX},
				"pool/4": {tier: 4}, // Invalid tier
			},
			setup: func() *InternalEmissionReward {
				return NewInternalEmissionReward()
			},
			verify: func(r *InternalEmissionReward) {
				rewardPool := r.GetRewardPoolsMap()

				// TIER1 pool verification
				pool1 := rewardPool.GetRewardPoolByPoolPath("pool/1")
				if pool1.GetTier() != TIER1_INDEX {
					t.Errorf("pool/1 should be TIER1, but got %d", pool1.GetTier())
				}

				// TIER2 pool verification
				pool2 := rewardPool.GetRewardPoolByPoolPath("pool/2")
				if pool2.GetTier() != TIER2_INDEX {
					t.Errorf("pool/2 should be TIER2, but got %d", pool2.GetTier())
				}

				// TIER3 pool verification
				pool3 := rewardPool.GetRewardPoolByPoolPath("pool/3")
				if pool3.GetTier() != TIER3_INDEX {
					t.Errorf("pool/3 should be TIER3, but got %d", pool3.GetTier())
				}

				// Invalid tier pool verification
				pool4 := rewardPool.GetRewardPoolByPoolPath("pool/4")
				if pool4.GetTier() != 0 {
					t.Errorf("pool/4 should not be selected, but got tier %d", pool4.GetTier())
				}
			},
		},
		{
			name:  "Empty pool map",
			pools: map[string]InternalTier{},
			setup: func() *InternalEmissionReward {
				return NewInternalEmissionReward()
			},
			verify: func(r *InternalEmissionReward) {
				rewardPool := r.GetRewardPoolsMap()
				if len(rewardPool.GetRewardPools()) != 0 {
					t.Errorf("reward pools should be empty, but got %d pools", len(rewardPool.GetRewardPools()))
				}
			},
		},
		{
			name: "Invalid tier only",
			pools: map[string]InternalTier{
				"pool/1": {tier: 4},
				"pool/2": {tier: 5},
			},
			setup: func() *InternalEmissionReward {
				return NewInternalEmissionReward()
			},
			verify: func(r *InternalEmissionReward) {
				rewardPool := r.GetRewardPoolsMap()
				if len(rewardPool.GetRewardPools()) != 0 {
					t.Errorf("no pools should be selected, but got %d pools", len(rewardPool.GetRewardPools()))
				}
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			r := tt.setup()
			r.SelectRewardPools(tt.pools)
			tt.verify(r)
		})
	}
}
