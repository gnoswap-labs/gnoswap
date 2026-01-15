# position

`import "gno.land/r/gnoswap/position"`



## Index

- [CollectFee](#collectfee)
- [DecreaseLiquidity](#decreaseliquidity)
- [GetImplementationPackagePath](#getimplementationpackagepath)
- [GetPositionCount](#getpositioncount)
- [GetPositionFeeGrowthInside0LastX128](#getpositionfeegrowthinside0lastx128)
- [GetPositionFeeGrowthInside1LastX128](#getpositionfeegrowthinside1lastx128)
- [GetPositionFeeGrowthInsideLastX128](#getpositionfeegrowthinsidelastx128)
- [GetPositionIDs](#getpositionids)
- [GetPositionLiquidity](#getpositionliquidity)
- [GetPositionOperator](#getpositionoperator)
- [GetPositionOwner](#getpositionowner)
- [GetPositionPoolKey](#getpositionpoolkey)
- [GetPositionTickLower](#getpositionticklower)
- [GetPositionTickUpper](#getpositiontickupper)
- [GetPositionTicks](#getpositionticks)
- [GetPositionToken0Balance](#getpositiontoken0balance)
- [GetPositionToken1Balance](#getpositiontoken1balance)
- [GetPositionTokenBalances](#getpositiontokenbalances)
- [GetPositionTokensOwed](#getpositiontokensowed)
- [GetPositionTokensOwed0](#getpositiontokensowed0)
- [GetPositionTokensOwed1](#getpositiontokensowed1)
- [GetUnclaimedFee](#getunclaimedfee)
- [IncreaseLiquidity](#increaseliquidity)
- [IsBurned](#isburned)
- [IsInRange](#isinrange)
- [Mint](#mint)
- [RegisterInitializer](#registerinitializer)
- [Reposition](#reposition)
- [SetPositionOperator](#setpositionoperator)
- [UpgradeImpl](#upgradeimpl)
- [IPosition](#iposition)
- [IPositionGetter](#ipositiongetter)
- [IPositionManager](#ipositionmanager)
- [IPositionStore](#ipositionstore)
- [Position](#position)
- [StoreKey](#storekey)


## Functions

<a id="collectfee"></a>

### CollectFee

```go

func CollectFee(cur realm, positionId uint64, unwrapResult bool) (uint64, string, string, string, string, string)

```

CollectFee collects accumulated fees from a position.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| cur | realm |  |
| positionId | uint64 | ID of the position |
| unwrapResult | bool | whether to unwrap WGNOT to GNOT |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| positionId | uint64 | position ID |
| amount0 | string | amount of token0 collected |
| amount1 | string | amount of token1 collected |
| poolPath | string | pool path |
| token0Path | string | token0 path |
| token1Path | string | token1 path |

---

<a id="decreaseliquidity"></a>

### DecreaseLiquidity

```go

func DecreaseLiquidity(cur realm, positionId uint64, liquidityStr string, amount0MinStr string, amount1MinStr string, deadline int64, unwrapResult bool) (uint64, string, string, string, string, string, string)

```

DecreaseLiquidity removes liquidity from a position.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| cur | realm |  |
| positionId | uint64 | ID of the position |
| liquidityStr | string | amount of liquidity to remove |
| amount0MinStr | string | minimum amount of token0 |
| amount1MinStr | string | minimum amount of token1 |
| deadline | int64 | transaction deadline |
| unwrapResult | bool | whether to unwrap WGNOT to GNOT |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| positionId | uint64 | position ID |
| liquidity | string | removed liquidity amount |
| amount0 | string | amount of token0 removed |
| amount1 | string | amount of token1 removed |
| poolPath | string | pool path |
| amount0AfterFee | string | net amount of token0 after fees |
| amount1AfterFee | string | net amount of token1 after fees |

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

<a id="getpositioncount"></a>

### GetPositionCount

```go

func GetPositionCount() int

```

GetPositionCount returns the total number of positions.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| count | int | total number of positions |

---

<a id="getpositionfeegrowthinside0lastx128"></a>

### GetPositionFeeGrowthInside0LastX128

```go

func GetPositionFeeGrowthInside0LastX128(positionId uint64) *u256.Uint

```

GetPositionFeeGrowthInside0LastX128 returns the last recorded fee growth inside for token0.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| positionId | uint64 | ID of the position |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| feeGrowth | *u256.Uint | fee growth inside for token0 in X128 format |

---

<a id="getpositionfeegrowthinside1lastx128"></a>

### GetPositionFeeGrowthInside1LastX128

```go

func GetPositionFeeGrowthInside1LastX128(positionId uint64) *u256.Uint

```

GetPositionFeeGrowthInside1LastX128 returns the last recorded fee growth inside for token1.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| positionId | uint64 | ID of the position |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| feeGrowth | *u256.Uint | fee growth inside for token1 in X128 format |

---

<a id="getpositionfeegrowthinsidelastx128"></a>

### GetPositionFeeGrowthInsideLastX128

```go

func GetPositionFeeGrowthInsideLastX128(positionId uint64) (*u256.Uint, *u256.Uint)

```

GetPositionFeeGrowthInsideLastX128 returns the last recorded fee growth inside for both tokens.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| positionId | uint64 | ID of the position |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| feeGrowth0 | *u256.Uint | fee growth inside for token0 in X128 format |
| feeGrowth1 | *u256.Uint | fee growth inside for token1 in X128 format |

---

<a id="getpositionids"></a>

### GetPositionIDs

```go

func GetPositionIDs(offset int, count int) []uint64

```

GetPositionIDs returns a paginated list of position IDs.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| offset | int | starting index for pagination |
| count | int | number of position IDs to return |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| positionIDs | []uint64 | slice of position IDs |

---

<a id="getpositionliquidity"></a>

### GetPositionLiquidity

```go

func GetPositionLiquidity(positionId uint64) *u256.Uint

```

GetPositionLiquidity returns the liquidity amount of a position.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| positionId | uint64 | ID of the position |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| liquidity | *u256.Uint | liquidity amount of the position |

---

<a id="getpositionoperator"></a>

### GetPositionOperator

```go

func GetPositionOperator(positionId uint64) address

```

GetPositionOperator returns the operator address of a position.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| positionId | uint64 | ID of the position |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| operator | address | address approved for spending this position |

---

<a id="getpositionowner"></a>

### GetPositionOwner

```go

func GetPositionOwner(positionId uint64) address

```

GetPositionOwner returns the owner address of a position NFT.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| positionId | uint64 | ID of the position |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| owner | address | address that owns the position NFT |

---

<a id="getpositionpoolkey"></a>

### GetPositionPoolKey

```go

func GetPositionPoolKey(positionId uint64) string

```

GetPositionPoolKey returns the pool key of a position.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| positionId | uint64 | ID of the position |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| poolKey | string | pool path identifier |

---

<a id="getpositionticklower"></a>

### GetPositionTickLower

```go

func GetPositionTickLower(positionId uint64) int32

```

GetPositionTickLower returns the lower tick of a position.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| positionId | uint64 | ID of the position |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| tickLower | int32 | lower tick boundary |

---

<a id="getpositiontickupper"></a>

### GetPositionTickUpper

```go

func GetPositionTickUpper(positionId uint64) int32

```

GetPositionTickUpper returns the upper tick of a position.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| positionId | uint64 | ID of the position |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| tickUpper | int32 | upper tick boundary |

---

<a id="getpositionticks"></a>

### GetPositionTicks

```go

func GetPositionTicks(positionId uint64) (int32, int32)

```

GetPositionTicks returns the lower and upper ticks of a position.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| positionId | uint64 | ID of the position |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| tickLower | int32 | lower tick boundary |
| tickUpper | int32 | upper tick boundary |

---

<a id="getpositiontoken0balance"></a>

### GetPositionToken0Balance

```go

func GetPositionToken0Balance(positionId uint64) *u256.Uint

```

GetPositionToken0Balance returns the token0 balance of a position.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| positionId | uint64 | ID of the position |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| balance | *u256.Uint | token0 balance |

---

<a id="getpositiontoken1balance"></a>

### GetPositionToken1Balance

```go

func GetPositionToken1Balance(positionId uint64) *u256.Uint

```

GetPositionToken1Balance returns the token1 balance of a position.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| positionId | uint64 | ID of the position |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| balance | *u256.Uint | token1 balance |

---

<a id="getpositiontokenbalances"></a>

### GetPositionTokenBalances

```go

func GetPositionTokenBalances(positionId uint64) (string, string)

```

GetPositionTokenBalances returns the token balances of a position.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| positionId | uint64 | ID of the position |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| token0Balance | string | balance of token0 |
| token1Balance | string | balance of token1 |

---

<a id="getpositiontokensowed"></a>

### GetPositionTokensOwed

```go

func GetPositionTokensOwed(positionId uint64) (*u256.Uint, *u256.Uint)

```

GetPositionTokensOwed returns the amount of tokens owed to a position.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| positionId | uint64 | ID of the position |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| tokensOwed0 | *u256.Uint | amount of token0 owed |
| tokensOwed1 | *u256.Uint | amount of token1 owed |

---

<a id="getpositiontokensowed0"></a>

### GetPositionTokensOwed0

```go

func GetPositionTokensOwed0(positionId uint64) *u256.Uint

```

GetPositionTokensOwed0 returns the amount of token0 owed to a position.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| positionId | uint64 | ID of the position |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| tokensOwed | *u256.Uint | amount of token0 owed |

---

<a id="getpositiontokensowed1"></a>

### GetPositionTokensOwed1

```go

func GetPositionTokensOwed1(positionId uint64) *u256.Uint

```

GetPositionTokensOwed1 returns the amount of token1 owed to a position.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| positionId | uint64 | ID of the position |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| tokensOwed | *u256.Uint | amount of token1 owed |

---

<a id="getunclaimedfee"></a>

### GetUnclaimedFee

```go

func GetUnclaimedFee(positionId uint64) (*u256.Uint, *u256.Uint)

```

GetUnclaimedFee returns the unclaimed fees for both tokens of a position.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| positionId | uint64 | ID of the position |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| unclaimedFee0 | *u256.Uint | unclaimed fee amount for token0 |
| unclaimedFee1 | *u256.Uint | unclaimed fee amount for token1 |

---

<a id="increaseliquidity"></a>

### IncreaseLiquidity

```go

func IncreaseLiquidity(cur realm, positionId uint64, amount0DesiredStr string, amount1DesiredStr string, amount0MinStr string, amount1MinStr string, deadline int64) (uint64, string, string, string, string)

```

IncreaseLiquidity adds liquidity to an existing position.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| cur | realm |  |
| positionId | uint64 | ID of the position |
| amount0DesiredStr | string | desired amount of token0 |
| amount1DesiredStr | string | desired amount of token1 |
| amount0MinStr | string | minimum amount of token0 |
| amount1MinStr | string | minimum amount of token1 |
| deadline | int64 | transaction deadline |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| positionId | uint64 | position ID |
| liquidity | string | new liquidity amount |
| amount0 | string | amount of token0 added |
| amount1 | string | amount of token1 added |
| poolPath | string | pool path |

---

<a id="isburned"></a>

### IsBurned

```go

func IsBurned(positionId uint64) bool

```

IsBurned returns whether a position has been burned.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| positionId | uint64 | ID of the position |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| burned | bool | true if position has been burned |

---

<a id="isinrange"></a>

### IsInRange

```go

func IsInRange(positionId uint64) bool

```

IsInRange returns whether a position's ticks are within the current price range.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| positionId | uint64 | ID of the position |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| inRange | bool | true if position is within current price range |

---

<a id="mint"></a>

### Mint

```go

func Mint(cur realm, token0 string, token1 string, fee uint32, tickLower int32, tickUpper int32, amount0Desired string, amount1Desired string, amount0Min string, amount1Min string, deadline int64, mintTo address, caller address, referrer string) (uint64, string, string, string)

```

Mint creates a new liquidity position NFT.

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
| mintTo | address | recipient address for the position NFT |
| caller | address | caller address |
| referrer | string | referrer address for reward tracking |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| positionId | uint64 | position ID |
| liquidity | string | liquidity amount |
| amount0 | string | amount of token0 added |
| amount1 | string | amount of token1 added |

---

<a id="registerinitializer"></a>

### RegisterInitializer

```go

func RegisterInitializer(cur realm, initializer func(...))

```

RegisterInitializer registers a new position implementation version.
This function is called by each version (v1, v2, etc.) during initialization
to register their implementation with the proxy system.

The initializer function creates a new instance of the implementation
using the provided positionStore interface.

The stateInitializer function creates the initial state for this version.

Security: Only contracts within the domain path can register initializers.
Each package path can only register once to prevent duplicate registrations.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| cur | realm |  |
| initializer | func(...) |  |

---

<a id="reposition"></a>

### Reposition

```go

func Reposition(cur realm, positionId uint64, tickLower int32, tickUpper int32, amount0DesiredStr string, amount1DesiredStr string, amount0MinStr string, amount1MinStr string, deadline int64) (uint64, string, int32, int32, string, string)

```

Reposition changes the tick range of a position.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| cur | realm |  |
| positionId | uint64 | ID of the position |
| tickLower | int32 | new lower tick boundary |
| tickUpper | int32 | new upper tick boundary |
| amount0DesiredStr | string | desired amount of token0 |
| amount1DesiredStr | string | desired amount of token1 |
| amount0MinStr | string | minimum amount of token0 |
| amount1MinStr | string | minimum amount of token1 |
| deadline | int64 | transaction deadline |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| positionId | uint64 | position ID |
| liquidity | string | new liquidity amount |
| tickLower | int32 | new lower tick |
| tickUpper | int32 | new upper tick |
| amount0 | string | amount of token0 used |
| amount1 | string | amount of token1 used |

---

<a id="setpositionoperator"></a>

### SetPositionOperator

```go

func SetPositionOperator(cur realm, positionId uint64, operator address)

```

SetPositionOperator sets an operator for a position.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| cur | realm |  |
| positionId | uint64 | ID of the position |
| operator | address | address of the operator |

---

<a id="upgradeimpl"></a>

### UpgradeImpl

```go

func UpgradeImpl(cur realm, packagePath string)

```

UpgradeImpl switches the active position implementation to a different version.
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

<a id="iposition"></a>

### IPosition

```go

type IPosition interface

```

---

<a id="ipositiongetter"></a>

### IPositionGetter

```go

type IPositionGetter interface

```

---

<a id="ipositionmanager"></a>

### IPositionManager

```go

type IPositionManager interface

```

---

<a id="ipositionstore"></a>

### IPositionStore

```go

type IPositionStore interface

```

#### Constructors

- `func NewPositionStore(kvStore store.KVStore) IPositionStore`

---

<a id="position"></a>

### Position

```go

type Position struct

```

Position represents a liquidity position in a pool.
Each position tracks the amount of liquidity, fee growth, and tokens owed to the position owner.

#### Methods

<a id="position.burned"></a>
##### Burned

```go
func (p *Position) Burned() bool
```

Burned returns whether the position has been burned.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| burned | bool | true if position is burned |

<a id="position.feegrowthinside0lastx128"></a>
##### FeeGrowthInside0LastX128

```go
func (p *Position) FeeGrowthInside0LastX128() *u256.Uint
```

FeeGrowthInside0LastX128 returns the last recorded fee growth inside for token0.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| feeGrowth | *u256.Uint | fee growth in X128 format |

<a id="position.feegrowthinside1lastx128"></a>
##### FeeGrowthInside1LastX128

```go
func (p *Position) FeeGrowthInside1LastX128() *u256.Uint
```

FeeGrowthInside1LastX128 returns the last recorded fee growth inside for token1.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| feeGrowth | *u256.Uint | fee growth in X128 format |

<a id="position.isclear"></a>
##### IsClear

```go
func (p *Position) IsClear() bool
```

IsClear reports whether the position is empty.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| clear | bool | true if liquidity and tokens owed are zero |

<a id="position.liquidity"></a>
##### Liquidity

```go
func (p *Position) Liquidity() *u256.Uint
```

Liquidity returns the liquidity amount of the position.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| liquidity | *u256.Uint | liquidity amount |

<a id="position.operator"></a>
##### Operator

```go
func (p *Position) Operator() address
```

Operator returns the operator address approved for this position.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| operator | address | approved operator address |

<a id="position.poolkey"></a>
##### PoolKey

```go
func (p *Position) PoolKey() string
```

PoolKey returns the pool path of the position.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| poolKey | string | pool path identifier |

<a id="position.setburned"></a>
##### SetBurned

```go
func (p *Position) SetBurned(burned bool)
```

SetBurned sets the burned status of the position.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| burned | bool | true to mark as burned |

<a id="position.setfeegrowthinside0lastx128"></a>
##### SetFeeGrowthInside0LastX128

```go
func (p *Position) SetFeeGrowthInside0LastX128(feeGrowthInside0LastX128 *u256.Uint)
```

SetFeeGrowthInside0LastX128 sets the last recorded fee growth inside for token0.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| feeGrowthInside0LastX128 | *u256.Uint | fee growth in X128 format |

<a id="position.setfeegrowthinside1lastx128"></a>
##### SetFeeGrowthInside1LastX128

```go
func (p *Position) SetFeeGrowthInside1LastX128(feeGrowthInside1LastX128 *u256.Uint)
```

SetFeeGrowthInside1LastX128 sets the last recorded fee growth inside for token1.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| feeGrowthInside1LastX128 | *u256.Uint | fee growth in X128 format |

<a id="position.setliquidity"></a>
##### SetLiquidity

```go
func (p *Position) SetLiquidity(liquidity *u256.Uint)
```

SetLiquidity sets the liquidity amount of the position.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| liquidity | *u256.Uint | liquidity amount |

<a id="position.setoperator"></a>
##### SetOperator

```go
func (p *Position) SetOperator(operator address)
```

SetOperator sets the operator address for this position.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| operator | address | address to approve as operator |

<a id="position.setpoolkey"></a>
##### SetPoolKey

```go
func (p *Position) SetPoolKey(poolKey string)
```

SetPoolKey sets the pool path of the position.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| poolKey | string | pool path identifier |

<a id="position.setticklower"></a>
##### SetTickLower

```go
func (p *Position) SetTickLower(tickLower int32)
```

SetTickLower sets the lower tick boundary of the position.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| tickLower | int32 | lower tick boundary |

<a id="position.settickupper"></a>
##### SetTickUpper

```go
func (p *Position) SetTickUpper(tickUpper int32)
```

SetTickUpper sets the upper tick boundary of the position.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| tickUpper | int32 | upper tick boundary |

<a id="position.settoken0balance"></a>
##### SetToken0Balance

```go
func (p *Position) SetToken0Balance(token0Balance *u256.Uint)
```

SetToken0Balance sets the token0 balance of the position.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| token0Balance | *u256.Uint | token0 balance |

<a id="position.settoken1balance"></a>
##### SetToken1Balance

```go
func (p *Position) SetToken1Balance(token1Balance *u256.Uint)
```

SetToken1Balance sets the token1 balance of the position.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| token1Balance | *u256.Uint | token1 balance |

<a id="position.settokensowed0"></a>
##### SetTokensOwed0

```go
func (p *Position) SetTokensOwed0(tokensOwed0 *u256.Uint)
```

SetTokensOwed0 sets the amount of token0 owed to the position.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| tokensOwed0 | *u256.Uint | uncollected token0 amount |

<a id="position.settokensowed1"></a>
##### SetTokensOwed1

```go
func (p *Position) SetTokensOwed1(tokensOwed1 *u256.Uint)
```

SetTokensOwed1 sets the amount of token1 owed to the position.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| tokensOwed1 | *u256.Uint | uncollected token1 amount |

<a id="position.ticklower"></a>
##### TickLower

```go
func (p *Position) TickLower() int32
```

TickLower returns the lower tick boundary of the position.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| tickLower | int32 | lower tick boundary |

<a id="position.tickupper"></a>
##### TickUpper

```go
func (p *Position) TickUpper() int32
```

TickUpper returns the upper tick boundary of the position.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| tickUpper | int32 | upper tick boundary |

<a id="position.token0balance"></a>
##### Token0Balance

```go
func (p *Position) Token0Balance() *u256.Uint
```

Token0Balance returns the token0 balance of the position.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| token0Balance | *u256.Uint | token0 balance |

<a id="position.token1balance"></a>
##### Token1Balance

```go
func (p *Position) Token1Balance() *u256.Uint
```

Token1Balance returns the token1 balance of the position.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| token1Balance | *u256.Uint | token1 balance |

<a id="position.tokensowed0"></a>
##### TokensOwed0

```go
func (p *Position) TokensOwed0() *u256.Uint
```

TokensOwed0 returns the amount of token0 owed to the position.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| tokensOwed0 | *u256.Uint | uncollected token0 amount |

<a id="position.tokensowed1"></a>
##### TokensOwed1

```go
func (p *Position) TokensOwed1() *u256.Uint
```

TokensOwed1 returns the amount of token1 owed to the position.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| tokensOwed1 | *u256.Uint | uncollected token1 amount |


#### Constructors

- `func GetPosition(positionId uint64) (Position, error)`
- `func NewPosition(poolKey string, tickLower int32, tickUpper int32, liquidity *u256.Uint, feeGrowthInside0LastX128 *u256.Uint, feeGrowthInside1LastX128 *u256.Uint, tokensOwed0 *u256.Uint, tokensOwed1 *u256.Uint, token0Balance *u256.Uint, token1Balance *u256.Uint, burned bool, operator address) *Position`

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
