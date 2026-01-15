# gns

`import "gno.land/r/gnoswap/gns"`

Package gns implements the GNS governance and utility token for GnoSwap.

GNS is a GRC20-compliant token with a deflationary emission schedule.
The emission follows a 12-year schedule with halving every 2 years:
  - Years 1-2:  225,000,000 GNS per year (100%)
  - Years 3-4:  112,500,000 GNS per year (50%)
  - Years 5-6:   56,250,000 GNS per year (25%)
  - Years 7-8:   28,125,000 GNS per year (12.5%)
  - Years 9-12:  14,062,500 GNS per year (6.25%)

Token Economics:
  - Maximum Supply: 1,000,000,000 GNS
  - Initial Mint:     100,000,000 GNS
  - Total Emission:   900,000,000 GNS

Key Functions:
  - InitEmissionState: Initializes emission schedule (emission contract only)
  - MintGns: Mints tokens per emission schedule (emission contract only)
  - Burn: Burns tokens from circulation (admin only)
  - Transfer/TransferFrom/Approve: Standard GRC20 operations

The emission state tracks accumulated and remaining amounts per halving year,
ensuring precise token distribution according to the schedule.


## Index

- [DAY_PER_YEAR](#day_per_year)
- [SECONDS_PER_DAY](#seconds_per_day)
- [SECONDS_IN_YEAR](#seconds_in_year)
- [HALVING_START_YEAR](#halving_start_year)
- [HALVING_END_YEAR](#halving_end_year)
- [MAXIMUM_SUPPLY](#maximum_supply)
- [INITIAL_MINT_AMOUNT](#initial_mint_amount)
- [MAX_EMISSION_AMOUNT](#max_emission_amount)
- [UserTeller](#userteller)
- [Allowance](#allowance)
- [Approve](#approve)
- [BalanceOf](#balanceof)
- [CalculateMintGnsAmount](#calculatemintgnsamount)
- [Decimals](#decimals)
- [GetAmountPerSecondPerHalvingYear](#getamountpersecondperhalvingyear)
- [GetCurrentYear](#getcurrentyear)
- [GetEmissionAccumulatedAmountByTimestamp](#getemissionaccumulatedamountbytimestamp)
- [GetEmissionAmountPerSecondByTimestamp](#getemissionamountpersecondbytimestamp)
- [GetEmissionAmountPerSecondInRange](#getemissionamountpersecondinrange)
- [GetEmissionEndTimestamp](#getemissionendtimestamp)
- [GetEmissionLeftAmountByTimestamp](#getemissionleftamountbytimestamp)
- [GetEmissionStartHeight](#getemissionstartheight)
- [GetEmissionStartTimestamp](#getemissionstarttimestamp)
- [GetHalvingAmountsPerYear](#gethalvingamountsperyear)
- [GetHalvingYear](#gethalvingyear)
- [GetHalvingYearAccuAmount](#gethalvingyearaccuamount)
- [GetHalvingYearEndTimestamp](#gethalvingyearendtimestamp)
- [GetHalvingYearInfo](#gethalvingyearinfo)
- [GetHalvingYearLeftAmount](#gethalvingyearleftamount)
- [GetHalvingYearMaxAmount](#gethalvingyearmaxamount)
- [GetHalvingYearMintAmount](#gethalvingyearmintamount)
- [GetHalvingYearStartTimestamp](#gethalvingyearstarttimestamp)
- [GetInitialMintAmount](#getinitialmintamount)
- [GetMaxEmissionAmount](#getmaxemissionamount)
- [GetMaximumSupply](#getmaximumsupply)
- [InitEmissionState](#initemissionstate)
- [IsEmissionActive](#isemissionactive)
- [IsEmissionEnded](#isemissionended)
- [IsEmissionInitialized](#isemissioninitialized)
- [KnownAccounts](#knownaccounts)
- [LastMintedTimestamp](#lastmintedtimestamp)
- [LeftEmissionAmount](#leftemissionamount)
- [MintGns](#mintgns)
- [MintedEmissionAmount](#mintedemissionamount)
- [Name](#name)
- [Render](#render)
- [Symbol](#symbol)
- [TotalSupply](#totalsupply)
- [Transfer](#transfer)
- [TransferFrom](#transferfrom)
- [EmissionState](#emissionstate)
- [HalvingData](#halvingdata)


## Constants

<a id="day_per_year"></a>
<a id="seconds_per_day"></a>
<a id="seconds_in_year"></a>
<a id="halving_start_year"></a>
<a id="halving_end_year"></a>
```go
const (
	DAY_PER_YEAR = 365
	SECONDS_PER_DAY = 86400
	SECONDS_IN_YEAR = 31536000
	HALVING_START_YEAR = int64(...)
	HALVING_END_YEAR = int64(...)
)
```

<a id="maximum_supply"></a>
<a id="initial_mint_amount"></a>
<a id="max_emission_amount"></a>
```go
const (
	MAXIMUM_SUPPLY = int64(...)
	INITIAL_MINT_AMOUNT = int64(...)
	MAX_EMISSION_AMOUNT = int64(...)
)
```


## Variables

<a id="userteller"></a>
```go
var (
	UserTeller
)
```


## Functions

<a id="allowance"></a>

### Allowance

```go

func Allowance(owner address, spender address) int64

```

Allowance returns the amount of GNS that a spender is allowed to transfer from an owner.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| owner | address | token owner address |
| spender | address | spender address |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| allowance | int64 | approved amount |

---

<a id="approve"></a>

### Approve

```go

func Approve(cur realm, spender address, amount int64)

```

Approve allows spender to transfer GNS tokens from caller's account.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| cur | realm |  |
| spender | address | address authorized to spend |
| amount | int64 | maximum amount spender can transfer |

---

<a id="balanceof"></a>

### BalanceOf

```go

func BalanceOf(owner address) int64

```

BalanceOf returns the GNS balance of a specific address.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| owner | address | address to check balance for |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| balance | int64 | token balance |

---

<a id="calculatemintgnsamount"></a>

### CalculateMintGnsAmount

```go

func CalculateMintGnsAmount(fromTimestamp int64, toTimestamp int64) int64

```

CalculateMintGnsAmount returns the amount of GNS that would be minted for the given timestamp range.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| fromTimestamp | int64 | start timestamp |
| toTimestamp | int64 | end timestamp |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| amount | int64 | GNS amount that would be minted |

---

<a id="decimals"></a>

### Decimals

```go

func Decimals() int

```

Decimals returns the number of decimal places for GNS token.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| decimals | int | number of decimal places |

---

<a id="getamountpersecondperhalvingyear"></a>

### GetAmountPerSecondPerHalvingYear

```go

func GetAmountPerSecondPerHalvingYear(year int64) int64

```

GetAmountPerSecondPerHalvingYear returns the emission rate per second for the specified halving year.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| year | int64 | halving year (1-12) |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| amount | int64 | emission rate per second for the year |

---

<a id="getcurrentyear"></a>

### GetCurrentYear

```go

func GetCurrentYear() int64

```

GetCurrentYear returns the current halving year (1-12) or 0 if emission is not active.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| year | int64 | current halving year |

---

<a id="getemissionaccumulatedamountbytimestamp"></a>

### GetEmissionAccumulatedAmountByTimestamp

```go

func GetEmissionAccumulatedAmountByTimestamp(timestamp int64) int64

```

GetEmissionAccumulatedAmountByTimestamp returns the accumulated emission amount for the halving year at given timestamp.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| timestamp | int64 | timestamp to check |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| amount | int64 | accumulated emission amount, or 0 if outside emission period |

---

<a id="getemissionamountpersecondbytimestamp"></a>

### GetEmissionAmountPerSecondByTimestamp

```go

func GetEmissionAmountPerSecondByTimestamp(timestamp int64) int64

```

GetEmissionAmountPerSecondByTimestamp returns the emission rate per second for a given timestamp.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| timestamp | int64 | timestamp to check |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| amount | int64 | emission rate per second, or 0 if outside emission period |

---

<a id="getemissionamountpersecondinrange"></a>

### GetEmissionAmountPerSecondInRange

```go

func GetEmissionAmountPerSecondInRange(fromTime int64, toTime int64) ([]int64, []int64)

```

GetEmissionAmountPerSecondInRange returns halving timestamps and emission rates for the given time range.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| fromTime | int64 | start timestamp |
| toTime | int64 | end timestamp |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| halvingTimes | []int64 | timestamps when halving periods start |
| halvingEmissions | []int64 | emission rates per second at each halving |

---

<a id="getemissionendtimestamp"></a>

### GetEmissionEndTimestamp

```go

func GetEmissionEndTimestamp() int64

```

GetEmissionEndTimestamp returns the timestamp when emission schedule ends.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| timestamp | int64 | emission end timestamp |

---

<a id="getemissionleftamountbytimestamp"></a>

### GetEmissionLeftAmountByTimestamp

```go

func GetEmissionLeftAmountByTimestamp(timestamp int64) int64

```

GetEmissionLeftAmountByTimestamp returns the remaining emission amount for the halving year at given timestamp.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| timestamp | int64 | timestamp to check |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| amount | int64 | remaining emission amount, or 0 if outside emission period |

---

<a id="getemissionstartheight"></a>

### GetEmissionStartHeight

```go

func GetEmissionStartHeight() int64

```

GetEmissionStartHeight returns the block height when emission schedule was initialized.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| height | int64 | emission start block height |

---

<a id="getemissionstarttimestamp"></a>

### GetEmissionStartTimestamp

```go

func GetEmissionStartTimestamp() int64

```

GetEmissionStartTimestamp returns the timestamp when emission schedule begins.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| timestamp | int64 | emission start timestamp |

---

<a id="gethalvingamountsperyear"></a>

### GetHalvingAmountsPerYear

```go

func GetHalvingAmountsPerYear(year int64) int64

```

GetHalvingAmountsPerYear returns the total emission amount allocated for the specified year.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| year | int64 | halving year (1-12) |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| amount | int64 | allocated emission amount, or 0 if year is invalid |

---

<a id="gethalvingyear"></a>

### GetHalvingYear

```go

func GetHalvingYear(timestamp int64) int64

```

GetHalvingYear returns the halving year (1-12) for a given timestamp.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| timestamp | int64 | timestamp to check |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| year | int64 | halving year (1-12) or 0 if outside emission period |

---

<a id="gethalvingyearaccuamount"></a>

### GetHalvingYearAccuAmount

```go

func GetHalvingYearAccuAmount(year int64) int64

```

GetHalvingYearAccuAmount returns the accumulated token issuance for the specified halving year.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| year | int64 | halving year (1-12) |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| amount | int64 | accumulated issuance amount for the year |

---

<a id="gethalvingyearendtimestamp"></a>

### GetHalvingYearEndTimestamp

```go

func GetHalvingYearEndTimestamp(year int64) int64

```

GetHalvingYearEndTimestamp returns the end timestamp for the specified halving year.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| year | int64 | halving year (1-12) |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| timestamp | int64 | end timestamp for the year |

---

<a id="gethalvingyearinfo"></a>

### GetHalvingYearInfo

```go

func GetHalvingYearInfo(timestamp int64) (int64, int64, int64)

```

GetHalvingYearInfo returns the halving year, start timestamp, and end timestamp for a given timestamp.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| timestamp | int64 | timestamp to check |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| year | int64 | halving year (1-12), or 0 if outside emission period |
| startTimestamp | int64 | year start timestamp |
| endTimestamp | int64 | year end timestamp |

---

<a id="gethalvingyearleftamount"></a>

### GetHalvingYearLeftAmount

```go

func GetHalvingYearLeftAmount(year int64) int64

```

GetHalvingYearLeftAmount returns the remaining token issuance for the specified halving year.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| year | int64 | halving year (1-12) |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| amount | int64 | remaining issuance amount for the year |

---

<a id="gethalvingyearmaxamount"></a>

### GetHalvingYearMaxAmount

```go

func GetHalvingYearMaxAmount(year int64) int64

```

GetHalvingYearMaxAmount returns the maximum token issuance for the specified halving year.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| year | int64 | halving year (1-12) |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| amount | int64 | maximum issuance amount for the year |

---

<a id="gethalvingyearmintamount"></a>

### GetHalvingYearMintAmount

```go

func GetHalvingYearMintAmount(year int64) int64

```

GetHalvingYearMintAmount returns the amount of tokens minted for the specified halving year.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| year | int64 | halving year (1-12) |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| amount | int64 | minted amount for the year |

---

<a id="gethalvingyearstarttimestamp"></a>

### GetHalvingYearStartTimestamp

```go

func GetHalvingYearStartTimestamp(year int64) int64

```

GetHalvingYearStartTimestamp returns the start timestamp for the specified halving year.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| year | int64 | halving year (1-12) |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| timestamp | int64 | start timestamp for the year |

---

<a id="getinitialmintamount"></a>

### GetInitialMintAmount

```go

func GetInitialMintAmount() int64

```

GetInitialMintAmount returns the initial amount of gns tokens to be minted.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| amount | int64 | initial mint amount |

---

<a id="getmaxemissionamount"></a>

### GetMaxEmissionAmount

```go

func GetMaxEmissionAmount() int64

```

GetMaxEmissionAmount returns the maximum amount of emission allowed.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| amount | int64 | maximum emission amount |

---

<a id="getmaximumsupply"></a>

### GetMaximumSupply

```go

func GetMaximumSupply() int64

```

GetMaximumSupply returns the maximum supply of gns tokens.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| supply | int64 | maximum token supply |

---

<a id="initemissionstate"></a>

### InitEmissionState

```go

func InitEmissionState(cur realm, height int64, timestamp int64)

```

InitEmissionState initializes emission schedule with start timestamp.
Sets up 12-year emission schedule with halving every 2 years.


Only callable by emission contract. Panics if caller is not emission contract.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| cur | realm |  |
| height | int64 | block height when emission starts |
| timestamp | int64 | timestamp when emission starts |

---

<a id="isemissionactive"></a>

### IsEmissionActive

```go

func IsEmissionActive() bool

```

IsEmissionActive returns true if emission is currently active based on current time.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| active | bool | true if emission is active |

---

<a id="isemissionended"></a>

### IsEmissionEnded

```go

func IsEmissionEnded() bool

```

IsEmissionEnded returns true if emission schedule has completed.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| ended | bool | true if emission has ended |

---

<a id="isemissioninitialized"></a>

### IsEmissionInitialized

```go

func IsEmissionInitialized() bool

```

IsEmissionInitialized returns true if emission schedule has been initialized.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| initialized | bool | true if emission is initialized |

---

<a id="knownaccounts"></a>

### KnownAccounts

```go

func KnownAccounts() int

```

KnownAccounts returns the number of addresses that have held GNS.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| count | int | number of known accounts |

---

<a id="lastmintedtimestamp"></a>

### LastMintedTimestamp

```go

func LastMintedTimestamp() int64

```

LastMintedTimestamp returns the timestamp of the last GNS emission mint.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| timestamp | int64 | last minted timestamp |

---

<a id="leftemissionamount"></a>

### LeftEmissionAmount

```go

func LeftEmissionAmount() int64

```

LeftEmissionAmount returns the remaining GNS tokens available for emission.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| amount | int64 | remaining emission amount |

---

<a id="mintgns"></a>

### MintGns

```go

func MintGns(cur realm, address address) int64

```

MintGns mints new GNS tokens according to the emission schedule.



Only callable by emission contract.

Note: Halt check is performed by the caller (emission.MintAndDistributeGns)
to allow graceful handling. This function assumes caller has already verified
halt status before invoking.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| cur | realm |  |
| address | address | recipient address for minted tokens |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| amount | int64 | amount of GNS minted |

---

<a id="mintedemissionamount"></a>

### MintedEmissionAmount

```go

func MintedEmissionAmount() int64

```

MintedEmissionAmount returns the total GNS tokens minted through emission,
excluding the initial mint amount.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| amount | int64 | total minted emission amount |

---

<a id="name"></a>

### Name

```go

func Name() string

```

Name returns the name of the GNS token.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| name | string | token name |

---

<a id="render"></a>

### Render

```go

func Render(path string) string

```

Render returns token information for web interface.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| path | string | render path for specific views |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| output | string | formatted token information |

---

<a id="symbol"></a>

### Symbol

```go

func Symbol() string

```

Symbol returns the symbol of the GNS token.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| symbol | string | token symbol |

---

<a id="totalsupply"></a>

### TotalSupply

```go

func TotalSupply() int64

```

TotalSupply returns the total supply of GNS tokens in circulation.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| supply | int64 | total token supply |

---

<a id="transfer"></a>

### Transfer

```go

func Transfer(cur realm, to address, amount int64)

```

Transfer transfers GNS tokens from caller to recipient.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| cur | realm |  |
| to | address | recipient address |
| amount | int64 | amount to transfer |

---

<a id="transferfrom"></a>

### TransferFrom

```go

func TransferFrom(cur realm, from address, to address, amount int64)

```

TransferFrom transfers GNS tokens on behalf of owner.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| cur | realm |  |
| from | address | token owner address |
| to | address | recipient address |
| amount | int64 | amount to transfer |


## Types

<a id="emissionstate"></a>

### EmissionState

```go

type EmissionState struct

```

EmissionState manages emission state and halving data.
Tracks emission timing, status, and halving year information for 12-year schedule.

#### Methods

<a id="emissionstate.clone"></a>
##### Clone

```go
func (e *EmissionState) Clone() *EmissionState
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | *EmissionState |  |


#### Constructors

- `func NewEmissionState(startHeight int64, startTimestamp int64) *EmissionState`

---

<a id="halvingdata"></a>

### HalvingData

```go

type HalvingData struct

```

HalvingData stores emission data for each halving period.
Contains timestamps, amounts, and rates for the 12-year emission schedule.

#### Methods

<a id="halvingdata.clone"></a>
##### Clone

```go
func (h *HalvingData) Clone() *HalvingData
```

Clone creates a deep copy of the halving data.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| halvingData | *HalvingData | cloned halving data |


#### Constructors

- `func GetHalvingInfo() *HalvingData`
- `func NewHalvingData(startTimestamp int64) *HalvingData`
