package staker

import (
	"std"

	u256 "gno.land/p/gnoswap/uint256"
	pn "gno.land/r/gnoswap/v2/position"
)

// For Emission Reward Distribution
var (
	_billion *u256.Uint
)

func init() {
	_billion = u256.NewUint(1_000_000_000)
}

type RewardRecipientsMap struct {
	poolLiquidity map[string]*PoolLiquidity // poolPath -> poolLiquidity
}

// NewRewardRecipientMap creates a new RewardRecipientsMap
func NewRewardRecipientMap() *RewardRecipientsMap {
	return &RewardRecipientsMap{
		poolLiquidity: make(map[string]*PoolLiquidity),
	}
}

func (r *RewardRecipientsMap) SetPoolLiquidity(poolPath string, poolLiquidity *PoolLiquidity) {
	r.poolLiquidity[poolPath] = poolLiquidity
}

func (r *RewardRecipientsMap) GetPoolLiquidity(poolPath string) *PoolLiquidity {
	if _, exist := r.poolLiquidity[poolPath]; !exist {
		return nil
	}
	return r.poolLiquidity[poolPath]
}

func (r *RewardRecipientsMap) GetRewardRecipientsMap() map[string]*PoolLiquidity {
	return r.poolLiquidity
}

type PoolLiquidity struct {
	totalLiquidity   *u256.Uint                        // total liquidity
	inRangeLiquidity map[uint64]*InRangeLiquidity      // tokenID -> liquidity
	inRangeReward    map[uint64]*InRangePositionReward // tokenID -> reward
}

// NewPoolLiquidity creates a new PoolLiquidity
func NewPoolLiquidity() *PoolLiquidity {
	return &PoolLiquidity{
		totalLiquidity:   u256.Zero(),
		inRangeLiquidity: make(map[uint64]*InRangeLiquidity),
		inRangeReward:    make(map[uint64]*InRangePositionReward),
	}
}

func (p *PoolLiquidity) SetTotalLiquidity(totalLiquidity *u256.Uint) {
	p.totalLiquidity = totalLiquidity
}

func (p *PoolLiquidity) SetInRangeLiquidity(tokenID uint64, inRangeLiquidity *InRangeLiquidity) {
	p.inRangeLiquidity[tokenID] = inRangeLiquidity
}

func (p *PoolLiquidity) SetInRangeReward(tokenID uint64, inRangePositionReward *InRangePositionReward) {
	p.inRangeReward[tokenID] = inRangePositionReward
}

func (p *PoolLiquidity) GetTotalLiquidity() *u256.Uint {
	return p.totalLiquidity
}

func (p *PoolLiquidity) GetInRangeLiquidity(tokenID uint64) *InRangeLiquidity {
	if _, exist := p.inRangeLiquidity[tokenID]; !exist {
		return nil
	}
	return p.inRangeLiquidity[tokenID]
}

func (p *PoolLiquidity) GetInRangeLiquidityMap() map[uint64]*InRangeLiquidity {
	return p.inRangeLiquidity
}

func (p *PoolLiquidity) GetOrCreateInRangeLiquidity(tokenID uint64) *InRangeLiquidity {
	if _, exist := p.inRangeLiquidity[tokenID]; !exist {
		p.inRangeLiquidity[tokenID] = NewInRangeLiquidity()
	}
	return p.inRangeLiquidity[tokenID]
}

func (p *PoolLiquidity) GetOrCreateInRangePositionReward(tokenID uint64) *InRangePositionReward {
	if _, exist := p.inRangeReward[tokenID]; !exist {
		p.inRangeReward[tokenID] = NewInRangePositionReward()
	}
	return p.inRangeReward[tokenID]
}

func (p *PoolLiquidity) GetInRangeRewardMap() map[uint64]*InRangePositionReward {
	return p.inRangeReward
}

func (p *PoolLiquidity) GetInRangeReward(tokenID uint64) *InRangePositionReward {
	if _, exist := p.inRangeReward[tokenID]; !exist {
		return nil
	}
	return p.inRangeReward[tokenID]
}

