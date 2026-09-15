package staker

import (
	"chain/runtime"
	"errors"
	"time"

	rotree "gno.land/p/nt/bptree/rotree/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	u256 "gno.land/p/gnoswap/uint256/v1"

	sr "gno.land/r/gnoswap/staker"
)

// findPoolByPoolPath retrieves the pool by its path, or nil when it does not
// exist. Read-only views use it so a missing pool reads as nil rather than
// aborting the caller's transaction.
func (s *stakerV1) findPoolByPoolPath(poolPath string) *sr.Pool {
	result := s.store.GetPools().Get(poolPath)
	if result == nil {
		return nil
	}

	pool, ok := result.(*sr.Pool)
	if !ok {
		return nil
	}

	return pool
}

// getPoolByPoolPath retrieves the pool by its path.
func (s *stakerV1) getPoolByPoolPath(poolPath string) (*sr.Pool, error) {
	result := s.store.GetPools().Get(poolPath)
	if result == nil {
		return nil, makeErrorWithDetails(
			errDataNotFound,
			ufmt.Sprintf("poolPath(%s) pool does not exist", poolPath),
		)
	}

	pool, ok := result.(*sr.Pool)
	if !ok {
		return nil, makeErrorWithDetails(
			errDataNotFound,
			ufmt.Sprintf("poolPath(%s) pool does not exist", poolPath),
		)
	}

	return pool, nil
}

// GetPool returns the pool for the given path.
//
// Parameters:
//   - poolPath: Pool path whose pool entry is queried.
//
// Returns:
//   - *sr.Pool: Pool registered at poolPath, or nil when the lookup fails.
//   - error: Non-nil when poolPath has no valid pool entry; nil on success.
func (s *stakerV1) GetPool(poolPath string) (*sr.Pool, error) {
	pool, err := s.getPoolByPoolPath(poolPath)
	if err != nil {
		return nil, err
	}
	return pool, nil
}

// getIncentive retrieves an external incentive by ID.
func (s *stakerV1) getIncentive(poolPath string, incentiveId string) (*sr.ExternalIncentive, error) {
	pool, err := s.getPoolByPoolPath(poolPath)
	if err != nil {
		return nil, err
	}

	incentives := pool.Incentives()
	incentive := incentives.IncentiveTrees().Get(incentiveId)
	if incentive == nil {
		return nil, ufmt.Errorf("incentiveId(%s) incentive does not exist", incentiveId)
	}

	ictv, ok := incentive.(*sr.ExternalIncentive)
	if !ok {
		return nil, ufmt.Errorf("failed to cast incentive to *ExternalIncentive: %T", incentive)
	}
	return ictv, nil
}

// GetIncentiveStartTimestamp returns the start timestamp of an incentive.
//
// Parameters:
//   - poolPath: Pool path containing the incentive.
//   - incentiveId: External incentive identifier whose start time is queried.
//
// Returns:
//   - int64: Incentive start timestamp in Unix seconds.
//   - error: Non-nil when poolPath or incentiveId cannot be resolved; nil on success.
func (s *stakerV1) GetIncentiveStartTimestamp(poolPath string, incentiveId string) (int64, error) {
	incentive, err := s.getIncentive(poolPath, incentiveId)
	if err != nil {
		return 0, err
	}

	return incentive.StartTimestamp(), nil
}

// GetIncentiveEndTimestamp returns the end timestamp of an incentive.
//
// Parameters:
//   - poolPath: Pool path containing the incentive.
//   - incentiveId: External incentive identifier whose end time is queried.
//
// Returns:
//   - int64: Incentive end timestamp in Unix seconds.
//   - error: Non-nil when poolPath or incentiveId cannot be resolved; nil on success.
func (s *stakerV1) GetIncentiveEndTimestamp(poolPath string, incentiveId string) (int64, error) {
	incentive, err := s.getIncentive(poolPath, incentiveId)
	if err != nil {
		return 0, err
	}

	return incentive.EndTimestamp(), nil
}

// GetTargetPoolPathByIncentiveId returns the target pool path of an incentive.
//
// Parameters:
//   - poolPath: Pool path containing the incentive.
//   - incentiveId: External incentive identifier whose target pool is queried.
//
// Returns:
//   - string: Pool path targeted by the incentive.
//   - error: Non-nil when poolPath or incentiveId cannot be resolved; nil on success.
func (s *stakerV1) GetTargetPoolPathByIncentiveId(poolPath string, incentiveId string) (string, error) {
	incentive, err := s.getIncentive(poolPath, incentiveId)
	if err != nil {
		return "", err
	}

	return incentive.TargetPoolPath(), nil
}

