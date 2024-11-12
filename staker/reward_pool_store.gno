package staker

const (
	TIER1_INDEX   = 0
	TIER2_INDEX   = 1
	TIER3_INDEX   = 2
	TIER_TYPE_NUM = 3
)

// RewardPool represents a reward pool.
// A RewardPool type has the following fields:
// - tier: tier of pool
// - rewardAmount: distributable reward amount
// - distributedAmount: distributed reward amount
// - leftAmount: left reward amount
type RewardPool struct {
	tier              uint64
	rewardAmount      uint64
	distributedAmount uint64
	leftAmount        uint64
}

func NewRewardPool() *RewardPool {
	return &RewardPool{
		tier:              0,
		rewardAmount:      0,
		distributedAmount: 0,
		leftAmount:        0,
	}
}

func (r *RewardPool) SetTier(tier uint64) {
	r.tier = tier
}

func (r *RewardPool) SetRewardAmount(rewardAmount uint64) {
	r.rewardAmount = rewardAmount
}

func (r *RewardPool) SetDistributedAmount(distributedAmount uint64) {
	r.distributedAmount = distributedAmount
}

func (r *RewardPool) SetLeftAmount(leftAmount uint64) {
	r.leftAmount = leftAmount
}

func (r *RewardPool) GetTier() uint64 {
	return r.tier
}

func (r *RewardPool) GetRewardAmount() uint64 {
	return r.rewardAmount
}

func (r *RewardPool) GetDistributedAmount() uint64 {
	return r.distributedAmount
}

func (r *RewardPool) GetLeftAmount() uint64 {
	return r.leftAmount
}

type RewardPoolMap struct {
	rewardPools                 map[string]*RewardPool // poolPath -> RewardPool
	rewardAmountForTier         [TIER_TYPE_NUM]uint64  // total reward amount for each tier
	rewardAmountForTierEachPool [TIER_TYPE_NUM]uint64  // reward amount for each pool in each tier
	leftAmountForTier           [TIER_TYPE_NUM]uint64  // left reward amount for each tier
}

func NewRewardPoolMap() *RewardPoolMap {
	return &RewardPoolMap{
		rewardPools:                 make(map[string]*RewardPool),
		rewardAmountForTier:         [TIER_TYPE_NUM]uint64{},
		rewardAmountForTierEachPool: [TIER_TYPE_NUM]uint64{},
		leftAmountForTier:           [TIER_TYPE_NUM]uint64{},
	}
}

func (r *RewardPoolMap) SetRewardPoolMap(rewardPools map[string]*RewardPool) {
	r.rewardPools = rewardPools
}

func (r *RewardPoolMap) SetRewardPool(poolPath string, rewardPool *RewardPool) {
	r.rewardPools[poolPath] = rewardPool
}

func (r *RewardPoolMap) SetPoolTier(poolPath string, tier uint64) {
	if _, exist := r.rewardPools[poolPath]; !exist {
		r.rewardPools[poolPath] = NewRewardPool()
	}
	r.rewardPools[poolPath].SetTier(tier)
}

func (r *RewardPoolMap) SetPoolRewardAmount(poolPath string, rewardAmount uint64) {
	if _, exist := r.rewardPools[poolPath]; !exist {
		r.rewardPools[poolPath] = NewRewardPool()
	}
	r.rewardPools[poolPath].SetRewardAmount(rewardAmount)
}

func (r *RewardPoolMap) SetRewardAmountForTier(tierIndex int, amount uint64) {
	r.rewardAmountForTier[tierIndex] = amount
}

func (r *RewardPoolMap) SetRewardAmountForTierEachPool(tierIndex int, amount uint64) {
	r.rewardAmountForTierEachPool[tierIndex] = amount
}

func (r *RewardPoolMap) SetLeftAmountForTier(tierIndex int, amount uint64) {
	r.leftAmountForTier[tierIndex] = amount
}

func (r *RewardPoolMap) GetRewardPools() map[string]*RewardPool {
	return r.rewardPools
}

func (r *RewardPoolMap) GetRewardPoolByPoolPath(poolPath string) *RewardPool {
	if _, exist := r.rewardPools[poolPath]; !exist {
		r.rewardPools[poolPath] = NewRewardPool()
	}
	return r.rewardPools[poolPath]
}

func (r *RewardPoolMap) GetPoolTier(poolPath string) uint64 {
	if _, exist := r.rewardPools[poolPath]; !exist {
		r.rewardPools[poolPath] = NewRewardPool()
	}
	return r.rewardPools[poolPath].tier
}

func (r *RewardPoolMap) GetPoolRewardAmount(poolPath string) uint64 {
	if _, exist := r.rewardPools[poolPath]; !exist {
		r.rewardPools[poolPath] = NewRewardPool()
	}
	return r.rewardPools[poolPath].rewardAmount
}

func (r *RewardPoolMap) GetRewardAmountForTier(tierIndex int) uint64 {
	return r.rewardAmountForTier[tierIndex]
}

func (r *RewardPoolMap) GetRewardAmountForTierEachPool(tierIndex int) uint64 {
	return r.rewardAmountForTierEachPool[tierIndex]
}

func (r *RewardPoolMap) GetLeftAmountForTier(tierIndex int) uint64 {
	return r.leftAmountForTier[tierIndex]
}
