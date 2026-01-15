# emission

`import "gno.land/r/gnoswap/emission"`

Package emission manages GNS token emission and distribution for GnoSwap.

The emission system controls creation and distribution of new GNS tokens
with a deflationary model featuring periodic halvings over 12 years.

Emission Schedule:
  - Year 1-2:  100% emission rate (225,000,000 GNS/year)
  - Year 3-4:   50% emission rate (112,500,000 GNS/year)
  - Year 5-6:   25% emission rate  (56,250,000 GNS/year)
  - Year 7-8: 12.5% emission rate  (28,125,000 GNS/year)
  - Year 9-12: 6.25% emission rate (14,062,500 GNS/year)

Distribution Targets (configurable via governance):
  - LIQUIDITY_STAKER: Rewards for LP providers (default 75%)
  - DEVOPS: Development and operations fund (default 20%)
  - COMMUNITY_POOL: Community-governed treasury (default 5%)
  - GOV_STAKER: GNS staking rewards (default 0%)

Key Functions:
  - MintAndDistributeGns: Mints and distributes GNS per emission schedule
  - SetDistributionStartTime: One-time setup of emission start timestamp
  - ChangeDistributionPct: Updates distribution percentages
  - ClearDistributedToStaker/GovStaker: Resets pending distribution amounts


## Index

