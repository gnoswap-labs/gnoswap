# staker

`import "gno.land/r/gnoswap/staker"`

Package staker manages liquidity mining rewards for GnoSwap positions.

The staker distributes GNS emissions and external incentives to liquidity
providers based on their position size, price range, and staking duration.
It supports both internal GNS rewards and external token incentives.

Rewards are calculated per-tick and accumulate over time, with automatic
compounding and fee collection integration.


## Index

- [AllTierCount](#alltiercount)
- [AddToken](#addtoken)
- [ChangePoolTier](#changepooltier)
- [CollectReward](#collectreward)
- [CollectableEmissionReward](#collectableemissionreward)
- [CollectableExternalIncentiveReward](#collectableexternalincentivereward)
- [CreateExternalIncentive](#createexternalincentive)
- [DecodeInt64](#decodeint64)
- [DecodeUint](#decodeuint)
- [EncodeInt](#encodeint)
- [EncodeInt64](#encodeint64)
- [EncodeUint](#encodeuint)
- [EndExternalIncentive](#endexternalincentive)
- [GetAllowedTokens](#getallowedtokens)
- [GetCreatedHeightOfIncentive](#getcreatedheightofincentive)
- [GetDepositCollectedExternalReward](#getdepositcollectedexternalreward)
- [GetDepositCollectedInternalReward](#getdepositcollectedinternalreward)
- [GetDepositExternalIncentiveIdList](#getdepositexternalincentiveidlist)
- [GetDepositExternalRewardLastCollectTimestamp](#getdepositexternalrewardlastcollecttimestamp)
- [GetDepositGnsAmount](#getdepositgnsamount)
- [GetDepositInternalRewardLastCollectTimestamp](#getdepositinternalrewardlastcollecttimestamp)
- [GetDepositLiquidity](#getdepositliquidity)
- [GetDepositLiquidityAsString](#getdepositliquidityasstring)
- [GetDepositOwner](#getdepositowner)
- [GetDepositStakeTime](#getdepositstaketime)
- [GetDepositTargetPoolPath](#getdeposittargetpoolpath)
- [GetDepositTickLower](#getdepositticklower)
- [GetDepositTickUpper](#getdeposittickupper)
- [GetImplementationPackagePath](#getimplementationpackagepath)
- [GetIncentiveCreatedTimestamp](#getincentivecreatedtimestamp)
- [GetIncentiveDepositGnsAmount](#getincentivedepositgnsamount)
- [GetIncentiveDistributedRewardAmount](#getincentivedistributedrewardamount)
- [GetIncentiveEndTimestamp](#getincentiveendtimestamp)
- [GetIncentiveRefunded](#getincentiverefunded)
- [GetIncentiveRefundee](#getincentiverefundee)
- [GetIncentiveRemainingRewardAmount](#getincentiveremainingrewardamount)
- [GetIncentiveRewardAmount](#getincentiverewardamount)
- [GetIncentiveRewardAmountAsString](#getincentiverewardamountasstring)
- [GetIncentiveRewardPerSecond](#getincentiverewardpersecond)
- [GetIncentiveRewardToken](#getincentiverewardtoken)
- [GetIncentiveStartTimestamp](#getincentivestarttimestamp)
- [GetIncentiveTotalRewardAmount](#getincentivetotalrewardamount)
- [GetMinimumRewardAmount](#getminimumrewardamount)
- [GetMinimumRewardAmountForToken](#getminimumrewardamountfortoken)
- [GetPoolGlobalRewardRatioAccumulation](#getpoolglobalrewardratioaccumulation)
- [GetPoolGlobalRewardRatioAccumulationCount](#getpoolglobalrewardratioaccumulationcount)
- [GetPoolGlobalRewardRatioAccumulationIDs](#getpoolglobalrewardratioaccumulationids)
- [GetPoolHistoricalTick](#getpoolhistoricaltick)
- [GetPoolHistoricalTickCount](#getpoolhistoricaltickcount)
- [GetPoolHistoricalTickIDs](#getpoolhistoricaltickids)
- [GetPoolIncentiveCount](#getpoolincentivecount)
- [GetPoolIncentiveIDs](#getpoolincentiveids)
- [GetPoolIncentiveIdList](#getpoolincentiveidlist)
- [GetPoolReward](#getpoolreward)
- [GetPoolRewardCache](#getpoolrewardcache)
- [GetPoolRewardCacheCount](#getpoolrewardcachecount)
- [GetPoolRewardCacheIDs](#getpoolrewardcacheids)
- [GetPoolStakedLiquidity](#getpoolstakedliquidity)
- [GetPoolTier](#getpooltier)
- [GetPoolTierCount](#getpooltiercount)
- [GetPoolTierRatio](#getpooltierratio)
- [GetPoolsByTier](#getpoolsbytier)
- [GetSpecificTokenMinimumRewardAmount](#getspecifictokenminimumrewardamount)
- [GetStakedPositionsByUser](#getstakedpositionsbyuser)
- [GetTargetPoolPathByIncentiveId](#gettargetpoolpathbyincentiveid)
- [GetTotalEmissionSent](#gettotalemissionsent)
- [GetTotalStakedUserCount](#gettotalstakedusercount)
- [GetTotalStakedUserPositionCount](#gettotalstakeduserpositioncount)
- [GetUnstakingFee](#getunstakingfee)
- [IsIncentiveActive](#isincentiveactive)
- [IsStaked](#isstaked)
- [MintAndStake](#mintandstake)
- [RegisterInitializer](#registerinitializer)
- [RemovePoolTier](#removepooltier)
- [RemoveToken](#removetoken)
- [SetDepositGnsAmount](#setdepositgnsamount)
- [SetMinimumRewardAmount](#setminimumrewardamount)
- [SetPoolTier](#setpooltier)
- [SetTokenMinimumRewardAmount](#settokenminimumrewardamount)
- [SetUnStakingFee](#setunstakingfee)
- [SetWarmUp](#setwarmup)
- [StakeToken](#staketoken)
- [UnStakeToken](#unstaketoken)
- [UpgradeImpl](#upgradeimpl)
- [Counter](#counter)
- [Deposit](#deposit)
- [EmissionAccessor](#emissionaccessor)
- [ExternalIncentive](#externalincentive)
- [IStaker](#istaker)
- [IStakerGetter](#istakergetter)
- [IStakerManager](#istakermanager)
- [IStakerStore](#istakerstore)
- [Incentives](#incentives)
- [NFTAccessor](#nftaccessor)
- [Pool](#pool)
- [PoolAccessor](#poolaccessor)
- [StoreKey](#storekey)
- [SwapBatchProcessor](#swapbatchprocessor)
- [SwapTickCross](#swaptickcross)
- [Tick](#tick)
- [Ticks](#ticks)
- [TierRatio](#tierratio)
- [UintTree](#uinttree)
- [Warmup](#warmup)


## Constants

<a id="alltiercount"></a>
```go
const (
	AllTierCount = 4
)
```


## Functions

<a id="addtoken"></a>

### AddToken

```go

func AddToken(cur realm, tokenPath string)

```

AddToken adds a token to the reward token whitelist.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| cur | realm |  |
| tokenPath | string | path of the token to add |

---

<a id="changepooltier"></a>

### ChangePoolTier

```go

func ChangePoolTier(cur realm, poolPath string, tier uint64)

```

ChangePoolTier changes the reward tier of a pool.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| cur | realm |  |
| poolPath | string | path of the pool |
| tier | uint64 | new reward tier level |

---

<a id="collectreward"></a>

### CollectReward

```go

func CollectReward(cur realm, positionId uint64, unwrapResult bool) (string, string, map[string]int64, map[string]int64)

```

CollectReward collects accumulated rewards from a staked position.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| cur | realm |  |
| positionId | uint64 | ID of the staked position |
| unwrapResult | bool | whether to unwrap WGNOT to GNOT |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| poolPath | string | pool path |
| stakeDetail | string | staking details |
| internalRewards | map[string]int64 | internal rewards |
| externalRewards | map[string]int64 | external rewards |

---

<a id="collectableemissionreward"></a>

### CollectableEmissionReward

```go

func CollectableEmissionReward(positionId uint64) int64

```

CollectableEmissionReward returns the claimable internal reward amount.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| positionId | uint64 | ID of the staked position |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| reward | int64 | claimable internal reward amount |

---

<a id="collectableexternalincentivereward"></a>

### CollectableExternalIncentiveReward

```go

func CollectableExternalIncentiveReward(positionId uint64, incentiveId string) int64

```

CollectableExternalIncentiveReward returns the claimable external reward amount.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| positionId | uint64 | ID of the staked position |
| incentiveId | string | ID of the incentive |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| reward | int64 | claimable external reward amount |

---

<a id="createexternalincentive"></a>

### CreateExternalIncentive

```go

func CreateExternalIncentive(cur realm, targetPoolPath string, rewardToken string, rewardAmount int64, startTimestamp int64, endTimestamp int64)

```

CreateExternalIncentive creates an external reward incentive for a pool.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| cur | realm |  |
| targetPoolPath | string | pool to incentivize |
| rewardToken | string | token to use as reward |
| rewardAmount | int64 | total reward amount |
| startTimestamp | int64 | incentive start time |
| endTimestamp | int64 | incentive end time |

---

<a id="decodeint64"></a>

### DecodeInt64

```go

func DecodeInt64(s string) int64

```

DecodeInt64 converts a zero-padded string back into an int64 number.



Panics:
- If the string cannot be parsed into an int64.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| s | string | zero-padded string |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| value | int64 | decoded number |

---

<a id="decodeuint"></a>

### DecodeUint

```go

func DecodeUint(s string) uint64

```

DecodeUint converts a zero-padded string back into a uint64 number.



Panics:
- If the string cannot be parsed into a uint64.

Example:
Input: "00000000000000012345"
Output: 12345

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| s | string | zero-padded string |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| value | uint64 | decoded number |

---

<a id="encodeint"></a>

### EncodeInt

```go

func EncodeInt(num int32) string

```

EncodeInt takes an int32 and returns a zero-padded decimal string
with up to 10 digits for the absolute value.
If the number is negative, the '-' sign comes first, followed by zeros, then digits.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| num | int32 | number to encode |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| encoded | string | zero-padded string representation of the number |

---

<a id="encodeint64"></a>

### EncodeInt64

```go

func EncodeInt64(num int64) string

```

EncodeInt64 converts a non-negative int64 into a zero-padded decimal string.



Panics:
- If the number is negative.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| num | int64 | number to encode |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| encoded | string | zero-padded string representation of the number |

---

<a id="encodeuint"></a>

### EncodeUint

```go

func EncodeUint(num uint64) string

```

EncodeUint converts a uint64 number into a zero-padded 20-character string.



Example:
Input: 12345
Output: "00000000000000012345"

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| num | uint64 | number to encode |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| encoded | string | zero-padded string representation of the number |

---

<a id="endexternalincentive"></a>

### EndExternalIncentive

```go

func EndExternalIncentive(cur realm, targetPoolPath string, incentiveId string)

```

EndExternalIncentive terminates an external incentive early.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| cur | realm |  |
| targetPoolPath | string | path of the pool |
| incentiveId | string | ID of the incentive to end |

---

<a id="getallowedtokens"></a>

### GetAllowedTokens

```go

func GetAllowedTokens() []string

```

GetAllowedTokens returns the allowed external incentive tokens.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| tokens | []string | list of allowed token paths |

---

<a id="getcreatedheightofincentive"></a>

### GetCreatedHeightOfIncentive

```go

func GetCreatedHeightOfIncentive(poolPath string, incentiveId string) int64

```

GetCreatedHeightOfIncentive returns the block height when an incentive was created.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| poolPath | string | path of the pool |
| incentiveId | string | ID of the incentive |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| height | int64 | block height at creation |

---

<a id="getdepositcollectedexternalreward"></a>

### GetDepositCollectedExternalReward

```go

func GetDepositCollectedExternalReward(lpTokenId uint64, incentiveId string) int64

```

GetDepositCollectedExternalReward returns the collected external reward amount of a position.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| lpTokenId | uint64 | ID of the LP token position |
| incentiveId | string | ID of the incentive |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| amount | int64 | collected external reward amount |

---

<a id="getdepositcollectedinternalreward"></a>

### GetDepositCollectedInternalReward

```go

func GetDepositCollectedInternalReward(lpTokenId uint64) int64

```

GetDepositCollectedInternalReward returns the collected internal reward amount of a position.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| lpTokenId | uint64 | ID of the LP token position |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| amount | int64 | collected internal reward amount |

---

<a id="getdepositexternalincentiveidlist"></a>

### GetDepositExternalIncentiveIdList

```go

func GetDepositExternalIncentiveIdList(lpTokenId uint64) []string

```

GetDepositExternalIncentiveIdList returns external incentive IDs for a deposit.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| lpTokenId | uint64 | ID of the LP token position |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| incentiveIds | []string | list of external incentive IDs |

---

<a id="getdepositexternalrewardlastcollecttimestamp"></a>

### GetDepositExternalRewardLastCollectTimestamp

```go

func GetDepositExternalRewardLastCollectTimestamp(lpTokenId uint64, incentiveId string) int64

```

GetDepositExternalRewardLastCollectTimestamp returns the last external reward collection time for a position.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| lpTokenId | uint64 | ID of the LP token position |
| incentiveId | string | ID of the incentive |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| timestamp | int64 | last collection timestamp |

---

<a id="getdepositgnsamount"></a>

### GetDepositGnsAmount

```go

func GetDepositGnsAmount() int64

```

GetDepositGnsAmount returns the required GNS deposit amount for staking.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| amount | int64 | required GNS deposit amount |

---

<a id="getdepositinternalrewardlastcollecttimestamp"></a>

### GetDepositInternalRewardLastCollectTimestamp

```go

func GetDepositInternalRewardLastCollectTimestamp(lpTokenId uint64) int64

```

GetDepositInternalRewardLastCollectTimestamp returns the last internal reward collection time for a position.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| lpTokenId | uint64 | ID of the LP token position |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| timestamp | int64 | last collection timestamp |

---

<a id="getdepositliquidity"></a>

### GetDepositLiquidity

```go

func GetDepositLiquidity(lpTokenId uint64) *u256.Uint

```

GetDepositLiquidity returns the liquidity amount of a staked position.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| lpTokenId | uint64 | ID of the LP token position |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| liquidity | *u256.Uint | liquidity amount |

---

<a id="getdepositliquidityasstring"></a>

### GetDepositLiquidityAsString

```go

func GetDepositLiquidityAsString(lpTokenId uint64) string

```

GetDepositLiquidityAsString returns the liquidity amount of a staked position as string.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| lpTokenId | uint64 | ID of the LP token position |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| liquidity | string | liquidity amount as string |

---

<a id="getdepositowner"></a>

### GetDepositOwner

```go

func GetDepositOwner(lpTokenId uint64) address

```

GetDepositOwner returns the owner of a staked position.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| lpTokenId | uint64 | ID of the LP token position |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| owner | address | owner address |

---

<a id="getdepositstaketime"></a>

### GetDepositStakeTime

```go

func GetDepositStakeTime(lpTokenId uint64) int64

```

GetDepositStakeTime returns the staking duration of a position.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| lpTokenId | uint64 | ID of the LP token position |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| stakeTime | int64 | staking timestamp |

---

<a id="getdeposittargetpoolpath"></a>

### GetDepositTargetPoolPath

```go

func GetDepositTargetPoolPath(lpTokenId uint64) string

```

GetDepositTargetPoolPath returns the pool path of a staked position.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| lpTokenId | uint64 | ID of the LP token position |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| poolPath | string | target pool path |

---

<a id="getdepositticklower"></a>

### GetDepositTickLower

```go

func GetDepositTickLower(lpTokenId uint64) int32

```

GetDepositTickLower returns the lower tick of a staked position.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| lpTokenId | uint64 | ID of the LP token position |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| tickLower | int32 | lower tick boundary |

---

<a id="getdeposittickupper"></a>

### GetDepositTickUpper

```go

func GetDepositTickUpper(lpTokenId uint64) int32

```

GetDepositTickUpper returns the upper tick of a staked position.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| lpTokenId | uint64 | ID of the LP token position |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| tickUpper | int32 | upper tick boundary |

---

<a id="getimplementationpackagepath"></a>

### GetImplementationPackagePath

```go

func GetImplementationPackagePath() string

```

GetImplementationPackagePath returns the package path of the currently active implementation.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| packagePath | string | package path of the active implementation |

---

<a id="getincentivecreatedtimestamp"></a>

### GetIncentiveCreatedTimestamp

```go

func GetIncentiveCreatedTimestamp(poolPath string, incentiveId string) int64

```

GetIncentiveCreatedTimestamp returns the creation timestamp of an incentive.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| poolPath | string | path of the pool |
| incentiveId | string | ID of the incentive |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| timestamp | int64 | creation timestamp |

---

<a id="getincentivedepositgnsamount"></a>

### GetIncentiveDepositGnsAmount

```go

func GetIncentiveDepositGnsAmount(poolPath string, incentiveId string) int64

```

GetIncentiveDepositGnsAmount returns the deposited GNS amount of an incentive.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| poolPath | string | path of the pool |
| incentiveId | string | ID of the incentive |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| amount | int64 | deposited GNS amount |

---

<a id="getincentivedistributedrewardamount"></a>

### GetIncentiveDistributedRewardAmount

```go

func GetIncentiveDistributedRewardAmount(poolPath string, incentiveId string) int64

```

GetIncentiveDistributedRewardAmount returns the distributed reward amount of an incentive.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| poolPath | string | path of the pool |
| incentiveId | string | ID of the incentive |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| amount | int64 | distributed reward amount |

---

<a id="getincentiveendtimestamp"></a>

### GetIncentiveEndTimestamp

```go

func GetIncentiveEndTimestamp(poolPath string, incentiveId string) int64

```

GetIncentiveEndTimestamp returns the end timestamp of an incentive.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| poolPath | string | path of the pool |
| incentiveId | string | ID of the incentive |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| timestamp | int64 | end timestamp |

---

<a id="getincentiverefunded"></a>

### GetIncentiveRefunded

```go

func GetIncentiveRefunded(poolPath string, incentiveId string) bool

```

GetIncentiveRefunded returns whether an incentive has been refunded.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| poolPath | string | path of the pool |
| incentiveId | string | ID of the incentive |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| refunded | bool | true if incentive has been refunded |

---

<a id="getincentiverefundee"></a>

### GetIncentiveRefundee

```go

func GetIncentiveRefundee(poolPath string, incentiveId string) address

```

GetIncentiveRefundee returns the refundee address of an incentive.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| poolPath | string | path of the pool |
| incentiveId | string | ID of the incentive |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| refundee | address | refundee address |

---

<a id="getincentiveremainingrewardamount"></a>

### GetIncentiveRemainingRewardAmount

```go

func GetIncentiveRemainingRewardAmount(poolPath string, incentiveId string) int64

```

GetIncentiveRemainingRewardAmount returns the remaining reward amount of an incentive.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| poolPath | string | path of the pool |
| incentiveId | string | ID of the incentive |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| amount | int64 | remaining reward amount |

---

<a id="getincentiverewardamount"></a>

### GetIncentiveRewardAmount

```go

func GetIncentiveRewardAmount(poolPath string, incentiveId string) *u256.Uint

```

GetIncentiveRewardAmount returns the total reward amount of an incentive.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| poolPath | string | path of the pool |
| incentiveId | string | ID of the incentive |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| amount | *u256.Uint | total reward amount |

---

<a id="getincentiverewardamountasstring"></a>

### GetIncentiveRewardAmountAsString

```go

func GetIncentiveRewardAmountAsString(poolPath string, incentiveId string) string

```

GetIncentiveRewardAmountAsString returns the total reward amount of an incentive as string.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| poolPath | string | path of the pool |
| incentiveId | string | ID of the incentive |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| amount | string | total reward amount as string |

---

<a id="getincentiverewardpersecond"></a>

### GetIncentiveRewardPerSecond

```go

func GetIncentiveRewardPerSecond(poolPath string, incentiveId string) int64

```

GetIncentiveRewardPerSecond returns the reward rate per second of an incentive.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| poolPath | string | path of the pool |
| incentiveId | string | ID of the incentive |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| rate | int64 | reward per second |

---

<a id="getincentiverewardtoken"></a>

### GetIncentiveRewardToken

```go

func GetIncentiveRewardToken(poolPath string, incentiveId string) string

```

GetIncentiveRewardToken returns the reward token of an incentive.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| poolPath | string | path of the pool |
| incentiveId | string | ID of the incentive |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| tokenPath | string | reward token path |

---

<a id="getincentivestarttimestamp"></a>

### GetIncentiveStartTimestamp

```go

func GetIncentiveStartTimestamp(poolPath string, incentiveId string) int64

```

GetIncentiveStartTimestamp returns the start timestamp of an incentive.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| poolPath | string | path of the pool |
| incentiveId | string | ID of the incentive |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| timestamp | int64 | start timestamp |

---

<a id="getincentivetotalrewardamount"></a>

### GetIncentiveTotalRewardAmount

```go

func GetIncentiveTotalRewardAmount(poolPath string, incentiveId string) int64

```

GetIncentiveTotalRewardAmount returns the total reward amount of an incentive.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| poolPath | string | path of the pool |
| incentiveId | string | ID of the incentive |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| amount | int64 | total reward amount |

---

<a id="getminimumrewardamount"></a>

### GetMinimumRewardAmount

```go

func GetMinimumRewardAmount() int64

```

GetMinimumRewardAmount returns the minimum reward amount to distribute.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| amount | int64 | minimum reward amount |

---

<a id="getminimumrewardamountfortoken"></a>

### GetMinimumRewardAmountForToken

```go

func GetMinimumRewardAmountForToken(tokenPath string) int64

```

GetMinimumRewardAmountForToken returns the minimum reward amount for a specific token.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| tokenPath | string | path of the token |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| amount | int64 | minimum reward amount for the token |

---

<a id="getpoolglobalrewardratioaccumulation"></a>

### GetPoolGlobalRewardRatioAccumulation

```go

func GetPoolGlobalRewardRatioAccumulation(poolPath string, timestamp uint64) *u256.Uint

```

GetPoolGlobalRewardRatioAccumulation returns the global reward ratio accumulation at a specific timestamp for a pool.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| poolPath | string | path of the pool |
| timestamp | uint64 | accumulation timestamp |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| ratio | *u256.Uint | global reward ratio accumulation |

---

<a id="getpoolglobalrewardratioaccumulationcount"></a>

### GetPoolGlobalRewardRatioAccumulationCount

```go

func GetPoolGlobalRewardRatioAccumulationCount(poolPath string) uint64

```

GetPoolGlobalRewardRatioAccumulationCount returns the number of global reward ratio accumulation entries for a pool.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| poolPath | string | path of the pool |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| count | uint64 | number of accumulation entries |

---

<a id="getpoolglobalrewardratioaccumulationids"></a>

### GetPoolGlobalRewardRatioAccumulationIDs

```go

func GetPoolGlobalRewardRatioAccumulationIDs(poolPath string, offset int, count int) []uint64

```

GetPoolGlobalRewardRatioAccumulationIDs returns a paginated list of timestamps for global reward ratio accumulation entries.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| poolPath | string | path of the pool |
| offset | int | starting index |
| count | int | number of entries to return |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| timestamps | []uint64 | list of accumulation timestamps |

---

<a id="getpoolhistoricaltick"></a>

### GetPoolHistoricalTick

```go

func GetPoolHistoricalTick(poolPath string, tick uint64) int32

```

GetPoolHistoricalTick returns the historical tick at a specific timestamp for a pool.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| poolPath | string | path of the pool |
| tick | uint64 | tick index |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| tick | int32 | historical tick value |

---

<a id="getpoolhistoricaltickcount"></a>

### GetPoolHistoricalTickCount

```go

func GetPoolHistoricalTickCount(poolPath string) uint64

```

GetPoolHistoricalTickCount returns the number of historical tick entries for a pool.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| poolPath | string | path of the pool |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| count | uint64 | number of historical tick entries |

---

<a id="getpoolhistoricaltickids"></a>

### GetPoolHistoricalTickIDs

```go

func GetPoolHistoricalTickIDs(poolPath string, offset int, count int) []int32

```

GetPoolHistoricalTickIDs returns a paginated list of historical tick values for a pool.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| poolPath | string | path of the pool |
| offset | int | starting index |
| count | int | number of entries to return |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| ticks | []int32 | list of historical tick values |

---

<a id="getpoolincentivecount"></a>

### GetPoolIncentiveCount

```go

func GetPoolIncentiveCount(poolPath string) uint64

```

GetPoolIncentiveCount returns the number of incentives for a pool.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| poolPath | string | path of the pool |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| count | uint64 | number of incentives |

---

<a id="getpoolincentiveids"></a>

### GetPoolIncentiveIDs

```go

func GetPoolIncentiveIDs(poolPath string, offset int, count int) []string

```

GetPoolIncentiveIDs returns a paginated list of incentive IDs for a pool.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| poolPath | string | path of the pool |
| offset | int | starting index |
| count | int | number of IDs to return |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| incentiveIds | []string | list of incentive IDs |

---

<a id="getpoolincentiveidlist"></a>

### GetPoolIncentiveIdList

```go

func GetPoolIncentiveIdList(poolPath string) []string

```

GetPoolIncentiveIdList returns all incentive IDs for a pool.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| poolPath | string | path of the pool |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| incentiveIds | []string | list of incentive IDs |

---

<a id="getpoolreward"></a>

### GetPoolReward

```go

func GetPoolReward(tier uint64) int64

```

GetPoolReward returns the reward amount for a tier.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| tier | uint64 | tier level |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| reward | int64 | reward amount for the tier |

---

<a id="getpoolrewardcache"></a>

### GetPoolRewardCache

```go

func GetPoolRewardCache(poolPath string, timestamp uint64) int64

```

GetPoolRewardCache returns the reward cache value at a specific timestamp for a pool.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| poolPath | string | path of the pool |
| timestamp | uint64 | cache timestamp |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| reward | int64 | cached reward value |

---

<a id="getpoolrewardcachecount"></a>

### GetPoolRewardCacheCount

```go

func GetPoolRewardCacheCount(poolPath string) uint64

```

GetPoolRewardCacheCount returns the number of reward cache entries for a pool.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| poolPath | string | path of the pool |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| count | uint64 | number of reward cache entries |

---

<a id="getpoolrewardcacheids"></a>

### GetPoolRewardCacheIDs

```go

func GetPoolRewardCacheIDs(poolPath string, offset int, count int) []int64

```

GetPoolRewardCacheIDs returns a paginated list of reward cache timestamps for a pool.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| poolPath | string | path of the pool |
| offset | int | starting index |
| count | int | number of entries to return |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| timestamps | []int64 | list of reward cache timestamps |

---

<a id="getpoolstakedliquidity"></a>

### GetPoolStakedLiquidity

```go

func GetPoolStakedLiquidity(poolPath string) string

```

GetPoolStakedLiquidity returns the current total staked liquidity of a pool.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| poolPath | string | path of the pool |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| liquidity | string | total staked liquidity as string |

---

<a id="getpooltier"></a>

### GetPoolTier

```go

func GetPoolTier(poolPath string) uint64

```

GetPoolTier returns the tier of a pool.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| poolPath | string | path of the pool |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| tier | uint64 | tier level |

---

<a id="getpooltiercount"></a>

### GetPoolTierCount

```go

func GetPoolTierCount(tier uint64) uint64

```

GetPoolTierCount returns the number of pools in a tier.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| tier | uint64 | tier level |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| count | uint64 | number of pools |

---

<a id="getpooltierratio"></a>

### GetPoolTierRatio

```go

func GetPoolTierRatio(poolPath string) uint64

```

GetPoolTierRatio returns the reward ratio of a pool.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| poolPath | string | path of the pool |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| ratio | uint64 | reward ratio |

---

<a id="getpoolsbytier"></a>

### GetPoolsByTier

```go

func GetPoolsByTier(tier uint64) []string

```

GetPoolsByTier returns the pool list for a tier.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| tier | uint64 | tier level |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| pools | []string | list of pool paths |

---

<a id="getspecifictokenminimumrewardamount"></a>

### GetSpecificTokenMinimumRewardAmount

```go

func GetSpecificTokenMinimumRewardAmount(tokenPath string) (int64, bool)

```

GetSpecificTokenMinimumRewardAmount returns the minimum reward amount for a specific token.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| tokenPath | string | path of the token |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| amount | int64 | minimum reward amount |
| exists | bool | true if token has specific minimum |

---

<a id="getstakedpositionsbyuser"></a>

### GetStakedPositionsByUser

```go

func GetStakedPositionsByUser(owner address, offset int, count int) []uint64

```

GetStakedPositionsByUser returns staked position IDs for a user with pagination.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| owner | address | owner address |
| offset | int | starting index |
| count | int | number of positions to return |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| positionIds | []uint64 | list of staked position IDs |

---

<a id="gettargetpoolpathbyincentiveid"></a>

### GetTargetPoolPathByIncentiveId

```go

func GetTargetPoolPathByIncentiveId(poolPath string, incentiveId string) string

```

GetTargetPoolPathByIncentiveId returns the pool path for an incentive ID.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| poolPath | string | path of the pool |
| incentiveId | string | ID of the incentive |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| targetPoolPath | string | target pool path |

---

<a id="gettotalemissionsent"></a>

### GetTotalEmissionSent

```go

func GetTotalEmissionSent() int64

```

GetTotalEmissionSent returns the total GNS emission sent.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| amount | int64 | total GNS emission sent |

---

<a id="gettotalstakedusercount"></a>

### GetTotalStakedUserCount

```go

func GetTotalStakedUserCount() uint64

```

GetTotalStakedUserCount returns the total number of staked users.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| count | uint64 | total number of users with staked positions |

---

<a id="gettotalstakeduserpositioncount"></a>

### GetTotalStakedUserPositionCount

```go

func GetTotalStakedUserPositionCount(user address) uint64

```

GetTotalStakedUserPositionCount returns the staked position count for a user.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| user | address | user address |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| count | uint64 | number of staked positions |

---

<a id="getunstakingfee"></a>

### GetUnstakingFee

```go

func GetUnstakingFee() int64

```

GetUnstakingFee returns the unstaking fee percentage.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| fee | int64 | unstaking fee percentage |

---

<a id="isincentiveactive"></a>

### IsIncentiveActive

```go

func IsIncentiveActive(poolPath string, incentiveId string) bool

```

IsIncentiveActive returns whether an incentive is active.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| poolPath | string | path of the pool |
| incentiveId | string | ID of the incentive |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| active | bool | true if incentive is active |

---

<a id="isstaked"></a>

### IsStaked

```go

func IsStaked(positionId uint64) bool

```

IsStaked returns whether a position is staked.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| positionId | uint64 | ID of the position |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| staked | bool | true if position is staked |

---

<a id="mintandstake"></a>

### MintAndStake

```go

func MintAndStake(cur realm, token0 string, token1 string, fee uint32, tickLower int32, tickUpper int32, amount0Desired string, amount1Desired string, amount0Min string, amount1Min string, deadline int64, referrer string) (uint64, string, string, string, string)

```

MintAndStake creates a new position and immediately stakes it.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| cur | realm |  |
| token0 | string | path of the first token |
| token1 | string | path of the second token |
| fee | uint32 | pool fee tier |
| tickLower | int32 | lower tick boundary |
| tickUpper | int32 | upper tick boundary |
| amount0Desired | string | desired amount of token0 |
| amount1Desired | string | desired amount of token1 |
| amount0Min | string | minimum amount of token0 |
| amount1Min | string | minimum amount of token1 |
| deadline | int64 | transaction deadline |
| referrer | string | referrer address for reward tracking |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| positionId | uint64 | position ID |
| liquidity | string | liquidity amount |
| amount0 | string | amount of token0 added |
| amount1 | string | amount of token1 added |
| stakeDetail | string | staking details |

---

<a id="registerinitializer"></a>

### RegisterInitializer

```go

func RegisterInitializer(cur realm, initializer func(...))

```

RegisterInitializer registers a new staker implementation version.
This function is called by each version (v1, v2, etc.) during initialization
to register their implementation with the proxy system.

The initializer function creates a new instance of the implementation
using the provided stakerStore interface.

Security: Only contracts within the domain path can register initializers.
Each package path can only register once to prevent duplicate registrations.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| cur | realm |  |
| initializer | func(...) |  |

---

<a id="removepooltier"></a>

### RemovePoolTier

```go

func RemovePoolTier(cur realm, poolPath string)

```

RemovePoolTier removes a pool from the tier system.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| cur | realm |  |
| poolPath | string | path of the pool |

---

<a id="removetoken"></a>

### RemoveToken

```go

func RemoveToken(cur realm, tokenPath string)

```

RemoveToken removes a token from the reward token whitelist.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| cur | realm |  |
| tokenPath | string | path of the token to remove |

---

<a id="setdepositgnsamount"></a>

### SetDepositGnsAmount

```go

func SetDepositGnsAmount(cur realm, amount int64)

```

SetDepositGnsAmount sets the required GNS deposit amount for staking.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| cur | realm |  |
| amount | int64 | required GNS amount |

---

<a id="setminimumrewardamount"></a>

### SetMinimumRewardAmount

```go

func SetMinimumRewardAmount(cur realm, amount int64)

```

SetMinimumRewardAmount sets the minimum reward amount to distribute.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| cur | realm |  |
| amount | int64 | minimum reward amount |

---

<a id="setpooltier"></a>

### SetPoolTier

```go

func SetPoolTier(cur realm, poolPath string, tier uint64)

```

SetPoolTier sets the reward tier for a pool.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| cur | realm |  |
| poolPath | string | path of the pool |
| tier | uint64 | reward tier level |

---

<a id="settokenminimumrewardamount"></a>

### SetTokenMinimumRewardAmount

```go

func SetTokenMinimumRewardAmount(cur realm, paramsStr string)

```

SetTokenMinimumRewardAmount sets minimum reward amounts per token.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| cur | realm |  |
| paramsStr | string | encoded parameters for token minimum amounts |

---

<a id="setunstakingfee"></a>

### SetUnStakingFee

```go

func SetUnStakingFee(cur realm, fee int64)

```

SetUnStakingFee sets the unstaking fee percentage.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| cur | realm |  |
| fee | int64 | unstaking fee percentage |

---

<a id="setwarmup"></a>

### SetWarmUp

```go

func SetWarmUp(cur realm, pct int64, timeDuration int64)

```

SetWarmUp sets the warm-up period parameters for staking.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| cur | realm |  |
| pct | int64 | warmup percentage |
| timeDuration | int64 | warmup time duration in seconds |

---

<a id="staketoken"></a>

### StakeToken

```go

func StakeToken(cur realm, positionId uint64, referrer string) string

```

StakeToken stakes a position NFT to earn rewards.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| cur | realm |  |
| positionId | uint64 | ID of the position to stake |
| referrer | string | referrer address for reward tracking |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| depositId | string | deposit ID |

---

<a id="unstaketoken"></a>

### UnStakeToken

```go

func UnStakeToken(cur realm, positionId uint64, unwrapResult bool) string

```

UnStakeToken unstakes a position NFT and collects rewards.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| cur | realm |  |
| positionId | uint64 | ID of the position to unstake |
| unwrapResult | bool | whether to unwrap WGNOT to GNOT |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| rewardDetail | string | collected reward details |

---

<a id="upgradeimpl"></a>

### UpgradeImpl

```go

func UpgradeImpl(cur realm, packagePath string)

```

UpgradeImpl switches the active staker implementation to a different version.
This function allows seamless upgrades from one version to another without
data migration or downtime.

Security: Only admin or governance can perform upgrades.
The new implementation must have been previously registered via RegisterInitializer.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| cur | realm |  |
| packagePath | string |  |


## Types

<a id="counter"></a>

### Counter

```go

type Counter struct

```

#### Methods

<a id="counter.get"></a>
##### Get

```go
func (c *Counter) Get() int64
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int64 |  |

<a id="counter.next"></a>
##### Next

```go
func (c *Counter) Next() int64
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int64 |  |


#### Constructors

- `func NewCounter() *Counter`

---

<a id="deposit"></a>

### Deposit

```go

type Deposit struct

```

#### Methods

<a id="deposit.addexternalincentiveid"></a>
##### AddExternalIncentiveId

```go
func (d *Deposit) AddExternalIncentiveId(incentiveId string)
```

AddExternalIncentiveId adds an external incentive id to the deposit.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| incentiveId | string |  |

<a id="deposit.clone"></a>
##### Clone

```go
func (d *Deposit) Clone() *Deposit
```

Clone returns a deep copy of the deposit.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | *Deposit |  |

<a id="deposit.collectedexternalrewards"></a>
##### CollectedExternalRewards

```go
func (d *Deposit) CollectedExternalRewards() *avl.Tree
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | *avl.Tree |  |

<a id="deposit.collectedinternalreward"></a>
##### CollectedInternalReward

```go
func (d *Deposit) CollectedInternalReward() int64
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int64 |  |

<a id="deposit.externalincentiveids"></a>
##### ExternalIncentiveIds

```go
func (d *Deposit) ExternalIncentiveIds() *avl.Tree
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | *avl.Tree |  |

<a id="deposit.externalrewardlastcollecttimes"></a>
##### ExternalRewardLastCollectTimes

```go
func (d *Deposit) ExternalRewardLastCollectTimes() *avl.Tree
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | *avl.Tree |  |

<a id="deposit.getcollectedexternalreward"></a>
##### GetCollectedExternalReward

```go
func (d *Deposit) GetCollectedExternalReward(incentiveID string) (int64, bool)
```

GetCollectedExternalReward returns the collected external reward for the given incentive ID.
Returns 0 if the incentive ID does not exist.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| incentiveID | string |  |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int64 |  |
|  | bool |  |

<a id="deposit.getexternalincentiveidlist"></a>
##### GetExternalIncentiveIdList

```go
func (d *Deposit) GetExternalIncentiveIdList() []string
```

GetExternalIncentiveIdList returns a list of external incentive ids for the deposit.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | []string |  |

<a id="deposit.getexternalrewardlastcollecttime"></a>
##### GetExternalRewardLastCollectTime

```go
func (d *Deposit) GetExternalRewardLastCollectTime(incentiveID string) (int64, bool)
```

GetExternalRewardLastCollectTime returns the last collect time for the given incentive ID.
Returns 0 if the incentive ID does not exist.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| incentiveID | string |  |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int64 |  |
|  | bool |  |

<a id="deposit.hasexternalincentiveid"></a>
##### HasExternalIncentiveId

```go
func (d *Deposit) HasExternalIncentiveId(incentiveId string) bool
```

HasExternalIncentiveId checks if the deposit has the given external incentive id.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| incentiveId | string |  |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | bool |  |

<a id="deposit.internalrewardlastcollecttime"></a>
##### InternalRewardLastCollectTime

```go
func (d *Deposit) InternalRewardLastCollectTime() int64
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int64 |  |

<a id="deposit.iterateexternalincentiveids"></a>
##### IterateExternalIncentiveIds

```go
func (d *Deposit) IterateExternalIncentiveIds(fn func(...))
```

IterateExternalIncentiveIds iterates over external incentive IDs without allocating a slice.
The callback function receives each incentive ID and should return false to continue iteration,
or true to stop early. This method is more memory-efficient than GetExternalIncentiveIdList
for cases where you only need to process IDs sequentially.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| fn | func(...) |  |

<a id="deposit.lastexternalincentiveupdatedat"></a>
##### LastExternalIncentiveUpdatedAt

```go
func (d *Deposit) LastExternalIncentiveUpdatedAt() int64
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int64 |  |

<a id="deposit.liquidity"></a>
##### Liquidity

```go
func (d *Deposit) Liquidity() *u256.Uint
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | *u256.Uint |  |

<a id="deposit.owner"></a>
##### Owner

```go
func (d *Deposit) Owner() address
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | address |  |

<a id="deposit.removeexternalincentiveid"></a>
##### RemoveExternalIncentiveId

```go
func (d *Deposit) RemoveExternalIncentiveId(incentiveId string)
```

RemoveExternalIncentiveId removes an external incentive id from the deposit.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| incentiveId | string |  |

<a id="deposit.setcollectedexternalreward"></a>
##### SetCollectedExternalReward

```go
func (d *Deposit) SetCollectedExternalReward(incentiveID string, reward int64)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| incentiveID | string |  |
| reward | int64 |  |

<a id="deposit.setcollectedexternalrewards"></a>
##### SetCollectedExternalRewards

```go
func (d *Deposit) SetCollectedExternalRewards(collectedExternalRewards *avl.Tree)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| collectedExternalRewards | *avl.Tree |  |

<a id="deposit.setcollectedinternalreward"></a>
##### SetCollectedInternalReward

```go
func (d *Deposit) SetCollectedInternalReward(collectedInternalReward int64)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| collectedInternalReward | int64 |  |

<a id="deposit.setexternalincentiveids"></a>
##### SetExternalIncentiveIds

```go
func (d *Deposit) SetExternalIncentiveIds(externalIncentiveIds *avl.Tree)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| externalIncentiveIds | *avl.Tree |  |

<a id="deposit.setexternalrewardlastcollecttime"></a>
##### SetExternalRewardLastCollectTime

```go
func (d *Deposit) SetExternalRewardLastCollectTime(incentiveID string, currentTime int64)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| incentiveID | string |  |
| currentTime | int64 |  |

<a id="deposit.setexternalrewardlastcollecttimes"></a>
##### SetExternalRewardLastCollectTimes

```go
func (d *Deposit) SetExternalRewardLastCollectTimes(externalRewardLastCollectTimes *avl.Tree)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| externalRewardLastCollectTimes | *avl.Tree |  |

<a id="deposit.setinternalrewardlastcollecttime"></a>
##### SetInternalRewardLastCollectTime

```go
func (d *Deposit) SetInternalRewardLastCollectTime(internalRewardLastCollectTime int64)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| internalRewardLastCollectTime | int64 |  |

<a id="deposit.setlastexternalincentiveupdatedat"></a>
##### SetLastExternalIncentiveUpdatedAt

```go
func (d *Deposit) SetLastExternalIncentiveUpdatedAt(timestamp int64)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| timestamp | int64 |  |

<a id="deposit.setliquidity"></a>
##### SetLiquidity

```go
func (d *Deposit) SetLiquidity(liquidity *u256.Uint)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| liquidity | *u256.Uint |  |

<a id="deposit.setowner"></a>
##### SetOwner

```go
func (d *Deposit) SetOwner(owner address)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| owner | address |  |

<a id="deposit.setstaketime"></a>
##### SetStakeTime

```go
func (d *Deposit) SetStakeTime(stakeTime int64)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| stakeTime | int64 |  |

<a id="deposit.settargetpoolpath"></a>
##### SetTargetPoolPath

```go
func (d *Deposit) SetTargetPoolPath(targetPoolPath string)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| targetPoolPath | string |  |

<a id="deposit.setticklower"></a>
##### SetTickLower

```go
func (d *Deposit) SetTickLower(tickLower int32)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| tickLower | int32 |  |

<a id="deposit.settickupper"></a>
##### SetTickUpper

```go
func (d *Deposit) SetTickUpper(tickUpper int32)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| tickUpper | int32 |  |

<a id="deposit.setwarmups"></a>
##### SetWarmups

```go
func (d *Deposit) SetWarmups(warmups []Warmup)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| warmups | []Warmup |  |

<a id="deposit.staketime"></a>
##### StakeTime

```go
func (d *Deposit) StakeTime() int64
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int64 |  |

<a id="deposit.targetpoolpath"></a>
##### TargetPoolPath

```go
func (d *Deposit) TargetPoolPath() string
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | string |  |

<a id="deposit.ticklower"></a>
##### TickLower

```go
func (d *Deposit) TickLower() int32
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int32 |  |

<a id="deposit.tickupper"></a>
##### TickUpper

```go
func (d *Deposit) TickUpper() int32
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int32 |  |

<a id="deposit.warmups"></a>
##### Warmups

```go
func (d *Deposit) Warmups() []Warmup
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | []Warmup |  |


#### Constructors

- `func GetDeposit(lpTokenId uint64) *Deposit`
- `func NewDeposit(owner address, targetPoolPath string, liquidity *u256.Uint, currentTime int64, tickLower int32, tickUpper int32, warmups []Warmup) *Deposit`

---

<a id="emissionaccessor"></a>

### EmissionAccessor

```go

type EmissionAccessor interface

```

---

<a id="externalincentive"></a>

### ExternalIncentive

```go

type ExternalIncentive struct

```

#### Methods

<a id="externalincentive.clone"></a>
##### Clone

```go
func (e *ExternalIncentive) Clone() *ExternalIncentive
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | *ExternalIncentive |  |

<a id="externalincentive.createdheight"></a>
##### CreatedHeight

```go
func (e *ExternalIncentive) CreatedHeight() int64
```

CreatedHeight returns the created height

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int64 |  |

<a id="externalincentive.createdtimestamp"></a>
##### CreatedTimestamp

```go
func (e *ExternalIncentive) CreatedTimestamp() int64
```

CreatedTimestamp returns the created timestamp

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int64 |  |

<a id="externalincentive.depositgnsamount"></a>
##### DepositGnsAmount

```go
func (e *ExternalIncentive) DepositGnsAmount() int64
```

DepositGnsAmount returns the deposit GNS amount

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int64 |  |

<a id="externalincentive.distributedrewardamount"></a>
##### DistributedRewardAmount

```go
func (e *ExternalIncentive) DistributedRewardAmount() int64
```

DistributedRewardAmount returns the distributed reward amount

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int64 |  |

<a id="externalincentive.endtimestamp"></a>
##### EndTimestamp

```go
func (e *ExternalIncentive) EndTimestamp() int64
```

EndTimestamp returns the end timestamp

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int64 |  |

<a id="externalincentive.incentiveid"></a>
##### IncentiveId

```go
func (e *ExternalIncentive) IncentiveId() string
```

IncentiveId returns the incentive ID

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | string |  |

<a id="externalincentive.isrequestunwrap"></a>
##### IsRequestUnwrap

```go
func (e *ExternalIncentive) IsRequestUnwrap() bool
```

IsRequestUnwrap returns the request unwrap status

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | bool |  |

<a id="externalincentive.refunded"></a>
##### Refunded

```go
func (e *ExternalIncentive) Refunded() bool
```

Refunded returns the refunded status

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | bool |  |

<a id="externalincentive.refundee"></a>
##### Refundee

```go
func (e *ExternalIncentive) Refundee() address
```

Refundee returns the refundee address

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | address |  |

<a id="externalincentive.rewardamount"></a>
##### RewardAmount

```go
func (e *ExternalIncentive) RewardAmount() int64
```

RewardAmount returns the reward amount

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int64 |  |

<a id="externalincentive.rewardpersecond"></a>
##### RewardPerSecond

```go
func (e *ExternalIncentive) RewardPerSecond() int64
```

RewardPerSecond returns the reward per second

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int64 |  |

<a id="externalincentive.rewardtoken"></a>
##### RewardToken

```go
func (e *ExternalIncentive) RewardToken() string
```

RewardToken returns the reward token

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | string |  |

<a id="externalincentive.setcreatedheight"></a>
##### SetCreatedHeight

```go
func (e *ExternalIncentive) SetCreatedHeight(createdHeight int64)
```

SetCreatedHeight sets the created height

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| createdHeight | int64 |  |

<a id="externalincentive.setcreatedtimestamp"></a>
##### SetCreatedTimestamp

```go
func (e *ExternalIncentive) SetCreatedTimestamp(createdTimestamp int64)
```

SetCreatedTimestamp sets the created timestamp

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| createdTimestamp | int64 |  |

<a id="externalincentive.setdepositgnsamount"></a>
##### SetDepositGnsAmount

```go
func (e *ExternalIncentive) SetDepositGnsAmount(depositGnsAmount int64)
```

SetDepositGnsAmount sets the deposit GNS amount

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| depositGnsAmount | int64 |  |

<a id="externalincentive.setdistributedrewardamount"></a>
##### SetDistributedRewardAmount

```go
func (e *ExternalIncentive) SetDistributedRewardAmount(distributedRewardAmount int64)
```

SetDistributedRewardAmount sets the distributed reward amount

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| distributedRewardAmount | int64 |  |

<a id="externalincentive.setendtimestamp"></a>
##### SetEndTimestamp

```go
func (e *ExternalIncentive) SetEndTimestamp(endTimestamp int64)
```

SetEndTimestamp sets the end timestamp

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| endTimestamp | int64 |  |

<a id="externalincentive.setincentiveid"></a>
##### SetIncentiveId

```go
func (e *ExternalIncentive) SetIncentiveId(incentiveId string)
```

SetIncentiveId sets the incentive ID

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| incentiveId | string |  |

<a id="externalincentive.setisrequestunwrap"></a>
##### SetIsRequestUnwrap

```go
func (e *ExternalIncentive) SetIsRequestUnwrap(isRequestUnwrap bool)
```

SetIsRequestUnwrap sets the request unwrap status

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| isRequestUnwrap | bool |  |

<a id="externalincentive.setrefunded"></a>
##### SetRefunded

```go
func (e *ExternalIncentive) SetRefunded(refunded bool)
```

SetRefunded sets the refunded status

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| refunded | bool |  |

<a id="externalincentive.setrefundee"></a>
##### SetRefundee

```go
func (e *ExternalIncentive) SetRefundee(refundee address)
```

SetRefundee sets the refundee address

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| refundee | address |  |

<a id="externalincentive.setrewardamount"></a>
##### SetRewardAmount

```go
func (e *ExternalIncentive) SetRewardAmount(rewardAmount int64)
```

SetRewardAmount sets the reward amount

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| rewardAmount | int64 |  |

<a id="externalincentive.setrewardpersecond"></a>
##### SetRewardPerSecond

```go
func (e *ExternalIncentive) SetRewardPerSecond(rewardPerSecond int64)
```

SetRewardPerSecond sets the reward per second

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| rewardPerSecond | int64 |  |

<a id="externalincentive.setrewardtoken"></a>
##### SetRewardToken

```go
func (e *ExternalIncentive) SetRewardToken(rewardToken string)
```

SetRewardToken sets the reward token

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| rewardToken | string |  |

<a id="externalincentive.setstarttimestamp"></a>
##### SetStartTimestamp

```go
func (e *ExternalIncentive) SetStartTimestamp(startTimestamp int64)
```

SetStartTimestamp sets the start timestamp

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| startTimestamp | int64 |  |

<a id="externalincentive.settargetpoolpath"></a>
##### SetTargetPoolPath

```go
func (e *ExternalIncentive) SetTargetPoolPath(targetPoolPath string)
```

SetTargetPoolPath sets the target pool path

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| targetPoolPath | string |  |

<a id="externalincentive.settotalrewardamount"></a>
##### SetTotalRewardAmount

```go
func (e *ExternalIncentive) SetTotalRewardAmount(totalRewardAmount int64)
```

SetTotalRewardAmount sets the total reward amount

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| totalRewardAmount | int64 |  |

<a id="externalincentive.starttimestamp"></a>
##### StartTimestamp

```go
func (e *ExternalIncentive) StartTimestamp() int64
```

StartTimestamp returns the start timestamp

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int64 |  |

<a id="externalincentive.targetpoolpath"></a>
##### TargetPoolPath

```go
func (e *ExternalIncentive) TargetPoolPath() string
```

TargetPoolPath returns the target pool path

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | string |  |

<a id="externalincentive.totalrewardamount"></a>
##### TotalRewardAmount

```go
func (e *ExternalIncentive) TotalRewardAmount() int64
```

TotalRewardAmount returns the total reward amount

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int64 |  |


#### Constructors

- `func GetExternalIncentiveByPoolPath(poolPath string) []ExternalIncentive`
- `func GetIncentive(poolPath string, incentiveId string) *ExternalIncentive`
- `func NewExternalIncentive(incentiveId string, targetPoolPath string, rewardToken string, rewardAmount int64, startTimestamp int64, endTimestamp int64, refundee address, depositGnsAmount int64, createdHeight int64, currentTime int64, isRequestUnwrap bool) *ExternalIncentive`

---

<a id="istaker"></a>

### IStaker

```go

type IStaker interface

```

---

<a id="istakergetter"></a>

### IStakerGetter

```go

type IStakerGetter interface

```

---

<a id="istakermanager"></a>

### IStakerManager

```go

type IStakerManager interface

```

---

<a id="istakerstore"></a>

### IStakerStore

```go

type IStakerStore interface

```

#### Constructors

- `func NewStakerStore(kvStore store.KVStore) IStakerStore`

---

<a id="incentives"></a>

### Incentives

```go

type Incentives struct

```

Incentives represents a collection of external incentives for a specific pool.

Fields:

  - incentives: AVL tree storing ExternalIncentive objects indexed by incentiveId
    The incentiveId serves as the key to efficiently lookup incentive details

  - targetPoolPath: String identifier for the pool this incentive collection belongs to
    Used to associate incentives with their corresponding liquidity pool

  - unclaimablePeriods: Tree storing periods when rewards cannot be claimed
    Maps start timestamp (key) to end timestamp (value)
    An end timestamp of 0 indicates an ongoing unclaimable period
    Used to track intervals when staking rewards are not claimable

#### Methods

<a id="incentives.incentive"></a>
##### Incentive

```go
func (i *Incentives) Incentive(incentiveId string) (*ExternalIncentive, bool)
```

Incentive returns an incentive by ID

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| incentiveId | string |  |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | *ExternalIncentive |  |
|  | bool |  |

<a id="incentives.incentivetrees"></a>
##### IncentiveTrees

```go
func (i *Incentives) IncentiveTrees() *avl.Tree
```

Incentives returns the incentives tree

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | *avl.Tree |  |

<a id="incentives.iterateincentives"></a>
##### IterateIncentives

```go
func (i *Incentives) IterateIncentives(fn func(...))
```

IterateIncentives iterates over all incentives

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| fn | func(...) |  |

<a id="incentives.setincentive"></a>
##### SetIncentive

```go
func (i *Incentives) SetIncentive(incentiveId string, incentive *ExternalIncentive)
```

SetIncentive sets an incentive by ID

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| incentiveId | string |  |
| incentive | *ExternalIncentive |  |

<a id="incentives.setincentives"></a>
##### SetIncentives

```go
func (i *Incentives) SetIncentives(incentives *avl.Tree)
```

SetIncentives sets the incentives tree

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| incentives | *avl.Tree |  |

<a id="incentives.settargetpoolpath"></a>
##### SetTargetPoolPath

```go
func (i *Incentives) SetTargetPoolPath(targetPoolPath string)
```

SetTargetPoolPath sets the target pool path

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| targetPoolPath | string |  |

<a id="incentives.setunclaimableperiods"></a>
##### SetUnclaimablePeriods

```go
func (i *Incentives) SetUnclaimablePeriods(unclaimablePeriods *UintTree)
```

SetUnclaimablePeriods sets the unclaimable periods tree

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| unclaimablePeriods | *UintTree |  |

<a id="incentives.targetpoolpath"></a>
##### TargetPoolPath

```go
func (i *Incentives) TargetPoolPath() string
```

TargetPoolPath returns the target pool path

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | string |  |

<a id="incentives.unclaimableperiods"></a>
##### UnclaimablePeriods

```go
func (i *Incentives) UnclaimablePeriods() *UintTree
```

UnclaimablePeriods returns the unclaimable periods tree

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | *UintTree |  |


#### Constructors

- `func NewIncentives(targetPoolPath string) *Incentives`

---

<a id="nftaccessor"></a>

### NFTAccessor

```go

type NFTAccessor interface

```

---

<a id="pool"></a>

### Pool

```go

type Pool struct

```

Pool is a struct for storing an incentivized pool information
Each pool stores Incentives and Ticks associated with it.

Fields:
- poolPath: The path of the pool.

  - currentStakedLiquidity:
    The current total staked liquidity of the in-range positions for the pool.
    Updated when tick cross happens or stake/unstake happens.
    Used to calculate the global reward ratio accumulation or
    decide whether to enter/exit unclaimable period.

  - lastUnclaimableTime:
    The time at which the unclaimable period started.
    Set to 0 when the pool is not in an unclaimable period.

  - unclaimableAcc:
    The accumulated undisributed unclaimable reward.
    Reset to 0 when processUnclaimableReward is called and sent to community pool.

  - rewardCache:
    The cached per-second reward emitted for this pool.
    Stores new entry only when the reward is changed.
    PoolTier.cacheReward() updates this.

- incentives: The external incentives associated with the pool.

- ticks: The Ticks associated with the pool.

  - globalRewardRatioAccumulation:
    Global ratio of Time / TotalStake accumulation(since the pool creation)
    Stores new entry only when tick cross or stake/unstake happens.
    It is used to calculate the reward for a staked position at certain time.

  - historicalTick:
    The historical tick for the pool at a given time.
    It does not reflect the exact tick at the timestamp,
    but it provides correct ordering for the staked position's ticks.
    Therefore, you should not compare it for equality, only for ordering.
    Set when tick cross happens or a new position is created.

#### Methods

<a id="pool.clone"></a>
##### Clone

```go
func (p *Pool) Clone() *Pool
```

Clone returns a deep copy of the pool.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | *Pool |  |

<a id="pool.globalrewardratioaccumulation"></a>
##### GlobalRewardRatioAccumulation

```go
func (p *Pool) GlobalRewardRatioAccumulation() *UintTree
```

GlobalRewardRatioAccumulation returns the global reward ratio accumulation tree

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | *UintTree |  |

<a id="pool.historicaltick"></a>
##### HistoricalTick

```go
func (p *Pool) HistoricalTick() *UintTree
```

HistoricalTick returns the historical tick tree

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | *UintTree |  |

<a id="pool.incentives"></a>
##### Incentives

```go
func (p *Pool) Incentives() *Incentives
```

Incentives returns the incentives

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | *Incentives |  |

<a id="pool.lastunclaimabletime"></a>
##### LastUnclaimableTime

```go
func (p *Pool) LastUnclaimableTime() int64
```

LastUnclaimableTime returns the last unclaimable time

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int64 |  |

<a id="pool.poolpath"></a>
##### PoolPath

```go
func (p *Pool) PoolPath() string
```

PoolPath returns the pool path

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | string |  |

<a id="pool.rewardcache"></a>
##### RewardCache

```go
func (p *Pool) RewardCache() *UintTree
```

RewardCache returns the reward cache tree

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | *UintTree |  |

<a id="pool.setglobalrewardratioaccumulation"></a>
##### SetGlobalRewardRatioAccumulation

```go
func (p *Pool) SetGlobalRewardRatioAccumulation(globalRewardRatioAccumulation *UintTree)
```

SetGlobalRewardRatioAccumulation sets the global reward ratio accumulation tree

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| globalRewardRatioAccumulation | *UintTree |  |

<a id="pool.sethistoricaltick"></a>
##### SetHistoricalTick

```go
func (p *Pool) SetHistoricalTick(historicalTick *UintTree)
```

SetHistoricalTick sets the historical tick tree

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| historicalTick | *UintTree |  |

<a id="pool.setincentives"></a>
##### SetIncentives

```go
func (p *Pool) SetIncentives(incentives *Incentives)
```

SetIncentives sets the incentives

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| incentives | *Incentives |  |

<a id="pool.setlastunclaimabletime"></a>
##### SetLastUnclaimableTime

```go
func (p *Pool) SetLastUnclaimableTime(lastUnclaimableTime int64)
```

SetLastUnclaimableTime sets the last unclaimable time

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| lastUnclaimableTime | int64 |  |

<a id="pool.setpoolpath"></a>
##### SetPoolPath

```go
func (p *Pool) SetPoolPath(poolPath string)
```

SetPoolPath sets the pool path

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| poolPath | string |  |

<a id="pool.setrewardcache"></a>
##### SetRewardCache

```go
func (p *Pool) SetRewardCache(rewardCache *UintTree)
```

SetRewardCache sets the reward cache tree

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| rewardCache | *UintTree |  |

<a id="pool.setstakedliquidity"></a>
##### SetStakedLiquidity

```go
func (p *Pool) SetStakedLiquidity(stakedLiquidity *UintTree)
```

SetStakedLiquidity sets the staked liquidity tree

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| stakedLiquidity | *UintTree |  |

<a id="pool.setticks"></a>
##### SetTicks

```go
func (p *Pool) SetTicks(ticks Ticks)
```

SetTicks sets the ticks

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| ticks | Ticks |  |

<a id="pool.setunclaimableacc"></a>
##### SetUnclaimableAcc

```go
func (p *Pool) SetUnclaimableAcc(unclaimableAcc int64)
```

SetUnclaimableAcc sets the unclaimable accumulation

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| unclaimableAcc | int64 |  |

<a id="pool.stakedliquidity"></a>
##### StakedLiquidity

```go
func (p *Pool) StakedLiquidity() *UintTree
```

StakedLiquidity returns the staked liquidity tree

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | *UintTree |  |

<a id="pool.ticks"></a>
##### Ticks

```go
func (p *Pool) Ticks() *Ticks
```

Ticks returns the ticks

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | *Ticks |  |

<a id="pool.unclaimableacc"></a>
##### UnclaimableAcc

```go
func (p *Pool) UnclaimableAcc() int64
```

UnclaimableAcc returns the unclaimable accumulation

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int64 |  |


#### Constructors

- `func GetPool(poolPath string) *Pool`
- `func NewPool(poolPath string, currentTime int64) *Pool`

---

<a id="poolaccessor"></a>

### PoolAccessor

```go

type PoolAccessor interface

```

---

<a id="storekey"></a>

### StoreKey

```go

type StoreKey string

```

#### Methods

<a id="storekey.string"></a>
##### String

```go
func (s StoreKey) String() string
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | string |  |


---

<a id="swapbatchprocessor"></a>

### SwapBatchProcessor

```go

type SwapBatchProcessor struct

```

SwapBatchProcessor processes tick crosses in batch for a swap
This processor accumulates all tick crosses that occur during a single swap
and processes them together at the end, reducing redundant calculations
and state updates that would occur with individual tick processing

#### Methods

<a id="swapbatchprocessor.addcross"></a>
##### AddCross

```go
func (s *SwapBatchProcessor) AddCross(tickCross *SwapTickCross)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| tickCross | *SwapTickCross |  |

<a id="swapbatchprocessor.crosses"></a>
##### Crosses

```go
func (s *SwapBatchProcessor) Crosses() []*SwapTickCross
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | []*SwapTickCross |  |

<a id="swapbatchprocessor.isactive"></a>
##### IsActive

```go
func (s *SwapBatchProcessor) IsActive() bool
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | bool |  |

<a id="swapbatchprocessor.lastcross"></a>
##### LastCross

```go
func (s *SwapBatchProcessor) LastCross() *SwapTickCross
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | *SwapTickCross |  |

<a id="swapbatchprocessor.pool"></a>
##### Pool

```go
func (s *SwapBatchProcessor) Pool() *Pool
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | *Pool |  |

<a id="swapbatchprocessor.poolpath"></a>
##### PoolPath

```go
func (s *SwapBatchProcessor) PoolPath() string
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | string |  |

<a id="swapbatchprocessor.setcrosses"></a>
##### SetCrosses

```go
func (s *SwapBatchProcessor) SetCrosses(crosses []*SwapTickCross)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| crosses | []*SwapTickCross |  |

<a id="swapbatchprocessor.setisactive"></a>
##### SetIsActive

```go
func (s *SwapBatchProcessor) SetIsActive(isActive bool)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| isActive | bool |  |

<a id="swapbatchprocessor.setpool"></a>
##### SetPool

```go
func (s *SwapBatchProcessor) SetPool(pool *Pool)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| pool | *Pool |  |

<a id="swapbatchprocessor.setpoolpath"></a>
##### SetPoolPath

```go
func (s *SwapBatchProcessor) SetPoolPath(poolPath string)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| poolPath | string |  |

<a id="swapbatchprocessor.settimestamp"></a>
##### SetTimestamp

```go
func (s *SwapBatchProcessor) SetTimestamp(timestamp int64)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| timestamp | int64 |  |

<a id="swapbatchprocessor.timestamp"></a>
##### Timestamp

```go
func (s *SwapBatchProcessor) Timestamp() int64
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int64 |  |


#### Constructors

- `func NewSwapBatchProcessor(poolPath string, pool *Pool, timestamp int64) *SwapBatchProcessor`

---

<a id="swaptickcross"></a>

### SwapTickCross

```go

type SwapTickCross struct

```

SwapTickCross stores information about a tick cross during a swap
This struct is used to accumulate tick cross events during a single swap transaction
for batch processing to optimize gas usage and computational efficiency

#### Methods

<a id="swaptickcross.delta"></a>
##### Delta

```go
func (s *SwapTickCross) Delta() *i256.Int
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | *i256.Int |  |

<a id="swaptickcross.tickid"></a>
##### TickID

```go
func (s *SwapTickCross) TickID() int32
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int32 |  |

<a id="swaptickcross.zeroforone"></a>
##### ZeroForOne

```go
func (s *SwapTickCross) ZeroForOne() bool
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | bool |  |


#### Constructors

- `func NewSwapTickCross(tickID int32, zeroForOne bool, delta *i256.Int) *SwapTickCross`

---

<a id="tick"></a>

### Tick

```go

type Tick struct

```

Tick represents the state of a specific tick in a pool.

Fields:
- id (int32): The ID of the tick.
- stakedLiquidityGross (*u256.Uint): Total gross staked liquidity at this tick.
- stakedLiquidityDelta (*i256.Int): Net change in staked liquidity at this tick.
- outsideAccumulation (*UintTree): RewardRatioAccumulation outside the tick.

#### Methods

<a id="tick.clone"></a>
##### Clone

```go
func (t *Tick) Clone() *Tick
```

Clone returns a deep copy of the tick.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | *Tick |  |

<a id="tick.id"></a>
##### Id

```go
func (t *Tick) Id() int32
```

Id returns the tick ID

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int32 |  |

<a id="tick.outsideaccumulation"></a>
##### OutsideAccumulation

```go
func (t *Tick) OutsideAccumulation() *UintTree
```

OutsideAccumulation returns the outside accumulation tree

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | *UintTree |  |

<a id="tick.setid"></a>
##### SetId

```go
func (t *Tick) SetId(id int32)
```

SetId sets the tick ID

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| id | int32 |  |

<a id="tick.setoutsideaccumulation"></a>
##### SetOutsideAccumulation

```go
func (t *Tick) SetOutsideAccumulation(outsideAccumulation *UintTree)
```

SetOutsideAccumulation sets the outside accumulation tree

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| outsideAccumulation | *UintTree |  |

<a id="tick.setstakedliquiditydelta"></a>
##### SetStakedLiquidityDelta

```go
func (t *Tick) SetStakedLiquidityDelta(stakedLiquidityDelta *i256.Int)
```

SetStakedLiquidityDelta sets the staked liquidity delta

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| stakedLiquidityDelta | *i256.Int |  |

<a id="tick.setstakedliquiditygross"></a>
##### SetStakedLiquidityGross

```go
func (t *Tick) SetStakedLiquidityGross(stakedLiquidityGross *u256.Uint)
```

SetStakedLiquidityGross sets the staked liquidity gross

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| stakedLiquidityGross | *u256.Uint |  |

<a id="tick.stakedliquiditydelta"></a>
##### StakedLiquidityDelta

```go
func (t *Tick) StakedLiquidityDelta() *i256.Int
```

StakedLiquidityDelta returns the staked liquidity delta

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | *i256.Int |  |

<a id="tick.stakedliquiditygross"></a>
##### StakedLiquidityGross

```go
func (t *Tick) StakedLiquidityGross() *u256.Uint
```

StakedLiquidityGross returns the staked liquidity gross

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | *u256.Uint |  |


#### Constructors

- `func NewTick(tickId int32) *Tick`

---

<a id="ticks"></a>

### Ticks

```go

type Ticks struct

```

Tick mapping for each pool

#### Methods

<a id="ticks.clone"></a>
##### Clone

```go
func (t Ticks) Clone() Ticks
```

Clone returns a deep copy of ticks.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | Ticks |  |

<a id="ticks.get"></a>
##### Get

```go
func (t *Ticks) Get(tickId int32) *Tick
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| tickId | int32 |  |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | *Tick |  |

<a id="ticks.has"></a>
##### Has

```go
func (self *Ticks) Has(tickId int32) bool
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| tickId | int32 |  |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | bool |  |

<a id="ticks.iterateticks"></a>
##### IterateTicks

```go
func (t *Ticks) IterateTicks(fn func(...))
```

IterateTicks iterates over all ticks

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| fn | func(...) |  |

<a id="ticks.settick"></a>
##### SetTick

```go
func (t *Ticks) SetTick(tickId int32, tick *Tick)
```

SetTick sets a tick by ID

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| tickId | int32 |  |
| tick | *Tick |  |

<a id="ticks.settree"></a>
##### SetTree

```go
func (t *Ticks) SetTree(tree *avl.Tree)
```

SetTree sets the ticks tree

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| tree | *avl.Tree |  |

<a id="ticks.tree"></a>
##### Tree

```go
func (t *Ticks) Tree() *avl.Tree
```

Tree returns the ticks tree

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | *avl.Tree |  |


#### Constructors

- `func NewTicks() Ticks`

---

<a id="tierratio"></a>

### TierRatio

```go

type TierRatio struct

```

100%, 0%, 0% if no tier2 and tier3
80%, 0%, 20% if no tier2
70%, 30%, 0% if no tier3
50%, 30%, 20% if has tier2 and tier3

#### Fields

- `Tier1 uint64`
- `Tier2 uint64`
- `Tier3 uint64`

#### Methods

<a id="tierratio.get"></a>
##### Get

```go
func (ratio *TierRatio) Get(tier uint64) (uint64, error)
```

Get returns the ratio(scaled up by 100) for the given tier.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| tier | uint64 |  |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | uint64 |  |
|  | error |  |


---

<a id="uinttree"></a>

### UintTree

```go

type UintTree struct

```

UintTree is a wrapper around an AVL tree for storing block timestamps as strings.
Since block timestamps are defined as int64, we take int64 and convert it to uint64 for the tree.

Methods:
- Get: Retrieves a value associated with a uint64 key.
- set: Stores a value with a uint64 key.
- Has: Checks if a uint64 key exists in the tree.
- remove: Removes a uint64 key and its associated value.
- Iterate: Iterates over keys and values in a range.
- ReverseIterate: Iterates in reverse order over keys and values in a range.

#### Methods

<a id="uinttree.clone"></a>
##### Clone

```go
func (self *UintTree) Clone() *UintTree
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | *UintTree |  |

<a id="uinttree.get"></a>
##### Get

```go
func (self *UintTree) Get(key int64) (any, bool)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| key | int64 |  |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | any |  |
|  | bool |  |

<a id="uinttree.has"></a>
##### Has

```go
func (self *UintTree) Has(key int64) bool
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| key | int64 |  |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | bool |  |

<a id="uinttree.iterate"></a>
##### Iterate

```go
func (self *UintTree) Iterate(start int64, end int64, fn func(...))
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| start | int64 |  |
| end | int64 |  |
| fn | func(...) |  |

<a id="uinttree.iteratebyoffset"></a>
##### IterateByOffset

```go
func (self *UintTree) IterateByOffset(offset int, count int, fn func(...))
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| offset | int |  |
| count | int |  |
| fn | func(...) |  |

<a id="uinttree.remove"></a>
##### Remove

```go
func (self *UintTree) Remove(key int64)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| key | int64 |  |

<a id="uinttree.reverseiterate"></a>
##### ReverseIterate

```go
func (self *UintTree) ReverseIterate(start int64, end int64, fn func(...))
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| start | int64 |  |
| end | int64 |  |
| fn | func(...) |  |

<a id="uinttree.set"></a>
##### Set

```go
func (self *UintTree) Set(key int64, value any)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| key | int64 |  |
| value | any |  |

<a id="uinttree.size"></a>
##### Size

```go
func (self *UintTree) Size() int
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int |  |


#### Constructors

- `func NewUintTree() *UintTree`

---

<a id="warmup"></a>

### Warmup

```go

type Warmup struct

```

#### Fields

- `Index int`
- `TimeDuration int64`
- `NextWarmupTime int64`
- `WarmupRatio uint64`

#### Methods

<a id="warmup.setnextwarmuptime"></a>
##### SetNextWarmupTime

```go
func (w *Warmup) SetNextWarmupTime(nextWarmupTime int64)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| nextWarmupTime | int64 |  |

<a id="warmup.settimeduration"></a>
##### SetTimeDuration

```go
func (w *Warmup) SetTimeDuration(timeDuration int64)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| timeDuration | int64 |  |

<a id="warmup.setwarmupratio"></a>
##### SetWarmupRatio

```go
func (w *Warmup) SetWarmupRatio(warmupRatio uint64)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| warmupRatio | uint64 |  |


#### Constructors

- `func DefaultWarmupTemplate() []Warmup`
- `func GetDepositWarmUp(lpTokenId uint64) []Warmup`
- `func GetWarmupTemplate() []Warmup`