func (p *PoolLiquidity) SetRewardToStakers(tokenID uint64, rewardAmount uint64) {
	inRangePositionReward := p.GetOrCreateInRangePositionReward(tokenID)
	inRangePositionReward.SetRewardAmount(rewardAmount)
	p.SetInRangeReward(tokenID, inRangePositionReward)
}

func (p *PoolLiquidity) HasLeftAmount(tokenID uint64) bool {
	if _, exist := p.inRangeReward[tokenID]; !exist {
		return false
	}
	return p.inRangeReward[tokenID].GetLeftAmount() > 0
}

func (p *PoolLiquidity) GetLeftAmount(tokenID uint64) uint64 {
	if p.HasLeftAmount(tokenID) {
		return p.inRangeReward[tokenID].GetLeftAmount()
	}
	return 0
}

func (p *PoolLiquidity) GetRewardAmount(tokenID uint64) uint64 {
	if _, exist := p.inRangeReward[tokenID]; !exist {
		return 0
	}
	return p.inRangeReward[tokenID].GetRewardAmount()
}

func (p *PoolLiquidity) GetStakedHeight(tokenID uint64) int64 {
	if _, exist := p.inRangeLiquidity[tokenID]; !exist {
		return 0
	}
	return p.inRangeLiquidity[tokenID].GetStakedHeight()
}

type InRangeLiquidity struct {
	liquidity      *u256.Uint // liquidity
	liquidityRatio *u256.Uint // liquidity ratio
	stakedHeight   int64      // staked block height
}

// NewInRangeLiquidity creates a new InRangeLiquidity
func NewInRangeLiquidity() *InRangeLiquidity {
	return &InRangeLiquidity{
		liquidity:      u256.Zero(),
		liquidityRatio: u256.Zero(),
	}
}

func (i *InRangeLiquidity) SetLiquidity(liquidity *u256.Uint) {
	i.liquidity = liquidity
}

func (i *InRangeLiquidity) SetLiquidityRatio(liquidityRatio *u256.Uint) {
	i.liquidityRatio = liquidityRatio
}

func (i *InRangeLiquidity) SetStakedHeight(stakedHeight int64) {
	i.stakedHeight = stakedHeight
}

func (i *InRangeLiquidity) GetLiquidity() *u256.Uint {
	return i.liquidity
}

func (i *InRangeLiquidity) GetLiquidityRatio() *u256.Uint {
	return i.liquidityRatio
}

func (i *InRangeLiquidity) GetStakedHeight() int64 {
	return i.stakedHeight
}

type InRangePositionReward struct {
	accumulatedRewardAmount uint64 // accumulated reward amount
	accumulatedPenalty      uint64 // accumulated penalty amount
	rewardAmount            uint64 // reward amount to be distributed
	leftAmount              uint64 // left reward amount to be distributed
	warmUpAmount            uint64 // warm-up reward amount (actual reward amount)
	warmUpPenalty           uint64 // warm-up penalty amount
}

// NewInRangePositionReward creates a new InRangePositionReward
func NewInRangePositionReward() *InRangePositionReward {
	return &InRangePositionReward{
		rewardAmount:  0,
		leftAmount:    0,
		warmUpAmount:  0,
		warmUpPenalty: 0,
	}
}

func (i *InRangePositionReward) SetRewardAmount(rewardAmount uint64) {
	i.rewardAmount = rewardAmount
}

func (i *InRangePositionReward) AddRewardAmount(rewardAmount uint64) {
	// TODO:
	// 1. log should be removed
	println(" > Before RewardAmount:", i.accumulatedRewardAmount)
	i.accumulatedRewardAmount += rewardAmount
	println(" > After RewardAmount:", i.accumulatedRewardAmount)
}

func (i *InRangePositionReward) SetLeftAmount(leftAmount uint64) {
	i.leftAmount = leftAmount
}

func (i *InRangePositionReward) SetWarmUpAmount(warmUpAmount uint64) {
	i.warmUpAmount = warmUpAmount
}

func (i *InRangePositionReward) SetWarmUpPenalty(warmUpPenalty uint64) {
	i.warmUpPenalty = warmUpPenalty
}

func (i *InRangePositionReward) GetRewardAmount() uint64 {
	return i.rewardAmount
}

