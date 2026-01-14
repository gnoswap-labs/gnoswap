# router

`import "gno.land/r/gnoswap/router"`

Package router provides swap routing and execution across GnoSwap liquidity pools.

The router handles token swaps with multi-hop routing, slippage protection,
and automatic GNOT wrapping/unwrapping. It supports both exact input and
exact output swap modes with deadline validation.

Key features:
- Multi-hop routing across up to 3 pools
- Quote distribution for optimal execution
- Native GNOT handling with automatic wrap/unwrap
- Slippage protection via min/max amounts
- Router fee (0.15%) on all swaps
- Deadline enforcement to prevent stale transactions

The router acts as a proxy to version-specific implementations,
currently routing to v1 for all swap operations.


## Index

- [DrySwapRoute](#dryswaproute)
- [ExactInSingleSwapRoute](#exactinsingleswaproute)
- [ExactInSwapRoute](#exactinswaproute)
- [ExactOutSingleSwapRoute](#exactoutsingleswaproute)
- [ExactOutSwapRoute](#exactoutswaproute)
- [GetImplementationPackagePath](#getimplementationpackagepath)
- [GetSwapFee](#getswapfee)
- [RegisterInitializer](#registerinitializer)
- [SetSwapFee](#setswapfee)
- [SwapCallback](#swapcallback)
- [UpgradeImpl](#upgradeimpl)
- [IRouter](#irouter)
- [IRouterStore](#irouterstore)
- [StoreKey](#storekey)


## Functions

<a id="dryswaproute"></a>

### DrySwapRoute

```go

func DrySwapRoute(inputToken string, outputToken string, specifiedAmount string, swapTypeStr string, strRouteArr string, quoteArr string, tokenAmountLimit string) (string, string, bool)

```

DrySwapRoute simulates a swap route without executing it.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| inputToken | string | path of input token |
| outputToken | string | path of output token |
| specifiedAmount | string | specified amount for the swap |
| swapTypeStr | string | swap type string ("ExactIn" or "ExactOut") |
| strRouteArr | string | encoded route array |
| quoteArr | string | encoded quote array |
| tokenAmountLimit | string | token amount limit |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| amountIn | string | estimated input amount |
| amountOut | string | estimated output amount |
| ok | bool | success status |

---

<a id="exactinsingleswaproute"></a>

### ExactInSingleSwapRoute

```go

func ExactInSingleSwapRoute(cur realm, inputToken string, outputToken string, amountIn string, routeArr string, amountOutMin string, sqrtPriceLimitX96 string, deadline int64, referrer string) (string, string)

```

ExactInSingleSwapRoute executes a single-hop swap with exact input amount.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| cur | realm |  |
| inputToken | string | path of input token |
| outputToken | string | path of output token |
| amountIn | string | exact input amount |
| routeArr | string | encoded route |
| amountOutMin | string | minimum output amount |
| sqrtPriceLimitX96 | string | price limit for the swap |
| deadline | int64 | transaction deadline |
| referrer | string | referrer address for reward tracking |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| amountIn | string | actual input amount |
| amountOut | string | actual output amount |

---

<a id="exactinswaproute"></a>

### ExactInSwapRoute

```go

func ExactInSwapRoute(cur realm, inputToken string, outputToken string, amountIn string, routeArr string, quoteArr string, amountOutMin string, deadline int64, referrer string) (string, string)

```

ExactInSwapRoute executes a multi-hop swap with exact input amount.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| cur | realm |  |
| inputToken | string | path of input token |
| outputToken | string | path of output token |
| amountIn | string | exact input amount |
| routeArr | string | encoded route array |
| quoteArr | string | encoded quote array |
| amountOutMin | string | minimum output amount |
| deadline | int64 | transaction deadline |
| referrer | string | referrer address for reward tracking |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| amountIn | string | actual input amount |
| amountOut | string | actual output amount |

---

<a id="exactoutsingleswaproute"></a>

### ExactOutSingleSwapRoute

```go

func ExactOutSingleSwapRoute(cur realm, inputToken string, outputToken string, amountOut string, routeArr string, amountInMax string, sqrtPriceLimitX96 string, deadline int64, referrer string) (string, string)

```

ExactOutSingleSwapRoute executes a single-hop swap with exact output amount.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| cur | realm |  |
| inputToken | string | path of input token |
| outputToken | string | path of output token |
| amountOut | string | exact output amount |
| routeArr | string | encoded route |
| amountInMax | string | maximum input amount |
| sqrtPriceLimitX96 | string | price limit for the swap |
| deadline | int64 | transaction deadline |
| referrer | string | referrer address for reward tracking |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| amountIn | string | actual input amount |
| amountOut | string | actual output amount |

---

<a id="exactoutswaproute"></a>

### ExactOutSwapRoute

```go

func ExactOutSwapRoute(cur realm, inputToken string, outputToken string, amountOut string, routeArr string, quoteArr string, amountInMax string, deadline int64, referrer string) (string, string)

```

ExactOutSwapRoute executes a multi-hop swap with exact output amount.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| cur | realm |  |
| inputToken | string | path of input token |
| outputToken | string | path of output token |
| amountOut | string | exact output amount |
| routeArr | string | encoded route array |
| quoteArr | string | encoded quote array |
| amountInMax | string | maximum input amount |
| deadline | int64 | transaction deadline |
| referrer | string | referrer address for reward tracking |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| amountIn | string | actual input amount |
| amountOut | string | actual output amount |

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

<a id="getswapfee"></a>

### GetSwapFee

```go

func GetSwapFee() uint64

```

GetSwapFee returns the current swap fee rate.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| fee | uint64 | swap fee in basis points |

---

<a id="registerinitializer"></a>

### RegisterInitializer

```go

func RegisterInitializer(cur realm, initializer func(...))

```

RegisterInitializer registers a new router implementation version.
This function is called by each version (v1, v2, etc.) during initialization
to register their implementation with the proxy system.

The initializer function creates a new instance of the implementation
using the provided routerStore interface.

Security: Only contracts within the domain path can register initializers.
Each package path can only register once to prevent duplicate registrations.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| cur | realm |  |
| initializer | func(...) |  |

---

<a id="setswapfee"></a>

### SetSwapFee

```go

func SetSwapFee(cur realm, fee uint64)

```

SetSwapFee sets the swap fee rate.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| cur | realm |  |
| fee | uint64 | new swap fee in basis points |

---

<a id="swapcallback"></a>

### SwapCallback

```go

func SwapCallback(token0Path string, token1Path string, amount0Delta int64, amount1Delta int64, payer address) error

```

SwapCallback is called by pools to transfer tokens during a swap.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| token0Path | string | path of token0 |
| token1Path | string | path of token1 |
| amount0Delta | int64 | amount change for token0 |
| amount1Delta | int64 | amount change for token1 |
| payer | address | address that will pay for the swap |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| err | error | error if callback fails |

---

<a id="upgradeimpl"></a>

### UpgradeImpl

```go

func UpgradeImpl(cur realm, packagePath string)

```

UpgradeImpl switches the active router implementation to a different version.
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

<a id="irouter"></a>

### IRouter

```go

type IRouter interface

```

---

<a id="irouterstore"></a>

### IRouterStore

```go

type IRouterStore interface

```

#### Constructors

- `func NewRouterStore(kvStore store.KVStore) IRouterStore`

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