// GetCreatedHeightOfIncentive returns the creation height of an incentive.
//
// Parameters:
//   - poolPath: Pool path containing the incentive.
//   - incentiveId: External incentive identifier whose creation height is queried.
//
// Returns:
//   - int64: Chain height at which the incentive was created.
//   - error: Non-nil when poolPath or incentiveId cannot be resolved; nil on success.
func (s *stakerV1) GetCreatedHeightOfIncentive(poolPath string, incentiveId string) (int64, error) {
	incentive, err := s.getIncentive(poolPath, incentiveId)
	if err != nil {
		return 0, err
	}

	return incentive.CreatedHeight(), nil
}

// GetIncentiveCreatedTimestamp returns the creation timestamp of an incentive.
//
// Parameters:
//   - poolPath: Pool path containing the incentive.
//   - incentiveId: External incentive identifier whose creation time is queried.
//
// Returns:
//   - int64: Incentive creation timestamp in Unix seconds.
//   - error: Non-nil when poolPath or incentiveId cannot be resolved; nil on success.
func (s *stakerV1) GetIncentiveCreatedTimestamp(poolPath string, incentiveId string) (int64, error) {
	incentive, err := s.getIncentive(poolPath, incentiveId)
	if err != nil {
		return 0, err
	}

	return incentive.CreatedTimestamp(), nil
}

// GetIncentiveTotalRewardAmount returns the total reward amount of an incentive.
//
// Parameters:
//   - poolPath: Pool path containing the incentive.
//   - incentiveId: External incentive identifier whose configured reward is queried.
//
// Returns:
//   - int64: Total reward amount configured for the incentive, in reward-token units.
//   - error: Non-nil when poolPath or incentiveId cannot be resolved; nil on success.
func (s *stakerV1) GetIncentiveTotalRewardAmount(poolPath string, incentiveId string) (int64, error) {
	incentive, err := s.getIncentive(poolPath, incentiveId)
	if err != nil {
		return 0, err
	}

	return incentive.TotalRewardAmount(), nil
}

// GetIncentiveDistributedRewardAmount returns the distributed reward amount of an incentive.
//
// Parameters:
//   - poolPath: Pool path containing the incentive.
//   - incentiveId: External incentive identifier whose distribution total is queried.
//
// Returns:
//   - int64: Reward amount already distributed by the incentive, in reward-token units.
//   - error: Non-nil when poolPath or incentiveId cannot be resolved; nil on success.
func (s *stakerV1) GetIncentiveDistributedRewardAmount(poolPath string, incentiveId string) (int64, error) {
	incentive, err := s.getIncentive(poolPath, incentiveId)
	if err != nil {
		return 0, err
	}

	return incentive.DistributedRewardAmount(), nil
}

// GetIncentiveRemainingRewardAmount returns the remaining reward amount of an incentive.
//
// Parameters:
//   - poolPath: Pool path containing the incentive.
//   - incentiveId: External incentive identifier whose remaining balance is queried.
//
// Returns:
//   - int64: Reward amount still available for collection, in reward-token units.
//   - error: Non-nil when poolPath or incentiveId cannot be resolved; nil on success.
func (s *stakerV1) GetIncentiveRemainingRewardAmount(poolPath string, incentiveId string) (int64, error) {
	incentive, err := s.getIncentive(poolPath, incentiveId)
	if err != nil {
		return 0, err
	}

	return incentive.RewardAmount(), nil
}

// GetIncentiveAccumulatedPenaltyAmount returns the accumulated warmup penalty amount of an incentive.
//
// Parameters:
//   - poolPath: Pool path containing the incentive.
//   - incentiveId: External incentive identifier whose penalties are queried.
//
// Returns:
//   - int64: Warm-up penalty accumulated for the incentive, in reward-token units.
//   - error: Non-nil when poolPath or incentiveId cannot be resolved; nil on success.
func (s *stakerV1) GetIncentiveAccumulatedPenaltyAmount(poolPath string, incentiveId string) (int64, error) {
	incentive, err := s.getIncentive(poolPath, incentiveId)
	if err != nil {
		return 0, err
	}

	return incentive.AccumulatedPenaltyAmount(), nil
}

