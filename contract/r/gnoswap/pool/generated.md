# pool

`import "gno.land/r/gnoswap/pool"`



## Index

- [Burn](#burn)
- [Collect](#collect)
- [CollectProtocol](#collectprotocol)
- [CreatePool](#createpool)
- [DrySwap](#dryswap)
- [ExistsPoolPath](#existspoolpath)
- [GetBalanceToken0](#getbalancetoken0)
- [GetBalanceToken1](#getbalancetoken1)
- [GetBalances](#getbalances)
- [GetFee](#getfee)
- [GetFeeAmountTickSpacing](#getfeeamounttickspacing)
- [GetFeeAmountTickSpacings](#getfeeamounttickspacings)
- [GetFeeGrowthGlobal0X128](#getfeegrowthglobal0x128)
- [GetFeeGrowthGlobal1X128](#getfeegrowthglobal1x128)
- [GetFeeGrowthGlobalX128](#getfeegrowthglobalx128)
- [GetFeeGrowthGlobals](#getfeegrowthglobals)
- [GetImplementationPackagePath](#getimplementationpackagepath)
- [GetInitializedTicksInRange](#getinitializedticksinrange)
- [GetLiquidity](#getliquidity)
- [GetMaxLiquidityPerTick](#getmaxliquiditypertick)
- [GetObservation](#getobservation)
- [GetPoolCount](#getpoolcount)
- [GetPoolCreationFee](#getpoolcreationfee)
- [GetPoolPath](#getpoolpath)
- [GetPoolPaths](#getpoolpaths)
- [GetPoolPositionCount](#getpoolpositioncount)
- [GetPoolPositionKeys](#getpoolpositionkeys)
- [GetPositionFeeGrowthInside0LastX128](#getpositionfeegrowthinside0lastx128)
- [GetPositionFeeGrowthInside1LastX128](#getpositionfeegrowthinside1lastx128)
- [GetPositionFeeGrowthInsideLastX128](#getpositionfeegrowthinsidelastx128)
- [GetPositionFeeGrowthInsideLasts](#getpositionfeegrowthinsidelasts)
- [GetPositionLiquidity](#getpositionliquidity)
- [GetPositionTokensOwed](#getpositiontokensowed)
- [GetPositionTokensOwed0](#getpositiontokensowed0)
- [GetPositionTokensOwed1](#getpositiontokensowed1)
- [GetProtocolFeesToken0](#getprotocolfeestoken0)
- [GetProtocolFeesToken1](#getprotocolfeestoken1)
- [GetProtocolFeesTokens](#getprotocolfeestokens)
- [GetSlot0FeeProtocol](#getslot0feeprotocol)
- [GetSlot0SqrtPriceX96](#getslot0sqrtpricex96)
- [GetSlot0Tick](#getslot0tick)
- [GetSlot0Unlocked](#getslot0unlocked)
- [GetTWAP](#gettwap)
- [GetTickBitmaps](#gettickbitmaps)
- [GetTickCumulativeOutside](#gettickcumulativeoutside)
- [GetTickFeeGrowthOutside0X128](#gettickfeegrowthoutside0x128)
- [GetTickFeeGrowthOutside1X128](#gettickfeegrowthoutside1x128)
- [GetTickFeeGrowthOutsideX128](#gettickfeegrowthoutsidex128)
- [GetTickFeeGrowthOutsides](#gettickfeegrowthoutsides)
- [GetTickInitialized](#gettickinitialized)
- [GetTickLiquidityGross](#gettickliquiditygross)
- [GetTickLiquidityNet](#gettickliquiditynet)
- [GetTickSecondsOutside](#getticksecondsoutside)
- [GetTickSecondsPerLiquidityOutsideX128](#getticksecondsperliquidityoutsidex128)
- [GetTickSpacing](#gettickspacing)
- [GetToken0Path](#gettoken0path)
- [GetToken1Path](#gettoken1path)
- [GetWithdrawalFee](#getwithdrawalfee)
- [HandleWithdrawalFee](#handlewithdrawalfee)
- [IncreaseObservationCardinalityNext](#increaseobservationcardinalitynext)
- [Mint](#mint)
- [ParsePoolPath](#parsepoolpath)
- [RegisterInitializer](#registerinitializer)
- [SetFeeProtocol](#setfeeprotocol)
- [SetPoolCreationFee](#setpoolcreationfee)
- [SetSwapEndHook](#setswapendhook)
- [SetSwapStartHook](#setswapstarthook)
- [SetTickCrossHook](#settickcrosshook)
- [SetWithdrawalFee](#setwithdrawalfee)
- [Swap](#swap)
- [UpgradeImpl](#upgradeimpl)
- [Balances](#balances)
- [CallbackMarker](#callbackmarker)
- [IPool](#ipool)
- [IPoolGetter](#ipoolgetter)
- [IPoolManager](#ipoolmanager)
- [IPoolPosition](#ipoolposition)
- [IPoolStore](#ipoolstore)
- [IPoolSwap](#ipoolswap)
- [Observation](#observation)
- [ObservationState](#observationstate)
- [Pool](#pool)
- [PositionInfo](#positioninfo)
- [ProtocolFees](#protocolfees)
- [Slot0](#slot0)
- [StoreKey](#storekey)
- [TickInfo](#tickinfo)
- [TokenPair](#tokenpair)


## Functions

<a id="burn"></a>

### Burn

```go

func Burn(cur realm, token0Path string, token1Path string, fee uint32, tickLower int32, tickUpper int32, liquidityAmount string, positionCaller address) (string, string)

```

Burn removes liquidity from a position.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| cur | realm |  |
| token0Path | string | path of the first token |
| token1Path | string | path of the second token |
| fee | uint32 | pool fee tier |
| tickLower | int32 | lower tick boundary |
| tickUpper | int32 | upper tick boundary |
| liquidityAmount | string | amount of liquidity to remove |
| positionCaller | address | caller address for the position |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| amount0 | string | amount of token0 returned |
| amount1 | string | amount of token1 returned |

---

<a id="collect"></a>

### Collect

```go

func Collect(cur realm, token0Path string, token1Path string, fee uint32, recipient address, tickLower int32, tickUpper int32, amount0Requested string, amount1Requested string) (string, string)

```

Collect transfers owed tokens from a position to recipient.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| cur | realm |  |
| token0Path | string | path of the first token |
| token1Path | string | path of the second token |
| fee | uint32 | pool fee tier |
| recipient | address | recipient address for collected tokens |
| tickLower | int32 | lower tick boundary |
| tickUpper | int32 | upper tick boundary |
| amount0Requested | string | max amount of token0 to collect |
| amount1Requested | string | max amount of token1 to collect |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| amount0 | string | amount of token0 collected |
| amount1 | string | amount of token1 collected |

---

<a id="collectprotocol"></a>

### CollectProtocol

```go

func CollectProtocol(cur realm, token0Path string, token1Path string, fee uint32, recipient address, amount0Requested string, amount1Requested string) (string, string)

```

CollectProtocol collects protocol fees from a pool.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| cur | realm |  |
| token0Path | string | path of the first token |
| token1Path | string | path of the second token |
| fee | uint32 | pool fee tier |
| recipient | address | recipient address for fees |
| amount0Requested | string | amount of token0 to collect |
| amount1Requested | string | amount of token1 to collect |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| amount0 | string | amount of token0 collected |
| amount1 | string | amount of token1 collected |

---

<a id="createpool"></a>

### CreatePool

```go

func CreatePool(cur realm, token0Path string, token1Path string, fee uint32, sqrtPriceX96 string)

```

CreatePool creates a new liquidity pool for a token pair.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| cur | realm |  |
| token0Path | string | path of the first token |
| token1Path | string | path of the second token |
| fee | uint32 | pool fee tier |
| sqrtPriceX96 | string | initial sqrt price (Q64.96 format) |

---

<a id="dryswap"></a>

### DrySwap

```go

func DrySwap(token0Path string, token1Path string, fee uint32, zeroForOne bool, amountSpecified string, sqrtPriceLimitX96 string) (string, string, bool)

```

DrySwap simulates a swap without executing it, returning the expected output.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| token0Path | string | path of the first token |
| token1Path | string | path of the second token |
| fee | uint32 | pool fee tier |
| zeroForOne | bool | true if swapping token0 for token1 |
| amountSpecified | string | amount to swap |
| sqrtPriceLimitX96 | string | price limit for the swap |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| amount0Delta | string | amount of token0 delta |
| amount1Delta | string | amount of token1 delta |
| ok | bool | swap success status |

---

<a id="existspoolpath"></a>

### ExistsPoolPath

```go

func ExistsPoolPath(poolPath string) bool

```

ExistsPoolPath checks if a pool exists at the given path.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| poolPath | string | pool identifier in token0:token1:fee form |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| exists | bool | true if the pool exists |

---

<a id="getbalancetoken0"></a>

### GetBalanceToken0

```go

func GetBalanceToken0(poolPath string) string

```

GetBalanceToken0 returns the balance of token0 in the pool.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| poolPath | string | pool identifier in token0:token1:fee form |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| balance0 | string | balance of token0 |

---

<a id="getbalancetoken1"></a>

### GetBalanceToken1

```go

func GetBalanceToken1(poolPath string) string

```

GetBalanceToken1 returns the balance of token1 in the pool.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| poolPath | string | pool identifier in token0:token1:fee form |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| balance1 | string | balance of token1 |

---

<a id="getbalances"></a>

### GetBalances

```go

func GetBalances(poolPath string) (string, string)

```

GetBalances returns the balances of the pool.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| poolPath | string | pool identifier in token0:token1:fee form |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| balance0 | string | balance of token0 |
| balance1 | string | balance of token1 |

---

<a id="getfee"></a>

### GetFee

```go

func GetFee(poolPath string) uint32

```

GetFee returns the fee tier of the pool.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| poolPath | string | pool identifier in token0:token1:fee form |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| fee | uint32 | pool fee tier |

---

<a id="getfeeamounttickspacing"></a>

### GetFeeAmountTickSpacing

```go

func GetFeeAmountTickSpacing(fee uint32) (spacing int32)

```

GetFeeAmountTickSpacing returns the tick spacing for a given fee tier.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| fee | uint32 | pool fee tier |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| spacing | int32 | tick spacing for the fee tier |

---

<a id="getfeeamounttickspacings"></a>

### GetFeeAmountTickSpacings

```go

func GetFeeAmountTickSpacings() map[uint32]int32

```

GetFeeAmountTickSpacings returns all fee tier to tick spacing mappings.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| feeAmountTickSpacings | map[uint32]int32 | mapping of fee tier to tick spacing |

---

<a id="getfeegrowthglobal0x128"></a>

### GetFeeGrowthGlobal0X128

```go

func GetFeeGrowthGlobal0X128(poolPath string) string

```

GetFeeGrowthGlobal0X128 returns the global fee growth for token0.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| poolPath | string | pool identifier in token0:token1:fee form |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| feeGrowthGlobal0X128 | string | fee growth for token0 as Q128.128 |

---

<a id="getfeegrowthglobal1x128"></a>

### GetFeeGrowthGlobal1X128

```go

func GetFeeGrowthGlobal1X128(poolPath string) string

```

GetFeeGrowthGlobal1X128 returns the global fee growth for token1.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| poolPath | string | pool identifier in token0:token1:fee form |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| feeGrowthGlobal1X128 | string | fee growth for token1 as Q128.128 |

---

<a id="getfeegrowthglobalx128"></a>

### GetFeeGrowthGlobalX128

```go

func GetFeeGrowthGlobalX128(poolPath string) (*u256.Uint, *u256.Uint)

```

GetFeeGrowthGlobalX128 returns the global fee growth for both tokens.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| poolPath | string | pool identifier in token0:token1:fee form |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| feeGrowthGlobal0X128 | *u256.Uint | fee growth for token0 as Q128.128 |
| feeGrowthGlobal1X128 | *u256.Uint | fee growth for token1 as Q128.128 |

---

<a id="getfeegrowthglobals"></a>

### GetFeeGrowthGlobals

```go

func GetFeeGrowthGlobals(poolPath string) (string, string)

```

GetFeeGrowthGlobals returns the global fee growth for both tokens.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| poolPath | string | pool identifier in token0:token1:fee form |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| feeGrowthGlobal0X128 | string | fee growth for token0 as Q128.128 |
| feeGrowthGlobal1X128 | string | fee growth for token1 as Q128.128 |

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

<a id="getinitializedticksinrange"></a>

### GetInitializedTicksInRange

```go

func GetInitializedTicksInRange(poolPath string, tickLower int32, tickUpper int32) []int32

```

GetInitializedTicksInRange returns initialized ticks within the given range.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| poolPath | string | pool identifier in token0:token1:fee form |
| tickLower | int32 | lower tick boundary |
| tickUpper | int32 | upper tick boundary |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| ticks | []int32 | initialized tick indices within the range |

---

<a id="getliquidity"></a>

### GetLiquidity

```go

func GetLiquidity(poolPath string) string

```

GetLiquidity returns the current liquidity in the pool.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| poolPath | string | pool identifier in token0:token1:fee form |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| liquidity | string | current liquidity as a decimal string |

---

<a id="getmaxliquiditypertick"></a>

### GetMaxLiquidityPerTick

```go

func GetMaxLiquidityPerTick(poolPath string) string

```

GetMaxLiquidityPerTick returns the maximum liquidity per tick for the pool.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| poolPath | string | pool identifier in token0:token1:fee form |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| maxLiquidityPerTick | string | max liquidity per tick as a decimal string |

---

<a id="getobservation"></a>

### GetObservation

```go

func GetObservation(poolPath string, secondsAgo int64) (tickCumulative int64, liquidityCumulative string, secondsPerLiquidityCumulativeX128 string, blockTimestamp int64)

```

GetObservation returns observation data for calculating time-weighted averages.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| poolPath | string | pool identifier in token0:token1:fee form |
| secondsAgo | int64 | time window to look back from current block timestamp |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| tickCumulative | int64 | tick cumulative |
| liquidityCumulative | string | liquidity cumulative |
| secondsPerLiquidityCumulativeX128 | string | seconds per liquidity cumulative (Q128.128) |
| blockTimestamp | int64 | block timestamp of the observation |

---

<a id="getpoolcount"></a>

### GetPoolCount

```go

func GetPoolCount() int

```

GetPoolCount returns the total number of pools.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| count | int | total number of pools |

---

<a id="getpoolcreationfee"></a>

### GetPoolCreationFee

```go

func GetPoolCreationFee() int64

```

GetPoolCreationFee returns the current pool creation fee.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| poolCreationFee | int64 | pool creation fee |

---

<a id="getpoolpath"></a>

### GetPoolPath

```go

func GetPoolPath(token0Path string, token1Path string, fee uint32) string

```

GetPoolPath generates a unique pool path string based on the token paths and fee tier.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| token0Path | string | path of the first token |
| token1Path | string | path of the second token |
| fee | uint32 | pool fee tier |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| poolPath | string | deterministic pool path in token0:token1:fee form |

---

<a id="getpoolpaths"></a>

### GetPoolPaths

```go

func GetPoolPaths(offset int, count int) []string

```

GetPoolPaths returns a paginated list of pool paths.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| offset | int | starting index for pagination |
| count | int | maximum number of pool paths to return |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| poolPaths | []string | pool paths for the requested page |

---

<a id="getpoolpositioncount"></a>

### GetPoolPositionCount

```go

func GetPoolPositionCount(poolPath string) int

```

GetPoolPositionCount returns the number of positions in a pool.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| poolPath | string | pool identifier in token0:token1:fee form |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| count | int | number of positions in the pool |

---

<a id="getpoolpositionkeys"></a>

### GetPoolPositionKeys

```go

func GetPoolPositionKeys(poolPath string, offset int, count int) []string

```

GetPoolPositionKeys returns a paginated list of position keys in a pool.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| poolPath | string | pool identifier in token0:token1:fee form |
| offset | int | starting index for pagination |
| count | int | maximum number of keys to return |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| keys | []string | position keys for the requested page |

---

<a id="getpositionfeegrowthinside0lastx128"></a>

### GetPositionFeeGrowthInside0LastX128

```go

func GetPositionFeeGrowthInside0LastX128(poolPath string, key string) string

```

GetPositionFeeGrowthInside0LastX128 returns the last recorded fee growth inside for token0.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| poolPath | string | pool identifier in token0:token1:fee form |
| key | string | position key |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| feeGrowthInside0LastX128 | string | fee growth for token0 inside the position |

---

<a id="getpositionfeegrowthinside1lastx128"></a>

### GetPositionFeeGrowthInside1LastX128

```go

func GetPositionFeeGrowthInside1LastX128(poolPath string, key string) string

```

GetPositionFeeGrowthInside1LastX128 returns the last recorded fee growth inside for token1.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| poolPath | string | pool identifier in token0:token1:fee form |
| key | string | position key |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| feeGrowthInside1LastX128 | string | fee growth for token1 inside the position |

---

<a id="getpositionfeegrowthinsidelastx128"></a>

### GetPositionFeeGrowthInsideLastX128

```go

func GetPositionFeeGrowthInsideLastX128(poolPath string, key string) (*u256.Uint, *u256.Uint)

```

GetPositionFeeGrowthInsideLastX128 returns the last recorded fee growth inside for both tokens.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| poolPath | string | pool identifier in token0:token1:fee form |
| key | string | position key |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| feeGrowthInside0LastX128 | *u256.Uint | fee growth for token0 inside the position |
| feeGrowthInside1LastX128 | *u256.Uint | fee growth for token1 inside the position |

---

<a id="getpositionfeegrowthinsidelasts"></a>

### GetPositionFeeGrowthInsideLasts

```go

func GetPositionFeeGrowthInsideLasts(poolPath string, key string) (string, string)

```

GetPositionFeeGrowthInsideLasts returns the last recorded fee growth inside for both tokens.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| poolPath | string | pool identifier in token0:token1:fee form |
| key | string | position key |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| feeGrowthInside0LastX128 | string | fee growth for token0 inside the position |
| feeGrowthInside1LastX128 | string | fee growth for token1 inside the position |

---

<a id="getpositionliquidity"></a>

### GetPositionLiquidity

```go

func GetPositionLiquidity(poolPath string, key string) *u256.Uint

```

GetPositionLiquidity returns the liquidity of a position.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| poolPath | string | pool identifier in token0:token1:fee form |
| key | string | position key |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| liquidity | *u256.Uint | position liquidity |

---

<a id="getpositiontokensowed"></a>

### GetPositionTokensOwed

```go

func GetPositionTokensOwed(poolPath string, key string) (string, string)

```

GetPositionTokensOwed returns the amount of tokens owed for both tokens.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| poolPath | string | pool identifier in token0:token1:fee form |
| key | string | position key |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| tokensOwed0 | string | amount of token0 owed to the position |
| tokensOwed1 | string | amount of token1 owed to the position |

---

<a id="getpositiontokensowed0"></a>

### GetPositionTokensOwed0

```go

func GetPositionTokensOwed0(poolPath string, key string) string

```

GetPositionTokensOwed0 returns the amount of token0 owed to a position.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| poolPath | string | pool identifier in token0:token1:fee form |
| key | string | position key |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| tokensOwed0 | string | amount of token0 owed to the position |

---

<a id="getpositiontokensowed1"></a>

### GetPositionTokensOwed1

```go

func GetPositionTokensOwed1(poolPath string, key string) string

```

GetPositionTokensOwed1 returns the amount of token1 owed to a position.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| poolPath | string | pool identifier in token0:token1:fee form |
| key | string | position key |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| tokensOwed1 | string | amount of token1 owed to the position |

---

<a id="getprotocolfeestoken0"></a>

### GetProtocolFeesToken0

```go

func GetProtocolFeesToken0(poolPath string) string

```

GetProtocolFeesToken0 returns accumulated protocol fees for token0.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| poolPath | string | pool identifier in token0:token1:fee form |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| protocolFeesToken0 | string | accumulated protocol fees for token0 |

---

<a id="getprotocolfeestoken1"></a>

### GetProtocolFeesToken1

```go

func GetProtocolFeesToken1(poolPath string) string

```

GetProtocolFeesToken1 returns accumulated protocol fees for token1.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| poolPath | string | pool identifier in token0:token1:fee form |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| protocolFeesToken1 | string | accumulated protocol fees for token1 |

---

<a id="getprotocolfeestokens"></a>

### GetProtocolFeesTokens

```go

func GetProtocolFeesTokens(poolPath string) (string, string)

```

GetProtocolFeesTokens returns the accumulated protocol fees for both tokens.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| poolPath | string | pool identifier in token0:token1:fee form |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| protocolFeesToken0 | string | accumulated protocol fees for token0 |
| protocolFeesToken1 | string | accumulated protocol fees for token1 |

---

<a id="getslot0feeprotocol"></a>

### GetSlot0FeeProtocol

```go

func GetSlot0FeeProtocol(poolPath string) uint8

```

GetSlot0FeeProtocol returns the protocol fee rate from slot0.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| poolPath | string | pool identifier in token0:token1:fee form |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| feeProtocol | uint8 | protocol fee rate packed in slot0 |

---

<a id="getslot0sqrtpricex96"></a>

### GetSlot0SqrtPriceX96

```go

func GetSlot0SqrtPriceX96(poolPath string) *u256.Uint

```

GetSlot0SqrtPriceX96 returns the current sqrt price from slot0.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| poolPath | string | pool identifier in token0:token1:fee form |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| sqrtPriceX96 | *u256.Uint | sqrt price in Q64.96 format |

---

<a id="getslot0tick"></a>

### GetSlot0Tick

```go

func GetSlot0Tick(poolPath string) int32

```

GetSlot0Tick returns the current tick from slot0.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| poolPath | string | pool identifier in token0:token1:fee form |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| tick | int32 | current tick |

---

<a id="getslot0unlocked"></a>

### GetSlot0Unlocked

```go

func GetSlot0Unlocked(poolPath string) bool

```

GetSlot0Unlocked returns the locked status from slot0.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| poolPath | string | pool identifier in token0:token1:fee form |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| unlocked | bool | true if pool is unlocked |

---

<a id="gettwap"></a>

### GetTWAP

```go

func GetTWAP(poolPath string, secondsAgo uint32) (int32, *u256.Uint, error)

```

GetTWAP returns the time-weighted average price for a pool.
Returns arithmetic mean tick and harmonic mean liquidity over the time period.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| poolPath | string | pool identifier in token0:token1:fee form |
| secondsAgo | uint32 | lookback window in seconds |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| meanTick | int32 | arithmetic mean tick |
| meanLiquidity | *u256.Uint | harmonic mean liquidity |
| err | error | non-nil on failure |

---

<a id="gettickbitmaps"></a>

### GetTickBitmaps

```go

func GetTickBitmaps(poolPath string, wordPos int16) (*u256.Uint, error)

```

GetTickBitmaps returns the tick bitmap for a given word position.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| poolPath | string | pool identifier in token0:token1:fee form |
| wordPos | int16 | bitmap word position |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| tickBitmap | *u256.Uint | tick bitmap copy |
| err | error | non-nil if the bitmap cannot be loaded |

---

<a id="gettickcumulativeoutside"></a>

### GetTickCumulativeOutside

```go

func GetTickCumulativeOutside(poolPath string, tick int32) int64

```

GetTickCumulativeOutside returns the tick cumulative value outside a tick.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| poolPath | string | pool identifier in token0:token1:fee form |
| tick | int32 | tick index |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| tickCumulativeOutside | int64 | tick cumulative outside the tick |

---

<a id="gettickfeegrowthoutside0x128"></a>

### GetTickFeeGrowthOutside0X128

```go

func GetTickFeeGrowthOutside0X128(poolPath string, tick int32) string

```

GetTickFeeGrowthOutside0X128 returns fee growth outside for token0 at a tick.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| poolPath | string | pool identifier in token0:token1:fee form |
| tick | int32 | tick index |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| feeGrowthOutside0X128 | string | fee growth outside for token0 as Q128.128 |

---

<a id="gettickfeegrowthoutside1x128"></a>

### GetTickFeeGrowthOutside1X128

```go

func GetTickFeeGrowthOutside1X128(poolPath string, tick int32) string

```

GetTickFeeGrowthOutside1X128 returns fee growth outside for token1 at a tick.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| poolPath | string | pool identifier in token0:token1:fee form |
| tick | int32 | tick index |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| feeGrowthOutside1X128 | string | fee growth outside for token1 as Q128.128 |

---

<a id="gettickfeegrowthoutsidex128"></a>

### GetTickFeeGrowthOutsideX128

```go

func GetTickFeeGrowthOutsideX128(poolPath string, tick int32) (*u256.Uint, *u256.Uint)

```

GetTickFeeGrowthOutsideX128 returns fee growth outside for both tokens at a tick.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| poolPath | string | pool identifier in token0:token1:fee form |
| tick | int32 | tick index |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| feeGrowthOutside0X128 | *u256.Uint | fee growth outside for token0 as Q128.128 |
| feeGrowthOutside1X128 | *u256.Uint | fee growth outside for token1 as Q128.128 |

---

<a id="gettickfeegrowthoutsides"></a>

### GetTickFeeGrowthOutsides

```go

func GetTickFeeGrowthOutsides(poolPath string, tick int32) (string, string)

```

GetTickFeeGrowthOutsides returns fee growth outside for both tokens at a tick.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| poolPath | string | pool identifier in token0:token1:fee form |
| tick | int32 | tick index |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| feeGrowthOutside0X128 | string | fee growth outside for token0 as Q128.128 |
| feeGrowthOutside1X128 | string | fee growth outside for token1 as Q128.128 |

---

<a id="gettickinitialized"></a>

### GetTickInitialized

```go

func GetTickInitialized(poolPath string, tick int32) bool

```

GetTickInitialized returns whether a tick is initialized.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| poolPath | string | pool identifier in token0:token1:fee form |
| tick | int32 | tick index |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| initialized | bool | true if the tick is initialized |

---

<a id="gettickliquiditygross"></a>

### GetTickLiquidityGross

```go

func GetTickLiquidityGross(poolPath string, tick int32) string

```

GetTickLiquidityGross returns the total liquidity that references a tick.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| poolPath | string | pool identifier in token0:token1:fee form |
| tick | int32 | tick index |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| liquidityGross | string | gross liquidity for the tick |

---

<a id="gettickliquiditynet"></a>

### GetTickLiquidityNet

```go

func GetTickLiquidityNet(poolPath string, tick int32) string

```

GetTickLiquidityNet returns the net liquidity change at a tick.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| poolPath | string | pool identifier in token0:token1:fee form |
| tick | int32 | tick index |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| liquidityNet | string | net liquidity change at the tick |

---

<a id="getticksecondsoutside"></a>

### GetTickSecondsOutside

```go

func GetTickSecondsOutside(poolPath string, tick int32) uint32

```

GetTickSecondsOutside returns seconds spent outside a tick.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| poolPath | string | pool identifier in token0:token1:fee form |
| tick | int32 | tick index |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| secondsOutside | uint32 | seconds spent outside the tick |

---

<a id="getticksecondsperliquidityoutsidex128"></a>

### GetTickSecondsPerLiquidityOutsideX128

```go

func GetTickSecondsPerLiquidityOutsideX128(poolPath string, tick int32) string

```

GetTickSecondsPerLiquidityOutsideX128 returns seconds per liquidity outside a tick.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| poolPath | string | pool identifier in token0:token1:fee form |
| tick | int32 | tick index |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| secondsPerLiquidityOutsideX128 | string | seconds per liquidity outside the tick as Q128.128 |

---

<a id="gettickspacing"></a>

### GetTickSpacing

```go

func GetTickSpacing(poolPath string) int32

```

GetTickSpacing returns the tick spacing of the pool.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| poolPath | string | pool identifier in token0:token1:fee form |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| tickSpacing | int32 | tick spacing |

---

<a id="gettoken0path"></a>

### GetToken0Path

```go

func GetToken0Path(poolPath string) string

```

GetToken0Path returns the path of token0 in the pool.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| poolPath | string | pool identifier in token0:token1:fee form |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| token0Path | string | token0 path |

---

<a id="gettoken1path"></a>

### GetToken1Path

```go

func GetToken1Path(poolPath string) string

```

GetToken1Path returns the path of token1 in the pool.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| poolPath | string | pool identifier in token0:token1:fee form |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| token1Path | string | token1 path |

---

<a id="getwithdrawalfee"></a>

### GetWithdrawalFee

```go

func GetWithdrawalFee() uint64

```

GetWithdrawalFee returns the current withdrawal fee rate.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| withdrawalFee | uint64 | withdrawal fee in basis points |

---

<a id="handlewithdrawalfee"></a>

### HandleWithdrawalFee

```go

func HandleWithdrawalFee(cur realm, positionId uint64, token0Path string, amount0 string, token1Path string, amount1 string, poolPath string, positionCaller address) (string, string)

```

HandleWithdrawalFee processes withdrawal fees for a position.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| cur | realm |  |
| positionId | uint64 | ID of the position |
| token0Path | string | path of the first token |
| amount0 | string | amount of token0 to withdraw |
| token1Path | string | path of the second token |
| amount1 | string | amount of token1 to withdraw |
| poolPath | string | pool identifier |
| positionCaller | address | caller address for the position |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| amount0 | string | net amount of token0 after fees |
| amount1 | string | net amount of token1 after fees |

---

<a id="increaseobservationcardinalitynext"></a>

### IncreaseObservationCardinalityNext

```go

func IncreaseObservationCardinalityNext(cur realm, token0Path string, token1Path string, fee uint32, cardinalityNext uint16)

```

IncreaseObservationCardinalityNext increases the observation cardinality for a pool.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| cur | realm |  |
| token0Path | string | path of the first token |
| token1Path | string | path of the second token |
| fee | uint32 | pool fee tier |
| cardinalityNext | uint16 | new observation cardinality limit |

---

<a id="mint"></a>

### Mint

```go

func Mint(cur realm, token0Path string, token1Path string, fee uint32, tickLower int32, tickUpper int32, liquidityAmount string, positionCaller address) (string, string)

```

Mint adds liquidity to a position.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| cur | realm |  |
| token0Path | string | path of the first token |
| token1Path | string | path of the second token |
| fee | uint32 | pool fee tier |
| tickLower | int32 | lower tick boundary |
| tickUpper | int32 | upper tick boundary |
| liquidityAmount | string | amount of liquidity to add |
| positionCaller | address | caller address for the position |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| amount0 | string | amount of token0 added |
| amount1 | string | amount of token1 added |

---

<a id="parsepoolpath"></a>

### ParsePoolPath

```go

func ParsePoolPath(poolPath string) (string, string, uint32)

```

ParsePoolPath splits a pool path into token paths and fee tier.



Panics if the poolPath is malformed or fee cannot be parsed.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| poolPath | string | pool identifier in token0:token1:fee form |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| token0Path | string | token0 path |
| token1Path | string | token1 path |
| fee | uint32 | fee tier |

---

<a id="registerinitializer"></a>

### RegisterInitializer

```go

func RegisterInitializer(cur realm, initializer func(...))

```

RegisterInitializer registers a new pool implementation version.
This function is called by each version (v1, v2, etc.) during initialization
to register their implementation with the proxy system.

The initializer function creates a new instance of the implementation
using the provided poolStore interface.

The stateInitializer function creates the initial state for this version.

Security: Only contracts within the domain path can register initializers.
Each package path can only register once to prevent duplicate registrations.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| cur | realm |  |
| initializer | func(...) |  |

---

<a id="setfeeprotocol"></a>

### SetFeeProtocol

```go

func SetFeeProtocol(cur realm, feeProtocol0 uint8, feeProtocol1 uint8)

```

SetFeeProtocol sets the protocol fee rates for a pool.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| cur | realm |  |
| feeProtocol0 | uint8 | protocol fee rate for token0 |
| feeProtocol1 | uint8 | protocol fee rate for token1 |

---

<a id="setpoolcreationfee"></a>

### SetPoolCreationFee

```go

func SetPoolCreationFee(cur realm, fee int64)

```

SetPoolCreationFee sets the pool creation fee.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| cur | realm |  |
| fee | int64 | fee charged when creating a new pool |

---

<a id="setswapendhook"></a>

### SetSwapEndHook

```go

func SetSwapEndHook(cur realm, hook func(...))

```

SetSwapEndHook sets the hook to be called at the end of a swap.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| cur | realm |  |
| hook | func(...) | callback invoked after a swap completes for a pool path |

---

<a id="setswapstarthook"></a>

### SetSwapStartHook

```go

func SetSwapStartHook(cur realm, hook func(...))

```

SetSwapStartHook sets the hook to be called at the start of a swap.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| cur | realm |  |
| hook | func(...) | callback invoked before a swap starts for a pool path |

---

<a id="settickcrosshook"></a>

### SetTickCrossHook

```go

func SetTickCrossHook(cur realm, hook func(...))

```

SetTickCrossHook sets the hook to be called when a tick is crossed during a swap.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| cur | realm |  |
| hook | func(...) | callback invoked when a swap crosses a tick within a pool |

---

<a id="setwithdrawalfee"></a>

### SetWithdrawalFee

```go

func SetWithdrawalFee(cur realm, fee uint64)

```

SetWithdrawalFee sets the withdrawal fee rate.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| cur | realm |  |
| fee | uint64 | withdrawal fee in basis points |

---

<a id="swap"></a>

### Swap

```go

func Swap(cur realm, token0Path string, token1Path string, fee uint32, recipient address, zeroForOne bool, amountSpecified string, sqrtPriceLimitX96 string, payer address, swapCallback func(...)) (string, string)

```

Swap executes a token swap in the pool.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| cur | realm |  |
| token0Path | string | path of the first token |
| token1Path | string | path of the second token |
| fee | uint32 | pool fee tier |
| recipient | address | recipient address for output tokens |
| zeroForOne | bool | true if swapping token0 for token1 |
| amountSpecified | string | amount to swap (positive for exact input, negative for exact output) |
| sqrtPriceLimitX96 | string | price limit for the swap |
| payer | address | address that will pay for the swap |
| swapCallback | func(...) | callback function for token transfer, callbackMarker is used to identify the callback |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| amount0Delta | string | amount of token0 delta |
| amount1Delta | string | amount of token1 delta |

---

<a id="upgradeimpl"></a>

### UpgradeImpl

```go

func UpgradeImpl(cur realm, packagePath string)

```

UpgradeImpl switches the active pool implementation to a different version.
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

<a id="balances"></a>

### Balances

```go

type Balances struct

```

#### Fields

- `TokenPair TokenPair`

---

<a id="callbackmarker"></a>

### CallbackMarker

```go

type CallbackMarker struct

```

---

<a id="ipool"></a>

### IPool

```go

type IPool interface

```

IPool interface defines all public methods that must be implemented by pool contract versions.
This interface serves as the contract between the proxy layer and implementation versions,
ensuring that all versions (v1, v2, v3, etc.) maintain the same public API.

This design enables seamless upgrades while maintaining backwards compatibility.
When upgrading from v1 to v2, the proxy simply switches the implementation pointer
without changing the public interface, ensuring zero downtime and no breaking changes.

---

<a id="ipoolgetter"></a>

### IPoolGetter

```go

type IPoolGetter interface

```

IPoolGetter interface defines data retrieval operations.
These methods provide read-only access to pool state and data.

---

<a id="ipoolmanager"></a>

### IPoolManager

```go

type IPoolManager interface

```

IPoolManager interface defines pool management operations.
These methods handle pool creation and fee configuration.

---

<a id="ipoolposition"></a>

### IPoolPosition

```go

type IPoolPosition interface

```

IPoolPosition interface defines position management operations.
These methods handle liquidity provision and position management.

---

<a id="ipoolstore"></a>

### IPoolStore

```go

type IPoolStore interface

```

IPoolStore interface defines the storage abstraction for pool data.
This interface provides a clean separation between business logic and storage,
allowing different implementations to use the same storage interface.

All pool implementations (v1, v2, etc.) use this interface to access
and modify pool state, ensuring data consistency across versions.

#### Constructors

- `func NewPoolStore(kvStore store.KVStore) IPoolStore`

---

<a id="ipoolswap"></a>

### IPoolSwap

```go

type IPoolSwap interface

```

IPoolSwap interface defines swap and protocol fee operations.
These methods handle token swaps and protocol fee management.

---

<a id="observation"></a>

### Observation

```go

type Observation struct

```

#### Methods

<a id="observation.blocktimestamp"></a>
##### BlockTimestamp

```go
func (o *Observation) BlockTimestamp() int64
```

Observation Getters methods

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int64 |  |

<a id="observation.clone"></a>
##### Clone

```go
func (o *Observation) Clone() *Observation
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | *Observation |  |

<a id="observation.initialized"></a>
##### Initialized

```go
func (o *Observation) Initialized() bool
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | bool |  |

<a id="observation.liquiditycumulative"></a>
##### LiquidityCumulative

```go
func (o *Observation) LiquidityCumulative() *u256.Uint
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | *u256.Uint |  |

<a id="observation.secondsperliquiditycumulativex128"></a>
##### SecondsPerLiquidityCumulativeX128

```go
func (o *Observation) SecondsPerLiquidityCumulativeX128() *u256.Uint
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | *u256.Uint |  |

<a id="observation.setblocktimestamp"></a>
##### SetBlockTimestamp

```go
func (o *Observation) SetBlockTimestamp(blockTimestamp int64)
```

Observation Setters methods

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| blockTimestamp | int64 |  |

<a id="observation.setinitialized"></a>
##### SetInitialized

```go
func (o *Observation) SetInitialized(initialized bool)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| initialized | bool |  |

<a id="observation.setliquiditycumulative"></a>
##### SetLiquidityCumulative

```go
func (o *Observation) SetLiquidityCumulative(liquidityCumulative *u256.Uint)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| liquidityCumulative | *u256.Uint |  |

<a id="observation.setsecondsperliquiditycumulativex128"></a>
##### SetSecondsPerLiquidityCumulativeX128

```go
func (o *Observation) SetSecondsPerLiquidityCumulativeX128(secondsPerLiquidityCumulativeX128 *u256.Uint)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| secondsPerLiquidityCumulativeX128 | *u256.Uint |  |

<a id="observation.settickcumulative"></a>
##### SetTickCumulative

```go
func (o *Observation) SetTickCumulative(tickCumulative int64)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| tickCumulative | int64 |  |

<a id="observation.tickcumulative"></a>
##### TickCumulative

```go
func (o *Observation) TickCumulative() int64
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int64 |  |


#### Constructors

- `func NewDefaultObservation() *Observation`
- `func NewObservation(blockTimestamp int64, tickCumulative int64, liquidityCumulative *u256.Uint, secondsPerLiquidityCumulativeX128 *u256.Uint, initialized bool) *Observation`

---

<a id="observationstate"></a>

### ObservationState

```go

type ObservationState struct

```

ObservationState manages the oracle's historical data

#### Methods

<a id="observationstate.cardinality"></a>
##### Cardinality

```go
func (os *ObservationState) Cardinality() uint16
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | uint16 |  |

<a id="observationstate.cardinalitynext"></a>
##### CardinalityNext

```go
func (os *ObservationState) CardinalityNext() uint16
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | uint16 |  |

<a id="observationstate.clone"></a>
##### Clone

```go
func (os *ObservationState) Clone() *ObservationState
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | *ObservationState |  |

<a id="observationstate.index"></a>
##### Index

```go
func (os *ObservationState) Index() uint16
```

ObservationState Getters methods

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | uint16 |  |

<a id="observationstate.observations"></a>
##### Observations

```go
func (os *ObservationState) Observations() map[uint16]*Observation
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | map[uint16]*Observation |  |

<a id="observationstate.setcardinality"></a>
##### SetCardinality

```go
func (os *ObservationState) SetCardinality(cardinality uint16)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| cardinality | uint16 |  |

<a id="observationstate.setcardinalitynext"></a>
##### SetCardinalityNext

```go
func (os *ObservationState) SetCardinalityNext(cardinalityNext uint16)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| cardinalityNext | uint16 |  |

<a id="observationstate.setindex"></a>
##### SetIndex

```go
func (os *ObservationState) SetIndex(index uint16)
```

ObservationState Setters methods

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| index | uint16 |  |

<a id="observationstate.setobservations"></a>
##### SetObservations

```go
func (os *ObservationState) SetObservations(observations map[uint16]*Observation)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| observations | map[uint16]*Observation |  |


#### Constructors

- `func GetObservationState(poolPath string) (*ObservationState, error)`
- `func NewObservationState(currentTime int64) *ObservationState`

---

<a id="pool"></a>

### Pool

```go

type Pool struct

```

type Pool describes a single Pool's state
A pool is identificed with a unique key (token0, token1, fee), where token0 < token1

#### Methods

<a id="pool.balancetoken0"></a>
##### BalanceToken0

```go
func (p *Pool) BalanceToken0() *u256.Uint
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | *u256.Uint |  |

<a id="pool.balancetoken1"></a>
##### BalanceToken1

```go
func (p *Pool) BalanceToken1() *u256.Uint
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | *u256.Uint |  |

<a id="pool.balances"></a>
##### Balances

```go
func (p *Pool) Balances() Balances
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | Balances |  |

<a id="pool.clone"></a>
##### Clone

```go
func (p *Pool) Clone() *Pool
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | *Pool |  |

<a id="pool.deletetick"></a>
##### DeleteTick

```go
func (p *Pool) DeleteTick(tick int32)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| tick | int32 |  |

<a id="pool.fee"></a>
##### Fee

```go
func (p *Pool) Fee() uint32
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | uint32 |  |

<a id="pool.feegrowthglobal0x128"></a>
##### FeeGrowthGlobal0X128

```go
func (p *Pool) FeeGrowthGlobal0X128() *u256.Uint
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | *u256.Uint |  |

<a id="pool.feegrowthglobal1x128"></a>
##### FeeGrowthGlobal1X128

```go
func (p *Pool) FeeGrowthGlobal1X128() *u256.Uint
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | *u256.Uint |  |

<a id="pool.liquidity"></a>
##### Liquidity

```go
func (p *Pool) Liquidity() *u256.Uint
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | *u256.Uint |  |

<a id="pool.maxliquiditypertick"></a>
##### MaxLiquidityPerTick

```go
func (p *Pool) MaxLiquidityPerTick() *u256.Uint
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | *u256.Uint |  |

<a id="pool.observationstate"></a>
##### ObservationState

```go
func (p *Pool) ObservationState() *ObservationState
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | *ObservationState |  |

<a id="pool.poolpath"></a>
##### PoolPath

```go
func (p *Pool) PoolPath() string
```

Pool Getters methods

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | string |  |

<a id="pool.positions"></a>
##### Positions

```go
func (p *Pool) Positions() *avl.Tree
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | *avl.Tree |  |

<a id="pool.protocolfees"></a>
##### ProtocolFees

```go
func (p *Pool) ProtocolFees() ProtocolFees
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | ProtocolFees |  |

<a id="pool.protocolfeestoken0"></a>
##### ProtocolFeesToken0

```go
func (p *Pool) ProtocolFeesToken0() *u256.Uint
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | *u256.Uint |  |

<a id="pool.protocolfeestoken1"></a>
##### ProtocolFeesToken1

```go
func (p *Pool) ProtocolFeesToken1() *u256.Uint
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | *u256.Uint |  |

<a id="pool.setbalancetoken0"></a>
##### SetBalanceToken0

```go
func (p *Pool) SetBalanceToken0(token0 *u256.Uint)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| token0 | *u256.Uint |  |

<a id="pool.setbalancetoken1"></a>
##### SetBalanceToken1

```go
func (p *Pool) SetBalanceToken1(token1 *u256.Uint)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| token1 | *u256.Uint |  |

<a id="pool.setbalances"></a>
##### SetBalances

```go
func (p *Pool) SetBalances(balances Balances)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| balances | Balances |  |

<a id="pool.setfee"></a>
##### SetFee

```go
func (p *Pool) SetFee(fee uint32)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| fee | uint32 |  |

<a id="pool.setfeegrowthglobal0x128"></a>
##### SetFeeGrowthGlobal0X128

```go
func (p *Pool) SetFeeGrowthGlobal0X128(feeGrowthGlobal0X128 *u256.Uint)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| feeGrowthGlobal0X128 | *u256.Uint |  |

<a id="pool.setfeegrowthglobal1x128"></a>
##### SetFeeGrowthGlobal1X128

```go
func (p *Pool) SetFeeGrowthGlobal1X128(feeGrowthGlobal1X128 *u256.Uint)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| feeGrowthGlobal1X128 | *u256.Uint |  |

<a id="pool.setliquidity"></a>
##### SetLiquidity

```go
func (p *Pool) SetLiquidity(liquidity *u256.Uint)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| liquidity | *u256.Uint |  |

<a id="pool.setmaxliquiditypertick"></a>
##### SetMaxLiquidityPerTick

```go
func (p *Pool) SetMaxLiquidityPerTick(maxLiquidityPerTick *u256.Uint)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| maxLiquidityPerTick | *u256.Uint |  |

<a id="pool.setobservationstate"></a>
##### SetObservationState

```go
func (p *Pool) SetObservationState(observationState *ObservationState)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| observationState | *ObservationState |  |

<a id="pool.setpositions"></a>
##### SetPositions

```go
func (p *Pool) SetPositions(positions *avl.Tree)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| positions | *avl.Tree |  |

<a id="pool.setprotocolfees"></a>
##### SetProtocolFees

```go
func (p *Pool) SetProtocolFees(protocolFees ProtocolFees)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| protocolFees | ProtocolFees |  |

<a id="pool.setprotocolfeestoken0"></a>
##### SetProtocolFeesToken0

```go
func (p *Pool) SetProtocolFeesToken0(token0 *u256.Uint)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| token0 | *u256.Uint |  |

<a id="pool.setprotocolfeestoken1"></a>
##### SetProtocolFeesToken1

```go
func (p *Pool) SetProtocolFeesToken1(token1 *u256.Uint)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| token1 | *u256.Uint |  |

<a id="pool.setslot0"></a>
##### SetSlot0

```go
func (p *Pool) SetSlot0(slot0 Slot0)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| slot0 | Slot0 |  |

<a id="pool.settickbitmaps"></a>
##### SetTickBitmaps

```go
func (p *Pool) SetTickBitmaps(tickBitmaps *avl.Tree)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| tickBitmaps | *avl.Tree |  |

<a id="pool.settickspacing"></a>
##### SetTickSpacing

```go
func (p *Pool) SetTickSpacing(tickSpacing int32)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| tickSpacing | int32 |  |

<a id="pool.setticks"></a>
##### SetTicks

```go
func (p *Pool) SetTicks(ticks *avl.Tree)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| ticks | *avl.Tree |  |

<a id="pool.settoken0path"></a>
##### SetToken0Path

```go
func (p *Pool) SetToken0Path(token0Path string)
```

Pool Setters methods

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| token0Path | string |  |

<a id="pool.settoken1path"></a>
##### SetToken1Path

```go
func (p *Pool) SetToken1Path(token1Path string)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| token1Path | string |  |

<a id="pool.slot0"></a>
##### Slot0

```go
func (p *Pool) Slot0() Slot0
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | Slot0 |  |

<a id="pool.slot0feeprotocol"></a>
##### Slot0FeeProtocol

```go
func (p *Pool) Slot0FeeProtocol() uint8
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | uint8 |  |

<a id="pool.slot0sqrtpricex96"></a>
##### Slot0SqrtPriceX96

```go
func (p *Pool) Slot0SqrtPriceX96() *u256.Uint
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | *u256.Uint |  |

<a id="pool.slot0tick"></a>
##### Slot0Tick

```go
func (p *Pool) Slot0Tick() int32
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int32 |  |

<a id="pool.slot0unlocked"></a>
##### Slot0Unlocked

```go
func (p *Pool) Slot0Unlocked() bool
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | bool |  |

<a id="pool.tickbitmaps"></a>
##### TickBitmaps

```go
func (p *Pool) TickBitmaps() *avl.Tree
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | *avl.Tree |  |

<a id="pool.tickspacing"></a>
##### TickSpacing

```go
func (p *Pool) TickSpacing() int32
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int32 |  |

<a id="pool.ticks"></a>
##### Ticks

```go
func (p *Pool) Ticks() *avl.Tree
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | *avl.Tree |  |

<a id="pool.token0path"></a>
##### Token0Path

```go
func (p *Pool) Token0Path() string
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | string |  |

<a id="pool.token1path"></a>
##### Token1Path

```go
func (p *Pool) Token1Path() string
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | string |  |


#### Constructors

- `func GetPool(token0Path string, token1Path string, fee uint32) (*Pool, error)`
- `func NewPool(token0Path string, token1Path string, fee uint32, sqrtPriceX96 *u256.Uint, tickSpacing int32, tick int32, slot0FeeProtocol uint8, maxLiquidityPerTick *u256.Uint) *Pool`

---

<a id="positioninfo"></a>

### PositionInfo

```go

type PositionInfo struct

```

#### Methods

<a id="positioninfo.feegrowthinside0lastx128"></a>
##### FeeGrowthInside0LastX128

```go
func (p *PositionInfo) FeeGrowthInside0LastX128() *u256.Uint
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | *u256.Uint |  |

<a id="positioninfo.feegrowthinside1lastx128"></a>
##### FeeGrowthInside1LastX128

```go
func (p *PositionInfo) FeeGrowthInside1LastX128() *u256.Uint
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | *u256.Uint |  |

<a id="positioninfo.liquidity"></a>
##### Liquidity

```go
func (p *PositionInfo) Liquidity() *u256.Uint
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | *u256.Uint |  |

<a id="positioninfo.setfeegrowthinside0lastx128"></a>
##### SetFeeGrowthInside0LastX128

```go
func (p *PositionInfo) SetFeeGrowthInside0LastX128(feeGrowthInside0LastX128 *u256.Uint)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| feeGrowthInside0LastX128 | *u256.Uint |  |

<a id="positioninfo.setfeegrowthinside1lastx128"></a>
##### SetFeeGrowthInside1LastX128

```go
func (p *PositionInfo) SetFeeGrowthInside1LastX128(feeGrowthInside1LastX128 *u256.Uint)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| feeGrowthInside1LastX128 | *u256.Uint |  |

<a id="positioninfo.setliquidity"></a>
##### SetLiquidity

```go
func (p *PositionInfo) SetLiquidity(liquidity *u256.Uint)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| liquidity | *u256.Uint |  |

<a id="positioninfo.settokensowed0"></a>
##### SetTokensOwed0

```go
func (p *PositionInfo) SetTokensOwed0(tokensOwed0 *u256.Uint)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| tokensOwed0 | *u256.Uint |  |

<a id="positioninfo.settokensowed1"></a>
##### SetTokensOwed1

```go
func (p *PositionInfo) SetTokensOwed1(tokensOwed1 *u256.Uint)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| tokensOwed1 | *u256.Uint |  |

<a id="positioninfo.tokensowed0"></a>
##### TokensOwed0

```go
func (p *PositionInfo) TokensOwed0() *u256.Uint
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | *u256.Uint |  |

<a id="positioninfo.tokensowed1"></a>
##### TokensOwed1

```go
func (p *PositionInfo) TokensOwed1() *u256.Uint
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | *u256.Uint |  |


#### Constructors

- `func GetPosition(poolPath string, key string) (PositionInfo, error)`
- `func NewDefaultPositionInfo() PositionInfo`
- `func NewPositionInfo(liquidity *u256.Uint, feeGrowthInside0LastX128 *u256.Uint, feeGrowthInside1LastX128 *u256.Uint, tokensOwed0 *u256.Uint, tokensOwed1 *u256.Uint) PositionInfo`

---

<a id="protocolfees"></a>

### ProtocolFees

```go

type ProtocolFees struct

```

#### Fields

- `TokenPair TokenPair`

---

<a id="slot0"></a>

### Slot0

```go

type Slot0 struct

```

#### Methods

<a id="slot0.feeprotocol"></a>
##### FeeProtocol

```go
func (s *Slot0) FeeProtocol() uint8
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | uint8 |  |

<a id="slot0.setfeeprotocol"></a>
##### SetFeeProtocol

```go
func (s *Slot0) SetFeeProtocol(feeProtocol uint8)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| feeProtocol | uint8 |  |

<a id="slot0.setsqrtpricex96"></a>
##### SetSqrtPriceX96

```go
func (s *Slot0) SetSqrtPriceX96(sqrtPriceX96 *u256.Uint)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| sqrtPriceX96 | *u256.Uint |  |

<a id="slot0.settick"></a>
##### SetTick

```go
func (s *Slot0) SetTick(tick int32)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| tick | int32 |  |

<a id="slot0.setunlocked"></a>
##### SetUnlocked

```go
func (s *Slot0) SetUnlocked(unlocked bool)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| unlocked | bool |  |

<a id="slot0.sqrtpricex96"></a>
##### SqrtPriceX96

```go
func (s *Slot0) SqrtPriceX96() *u256.Uint
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | *u256.Uint |  |

<a id="slot0.tick"></a>
##### Tick

```go
func (s *Slot0) Tick() int32
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int32 |  |

<a id="slot0.unlocked"></a>
##### Unlocked

```go
func (s *Slot0) Unlocked() bool
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | bool |  |


---

<a id="storekey"></a>

### StoreKey

```go

type StoreKey string

```

StoreKey defines the keys used for storing pool data in the KV store.
These keys are prefixed with the domain address to ensure namespace isolation.

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

<a id="tickinfo"></a>

### TickInfo

```go

type TickInfo struct

```

TickInfo stores information about a specific tick in the pool.
TIcks represent discrete price points that can be used as boundaries for positions.

#### Methods

<a id="tickinfo.feegrowthoutside0x128"></a>
##### FeeGrowthOutside0X128

```go
func (t *TickInfo) FeeGrowthOutside0X128() *u256.Uint
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | *u256.Uint |  |

<a id="tickinfo.feegrowthoutside1x128"></a>
##### FeeGrowthOutside1X128

```go
func (t *TickInfo) FeeGrowthOutside1X128() *u256.Uint
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | *u256.Uint |  |

<a id="tickinfo.initialized"></a>
##### Initialized

```go
func (t *TickInfo) Initialized() bool
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | bool |  |

<a id="tickinfo.liquiditygross"></a>
##### LiquidityGross

```go
func (t *TickInfo) LiquidityGross() *u256.Uint
```

TickInfo Getters methods

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | *u256.Uint |  |

<a id="tickinfo.liquiditynet"></a>
##### LiquidityNet

```go
func (t *TickInfo) LiquidityNet() *i256.Int
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | *i256.Int |  |

<a id="tickinfo.secondsoutside"></a>
##### SecondsOutside

```go
func (t *TickInfo) SecondsOutside() uint32
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | uint32 |  |

<a id="tickinfo.secondsperliquidityoutsidex128"></a>
##### SecondsPerLiquidityOutsideX128

```go
func (t *TickInfo) SecondsPerLiquidityOutsideX128() *u256.Uint
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | *u256.Uint |  |

<a id="tickinfo.setfeegrowthoutside0x128"></a>
##### SetFeeGrowthOutside0X128

```go
func (t *TickInfo) SetFeeGrowthOutside0X128(feeGrowthOutside0X128 *u256.Uint)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| feeGrowthOutside0X128 | *u256.Uint |  |

<a id="tickinfo.setfeegrowthoutside1x128"></a>
##### SetFeeGrowthOutside1X128

```go
func (t *TickInfo) SetFeeGrowthOutside1X128(feeGrowthOutside1X128 *u256.Uint)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| feeGrowthOutside1X128 | *u256.Uint |  |

<a id="tickinfo.setinitialized"></a>
##### SetInitialized

```go
func (t *TickInfo) SetInitialized(initialized bool)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| initialized | bool |  |

<a id="tickinfo.setliquiditygross"></a>
##### SetLiquidityGross

```go
func (t *TickInfo) SetLiquidityGross(liquidityGross *u256.Uint)
```

TickInfo Setters methods

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| liquidityGross | *u256.Uint |  |

<a id="tickinfo.setliquiditynet"></a>
##### SetLiquidityNet

```go
func (t *TickInfo) SetLiquidityNet(liquidityNet *i256.Int)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| liquidityNet | *i256.Int |  |

<a id="tickinfo.setsecondsoutside"></a>
##### SetSecondsOutside

```go
func (t *TickInfo) SetSecondsOutside(secondsOutside uint32)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| secondsOutside | uint32 |  |

<a id="tickinfo.setsecondsperliquidityoutsidex128"></a>
##### SetSecondsPerLiquidityOutsideX128

```go
func (t *TickInfo) SetSecondsPerLiquidityOutsideX128(secondsPerLiquidityOutsideX128 *u256.Uint)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| secondsPerLiquidityOutsideX128 | *u256.Uint |  |

<a id="tickinfo.settickcumulativeoutside"></a>
##### SetTickCumulativeOutside

```go
func (t *TickInfo) SetTickCumulativeOutside(tickCumulativeOutside int64)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| tickCumulativeOutside | int64 |  |

<a id="tickinfo.tickcumulativeoutside"></a>
##### TickCumulativeOutside

```go
func (t *TickInfo) TickCumulativeOutside() int64
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int64 |  |


#### Constructors

- `func GetTickInfo(poolPath string, tick int32) (TickInfo, error)`
- `func NewTickInfo() TickInfo`

---

<a id="tokenpair"></a>

### TokenPair

```go

type TokenPair struct

```

#### Methods

<a id="tokenpair.clone"></a>
##### Clone

```go
func (t *TokenPair) Clone() TokenPair
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | TokenPair |  |

<a id="tokenpair.settoken0"></a>
##### SetToken0

```go
func (t *TokenPair) SetToken0(token0 *u256.Uint)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| token0 | *u256.Uint |  |

<a id="tokenpair.settoken1"></a>
##### SetToken1

```go
func (t *TokenPair) SetToken1(token1 *u256.Uint)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| token1 | *u256.Uint |  |

<a id="tokenpair.token0"></a>
##### Token0

```go
func (t *TokenPair) Token0() *u256.Uint
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | *u256.Uint |  |

<a id="tokenpair.token1"></a>
##### Token1

```go
func (t *TokenPair) Token1() *u256.Uint
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | *u256.Uint |  |


#### Constructors

- `func NewTokenPair(token0 *u256.Uint, token1 *u256.Uint) TokenPair`
