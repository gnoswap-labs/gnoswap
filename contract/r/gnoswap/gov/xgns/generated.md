# xgns

`import "gno.land/r/gnoswap/gov/xgns"`

Package xgns implements the GRC20-compliant xGNS token that represents
staked GNS tokens. It manages minting/burning operations and tracks
voting power for governance.


## Index

- [BalanceOf](#balanceof)
- [Burn](#burn)
- [Mint](#mint)
- [Render](#render)
- [SupplyInfo](#supplyinfo)
- [TotalSupply](#totalsupply)


## Functions

<a id="balanceof"></a>

### BalanceOf

```go

func BalanceOf(owner address) int64

```

BalanceOf returns token balance for address.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| owner | address | address to check balance for |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| balance | int64 | token balance amount |

---

<a id="burn"></a>

### Burn

```go

func Burn(cur realm, from address, amount int64)

```

Burn burns tokens from address.


Only callable by governance staker contract.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| cur | realm |  |
| from | address | address to burn from |
| amount | int64 | amount to burn |

---

<a id="mint"></a>

### Mint

```go

func Mint(cur realm, to address, amount int64)

```

Mint mints tokens to address.


Only callable by governance staker contract.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| cur | realm |  |
| to | address | recipient address |
| amount | int64 | amount to mint |

---

<a id="render"></a>

### Render

```go

func Render(path string) string

```

Render returns a formatted representation of the token state.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| path | string | render path for specific views |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| output | string | formatted token state representation |

---

<a id="supplyinfo"></a>

### SupplyInfo

```go

func SupplyInfo() (totalIssued int64, issuedByDelegate int64, issuedByDepositGns int64, err error)

```

SupplyInfo returns supply breakdown information.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| totalIssued | int64 | total xGNS tokens issued |
| issuedByDelegate | int64 | tokens issued through governance delegation |
| issuedByDepositGns | int64 | tokens issued through launchpad deposit |
| err | error | error if launchpad address not found |

---

<a id="totalsupply"></a>

### TotalSupply

```go

func TotalSupply() int64

```

TotalSupply returns the total supply of xGNS tokens.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| supply | int64 | total xGNS token supply |