// GetIncentiveDepositGnsAmount returns the deposit GNS amount of an incentive.
//
// Parameters:
//   - poolPath: Pool path containing the incentive.
//   - incentiveId: External incentive identifier whose GNS deposit is queried.
//
// Returns:
//   - int64: GNS amount deposited when the incentive was created.
//   - error: Non-nil when poolPath or incentiveId cannot be resolved; nil on success.
func (s *stakerV1) GetIncentiveDepositGnsAmount(poolPath string, incentiveId string) (int64, error) {
	incentive, err := s.getIncentive(poolPath, incentiveId)
	if err != nil {
		return 0, err
	}

	return incentive.DepositGnsAmount(), nil
}

// GetIncentiveRefunded returns whether an incentive has been refunded.
//
// Parameters:
//   - poolPath: Pool path containing the incentive.
//   - incentiveId: External incentive identifier whose refund state is queried.
//
// Returns:
//   - bool: true when the incentive has been finalized/refunded; false while it remains unrefunded.
//   - error: Non-nil when poolPath or incentiveId cannot be resolved; nil on success.
func (s *stakerV1) GetIncentiveRefunded(poolPath string, incentiveId string) (bool, error) {
	incentive, err := s.getIncentive(poolPath, incentiveId)
	if err != nil {
		return false, err
	}

	return incentive.Refunded(), nil
}

// IsIncentiveActive reports whether an unrefunded incentive is active, including both start and end timestamps.
//
// Parameters:
//   - poolPath: Pool path containing the incentive.
//   - incentiveId: External incentive identifier whose activity is queried.
//
// Returns:
//   - bool: true when the current Unix time is within the incentive's start/end window and it is unrefunded; false otherwise.
//   - error: Non-nil when poolPath or incentiveId cannot be resolved; nil on success.
func (s *stakerV1) IsIncentiveActive(poolPath string, incentiveId string) (bool, error) {
	incentive, err := s.getIncentive(poolPath, incentiveId)
	if err != nil {
		return false, err
	}
	currentTime := time.Now().Unix()

	resolver := NewExternalIncentiveResolver(incentive)
	return resolver.isActive(currentTime) && !resolver.Refunded(), nil
}

// GetIncentiveRewardToken returns the reward token of an incentive.
//
// Parameters:
//   - poolPath: Pool path containing the incentive.
//   - incentiveId: External incentive identifier whose reward token is queried.
//
// Returns:
//   - string: Reward-token package path configured for the incentive.
//   - error: Non-nil when poolPath or incentiveId cannot be resolved; nil on success.
func (s *stakerV1) GetIncentiveRewardToken(poolPath string, incentiveId string) (string, error) {
	incentive, err := s.getIncentive(poolPath, incentiveId)
	if err != nil {
		return "", err
	}

	return incentive.RewardToken(), nil
}

// GetIncentiveRewardAmount returns the remaining reward amount of an incentive.
//
// Parameters:
//   - poolPath: Pool path containing the incentive.
//   - incentiveId: External incentive identifier whose remaining reward is queried.
//
// Returns:
//   - *u256.Uint: Remaining reward amount as a uint256 value, or nil when lookup fails.
//   - error: Non-nil when poolPath or incentiveId cannot be resolved; nil on success.
func (s *stakerV1) GetIncentiveRewardAmount(poolPath string, incentiveId string) (*u256.Uint, error) {
	incentive, err := s.getIncentive(poolPath, incentiveId)
	if err != nil {
		return nil, err
	}

	return u256.NewUintFromInt64(incentive.RewardAmount()), nil
}

// GetIncentiveRewardAmountAsString returns the remaining reward amount of an incentive as string.
//
// Parameters:
//   - poolPath: Pool path containing the incentive.
//   - incentiveId: External incentive identifier whose remaining reward is formatted.
//
// Returns:
//   - string: Remaining reward amount encoded as a decimal string.
//   - error: Non-nil when poolPath or incentiveId cannot be resolved; nil on success.
func (s *stakerV1) GetIncentiveRewardAmountAsString(poolPath string, incentiveId string) (string, error) {
	rewardAmount, err := s.GetIncentiveRewardAmount(poolPath, incentiveId)
	if err != nil {
		return "", err
	}

	return rewardAmount.ToString(), nil
}