- [LIQUIDITY_STAKER](#liquidity_staker)
- [DEVOPS](#devops)
- [COMMUNITY_POOL](#community_pool)
- [GOV_STAKER](#gov_staker)
- [AccumulateDistributedInfo](#accumulatedistributedinfo)
- [ChangeDistributionPct](#changedistributionpct)
- [ClearDistributedToGovStaker](#cleardistributedtogovstaker)
- [ClearDistributedToStaker](#cleardistributedtostaker)
- [GetAccuDistributedToCommunityPool](#getaccudistributedtocommunitypool)
- [GetAccuDistributedToDevOps](#getaccudistributedtodevops)
- [GetAccuDistributedToGovStaker](#getaccudistributedtogovstaker)
- [GetAccuDistributedToStaker](#getaccudistributedtostaker)
- [GetAllDistributionBpsPct](#getalldistributionbpspct)
- [GetDistributableAmount](#getdistributableamount)
- [GetDistributedToCommunityPool](#getdistributedtocommunitypool)
- [GetDistributedToDevOps](#getdistributedtodevops)
- [GetDistributedToGovStaker](#getdistributedtogovstaker)
- [GetDistributedToStaker](#getdistributedtostaker)
- [GetDistributionBpsPct](#getdistributionbpspct)
- [GetDistributionEndTimestamp](#getdistributionendtimestamp)
- [GetDistributionStartTimestamp](#getdistributionstarttimestamp)
- [GetEmissionAmountPerSecondBy](#getemissionamountpersecondby)
- [GetLastExecutedTimestamp](#getlastexecutedtimestamp)
- [GetLeftGNSAmount](#getleftgnsamount)
- [GetStakerEmissionAmountPerSecond](#getstakeremissionamountpersecond)
- [GetStakerEmissionAmountPerSecondInRange](#getstakeremissionamountpersecondinrange)
- [GetTotalAccuDistributed](#gettotalaccudistributed)
- [GetTotalDistributed](#gettotaldistributed)
- [MintAndDistributeGns](#mintanddistributegns)
- [SetDistributionStartTime](#setdistributionstarttime)
- [SetOnDistributionPctChangeCallback](#setondistributionpctchangecallback)


## Constants

<a id="liquidity_staker"></a>
<a id="devops"></a>
<a id="community_pool"></a>
<a id="gov_staker"></a>
```go
const (
	LIQUIDITY_STAKER int
	DEVOPS 
	COMMUNITY_POOL 
	GOV_STAKER 
)
```


## Functions

<a id="accumulatedistributedinfo"></a>

### AccumulateDistributedInfo

```go

func AccumulateDistributedInfo() (toStaker int64, toDevOps int64, toCommunityPool int64, toGovStaker int64)

```

AccumulateDistributedInfo returns pending distribution amounts for all targets.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| toStaker | int64 | pending GNS for liquidity stakers |
| toDevOps | int64 | pending GNS for DevOps |
| toCommunityPool | int64 | pending GNS for Community Pool |
| toGovStaker | int64 | pending GNS for governance stakers |

---

<a id="changedistributionpct"></a>

### ChangeDistributionPct

```go

func ChangeDistributionPct(cur realm, target01 int, pct01 int64, target02 int, pct02 int64, target03 int, pct03 int64, target04 int, pct04 int64)

```

ChangeDistributionPct changes distribution percentages for emission targets.

This function redistributes how newly minted GNS tokens are allocated across
protocol components. Before applying new ratios, it distributes any accumulated
emissions using the current ratios, ensuring emissions are distributed according
to the ratios in effect when they were generated. This prevents retroactive
application of new ratios to past emissions.


Requirements:
  - All four targets must be specified (use current values if unchanged)
  - Percentages must sum to exactly 10000 (100%)
  - Each percentage must be 0-10000
  - Targets must be unique (no duplicates)

Example:

	ChangeDistributionPct(
	  1, 7000,  // 70% to liquidity stakers
	  2, 2000,  // 20% to devops
	  3, 1000,  // 10% to community pool
	  4, 0      // 0% to governance stakers
	)

Only callable by admin or governance.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| cur | realm |  |
| target01 | int |  |
| pct01 | int64 |  |
| target02 | int |  |
| pct02 | int64 |  |
| target03 | int |  |
| pct03 | int64 |  |
| target04 | int |  |
| pct04 | int64 |  |

---

<a id="cleardistributedtogovstaker"></a>

### ClearDistributedToGovStaker

```go

func ClearDistributedToGovStaker(cur realm)

```

ClearDistributedToGovStaker resets the pending distribution amount for governance stakers.

Only callable by governance staker contract.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| cur | realm |  |

---

<a id="cleardistributedtostaker"></a>

### ClearDistributedToStaker

```go

func ClearDistributedToStaker(cur realm)

```

ClearDistributedToStaker resets the pending distribution amount for liquidity stakers.

Only callable by staker contract.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| cur | realm |  |

---

<a id="getaccudistributedtocommunitypool"></a>

### GetAccuDistributedToCommunityPool

```go

func GetAccuDistributedToCommunityPool() int64

```

GetAccuDistributedToCommunityPool returns the total historical GNS distributed to Community Pool.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| amount | int64 | total historical GNS distributed to Community Pool |

---

<a id="getaccudistributedtodevops"></a>

### GetAccuDistributedToDevOps

```go

func GetAccuDistributedToDevOps() int64

```

GetAccuDistributedToDevOps returns the total historical GNS distributed to DevOps.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| amount | int64 | total historical GNS distributed to DevOps |

---

<a id="getaccudistributedtogovstaker"></a>

### GetAccuDistributedToGovStaker

```go

func GetAccuDistributedToGovStaker() int64

```

GetAccuDistributedToGovStaker returns the total historical GNS distributed to governance stakers.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| amount | int64 | total historical GNS distributed to governance stakers |

---

<a id="getaccudistributedtostaker"></a>

### GetAccuDistributedToStaker

```go

func GetAccuDistributedToStaker() int64

```

GetAccuDistributedToStaker returns the total historical GNS distributed to liquidity stakers.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| amount | int64 | total historical GNS distributed to stakers |

---

<a id="getalldistributionbpspct"></a>

### GetAllDistributionBpsPct

```go

func GetAllDistributionBpsPct() map[int]int64

```

GetAllDistributionBpsPct returns all distribution percentages in basis points.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| percentages | map[int]int64 | map of target to percentage in basis points |

---

<a id="getdistributableamount"></a>

### GetDistributableAmount

```go

func GetDistributableAmount(amount int64, timestamp int64) (map[int]int64, int64)

```

GetDistributableAmount returns distribution amounts by target and the remainder.
If timestamp is outside the distribution window, it returns an empty map and the full amount as left.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| amount | int64 | total amount to distribute |
| timestamp | int64 | timestamp to check distribution window |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| distributions | map[int]int64 | map of target to distribution amount |
| remainder | int64 | undistributed amount |

---

<a id="getdistributedtocommunitypool"></a>

### GetDistributedToCommunityPool

```go

func GetDistributedToCommunityPool() int64

```

GetDistributedToCommunityPool returns the amount of GNS distributed to Community Pool.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| amount | int64 | pending GNS amount for Community Pool |

---

<a id="getdistributedtodevops"></a>

### GetDistributedToDevOps

```go

func GetDistributedToDevOps() int64

```

GetDistributedToDevOps returns accumulated GNS for DevOps.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| amount | int64 | pending GNS amount for DevOps |

---

<a id="getdistributedtogovstaker"></a>

### GetDistributedToGovStaker

```go

func GetDistributedToGovStaker() int64

```

GetDistributedToGovStaker returns the amount of GNS distributed to governance stakers since last clear.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| amount | int64 | pending GNS amount for governance stakers |

---

<a id="getdistributedtostaker"></a>

### GetDistributedToStaker

```go

func GetDistributedToStaker() int64

```

GetDistributedToStaker returns pending GNS for liquidity stakers.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| amount | int64 | pending GNS amount for stakers |

---

<a id="getdistributionbpspct"></a>

### GetDistributionBpsPct

```go

func GetDistributionBpsPct(target int) int64

```

GetDistributionBpsPct returns the distribution percentage in basis points for a specific target.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| target | int | distribution target identifier |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| percentage | int64 | distribution percentage in basis points |

---

<a id="getdistributionendtimestamp"></a>

### GetDistributionEndTimestamp

```go

func GetDistributionEndTimestamp() int64

```

GetDistributionEndTimestamp returns the timestamp when emission distribution ends.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| timestamp | int64 | distribution end timestamp, or 0 if not started |

---

<a id="getdistributionstarttimestamp"></a>

### GetDistributionStartTimestamp

```go

func GetDistributionStartTimestamp() int64

```

GetDistributionStartTimestamp returns the timestamp when emission distribution started.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| timestamp | int64 | distribution start timestamp, or 0 if not started |

---

<a id="getemissionamountpersecondby"></a>

### GetEmissionAmountPerSecondBy

```go

func GetEmissionAmountPerSecondBy(timestamp int64, distributionPct int64) int64

```

GetEmissionAmountPerSecondBy returns the emission amount per second for a given timestamp and distribution percentage.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| timestamp | int64 | timestamp to calculate emission for |
| distributionPct | int64 | distribution percentage in basis points |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| amount | int64 | emission amount per second |

---

<a id="getlastexecutedtimestamp"></a>

### GetLastExecutedTimestamp

```go

func GetLastExecutedTimestamp() int64

```

GetLastExecutedTimestamp returns the timestamp of the last emission distribution execution.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| timestamp | int64 | last execution timestamp |

---

<a id="getleftgnsamount"></a>

### GetLeftGNSAmount

```go

func GetLeftGNSAmount() int64

```

GetLeftGNSAmount returns the amount of undistributed GNS tokens from previous distributions.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| amount | int64 | undistributed GNS amount |

---

<a id="getstakeremissionamountpersecond"></a>

### GetStakerEmissionAmountPerSecond

```go

func GetStakerEmissionAmountPerSecond() int64

```

GetStakerEmissionAmountPerSecond returns the current per-second emission amount allocated to liquidity stakers.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| amount | int64 | emission amount per second for stakers |

---

<a id="getstakeremissionamountpersecondinrange"></a>

### GetStakerEmissionAmountPerSecondInRange

```go

func GetStakerEmissionAmountPerSecondInRange(start int64, end int64) ([]int64, []int64)

```

GetStakerEmissionAmountPerSecondInRange returns emission amounts allocated to liquidity stakers for a time range.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| start | int64 | start timestamp |
| end | int64 | end timestamp |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| halvingBlocks | []int64 | halving block timestamps |
| halvingEmissions | []int64 | emission amounts at each halving |

---

<a id="gettotalaccudistributed"></a>

### GetTotalAccuDistributed

```go

func GetTotalAccuDistributed() int64

```

GetTotalAccuDistributed returns the total accumulated distributed GNS amount.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| amount | int64 | total accumulated distributed GNS |

---

<a id="gettotaldistributed"></a>

### GetTotalDistributed

```go

func GetTotalDistributed() int64

```

GetTotalDistributed returns the total pending distributed GNS amount.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| amount | int64 | total pending distributed GNS |

---

<a id="mintanddistributegns"></a>

### MintAndDistributeGns

```go

func MintAndDistributeGns(cur realm) (int64, bool)

```

MintAndDistributeGns mints and distributes GNS tokens according to the emission schedule.

This function is called automatically by protocol contracts during user interactions
to trigger periodic GNS emission. It mints new tokens based on elapsed time since
last distribution and distributes them to predefined targets (staker, devops, etc.).


Note: Distribution only occurs if start timestamp is set and reached.
Any undistributed tokens from previous calls are carried forward.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| cur | realm |  |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| distributedAmount | int64 | total amount of GNS distributed in this call |
| success | bool | true if distribution was attempted |

---

<a id="setdistributionstarttime"></a>

### SetDistributionStartTime

```go

func SetDistributionStartTime(cur realm, startTimestamp int64)

```

SetDistributionStartTime sets the timestamp when emission distribution starts.

This function controls when GNS emission begins. Once set and reached, the protocol
starts minting GNS tokens according to the emission schedule. The timestamp can only
be set before distribution starts - it becomes immutable once active.


Requirements:
  - Must be called before distribution starts (one-time setup)
  - Timestamp must be in the future
  - Cannot be negative

Effects:
  - Sets global distribution start time
  - Initializes GNS emission state if not already started
  - Emission begins automatically when timestamp is reached

Only callable by admin or governance.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| cur | realm |  |
| startTimestamp | int64 | Unix timestamp when emission should begin |

---

<a id="setondistributionpctchangecallback"></a>

### SetOnDistributionPctChangeCallback

```go

func SetOnDistributionPctChangeCallback(cur realm, callback func(...))

```

SetOnDistributionPctChangeCallback sets a callback function to be called when distribution percentages change.
This allows external contracts (like staker) to update their internal caches when governance changes emission rates.


Only callable by the staker contract.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| cur | realm |  |
| callback | func(...) | function to call with emission amount per second when percentages change |