func (i *InRangePositionReward) GetLeftAmount() uint64 {
	return i.leftAmount
}

func (i *InRangePositionReward) GetWarmUpAmount() uint64 {
	return i.warmUpAmount
}

func (i *InRangePositionReward) GetWarmUpPenalty() uint64 {
	return i.warmUpPenalty
}

func (r *RewardRecipientsMap) SetInRangeLiquidity(poolPath string, tokenId uint64, inRangeLiquidity *InRangeLiquidity) {
	poolLiquidity := r.GetOrCreatePoolLiquidity(poolPath)
	poolLiquidity.SetInRangeLiquidity(tokenId, inRangeLiquidity)
	r.SetPoolLiquidity(poolPath, poolLiquidity)
}

func (r *RewardRecipientsMap) SetInRangePositionReward(poolPath string, tokenId uint64, inRangePositionReward *InRangePositionReward) {
	poolLiquidity := r.GetOrCreatePoolLiquidity(poolPath)
	poolLiquidity.SetInRangeReward(tokenId, inRangePositionReward)
	r.SetPoolLiquidity(poolPath, poolLiquidity)
}

func (r *RewardRecipientsMap) GetOrCreatePoolLiquidity(poolPath string) *PoolLiquidity {
	if _, exist := r.poolLiquidity[poolPath]; !exist {
		r.poolLiquidity[poolPath] = NewPoolLiquidity()
	}
	return r.poolLiquidity[poolPath]
}

func (r *RewardRecipientsMap) GetOrCreateInRangeLiquidity(poolPath string, tokenID uint64) *InRangeLiquidity {
	poolLiquidity := r.GetOrCreatePoolLiquidity(poolPath)
	if _, exist := poolLiquidity.inRangeLiquidity[tokenID]; !exist {
		poolLiquidity.inRangeLiquidity[tokenID] = NewInRangeLiquidity()
	}
	return poolLiquidity.inRangeLiquidity[tokenID]
}

func (r *RewardRecipientsMap) GetOrCreateInRangePositionReward(poolPath string, tokenID uint64) *InRangePositionReward {
	poolLiquidity := r.GetOrCreatePoolLiquidity(poolPath)
	if _, exist := poolLiquidity.inRangeReward[tokenID]; !exist {
		poolLiquidity.inRangeReward[tokenID] = NewInRangePositionReward()
	}
	return poolLiquidity.inRangeReward[tokenID]
}

// CalculateLiquidityRatio calculates the liquidity ratio
func (r *RewardRecipientsMap) CalculateLiquidityRatio(liquidity *u256.Uint, totalLiquidity *u256.Uint) *u256.Uint {
	if totalLiquidity.IsZero() || liquidity.IsZero() {
		return u256.NewUint(0)
	}
	totalStakedLiquidity := totalLiquidity
	poolTotalStakedLiquidityX96 := new(u256.Uint).Mul(totalStakedLiquidity, _q96)

	positionLiquidity := liquidity
	positionLiquidityX96x := new(u256.Uint).Mul(positionLiquidity, _q96)               // positionLiquidityX96
	positionLiquidityX96x = positionLiquidityX96x.Mul(positionLiquidityX96x, _billion) // positionLiquidityX96x

	positionLiquidityRatio := new(u256.Uint).Div(positionLiquidityX96x, poolTotalStakedLiquidityX96) // this value needs to be divided by 1_000_000_000 (positionLiquidityRatiox)
	positionLiquidityRatio = positionLiquidityRatio.Mul(positionLiquidityRatio, _q96)                // so first mul consts.Q96 (positionLiquidityRatioX96x)
	positionLiquidityRatio = positionLiquidityRatio.Div(positionLiquidityRatio, _billion)            // then divided by 1_000_000_000 (positionLiquidityRatioX96)

	return positionLiquidityRatio
}