// GetIncentiveRewardPerSecondX128 returns the Q128-scaled reward per second of
// an incentive (i.e. actual rate = value / 2^128). The Q128 form preserves
// sub-second precision that would otherwise be lost to int64 truncation.
//
// Parameters:
//   - poolPath: Pool path containing the incentive.
//   - incentiveId: External incentive identifier whose reward rate is queried.
//
// Returns:
//   - *u256.Uint: Q128-scaled reward-per-second value; divide by 2^128 for the unscaled rate.
//   - error: Non-nil when poolPath or incentiveId cannot be resolved; nil on success.
func (s *stakerV1) GetIncentiveRewardPerSecondX128(poolPath string, incentiveId string) (*u256.Uint, error) {
	incentive, err := s.getIncentive(poolPath, incentiveId)
	if err != nil {
		return nil, err
	}

	return incentive.RewardPerSecondX128(), nil
}

// GetIncentiveCreator returns the creator address of an incentive.
//
// Parameters:
//   - poolPath: Pool path containing the incentive.
//   - incentiveId: External incentive identifier whose creator is queried.
//
// Returns:
//   - address: Address that created the incentive.
//   - error: Non-nil when poolPath or incentiveId cannot be resolved; nil on success.
func (s *stakerV1) GetIncentiveCreator(poolPath string, incentiveId string) (address, error) {
	incentive, err := s.getIncentive(poolPath, incentiveId)
	if err != nil {
		return address(""), err
	}

	return incentive.Creator(), nil
}

// getDeposit retrieves a deposit by LP token ID.
func (s *stakerV1) getDeposit(lpTokenId uint64) (*sr.Deposit, error) {
	deposits := s.getDeposits()
	if !deposits.Has(lpTokenId) {
		return nil, makeErrorWithDetails(
			errDataNotFound,
			ufmt.Sprintf("lpTokenId(%d) deposit does not exist", lpTokenId),
		)
	}

	return deposits.get(lpTokenId), nil
}

// assertIsCollectablePosition ensures the position is staked or holds an exit checkpoint.
func (s *stakerV1) assertIsCollectablePosition(positionId uint64) error {
	if s.getDeposits().Has(positionId) || s.getUnstakedPositions().Has(positionId) {
		return nil
	}

	return makeErrorWithDetails(
		errDataNotFound,
		ufmt.Sprintf("lpTokenId(%d) deposit does not exist", positionId),
	)
}

// GetDeposit returns the deposit for the given LP token ID.
//
// Parameters:
//   - lpTokenId: LP position NFT token ID whose live deposit is queried.
//
// Returns:
//   - *sr.Deposit: Stored live deposit, or nil when lookup fails.
//   - error: Non-nil data-not-found error when lpTokenId is not currently deposited; nil on success.
func (s *stakerV1) GetDeposit(lpTokenId uint64) (*sr.Deposit, error) {
	return s.getDeposit(lpTokenId)
}

// CollectableEmissionReward returns the gross estimated internal GNS reward for a live staked
// deposit or an exit checkpoint left by UnStakeToken, before staking/protocol fee deduction during
// collection. The calculation is read-only, so querying an estimate never mutates state.
//
// Parameters:
//   - positionId: LP position NFT token ID or exit-checkpoint ID whose accrued GNS reward is estimated.
//
// Returns:
//   - int64: Gross estimated GNS emission amount in GNS base units (six decimals) before
//     staking/protocol fee deduction; zero may be a valid accrued amount.
//   - error: Non-nil when positionId is not staked/checked out or reward calculation fails; nil on success.
func (s *stakerV1) CollectableEmissionReward(positionId uint64) (int64, error) {
	currentTime := time.Now().Unix()
	currentHeight := runtime.ChainHeight()
	if err := s.assertIsCollectablePosition(positionId); err != nil {
		return 0, err
	}
	reward, err := s.calculateCollectablePositionReward(currentHeight, currentTime, positionId)
	if err != nil {
		return 0, err
	}
	return reward.Internal, nil
}

// CollectableExternalIncentiveReward returns the gross estimated external reward for an incentive
// before staking/protocol fee deduction during collection. The calculation is read-only, so
// querying an estimate never mutates state.
//
// Parameters:
//   - positionId: LP position NFT token ID or exit-checkpoint ID whose external reward is estimated.
//   - incentiveId: External incentive identifier to inspect; an absent reward entry yields zero
//     without error.
//
// Returns:
//   - int64: Gross estimated reward amount for incentiveId in that incentive's token's smallest
//     units, before staking/protocol fee deduction.
//   - error: Non-nil when positionId is not staked/checked out or reward calculation fails; nil on
//     success. An absent reward entry is not an error.
func (s *stakerV1) CollectableExternalIncentiveReward(positionId uint64, incentiveId string) (int64, error) {
	currentTime := time.Now().Unix()
	currentHeight := runtime.ChainHeight()
	if err := s.assertIsCollectablePosition(positionId); err != nil {
		return 0, err
	}
	reward, err := s.calculateCollectablePositionReward(currentHeight, currentTime, positionId)
	if err != nil {
		return 0, err
	}
	amount, ok := reward.External[incentiveId]
	if !ok {
		return 0, nil
	}
	return amount, nil
}

