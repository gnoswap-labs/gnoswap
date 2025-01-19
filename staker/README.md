# Staker Reward

## Abstract

Staker module distributes internal / external rewards to the stakers. 

* Internal reward(GNS emission) is distributed across internally incentivized("tiered") pools. Three tiers, 1, 2, and 3, are present. The emission is first splitted across three tiers based on TierRatio, evenly splitted between the tier member pools, and propertionally(in respect to staked liquidity) distributed to the in-range staked positions.

* External rewards(user provided incentives) could be set for pools. If a user creates an external incentive on a pool, the incentive will emit constant reward per block. Any user who have in-range staked liquidity on the pool will be eligible to claim the external incentive, proportionally to their liquidity.

* During the blocks where there are zero in-range staked liquidity, internal emission goes to community pool, and external reward gets refunded to the incentive creator.

* Each staked position will have their own warmup period designated upon their stake. Until they unstake, the staked positions will be passing through multiple warmup periods. For each warmup period, the user will get certain percentage of the reward and the rest will go to either community pool(internal) or the refundee(external). 

## Main Reward Calculation Logic

```go
func CalcPositionReward(param CalcPositionRewardParam) []Reward {
	// cache per-pool rewards in the internal incentive(tiers)
	param.PoolTier.cacheReward(param.CurrentHeight, param.Pools)

	deposit := param.Deposits.Get(param.TokenId)
	poolPath := deposit.targetPoolPath

	pool, ok := param.Pools.Get(poolPath)
	if !ok {
		pool = NewPool(poolPath, param.CurrentHeight)
		param.Pools.Set(poolPath, pool)
	}

	lastCollectHeight := deposit.lastCollectHeight

	// Initializes reward/penalty arrays for rewards and penalties for each warmup
	internalRewards := make([]uint64, len(deposit.warmups))
	internalPenalties := make([]uint64, len(deposit.warmups))
	externalRewards := make([]map[string]uint64, len(deposit.warmups))
	externalPenalties := make([]map[string]uint64, len(deposit.warmups))

	if param.PoolTier.CurrentTier(poolPath) != 0 {
		// Internal incentivized pool. 
		// Calculate reward for each warmup
		internalRewards, internalPenalties = pool.RewardStateOf(deposit).CalculateInternalReward(lastCollectHeight, param.CurrentHeight)
	}

	// All active incentives
	allIncentives := pool.incentives.GetAllInHeights(lastCollectHeight, param.CurrentHeight)

	for i := range externalRewards {
		externalRewards[i] = make(map[string]uint64)
		externalPenalties[i] = make(map[string]uint64)
	}

	for incentiveId, incentive := range allIncentives {
		// External incentivized pool.
		// Calculate reward for each warmup
		externalReward, externalPenalty := pool.RewardStateOf(deposit).CalculateExternalReward(int64(lastCollectHeight), int64(param.CurrentHeight), incentive)

		for i := range externalReward {
			externalRewards[i][incentiveId] = externalReward[i]
			externalPenalties[i][incentiveId] = externalPenalty[i]
		}
	}

	rewards := make([]Reward, len(internalRewards))
	for i := range internalRewards {
		rewards[i] = Reward{
			Internal:        internalRewards[i],
			InternalPenalty: internalPenalties[i],
			External:        externalRewards[i],
			ExternalPenalty: externalPenalties[i],
		}
	}

	return rewards
}
```

## Internal Reward

Internal rewards are distributed across the different tiers, and then each pools. Each internal reward is calculated via
$$
\text{poolReward}(\mathrm{pool}) 
= \frac{\text{emission} \,\times\, \mathrm{TierRatio}\!\bigl(\mathrm{tier}(\mathrm{pool})\bigr)}
       {\mathrm{Count}\!\bigl(\mathrm{tier}(\mathrm{pool})\bigr)},
$$
$$
\mathrm{TierRatio}(t) \;=\;
\begin{cases}
[1,\,0,\,0]_{\,t-1}, 
& \text{if } \mathrm{Count}(2) = 0 \;\land\; \mathrm{Count}(3) = 0, \\[8pt]
[0.8,\,0,\,0.2]_{\,t-1}, 
& \text{if } \mathrm{Count}(2) = 0, \\[8pt]
[0.7,\,0.3,\,0]_{\,t-1}, 
& \text{if } \mathrm{Count}(3) = 0, \\[8pt]
[0.5,\,0.3,\,0.2]_{\,t-1}, 
& \text{otherwise}.
\end{cases}
$$
$$
\text{emission} 
= \mathrm{GNSEmissionPerSecond} 
  \;\times\;
  \biggl(\frac{\mathrm{avgMsPerBlock}}{1000}\biggr)
  \;\times\;
  \mathrm{StakerEmissionRatio}.
$$

There is always at least one tier-1 pool.

The result of this equation could be changed when variable emission or Count(t) changes.

Emission(for staker contract) is calculated by applying avgMsPerBlock and StakerEmissionRatio to GNSEmissionPerSecond. GNSEmissionPerSecond is constant(other than halving event, which we will ignore in this paragraph). When one of those two variables are modified, the `callbackStakerEmissionChange` function is called, which will caches the reward until the current block and updates the current emission with the provided amount.

PoolTier.cacheReward recalculates all reward-related updates happened since the last cache height.
- Halving blocks: if there were halving events, split caching operation at the halving periods. The caching will be done for each halving periods, staker emission is updated, and then the caching operation moves forward.
- Unclaimable period: if the pool is currently in the unclaimable period(there are no claimable stakers), it will updates the unclaimable accumulation using the old emission, and then updates to start a new period(only for the internal)
- After checking these, it updates GlobalRewardRatioAccumulation, which is used to calculate the rewards for the positions.

Once the cache is filled until the current block, CalculateInternalReward is called to obtain reward for the total claimable internal reward for the position.

The reward is calculated in the following way(given a poolReward):

$$
\begin{aligned}
\text{TotalReward}
&=
  \underbrace{\text{CRP}\bigl(\text{startHeight},\, h_1\bigr)}_{\text{CRP}(s,h_1)} \times r_1
  \;+\;
  \underbrace{\text{CRP}\bigl(h_1,\, h_2\bigr)}_{\text{CRP}(h_1,h_2)} \times r_2
  \;+\;
  \underbrace{\text{CRP}\bigl(h_2,\, \text{endHeight}\bigr)}_{\text{CRP}(h_2,e)} \times r_3,
\\[6pt]
\text{CRP}(a, b)
&=
  \text{CalcRaw}(b)
  \;-\;
  \text{CalcRaw}(a),
\\[6pt]
\text{CalcRaw}(h)
&=
  \begin{cases}
    L(h) \;-\; U(h), 
      & \text{if } \text{tick}(h) < \ell, \\[6pt]
    U(h) \;-\; L(h), 
      & \text{if } \text{tick}(h) \ge u, \\[6pt]
    G(h) \;-\; \bigl(L(h) + U(h)\bigr), 
      & \text{otherwise}.
  \end{cases}
\end{aligned}
$$

## External Reward

## Unclaimable Period

## Warmup Period