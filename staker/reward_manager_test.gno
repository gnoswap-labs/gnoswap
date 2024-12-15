package staker

import (
	"testing"

	u256 "gno.land/p/gnoswap/uint256"
)

func TestRewardManager_Internal(t *testing.T) {
	tests := []struct {
		name     string
		setup    func() *RewardManager
		testFunc func(*RewardManager)
		verify   func(*RewardManager) bool
		wantErr  bool
	}{
		{
			name: "create new RewardManager instance",
			setup: func() *RewardManager {
				return NewRewardManager()
			},
			verify: func(rm *RewardManager) bool {
				return rm.internalReward != nil && rm.externalReward != nil
			},
		},
		{
			name: "set and get InternalEmissionReward",
			setup: func() *RewardManager {
				return NewRewardManager()
			},
			testFunc: func(rm *RewardManager) {
				newInternalReward := NewInternalEmissionReward()
				recipientsMap := NewRewardRecipientMap()
				poolLiquidity := NewPoolLiquidity()
				inRangeLiquidity := NewInRangeLiquidity()
				inRangeLiquidity.SetLiquidity(u256.NewUint(1000))
				poolLiquidity.AddInRangePosition(1, inRangeLiquidity)
				recipientsMap.SetPoolLiquidity("test/pool", poolLiquidity)
				newInternalReward.SetRewardRecipientsMap(recipientsMap)

				rm.SetInternalEmissionReward(newInternalReward)
			},
			verify: func(rm *RewardManager) bool {
				internalReward := rm.GetInternalEmissionReward()
				if internalReward == nil {
					return false
				}

				recipientsMap := internalReward.GetRewardRecipientsMap()
				if recipientsMap == nil {
					return false
				}

				poolLiquidity := recipientsMap.GetPoolLiquidity("test/pool")
				if poolLiquidity == nil {
					return false
				}

				position := poolLiquidity.GetInRangeLiquidity(1)
				if position == nil {
					return false
				}

				return position.GetLiquidity().Eq(u256.NewUint(1000))
			},
		},
		{
			name: "set nil InternalEmissionReward",
			setup: func() *RewardManager {
				return NewRewardManager()
			},
			testFunc: func(rm *RewardManager) {
				rm.SetInternalEmissionReward(nil)
			},
			verify: func(rm *RewardManager) bool {
				return rm.GetInternalEmissionReward() == nil
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			rm := tt.setup()

			if tt.testFunc != nil {
				tt.testFunc(rm)
			}

			if result := tt.verify(rm); !result {
				t.Errorf("%s: verification failed", tt.name)
			}
		})
	}
}

func TestRewardManager_External(t *testing.T) {
	tests := []struct {
		name     string
		setup    func() *RewardManager
		testFunc func(*RewardManager)
		verify   func(*RewardManager) bool
		wantErr  bool
	}{
		{
			name: "create new RewardManager instance for external reward",
			setup: func() *RewardManager {
				return NewRewardManager()
			},
			verify: func(rm *RewardManager) bool {
				return rm.externalReward != nil
			},
		},
		{
			name: "set and get ExternalIncentiveReward",
			setup: func() *RewardManager {
				return NewRewardManager()
			},
			testFunc: func(rm *RewardManager) {
				newExternalReward := NewExternalIncentiveReward()
				externalCalculator := NewExternalCalculator(100)
				newExternalReward.SetExternalCalculator(externalCalculator)

				rm.SetExternalIncentiveReward(newExternalReward)
			},
			verify: func(rm *RewardManager) bool {
				externalReward := rm.GetExternalIncentiveReward()
				if externalReward == nil {
					return false
				}

				calculator := externalReward.GetExternalCalculator()
				if calculator == nil {
					return false
				}

				return true
			},
		},
		{
			name: "set nil ExternalIncentiveReward",
			setup: func() *RewardManager {
				return NewRewardManager()
			},
			testFunc: func(rm *RewardManager) {
				rm.SetExternalIncentiveReward(nil)
			},
			verify: func(rm *RewardManager) bool {
				return rm.GetExternalIncentiveReward() == nil
			},
		},
		{
			name: "get or create ExternalCalculator",
			setup: func() *RewardManager {
				rm := NewRewardManager()
				newExternalReward := NewExternalIncentiveReward()
				rm.SetExternalIncentiveReward(newExternalReward)
				return rm
			},
			testFunc: func(rm *RewardManager) {
				externalReward := rm.GetExternalIncentiveReward()
				calculator := externalReward.GetOrCreateExternalCalculator(200) // 높이 200으로 설정
				if calculator == nil {
					t.Error("calculator should not be nil")
				}
			},
			verify: func(rm *RewardManager) bool {
				externalReward := rm.GetExternalIncentiveReward()
				if externalReward == nil {
					return false
				}

				calculator := externalReward.GetExternalCalculator()
				return calculator != nil
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			rm := tt.setup()

			if tt.testFunc != nil {
				tt.testFunc(rm)
			}

			if result := tt.verify(rm); !result {
				t.Errorf("%s: verification failed", tt.name)
			}
		})
	}
}