// GetDepositOwner returns the owner of a deposit.
//
// Parameters:
//   - lpTokenId: LP position NFT token ID whose owner is queried.
//
// Returns:
//   - address: Address recorded as the deposit owner.
//   - error: Non-nil data-not-found error when lpTokenId is not currently deposited; nil on success.
func (s *stakerV1) GetDepositOwner(lpTokenId uint64) (address, error) {
	deposit, err := s.getDeposit(lpTokenId)
	if err != nil {
		return address(""), err
	}

	return deposit.Owner(), nil
}

// GetDepositStakeTime returns the Unix timestamp at which a position was staked.
//
// Parameters:
//   - lpTokenId: LP position NFT token ID whose stake time is queried.
//
// Returns:
//   - int64: Unix timestamp at which the position was staked.
//   - error: Non-nil data-not-found error when lpTokenId is not currently deposited; nil on success.
func (s *stakerV1) GetDepositStakeTime(lpTokenId uint64) (int64, error) {
	deposit, err := s.getDeposit(lpTokenId)
	if err != nil {
		return 0, err
	}

	return deposit.StakeTime(), nil
}

// GetDepositTargetPoolPath returns the target pool path of a deposit.
//
// Parameters:
//   - lpTokenId: LP position NFT token ID whose pool target is queried.
//
// Returns:
//   - string: Pool path targeted by the deposit.
//   - error: Non-nil data-not-found error when lpTokenId is not currently deposited; nil on success.
func (s *stakerV1) GetDepositTargetPoolPath(lpTokenId uint64) (string, error) {
	deposit, err := s.getDeposit(lpTokenId)
	if err != nil {
		return "", err
	}

	return deposit.TargetPoolPath(), nil
}

// GetDepositTickLower returns the lower tick of a deposit.
//
// Parameters:
//   - lpTokenId: LP position NFT token ID whose lower tick is queried.
//
// Returns:
//   - int32: Signed lower tick boundary recorded by the deposit.
//   - error: Non-nil data-not-found error when lpTokenId is not currently deposited; nil on success.
func (s *stakerV1) GetDepositTickLower(lpTokenId uint64) (int32, error) {
	deposit, err := s.getDeposit(lpTokenId)
	if err != nil {
		return 0, err
	}

	return deposit.TickLower(), nil
}

// GetDepositTickUpper returns the upper tick of a deposit.
//
// Parameters:
//   - lpTokenId: LP position NFT token ID whose upper tick is queried.
//
// Returns:
//   - int32: Signed upper tick boundary recorded by the deposit.
//   - error: Non-nil data-not-found error when lpTokenId is not currently deposited; nil on success.
func (s *stakerV1) GetDepositTickUpper(lpTokenId uint64) (int32, error) {
	deposit, err := s.getDeposit(lpTokenId)
	if err != nil {
		return 0, err
	}

	return deposit.TickUpper(), nil
}

// GetDepositLiquidity returns the liquidity of a deposit.
//
// Parameters:
//   - lpTokenId: LP position NFT token ID whose liquidity is queried.
//
// Returns:
//   - *u256.Uint: Position liquidity as an unsigned 256-bit value, or nil when lookup fails.
//   - error: Non-nil data-not-found error when lpTokenId is not currently deposited; nil on success.
func (s *stakerV1) GetDepositLiquidity(lpTokenId uint64) (*u256.Uint, error) {
	deposit, err := s.getDeposit(lpTokenId)
	if err != nil {
		return nil, err
	}

	return deposit.Liquidity(), nil
}

// GetDepositLiquidityAsString returns the liquidity of a deposit as string.
//
// Parameters:
//   - lpTokenId: LP position NFT token ID whose liquidity is formatted.
//
// Returns:
//   - string: Position liquidity encoded as a decimal string.
//   - error: Non-nil data-not-found error when lpTokenId is not currently deposited; nil on success.
func (s *stakerV1) GetDepositLiquidityAsString(lpTokenId uint64) (string, error) {
	liquidity, err := s.GetDepositLiquidity(lpTokenId)
	if err != nil {
		return "", err
	}

	return liquidity.ToString(), nil
}

