package staker

import (
	"std"
	"testing"
	"time"

	pusers "gno.land/p/demo/users"
	"gno.land/r/demo/users"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"

	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/r/gnoswap/v1/consts"

	pl "gno.land/r/gnoswap/v1/pool"
	pn "gno.land/r/gnoswap/v1/position"
)

func TestRequireTokenOwnership(t *testing.T) {
	owner := testutils.TestAddress("owner")
	caller := testutils.TestAddress("caller")

	tests := []struct {
		name   string
		owner  std.Address
		caller std.Address
		want   error
	}{
		{
			name:   "success - caller is owner",
			owner:  owner,
			caller: owner,
			want:   nil,
		},
		{
			name:   "success - staker is owner",
			owner:  consts.STAKER_ADDR,
			caller: caller,
			want:   nil,
		},
		{
			name:   "failure - no permission",
			owner:  owner,
			caller: caller,
			want:   errNoPermission,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := requireTokenOwnership(tt.owner, tt.caller)
			if tt.want == nil {
				uassert.NoError(t, got)
			}
			if got != tt.want {
				t.Errorf("expected error %v, got %v", tt.want, got)
			}
		})
	}
}

// func TestPoolHasIncentives(t *testing.T) {
// 	poolPath := "gno.land/r/demo/token1:gno.land/r/demo/token2:3000"

// 	tests := []struct {
// 		name      string
// 		setup     func()
// 		wantError bool
// 	}{
// 		{
// 			name: "success - has internal incentive",
// 			setup: func() {
// 				poolTiers.Set(poolPath, newInternalTier(1, time.Now().Unix()))
// 			},
// 			wantError: false,
// 		},
// 		{
// 			name: "success - has external incentive",
// 			setup: func() {
// 				poolIncentives.Set(poolPath, []string{"incentive1"})
// 			},
// 			wantError: false,
// 		},
// 		{
// 			name: "failure - no incentives",
// 			setup: func() {
// 				poolTiers = newPoolTiers()
// 				poolIncentives = newPoolIncentives()
// 			},
// 			wantError: true,
// 		},
// 	}

// 	for _, tt := range tests {
// 		t.Run(tt.name, func(t *testing.T) {
// 			poolTiers = newPoolTiers()
// 			poolIncentives = newPoolIncentives()

// 			tt.setup()

// 			got := poolHasIncentives(poolPath)
// 			if tt.wantError {
// 				uassert.Error(t, got)
// 			}
// 		})
// 	}
// }

// func TestApplyExternalReward(t *testing.T) {
// 	tokenId := uint64(1)
// 	owner := testutils.TestAddress("owner")
// 	ictvId := "incentive1"
// 	tokenPath := barPath
// 	poolPath := "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:3000"

// 	mockToken := struct {
// 		GRC20Interface
// 	}{
// 		GRC20Interface: BarToken{},
// 	}

// 	tests := []struct {
// 		name   string
// 		setup  func()
// 		reward externalRewardInfo
// 		want   struct {
// 			toUser            uint64
// 			remaining         uint64
// 			tokenAmountX96    *u256.Uint
// 			tokenAmountFull   uint64
// 			tokenAmountToGive uint64
// 		}
// 	}{
// 		{
// 			name: "no incentive",
// 			setup: func() {
// 				incentives = newIncentives()
// 			},
// 			reward: externalRewardInfo{
// 				ictvId:     "non_existing_incentive",
// 				tokenPath:  tokenPath,
// 				fullAmount: 100,
// 				toGive:     60,
// 			},
// 			want: struct {
// 				toUser            uint64
// 				remaining         uint64
// 				tokenAmountX96    *u256.Uint
// 				tokenAmountFull   uint64
// 				tokenAmountToGive uint64
// 			}{
// 				toUser:            0,
// 				remaining:         0,
// 				tokenAmountX96:    nil,
// 				tokenAmountFull:   0,
// 				tokenAmountToGive: 0,
// 			},
// 		},
// 	}

// 	for _, tt := range tests {
// 		t.Run(tt.name, func(t *testing.T) {
// 			std.TestSetOrigCaller(users.Resolve(admin))
// 			tt.setup()

// 			result := applyExternalReward(tokenId, tt.reward, owner, false)
// 			uassert.Equal(t, result.toUser, tt.want.toUser)
// 			uassert.Equal(t, result.left, tt.want.remaining)

// 			external := positionExternal[tokenId][tt.reward.ictvId]
// 			uassert.Equal(t, external.tokenAmountX96.ToString(), tt.want.tokenAmountX96.ToString())
// 			uassert.Equal(t, external.tokenAmountFull, tt.want.tokenAmountFull)

