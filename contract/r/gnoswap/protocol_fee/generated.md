# protocol_fee

`import "gno.land/r/gnoswap/protocol_fee"`

Package protocol_fee manages fee collection and distribution for GnoSwap protocol operations.

This contract collects fees from various protocol operations (swaps, pool creation,
withdrawals, staking claims) and distributes them to DevOps and Governance Stakers
according to configurable percentages.

Distribution Targets:
  - DevOps: Development and operations fund (default 0%)
  - GovStaker: Governance stakers / xGNS holders (default 100%)

Key Functions:
  - DistributeProtocolFee: Distributes accumulated fees to recipients
  - SetDevOpsPct/SetGovStakerPct: Configure distribution percentages
  - AddToProtocolFee: Adds fees to the distribution queue

The contract uses a version manager pattern for upgradeable implementations.


## Index

- [AddToProtocolFee](#addtoprotocolfee)
- [ClearAccuTransferToGovStaker](#clearaccutransfertogovstaker)
- [ClearTokenListWithAmount](#cleartokenlistwithamount)
- [DistributeProtocolFee](#distributeprotocolfee)
- [GetAccuTransferToDevOpsByTokenPath](#getaccutransfertodevopsbytokenpath)
- [GetAccuTransferToGovStakerByTokenPath](#getaccutransfertogovstakerbytokenpath)
- [GetAccuTransfersToDevOps](#getaccutransferstodevops)
- [GetAccuTransfersToGovStaker](#getaccutransferstogovstaker)
- [GetAmountOfToken](#getamountoftoken)
- [GetDevOpsPct](#getdevopspct)
- [GetDomainPath](#getdomainpath)
- [GetGovStakerPct](#getgovstakerpct)
- [GetHistoryOfDistributedToDevOpsByTokenPath](#gethistoryofdistributedtodevopsbytokenpath)
- [GetHistoryOfDistributedToGovStakerByTokenPath](#gethistoryofdistributedtogovstakerbytokenpath)
- [GetImplementationPackagePath](#getimplementationpackagepath)
- [GetTokenList](#gettokenlist)
- [GetTokenListWithAmount](#gettokenlistwithamount)
- [GetVersionPackagePath](#getversionpackagepath)
- [RegisterInitializer](#registerinitializer)
- [SetDevOpsPct](#setdevopspct)
- [SetGovStakerPct](#setgovstakerpct)
- [UpgradeImpl](#upgradeimpl)
- [IProtocolFee](#iprotocolfee)
- [IProtocolFeeGetter](#iprotocolfeegetter)
- [IProtocolFeeManager](#iprotocolfeemanager)
- [IProtocolFeeStore](#iprotocolfeestore)
- [StoreKey](#storekey)


## Functions

<a id="addtoprotocolfee"></a>

### AddToProtocolFee

```go

func AddToProtocolFee(cur realm, tokenPath string, amount int64)

```

AddToProtocolFee adds tokens to the protocol fee pool.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| cur | realm |  |
| tokenPath | string | path of the token |
| amount | int64 | amount to add |

---

<a id="clearaccutransfertogovstaker"></a>

### ClearAccuTransferToGovStaker

```go

func ClearAccuTransferToGovStaker(cur realm)

```

ClearAccuTransferToGovStaker clears accumulated transfers to GovStaker.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| cur | realm |  |

---

<a id="cleartokenlistwithamount"></a>

### ClearTokenListWithAmount

```go

func ClearTokenListWithAmount(cur realm)

```

ClearTokenListWithAmount clears the token list with amounts.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| cur | realm |  |

---

<a id="distributeprotocolfee"></a>

### DistributeProtocolFee

```go

func DistributeProtocolFee(cur realm) map[string]int64

```

DistributeProtocolFee distributes accumulated protocol fees to DevOps and GovStaker.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| cur | realm |  |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| amountsByToken | map[string]int64 | amounts distributed per token |

---

<a id="getaccutransfertodevopsbytokenpath"></a>

### GetAccuTransferToDevOpsByTokenPath

```go

func GetAccuTransferToDevOpsByTokenPath(tokenPath string) int64

```

GetAccuTransferToDevOpsByTokenPath returns accumulated DevOps transfer for a token.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| tokenPath | string | path of the token |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| amount | int64 | accumulated transfer amount |

---

<a id="getaccutransfertogovstakerbytokenpath"></a>

### GetAccuTransferToGovStakerByTokenPath

```go

func GetAccuTransferToGovStakerByTokenPath(tokenPath string) int64

```

GetAccuTransferToGovStakerByTokenPath returns accumulated GovStaker transfer for a token.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| tokenPath | string | path of the token |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| amount | int64 | accumulated transfer amount |

---

<a id="getaccutransferstodevops"></a>

### GetAccuTransfersToDevOps

```go

func GetAccuTransfersToDevOps() map[string]int64

```

GetAccuTransfersToDevOps returns accumulated transfers to DevOps.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| transfers | map[string]int64 | map of token paths to accumulated amounts |

---

<a id="getaccutransferstogovstaker"></a>

### GetAccuTransfersToGovStaker

```go

func GetAccuTransfersToGovStaker() map[string]int64

```

GetAccuTransfersToGovStaker returns accumulated transfers to GovStaker.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| transfers | map[string]int64 | map of token paths to accumulated amounts |

---

<a id="getamountoftoken"></a>

### GetAmountOfToken

```go

func GetAmountOfToken(tokenPath string) int64

```

GetAmountOfToken returns the amount of a specific token.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| tokenPath | string | path of the token |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| amount | int64 | token amount in the protocol fee pool |

---

<a id="getdevopspct"></a>

### GetDevOpsPct

```go

func GetDevOpsPct() int64

```

GetDevOpsPct returns the DevOps fee percentage.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| pct | int64 | DevOps fee percentage (0-100) |

---

<a id="getdomainpath"></a>

### GetDomainPath

```go

func GetDomainPath() string

```

GetDomainPath returns the domain path of the protocol fee contract.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| domainPath | string | protocol fee contract domain path |

---

<a id="getgovstakerpct"></a>

### GetGovStakerPct

```go

func GetGovStakerPct() int64

```

GetGovStakerPct returns the GovStaker fee percentage.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| pct | int64 | GovStaker fee percentage (0-100) |

---

<a id="gethistoryofdistributedtodevopsbytokenpath"></a>

### GetHistoryOfDistributedToDevOpsByTokenPath

```go

func GetHistoryOfDistributedToDevOpsByTokenPath(tokenPath string) int64

```

GetHistoryOfDistributedToDevOpsByTokenPath returns historical DevOps distributions for a token.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| tokenPath | string | path of the token |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| amount | int64 | total distributed amount |

---

<a id="gethistoryofdistributedtogovstakerbytokenpath"></a>

### GetHistoryOfDistributedToGovStakerByTokenPath

```go

func GetHistoryOfDistributedToGovStakerByTokenPath(tokenPath string) int64

```

GetHistoryOfDistributedToGovStakerByTokenPath returns historical GovStaker distributions for a token.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| tokenPath | string | path of the token |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| amount | int64 | total distributed amount |

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

<a id="gettokenlist"></a>

### GetTokenList

```go

func GetTokenList() []string

```

GetTokenList returns the list of token paths without amounts.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| tokenPaths | []string | slice of token paths |

---

<a id="gettokenlistwithamount"></a>

### GetTokenListWithAmount

```go

func GetTokenListWithAmount() map[string]int64

```

GetTokenListWithAmount returns the list of tokens with their amounts.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| tokenAmounts | map[string]int64 | map of token paths to their amounts |

---

<a id="getversionpackagepath"></a>

### GetVersionPackagePath

```go

func GetVersionPackagePath() string

```

GetVersionPackagePath returns the current implementation package path.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| packagePath | string | current implementation package path |

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
using the provided protocolFeeStore interface.

The stateInitializer function creates the initial state for this version.

Security: Only contracts within the domain path can register initializers.
Each package path can only register once to prevent duplicate registrations.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| cur | realm |  |
| initializer | func(...) |  |

---

<a id="setdevopspct"></a>

### SetDevOpsPct

```go

func SetDevOpsPct(cur realm, pct int64)

```

SetDevOpsPct sets the percentage of protocol fees allocated to DevOps.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| cur | realm |  |
| pct | int64 | percentage (0-100) |

---

<a id="setgovstakerpct"></a>

### SetGovStakerPct

```go

func SetGovStakerPct(cur realm, pct int64)

```

SetGovStakerPct sets the percentage of protocol fees allocated to GovStaker.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| cur | realm |  |
| pct | int64 | percentage (0-100) |

---

<a id="upgradeimpl"></a>

### UpgradeImpl

```go

func UpgradeImpl(cur realm, packagePath string)

```

UpgradeImpl switches the active protocol fee implementation to a different version.
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

<a id="iprotocolfee"></a>

### IProtocolFee

```go

type IProtocolFee interface

```

---

<a id="iprotocolfeegetter"></a>

### IProtocolFeeGetter

```go

type IProtocolFeeGetter interface

```

---

<a id="iprotocolfeemanager"></a>

### IProtocolFeeManager

```go

type IProtocolFeeManager interface

```

---

<a id="iprotocolfeestore"></a>

### IProtocolFeeStore

```go

type IProtocolFeeStore interface

```

#### Constructors

- `func NewProtocolFeeStore(kvStore store.KVStore) IProtocolFeeStore`

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