// GetDepositInternalRewardLastCollectTimestamp returns the last collect timestamp of a deposit.
//
// Parameters:
//   - lpTokenId: LP position NFT token ID whose internal-reward cursor is queried.
//
// Returns:
//   - int64: Unix timestamp of the deposit's last internal GNS reward collection.
//   - error: Non-nil data-not-found error when lpTokenId is not currently deposited; nil on success.
func (s *stakerV1) GetDepositInternalRewardLastCollectTimestamp(lpTokenId uint64) (int64, error) {
	deposit, err := s.getDeposit(lpTokenId)
	if err != nil {
		return 0, err
	}

	return deposit.InternalRewardLastCollectTime(), nil
}

// GetDepositCollectedInternalReward returns the collected internal reward amount.
//
// Parameters:
//   - lpTokenId: LP position NFT token ID whose collected GNS amount is queried.
//
// Returns:
//   - int64: Cumulative internal GNS reward already collected for the deposit.
//   - error: Non-nil data-not-found error when lpTokenId is not currently deposited; nil on success.
func (s *stakerV1) GetDepositCollectedInternalReward(lpTokenId uint64) (int64, error) {
	deposit, err := s.getDeposit(lpTokenId)
	if err != nil {
		return 0, err
	}

	return deposit.CollectedInternalReward(), nil
}

// GetDepositCollectedExternalReward returns the collected external reward amount for an incentive.
//
// Parameters:
//   - lpTokenId: LP position NFT token ID whose external-reward history is queried.
//   - incentiveId: External incentive identifier whose collected amount is queried.
//
// Returns:
//   - int64: Cumulative reward collected from incentiveId, in its reward-token units.
//   - error: Non-nil when the position deposit or its checkpoint data cannot be resolved; nil on success.
func (s *stakerV1) GetDepositCollectedExternalReward(lpTokenId uint64, incentiveId string) (int64, error) {
	depositResolver, err := s.getDepositResolver(lpTokenId)
	if err != nil {
		return 0, err
	}
	return depositResolver.CollectedExternalReward(incentiveId), nil
}

// GetDepositExternalRewardLastCollectTimestamp returns the last collect timestamp of a deposit.
//
// Parameters:
//   - lpTokenId: LP position NFT token ID whose external-reward cursor is queried.
//   - incentiveId: External incentive identifier whose collection time is queried.
//
// Returns:
//   - int64: Unix timestamp of the deposit's last collection for incentiveId.
//   - error: Non-nil when the position deposit or its checkpoint data cannot be resolved; nil on success.
func (s *stakerV1) GetDepositExternalRewardLastCollectTimestamp(lpTokenId uint64, incentiveId string) (int64, error) {
	depositResolver, err := s.getDepositResolver(lpTokenId)
	if err != nil {
		return 0, err
	}
	return depositResolver.ExternalRewardLastCollectTime(incentiveId), nil
}

// GetDepositWarmUp returns the warm-up records of a deposit.
//
// Parameters:
//   - lpTokenId: LP position NFT token ID whose warm-up records are queried.
//
// Returns:
//   - []sr.Warmup: Warm-up reward records currently associated with the deposit.
//   - error: Non-nil data-not-found error when lpTokenId is not currently deposited; nil on success.
func (s *stakerV1) GetDepositWarmUp(lpTokenId uint64) ([]sr.Warmup, error) {
	deposit, err := s.getDeposit(lpTokenId)
	if err != nil {
		return nil, err
	}

	return deposit.Warmups(), nil
}

// GetDepositExternalIncentiveIdList returns external incentive IDs for a deposit.
//
// Parameters:
//   - lpTokenId: LP position NFT token ID whose incentive index is queried.
//
// Returns:
//   - []string: External incentive identifiers tracked by the deposit.
//   - error: Non-nil data-not-found error when lpTokenId is not currently deposited; nil on success.
func (s *stakerV1) GetDepositExternalIncentiveIdList(lpTokenId uint64) ([]string, error) {
	deposit, err := s.getDeposit(lpTokenId)
	if err != nil {
		return nil, err
	}

	return deposit.GetExternalIncentiveIdList(), nil
}

// GetPoolTier returns the tier of a pool.
//
// Parameters:
//   - poolPath: Pool path whose current emission tier is queried.
//
// Returns:
//   - uint64: Current tier number; zero means the pool is not an internal-emission target.
func (s *stakerV1) GetPoolTier(poolPath string) uint64 {
	return s.getPoolTier().CurrentTier(poolPath)
}