// 			uassert.Equal(t, external.tokenAmountToGive, tt.want.tokenAmountToGive)

// 			warmUp := positionsExternalWarmUpAmount[tokenId][tt.reward.ictvId]
// 			uassert.Equal(t, warmUp.totalFull(), uint64(0))
// 			uassert.Equal(t, warmUp.totalGive(), uint64(0))
// 		})
// 	}
// }

// TODO: rewrite this test
// func Test_applyUnstake(t *testing.T) {
// 	var notExistTokenId uint64 = 999

// 	tests := []struct {
// 		name   string
// 		setup  func() (*RewardManager, unstakeInput)
// 		verify func(*RewardManager) bool
// 	}{
// 		{
// 			name: "Normal unstaking test",
// 			setup: func() (*RewardManager, unstakeInput) {
// 				rm := NewRewardManager()
// 				internalReward := NewInternalEmissionReward()
// 				recipientsMap := NewRewardRecipientMap()
// 				poolLiquidity := NewPoolLiquidity()

// 				inRangeLiquidity := NewInRangeLiquidity()
// 				inRangeLiquidity.SetLiquidity(u256.NewUint(1000))
// 				inRangeLiquidity.SetLiquidityRatio(u256.NewUint(100))
// 				inRangeLiquidity.SetStakedHeight(100)

// 				poolLiquidity.AddInRangePosition(1, inRangeLiquidity)
// 				recipientsMap.SetPoolLiquidity("test/pool", poolLiquidity)
// 				internalReward.SetRewardRecipientsMap(recipientsMap)
// 				rm.SetInternalEmissionReward(internalReward)

// 				input := unstakeInput{
// 					tokenId: 1,
// 					deposit: Deposit{
// 						targetPoolPath: "test/pool",
// 						stakeHeight:    100,
// 					},
// 				}

// 				return rm, input
// 			},
// 			verify: func(rm *RewardManager) bool {
// 				internalReward := rm.GetInternalEmissionReward()
// 				if internalReward == nil {
// 					return false
// 				}

// 				recipientsMap := internalReward.GetRewardRecipientsMap()
// 				if recipientsMap == nil {
// 					return false
// 				}

// 				poolLiquidity := recipientsMap.GetPoolLiquidity("test/pool")
// 				if poolLiquidity == nil {
// 					return false
// 				}

// 				position := poolLiquidity.GetInRangeLiquidity(1)
// 				if position == nil {
// 					return false
// 				}

// 				if !position.GetLiquidity().IsZero() {
// 					return false
// 				}
// 				if !position.GetLiquidityRatio().IsZero() {
// 					return false
// 				}
// 				if position.GetStakedHeight() != 0 {
// 					return false
// 				}

// 				return true
// 			},
// 		},
// 		{
// 			name: "Non-existent pool unstaking test",
// 			setup: func() (*RewardManager, unstakeInput) {
// 				rm := NewRewardManager()
// 				input := unstakeInput{
// 					tokenId: 1,
// 					deposit: Deposit{
// 						targetPoolPath: "non/existent/pool",
// 						stakeHeight:    100,
// 					},
// 				}
// 				return rm, input
// 			},
// 			verify: func(rm *RewardManager) bool {
// 				return rm.GetInternalEmissionReward() != nil
// 			},
// 		},
// 		{
// 			name: "Non-existent token ID unstaking test",
// 			setup: func() (*RewardManager, unstakeInput) {
// 				rm := NewRewardManager()
// 				internalReward := NewInternalEmissionReward()
// 				recipientsMap := NewRewardRecipientMap()
// 				poolLiquidity := NewPoolLiquidity()
// 				recipientsMap.SetPoolLiquidity("test/pool", poolLiquidity)
// 				internalReward.SetRewardRecipientsMap(recipientsMap)
// 				rm.SetInternalEmissionReward(internalReward)

// 				input := unstakeInput{
// 					tokenId: notExistTokenId,
// 					deposit: Deposit{
// 						targetPoolPath: "test/pool",
// 						stakeHeight:    100,
// 					},
// 				}
// 				return rm, input
// 			},
// 			verify: func(rm *RewardManager) bool {
// 				return rm.GetInternalEmissionReward() != nil
// 			},
// 		},
// 	}

// 	for _, tt := range tests {
// 		t.Run(tt.name, func(t *testing.T) {
// 			rm, input := tt.setup()

// 			resultRM := applyUnstake(rm, input)

// 			if !tt.verify(resultRM) {
// 				t.Errorf("%s: verification failed", tt.name)
// 			}
// 		})
// 	}
// }