// UpdatePoolLiquidity updates the pool total liquidity
// and updates the in-range liquidity with the position liquidity
// stakeHeight is used to calculate warm-up penalty
func (r *RewardRecipientsMap) UpdatePoolLiquidity(poolPath string, tokenID uint64, liquidity *u256.Uint, stakedHeight int64) {
	// 1. Get the pool liquidity
	poolLiquidity := r.GetOrCreatePoolLiquidity(poolPath)
	// 2. Get the in-range liquidity
	inRangePosition := poolLiquidity.GetOrCreateInRangeLiquidity(tokenID)
	// 3. Update the in-range liquidity
	inRangePosition.SetLiquidity(liquidity)
	// 4. Update the stake height
	inRangePosition.SetStakedHeight(stakedHeight)
	poolLiquidity.SetInRangeLiquidity(tokenID, inRangePosition)
	// 5. Update the total liquidity
	totalLiquidity := poolLiquidity.GetTotalLiquidity()
	totalLiquidity.Add(totalLiquidity, liquidity)
	poolLiquidity.SetTotalLiquidity(totalLiquidity)
	// 6. Update the pool liquidity
	r.SetPoolLiquidity(poolPath, poolLiquidity)
}

// UpdateInRangeLiquidityRatio calculates the in-range liquidity ratio
// and updates the in-range liquidity ratio
func (r *RewardRecipientsMap) UpdateInRangeLiquidityRatio(poolPath string, tokenID uint64) {
	// 1. Get the pool liquidity
	poolLiquidity := r.GetOrCreatePoolLiquidity(poolPath)
	// 2. Get the in-range liquidity
	inRangeLiquidity := poolLiquidity.GetInRangeLiquidity(tokenID)
	// 3. Calculate in-range liquidity ratio
	totalLiquidity := poolLiquidity.GetTotalLiquidity()
	liquidity := inRangeLiquidity.GetLiquidity()
	liquidityRatio := r.CalculateLiquidityRatio(liquidity, totalLiquidity)
	// 4. Update the in-range liquidity ratio
	inRangeLiquidity.SetLiquidityRatio(liquidityRatio)
	poolLiquidity.SetInRangeLiquidity(tokenID, inRangeLiquidity)
	r.SetPoolLiquidity(poolPath, poolLiquidity)

	// TODO:
	// 1. after refactoring is completed, poolsPositions should be removed
	positionsLiquidityRatio[tokenID] = liquidityRatio
}

// GenerateRewardRecipients generates reward recipients for each pool
// NOTE: this function is called when emission reward is calculated
// and reward recipients should have position in the pool with in-range liquidity
func (r *RewardRecipientsMap) GenerateRewardRecipients(depositList map[uint64]Deposit) {
	if r.poolLiquidity == nil {
		r.poolLiquidity = make(map[string]*PoolLiquidity)
	}

	currentHeight := std.GetHeight()
	for tokenId, deposit := range depositList {
		// Check if the posistion staked time is in the warm-up period
		if currentHeight <= deposit.stakeHeight {
			continue
		}
		// 1. Check if the position is in range, if not, skip the position
		if !pn.PositionIsInRange(tokenId) {
			continue
		}
		// 2. Check if the pool is eligible for rewards
		poolPath := deposit.targetPoolPath
		if !isExistPoolTiers(poolPath) {
			continue
		}
		// 3. get position liquidity
		positionLiquidity := pn.PositionGetPositionLiquidity(tokenId)
		// 4. get staked block height of the position
		positionStakedHeight := deposit.stakeHeight
		// 5. update liquidity
		r.UpdatePoolLiquidity(poolPath, tokenId, positionLiquidity, positionStakedHeight)
	}
}

// CalculateLiquidityRatioAndGetTokenIdMap calculates the liquidity ratio for each position
func (r *RewardRecipientsMap) CalculateLiquidityRatioAndGetTokenIdMap() map[string][]uint64 {
	// TODO:
	// 1. after refactoring is completed, poolsPositions should be removed
	tokenIdMap := make(map[string][]uint64) // clear

	poolLiquidityMap := r.GetRewardRecipientsMap()

	// 2. calculate the liquidity ratio for each position
	for poolPath, poolLiquidity := range poolLiquidityMap {
		inRangePosition := poolLiquidity.GetInRangeLiquidityMap()
		for tokenId, _ := range inRangePosition {
			r.UpdateInRangeLiquidityRatio(poolPath, tokenId)
			tokenIdMap[poolPath] = append(tokenIdMap[poolPath], tokenId)
		}
	}
	return tokenIdMap
}