// GetPoolTierRatio returns the current reward ratio for a pool's tier.
//
// Parameters:
//   - poolPath: Pool path whose current tier ratio is queried.
//
// Returns:
//   - uint64: Configured percentage weight (0-100) associated with the pool's current tier.
//   - error: Non-nil when the pool's current tier has no configured ratio; nil on success.
func (s *stakerV1) GetPoolTierRatio(poolPath string) (uint64, error) {
	tier := s.GetPoolTier(poolPath)
	ratio, err := s.getPoolTier().tierRatio.Get(tier)
	if err != nil {
		return 0, makeErrorWithDetails(errInvalidPoolTier, err.Error())
	}

	return ratio, nil
}

// GetPoolTierCount returns the number of pools in a tier.
//
// Parameters:
//   - tier: Tier number whose current pool membership count is queried.
//
// Returns:
//   - uint64: Number of pools currently assigned to tier; zero is returned for tier zero.
func (s *stakerV1) GetPoolTierCount(tier uint64) uint64 {
	if tier == 0 {
		return 0
	}
	return uint64(s.getPoolTier().CurrentCount(tier))
}

// GetPoolReward returns the current reward amount for a tier.
//
// Parameters:
//   - tier: Emission tier whose current per-pool reward is queried.
//
// Returns:
//   - int64: Current GNS reward allocation per second for one pool in tier.
//   - error: Non-nil when tier is outside the configured range or the emission rate cannot be read; nil on success.
func (s *stakerV1) GetPoolReward(tier uint64) (int64, error) {
	if tier == 0 || tier >= AllTierCount {
		return 0, makeErrorWithDetails(
			errInvalidPoolTier,
			ufmt.Sprintf("tier(%d) must be between 1 and %d", tier, AllTierCount-1),
		)
	}
	return s.getPoolTier().CurrentReward(tier)
}

// GetPoolStakedLiquidity returns the current total staked liquidity of a pool.
//
// Parameters:
//   - poolPath: Pool path whose current staked liquidity is queried.
//
// Returns:
//   - string: Current staked liquidity encoded as a decimal unsigned-integer string.
//   - error: Non-nil when poolPath has no registered pool; nil on success.
func (s *stakerV1) GetPoolStakedLiquidity(poolPath string) (string, error) {
	pool, err := s.getPoolByPoolPath(poolPath)
	if err != nil {
		return "", err
	}
	liquidity := NewPoolResolver(pool).CurrentStakedLiquidity(time.Now().Unix())
	if liquidity == nil {
		return u256.Zero().ToString(), nil
	}

	return liquidity.ToString(), nil
}

// GetPoolsByTier returns the list of pools in a tier.
//
// Parameters:
//   - tier: Tier number whose pool membership is listed.
//
// Returns:
//   - []string: Pool paths currently assigned to tier, or an empty slice for tier zero.
//   - error: Non-nil when stored tier membership cannot be cast to uint64; nil on success.
func (s *stakerV1) GetPoolsByTier(tier uint64) ([]string, error) {
	if tier == 0 {
		return []string{}, nil
	}

	pools := make([]string, 0)
	var iterErr error
	s.getPoolTier().membership.Iterate("", "", func(poolPath string, value any) bool {
		currentTier, ok := value.(uint64)
		if !ok {
			iterErr = errors.New("failed to cast tier to uint64")
			return true
		}
		if currentTier == tier {
			pools = append(pools, poolPath)
		}
		return false
	})
	if iterErr != nil {
		return nil, iterErr
	}

	return pools, nil
}

// GetTotalEmissionSent returns the total GNS emission sent.
//
// Returns:
//   - int64: Cumulative GNS emission amount sent by the staker.
func (s *stakerV1) GetTotalEmissionSent() int64 {
	return s.store.GetTotalEmissionSent()
}

// GetAllowedTokens returns the allowed external incentive token list.
//
// Returns:
//   - []string: Token paths currently allowed for external incentives.
func (s *stakerV1) GetAllowedTokens() []string {
	return s.store.GetAllowedTokens()
}

// GetDeniedRewardTokens returns the denied external incentive reward token list.
//
// Returns:
//   - []string: Token paths currently denied for newly created external incentives.
func (s *stakerV1) GetDeniedRewardTokens() []string {
	return s.store.GetDeniedRewardTokens()
}

// GetWarmupTemplate returns the current warmup template.
//
// Returns:
//   - []sr.Warmup: Current warm-up percentage and duration records used for reward calculations.
func (s *stakerV1) GetWarmupTemplate() []sr.Warmup {
	return s.store.GetWarmupTemplate()
}

// IsStaked returns whether a position is staked.
//
// Parameters:
//   - positionId: LP position NFT token ID whose live-staking status is queried.
//
// Returns:
//   - bool: true when positionId has a live deposit; false when it is not staked.
func (s *stakerV1) IsStaked(positionId uint64) bool {
	return s.getDeposits().Has(positionId)
}

// GetExternalIncentiveByPoolPath returns all external incentives for a pool.
//
// Parameters:
//   - poolPath: Pool path whose external incentives are listed.
//
// Returns:
//   - []sr.ExternalIncentive: External incentives targeting poolPath, or an empty slice when none exist.
//   - error: Non-nil when an external-incentive entry has an incompatible stored type; nil on success.
func (s *stakerV1) GetExternalIncentiveByPoolPath(poolPath string) ([]sr.ExternalIncentive, error) {
	incentives := make([]sr.ExternalIncentive, 0)
	var iterErr error

	s.store.GetExternalIncentives().Iterate("", "", func(_ string, value any) bool {
		incentive, ok := value.(*sr.ExternalIncentive)
		if !ok {
			iterErr = errors.New("failed to cast value to *ExternalIncentive")
			return true
		}
		if incentive.TargetPoolPath() == poolPath {
			incentives = append(incentives, *incentive)
		}
		return false
	})
	if iterErr != nil {
		return nil, iterErr
	}

	return incentives, nil
}

// GetPoolRewardCaches returns a read-only view of a pool's reward cache, keyed
// by the encoded block timestamp. nil is returned when the pool does not exist.
//
// Parameters:
//   - poolPath: Pool path whose reward-cache view is requested.
//
// Returns:
//   - *rotree.ReadOnlyTree: Read-only tree keyed by encoded Unix timestamps with int64 reward rates; nil when poolPath is absent or malformed.
func (s *stakerV1) GetPoolRewardCaches(poolPath string) *rotree.ReadOnlyTree {
	pool := s.findPoolByPoolPath(poolPath)
	if pool == nil {
		return nil
	}

	return pool.RewardCache().ReadOnly(rewardCacheEntry)
}

// GetPoolIncentives returns a read-only view of a pool's external incentives,
// keyed by incentive ID. nil is returned when the pool does not exist.
//
// Parameters:
//   - poolPath: Pool path whose external-incentive view is requested.
//
// Returns:
//   - *rotree.ReadOnlyTree: Read-only tree keyed by incentive ID with cloned external-incentive values; nil when poolPath is absent or malformed.
func (s *stakerV1) GetPoolIncentives(poolPath string) *rotree.ReadOnlyTree {
	pool := s.findPoolByPoolPath(poolPath)
	if pool == nil {
		return nil
	}

	return rotree.Wrap(pool.Incentives().IncentiveTrees(), cloneExternalIncentiveEntry)
}

// GetPoolGlobalRewardRatioAccumulations returns a read-only view of a pool's
// global reward ratio accumulation, keyed by the encoded block timestamp.
// nil is returned when the pool does not exist.
//
// Parameters:
//   - poolPath: Pool path whose global reward-ratio history is requested.
//
// Returns:
//   - *rotree.ReadOnlyTree: Read-only tree keyed by encoded Unix timestamps with string-encoded accumulations; nil when poolPath is absent or malformed.
func (s *stakerV1) GetPoolGlobalRewardRatioAccumulations(poolPath string) *rotree.ReadOnlyTree {
	pool := s.findPoolByPoolPath(poolPath)
	if pool == nil {
		return nil
	}

	return pool.GlobalRewardRatioAccumulation().ReadOnly(accumulationEntry)
}

// GetPoolHistoricalTicks returns a read-only view of a pool's historical ticks,
// keyed by the encoded block timestamp with the int32 tick as the value.
// nil is returned when the pool does not exist.
//
// Parameters:
//   - poolPath: Pool path whose historical tick view is requested.
//
// Returns:
//   - *rotree.ReadOnlyTree: Read-only tree keyed by encoded Unix timestamps with int32 tick values; nil when poolPath is absent or malformed.
func (s *stakerV1) GetPoolHistoricalTicks(poolPath string) *rotree.ReadOnlyTree {
	pool := s.findPoolByPoolPath(poolPath)
	if pool == nil {
		return nil
	}

	return pool.HistoricalTick().ReadOnly(historicalTickEntry)
}
