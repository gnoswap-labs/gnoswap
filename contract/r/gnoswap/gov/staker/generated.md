# staker

`import "gno.land/r/gnoswap/gov/staker"`



## Index

- [StoreKeyUnDelegationLockupPeriod](#storekeyundelegationlockupperiod)
- [StoreKeyEmissionRewardBalance](#storekeyemissionrewardbalance)
- [StoreKeyTotalDelegatedAmount](#storekeytotaldelegatedamount)
- [StoreKeyTotalLockedAmount](#storekeytotallockedamount)
- [StoreKeyDelegationNextID](#storekeydelegationnextid)
- [StoreKeyDelegations](#storekeydelegations)
- [StoreKeyTotalDelegationHistory](#storekeytotaldelegationhistory)
- [StoreKeyUserDelegationHistory](#storekeyuserdelegationhistory)
- [StoreKeyEmissionRewardManager](#storekeyemissionrewardmanager)
- [StoreKeyProtocolFeeRewardManager](#storekeyprotocolfeerewardmanager)
- [StoreKeyDelegationManager](#storekeydelegationmanager)
- [StoreKeyLaunchpadProjectDeposits](#storekeylaunchpadprojectdeposits)
- [ErrWithdrawNotCollectable](#errwithdrawnotcollectable)
- [CleanStakerDelegationSnapshotByAdmin](#cleanstakerdelegationsnapshotbyadmin)
- [CollectReward](#collectreward)
- [CollectRewardFromLaunchPad](#collectrewardfromlaunchpad)
- [CollectUndelegatedGns](#collectundelegatedgns)
- [DecodeInt64](#decodeint64)
- [DecodeUint](#decodeuint)
- [Delegate](#delegate)
- [EncodeInt64](#encodeint64)
- [EncodeUint](#encodeuint)
- [ExistsDelegation](#existsdelegation)
- [GetClaimableRewardByAddress](#getclaimablerewardbyaddress)
- [GetClaimableRewardByLaunchpad](#getclaimablerewardbylaunchpad)
- [GetClaimableRewardByRewardID](#getclaimablerewardbyrewardid)
- [GetCollectableWithdrawAmount](#getcollectablewithdrawamount)
- [GetDelegationCount](#getdelegationcount)
- [GetDelegationIDs](#getdelegationids)
- [GetDelegationWithdrawCount](#getdelegationwithdrawcount)
- [GetDelegatorDelegateeAddresses](#getdelegatordelegateeaddresses)
- [GetDelegatorDelegateeCount](#getdelegatordelegateecount)
- [GetEmissionAccumulatedTimestamp](#getemissionaccumulatedtimestamp)
- [GetEmissionAccumulatedX128PerStake](#getemissionaccumulatedx128perstake)
- [GetEmissionDistributedAmount](#getemissiondistributedamount)
- [GetEmissionRewardBalance](#getemissionrewardbalance)
- [GetImplementationPackagePath](#getimplementationpackagepath)
- [GetLaunchpadProjectDeposit](#getlaunchpadprojectdeposit)
- [GetLockedAmount](#getlockedamount)
- [GetProtocolFeeAccumulatedTimestamp](#getprotocolfeeaccumulatedtimestamp)
- [GetProtocolFeeAccumulatedX128PerStake](#getprotocolfeeaccumulatedx128perstake)
- [GetProtocolFeeAmount](#getprotocolfeeamount)
- [GetTotalDelegated](#gettotaldelegated)
- [GetTotalDelegationAmountAtSnapshot](#gettotaldelegationamountatsnapshot)
- [GetTotalLockedAmount](#gettotallockedamount)
- [GetTotalxGnsSupply](#gettotalxgnssupply)
- [GetUnDelegationLockupPeriod](#getundelegationlockupperiod)
- [GetUserDelegationAmountAtSnapshot](#getuserdelegationamountatsnapshot)
- [GetUserDelegationCount](#getuserdelegationcount)
- [GetUserDelegationIDs](#getuserdelegationids)
- [HasDelegationSnapshotsKey](#hasdelegationsnapshotskey)
- [Redelegate](#redelegate)
- [RegisterInitializer](#registerinitializer)
- [SetAmountByProjectWallet](#setamountbyprojectwallet)
- [SetUnDelegationLockupPeriodByAdmin](#setundelegationlockupperiodbyadmin)
- [Undelegate](#undelegate)
- [UpgradeImpl](#upgradeimpl)
- [Counter](#counter)
- [Delegation](#delegation)
- [DelegationManager](#delegationmanager)
- [DelegationType](#delegationtype)
- [DelegationWithdraw](#delegationwithdraw)
- [EmissionRewardManager](#emissionrewardmanager)
- [EmissionRewardState](#emissionrewardstate)
- [IGovStaker](#igovstaker)
- [IGovStakerAdmin](#igovstakeradmin)
- [IGovStakerDelegation](#igovstakerdelegation)
- [IGovStakerGetter](#igovstakergetter)
- [IGovStakerReward](#igovstakerreward)
- [IGovStakerStore](#igovstakerstore)
- [LaunchpadProjectDeposits](#launchpadprojectdeposits)
- [ProtocolFeeRewardManager](#protocolfeerewardmanager)
- [ProtocolFeeRewardState](#protocolfeerewardstate)
- [UintTree](#uinttree)


## Constants

Storage key constants
<a id="storekeyundelegationlockupperiod"></a>
<a id="storekeyemissionrewardbalance"></a>
<a id="storekeytotaldelegatedamount"></a>
<a id="storekeytotallockedamount"></a>
<a id="storekeydelegationnextid"></a>
<a id="storekeydelegations"></a>
<a id="storekeytotaldelegationhistory"></a>
<a id="storekeyuserdelegationhistory"></a>
<a id="storekeyemissionrewardmanager"></a>
<a id="storekeyprotocolfeerewardmanager"></a>
<a id="storekeydelegationmanager"></a>
<a id="storekeylaunchpadprojectdeposits"></a>
```go
const (
	StoreKeyUnDelegationLockupPeriod = "unDelegationLockupPeriod"
	StoreKeyEmissionRewardBalance = "emissionRewardBalance"
	StoreKeyTotalDelegatedAmount = "totalDelegatedAmount"
	StoreKeyTotalLockedAmount = "totalLockedAmount"
	StoreKeyDelegationNextID = "delegationNextID"
	StoreKeyDelegations = "delegations"
	StoreKeyTotalDelegationHistory = "totalDelegationHistory"
	StoreKeyUserDelegationHistory = "userDelegationHistory"
	StoreKeyEmissionRewardManager = "emissionRewardManager"
	StoreKeyProtocolFeeRewardManager = "protocolFeeRewardManager"
	StoreKeyDelegationManager = "delegationManager"
	StoreKeyLaunchpadProjectDeposits = "launchpadProjectDeposits"
)
```


## Variables

<a id="errwithdrawnotcollectable"></a>
```go
var (
	ErrWithdrawNotCollectable 
)
```


## Functions

<a id="cleanstakerdelegationsnapshotbyadmin"></a>

### CleanStakerDelegationSnapshotByAdmin

```go

func CleanStakerDelegationSnapshotByAdmin(cur realm, threshold int64)

```

CleanStakerDelegationSnapshotByAdmin removes old delegation snapshots.
Only callable by admin.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| cur | realm |  |
| threshold | int64 | timestamp threshold for cleanup |

---

<a id="collectreward"></a>

### CollectReward

```go

func CollectReward(cur realm)

```

CollectReward claims accumulated staking rewards.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| cur | realm |  |

---

<a id="collectrewardfromlaunchpad"></a>

### CollectRewardFromLaunchPad

```go

func CollectRewardFromLaunchPad(cur realm, to address)

```

CollectRewardFromLaunchPad claims rewards from launchpad projects.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| cur | realm |  |
| to | address | address to collect rewards for |

---

<a id="collectundelegatedgns"></a>

### CollectUndelegatedGns

```go

func CollectUndelegatedGns(cur realm) int64

```

CollectUndelegatedGns collects GNS tokens after the undelegation lockup period.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| cur | realm |  |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| amount | int64 | amount of GNS collected |

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

<a id="delegate"></a>

### Delegate

```go

func Delegate(cur realm, to address, amount int64, referrer string) int64

```

Delegate stakes GNS tokens to a delegatee address.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| cur | realm |  |
| to | address | address to delegate to |
| amount | int64 | amount of GNS to delegate |
| referrer | string | referrer address for reward tracking |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| delegationId | int64 | delegation ID |

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

<a id="existsdelegation"></a>

### ExistsDelegation

```go

func ExistsDelegation(delegationID int64) bool

```

ExistsDelegation checks if a delegation exists.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| delegationID | int64 | ID of the delegation |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| exists | bool | true if delegation exists |

---

<a id="getclaimablerewardbyaddress"></a>

### GetClaimableRewardByAddress

```go

func GetClaimableRewardByAddress(addr address) (int64, map[string]int64, error)

```

GetClaimableRewardByAddress returns claimable rewards for an address.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| addr | address | user address |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| emissionReward | int64 | emission reward amount |
| protocolFeeRewards | map[string]int64 | protocol fee rewards by token path |
| err | error | error if retrieval fails |

---

<a id="getclaimablerewardbylaunchpad"></a>

### GetClaimableRewardByLaunchpad

```go

func GetClaimableRewardByLaunchpad(addr address) (int64, map[string]int64, error)

```

GetClaimableRewardByLaunchpad returns claimable launchpad rewards for an address.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| addr | address | user address |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| emissionReward | int64 | emission reward amount |
| protocolFeeRewards | map[string]int64 | protocol fee rewards by token path |
| err | error | error if retrieval fails |

---

<a id="getclaimablerewardbyrewardid"></a>

### GetClaimableRewardByRewardID

```go

func GetClaimableRewardByRewardID(rewardID string) (int64, map[string]int64, error)

```

GetClaimableRewardByRewardID returns claimable reward details by reward ID.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| rewardID | string | ID of the reward |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| emissionReward | int64 | emission reward amount |
| protocolFeeRewards | map[string]int64 | protocol fee rewards by token path |
| err | error | error if retrieval fails |

---

<a id="getcollectablewithdrawamount"></a>

### GetCollectableWithdrawAmount

```go

func GetCollectableWithdrawAmount(delegationID int64) int64

```

GetCollectableWithdrawAmount returns the collectable withdraw amount for a specific delegation.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| delegationID | int64 | ID of the delegation |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| amount | int64 | collectable withdraw amount |

---

<a id="getdelegationcount"></a>

### GetDelegationCount

```go

func GetDelegationCount() int

```

GetDelegationCount returns the total number of delegations.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| count | int | total number of delegations |

---

<a id="getdelegationids"></a>

### GetDelegationIDs

```go

func GetDelegationIDs(offset int, count int) []int64

```

GetDelegationIDs returns a paginated list of delegation IDs.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| offset | int | starting index |
| count | int | number of IDs to return |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| delegationIds | []int64 | list of delegation IDs |

---

<a id="getdelegationwithdrawcount"></a>

### GetDelegationWithdrawCount

```go

func GetDelegationWithdrawCount(delegationID int64) int

```

GetDelegationWithdrawCount returns the total number of delegation withdraws for a specific delegation.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| delegationID | int64 | ID of the delegation |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| count | int | number of withdraws |

---

<a id="getdelegatordelegateeaddresses"></a>

### GetDelegatorDelegateeAddresses

```go

func GetDelegatorDelegateeAddresses(delegator address, offset int, count int) []address

```

GetDelegatorDelegateeAddresses returns a paginated list of delegatee addresses for a specific delegator.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| delegator | address | delegator address |
| offset | int | starting index |
| count | int | number of addresses to return |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| addresses | []address | list of delegatee addresses |

---

<a id="getdelegatordelegateecount"></a>

### GetDelegatorDelegateeCount

```go

func GetDelegatorDelegateeCount(delegator address) int

```

GetDelegatorDelegateeCount returns the number of delegatees for a specific delegator.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| delegator | address | delegator address |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| count | int | number of delegatees |

---

<a id="getemissionaccumulatedtimestamp"></a>

### GetEmissionAccumulatedTimestamp

```go

func GetEmissionAccumulatedTimestamp() int64

```

GetEmissionAccumulatedTimestamp returns the accumulated timestamp for emission rewards.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| timestamp | int64 | accumulated timestamp |

---

<a id="getemissionaccumulatedx128perstake"></a>

### GetEmissionAccumulatedX128PerStake

```go

func GetEmissionAccumulatedX128PerStake() *u256.Uint

```

GetEmissionAccumulatedX128PerStake returns the accumulated emission per stake (Q128).

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| accumulatedEmission | *u256.Uint | accumulated emission per stake |

---

<a id="getemissiondistributedamount"></a>

### GetEmissionDistributedAmount

```go

func GetEmissionDistributedAmount() int64

```

GetEmissionDistributedAmount returns the total distributed emission amount.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| amount | int64 | total distributed emission amount |

---

<a id="getemissionrewardbalance"></a>

### GetEmissionRewardBalance

```go

func GetEmissionRewardBalance() int64

```

GetEmissionRewardBalance returns the current emission reward balance.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| balance | int64 | current emission reward balance |

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

<a id="getlaunchpadprojectdeposit"></a>

### GetLaunchpadProjectDeposit

```go

func GetLaunchpadProjectDeposit(projectAddr string) (int64, bool)

```

GetLaunchpadProjectDeposit returns the deposit amount for a launchpad project.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| projectAddr | string | project address |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| amount | int64 | deposit amount |
| exists | bool | true if project exists |

---

<a id="getlockedamount"></a>

### GetLockedAmount

```go

func GetLockedAmount() int64

```

GetLockedAmount returns the total locked GNS amount.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| amount | int64 | total locked GNS amount |

---

<a id="getprotocolfeeaccumulatedtimestamp"></a>

### GetProtocolFeeAccumulatedTimestamp

```go

func GetProtocolFeeAccumulatedTimestamp() int64

```

GetProtocolFeeAccumulatedTimestamp returns the accumulated timestamp for protocol fee rewards.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| timestamp | int64 | accumulated timestamp |

---

<a id="getprotocolfeeaccumulatedx128perstake"></a>

### GetProtocolFeeAccumulatedX128PerStake

```go

func GetProtocolFeeAccumulatedX128PerStake(tokenPath string) *u256.Uint

```

GetProtocolFeeAccumulatedX128PerStake returns the accumulated protocol fee per stake (Q128) for a token path.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| tokenPath | string | path of the token |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| accumulatedFee | *u256.Uint | accumulated protocol fee per stake |

---

<a id="getprotocolfeeamount"></a>

### GetProtocolFeeAmount

```go

func GetProtocolFeeAmount(tokenPath string) int64

```

GetProtocolFeeAmount returns the protocol fee amounts for a token path.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| tokenPath | string | path of the token |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| amount | int64 | protocol fee amount |

---

<a id="gettotaldelegated"></a>

### GetTotalDelegated

```go

func GetTotalDelegated() int64

```

GetTotalDelegated returns the total amount of GNS delegated.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| amount | int64 | total delegated GNS amount |

---

<a id="gettotaldelegationamountatsnapshot"></a>

### GetTotalDelegationAmountAtSnapshot

```go

func GetTotalDelegationAmountAtSnapshot(snapshotTime int64) (int64, bool)

```

GetTotalDelegationAmountAtSnapshot returns the total delegation amount at a specific snapshot time.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| snapshotTime | int64 | snapshot timestamp |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| amount | int64 | total delegation amount |
| exists | bool | true if snapshot exists |

---

<a id="gettotallockedamount"></a>

### GetTotalLockedAmount

```go

func GetTotalLockedAmount() int64

```

GetTotalLockedAmount returns the total amount of GNS locked in undelegation.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| amount | int64 | total locked GNS amount |

---

<a id="gettotalxgnssupply"></a>

### GetTotalxGnsSupply

```go

func GetTotalxGnsSupply() int64

```

GetTotalxGnsSupply returns the total supply of xGNS tokens.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| supply | int64 | total xGNS token supply |

---

<a id="getundelegationlockupperiod"></a>

### GetUnDelegationLockupPeriod

```go

func GetUnDelegationLockupPeriod() int64

```

GetUnDelegationLockupPeriod returns the undelegation lockup period in seconds.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| period | int64 | lockup period in seconds |

---

<a id="getuserdelegationamountatsnapshot"></a>

### GetUserDelegationAmountAtSnapshot

```go

func GetUserDelegationAmountAtSnapshot(userAddr address, snapshotTime int64) (int64, bool)

```

GetUserDelegationAmountAtSnapshot returns the user delegation amount at a specific snapshot time.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| userAddr | address | user address |
| snapshotTime | int64 | snapshot timestamp |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| amount | int64 | user delegation amount |
| exists | bool | true if snapshot exists |

---

<a id="getuserdelegationcount"></a>

### GetUserDelegationCount

```go

func GetUserDelegationCount(delegator address, delegatee address) int

```

GetUserDelegationCount returns the number of delegations for a specific delegator-delegatee pair.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| delegator | address | delegator address |
| delegatee | address | delegatee address |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| count | int | number of delegations |

---

<a id="getuserdelegationids"></a>

### GetUserDelegationIDs

```go

func GetUserDelegationIDs(delegator address, delegatee address) []int64

```

GetUserDelegationIDs returns a list of delegation IDs for a specific delegator-delegatee pair.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| delegator | address | delegator address |
| delegatee | address | delegatee address |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| delegationIds | []int64 | list of delegation IDs |

---

<a id="hasdelegationsnapshotskey"></a>

### HasDelegationSnapshotsKey

```go

func HasDelegationSnapshotsKey() bool

```

HasDelegationSnapshotsKey returns true if delegation history exists.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| exists | bool | true if delegation history exists |

---

<a id="redelegate"></a>

### Redelegate

```go

func Redelegate(cur realm, delegatee address, newDelegatee address, amount int64) int64

```

Redelegate moves delegation from one delegatee to another.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| cur | realm |  |
| delegatee | address | current delegatee address |
| newDelegatee | address | new delegatee address |
| amount | int64 | amount to redelegate |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| resultCode | int64 | redelegation result code |

---

<a id="registerinitializer"></a>

### RegisterInitializer

```go

func RegisterInitializer(cur realm, initializer func(...))

```

RegisterInitializer registers an implementation
This function is called by each implementation version during init

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| cur | realm |  |
| initializer | func(...) |  |

---

<a id="setamountbyprojectwallet"></a>

### SetAmountByProjectWallet

```go

func SetAmountByProjectWallet(cur realm, addr address, amount int64, add bool)

```

SetAmountByProjectWallet sets reward amount for a project wallet.
Only callable by launchpad contract.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| cur | realm |  |
| addr | address | project wallet address |
| amount | int64 | reward amount |
| add | bool | true to add, false to subtract |

---

<a id="setundelegationlockupperiodbyadmin"></a>

### SetUnDelegationLockupPeriodByAdmin

```go

func SetUnDelegationLockupPeriodByAdmin(cur realm, period int64)

```

SetUnDelegationLockupPeriodByAdmin sets the undelegation lockup period.
Only callable by admin.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| cur | realm |  |
| period | int64 | lockup period in seconds |

---

<a id="undelegate"></a>

### Undelegate

```go

func Undelegate(cur realm, from address, amount int64) int64

```

Undelegate initiates the undelegation process for staked GNS.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| cur | realm |  |
| from | address | delegatee address to undelegate from |
| amount | int64 | amount of GNS to undelegate |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| resultCode | int64 | undelegation result code |

---

<a id="upgradeimpl"></a>

### UpgradeImpl

```go

func UpgradeImpl(cur realm, packagePath string)

```

UpgradeImpl upgrades the implementation to a new version
Only admin or governance can call this function

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

<a id="delegation"></a>

### Delegation

```go

type Delegation struct

```

Delegation represents a delegation between two addresses

#### Methods

<a id="delegation.addwithdraw"></a>
##### AddWithdraw

```go
func (d *Delegation) AddWithdraw(withdraw *DelegationWithdraw)
```

AddWithdraw adds a withdrawal to the delegation.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| withdraw | *DelegationWithdraw | withdrawal to add |

<a id="delegation.clone"></a>
##### Clone

```go
func (d *Delegation) Clone() *Delegation
```

Clone creates a deep copy of the delegation.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| delegation | *Delegation | cloned delegation instance |

<a id="delegation.collectedamount"></a>
##### CollectedAmount

```go
func (d *Delegation) CollectedAmount() int64
```

CollectedAmount returns the collected amount.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| amount | int64 | collected amount |

<a id="delegation.createdat"></a>
##### CreatedAt

```go
func (d *Delegation) CreatedAt() int64
```

CreatedAt returns the creation timestamp.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| timestamp | int64 | creation timestamp |

<a id="delegation.delegatefrom"></a>
##### DelegateFrom

```go
func (d *Delegation) DelegateFrom() address
```

DelegateFrom returns the delegator address.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| address | address | delegator address |

<a id="delegation.delegateto"></a>
##### DelegateTo

```go
func (d *Delegation) DelegateTo() address
```

DelegateTo returns the delegatee address.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| address | address | delegatee address |

<a id="delegation.id"></a>
##### ID

```go
func (d *Delegation) ID() int64
```

ID returns the unique delegation ID.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| id | int64 | delegation ID |

<a id="delegation.setcollectedamount"></a>
##### SetCollectedAmount

```go
func (d *Delegation) SetCollectedAmount(amount int64)
```

SetCollectedAmount sets the collected amount.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| amount | int64 | collected amount |

<a id="delegation.setundelegateamount"></a>
##### SetUnDelegateAmount

```go
func (d *Delegation) SetUnDelegateAmount(amount int64)
```

SetUnDelegateAmount sets the undelegated amount.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| amount | int64 | undelegated amount |

<a id="delegation.setwithdraws"></a>
##### SetWithdraws

```go
func (d *Delegation) SetWithdraws(withdraws []*DelegationWithdraw)
```

SetWithdraws sets the list of withdrawals.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| withdraws | []*DelegationWithdraw | list of withdrawals |

<a id="delegation.totaldelegatedamount"></a>
##### TotalDelegatedAmount

```go
func (d *Delegation) TotalDelegatedAmount() int64
```

TotalDelegatedAmount returns the total delegated amount.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| amount | int64 | total delegated amount |

<a id="delegation.undelegatedamount"></a>
##### UnDelegatedAmount

```go
func (d *Delegation) UnDelegatedAmount() int64
```

UnDelegatedAmount returns the undelegated amount.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| amount | int64 | undelegated amount |

<a id="delegation.withdraws"></a>
##### Withdraws

```go
func (d *Delegation) Withdraws() []*DelegationWithdraw
```

Withdraws returns the list of delegation withdraws.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| withdraws | []*DelegationWithdraw | list of delegation withdraws |


#### Constructors

- `func GetDelegation(delegationID int64) (*Delegation, error)`
- `func NewDelegation(id int64, delegateFrom address, delegateTo address, delegateAmount int64, createdHeight int64, createdAt int64) *Delegation`

---

<a id="delegationmanager"></a>

### DelegationManager

```go

type DelegationManager struct

```

DelegationManager manages the mapping between users and their delegation IDs.
It provides efficient lookup and management of user delegations organized by delegator and delegatee addresses.

#### Methods

<a id="delegationmanager.getdelegationids"></a>
##### GetDelegationIDs

```go
func (dm *DelegationManager) GetDelegationIDs(delegator string, delegatee string) ([]int64, bool)
```

GetDelegationIDs returns all delegation IDs for a specific delegator-delegatee pair.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| delegator | string |  |
| delegatee | string |  |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | []int64 |  |
|  | bool |  |

<a id="delegationmanager.getdelegatordelegations"></a>
##### GetDelegatorDelegations

```go
func (dm *DelegationManager) GetDelegatorDelegations(delegator string) (*avl.Tree, bool)
```

GetDelegatorDelegations returns all delegations for a specific delegator.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| delegator | string |  |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | *avl.Tree |  |
|  | bool |  |

<a id="delegationmanager.getuserdelegations"></a>
##### GetUserDelegations

```go
func (dm *DelegationManager) GetUserDelegations() *avl.Tree
```

GetUserDelegations returns the entire user delegations tree.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | *avl.Tree |  |

<a id="delegationmanager.setdelegationids"></a>
##### SetDelegationIDs

```go
func (dm *DelegationManager) SetDelegationIDs(delegator string, delegatee string, ids []int64)
```

SetDelegationIDs sets delegation IDs for a specific delegator-delegatee pair.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| delegator | string |  |
| delegatee | string |  |
| ids | []int64 |  |

<a id="delegationmanager.setuserdelegations"></a>
##### SetUserDelegations

```go
func (dm *DelegationManager) SetUserDelegations(userDelegations *avl.Tree)
```

SetUserDelegations sets the entire user delegations tree.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| userDelegations | *avl.Tree |  |


#### Constructors

- `func NewDelegationManager() *DelegationManager`

---

<a id="delegationtype"></a>

### DelegationType

```go

type DelegationType string

```

DelegationType represents the type of delegation operation

#### Methods

<a id="delegationtype.isdelegate"></a>
##### IsDelegate

```go
func (d DelegationType) IsDelegate() bool
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | bool |  |

<a id="delegationtype.isundelegate"></a>
##### IsUnDelegate

```go
func (d DelegationType) IsUnDelegate() bool
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | bool |  |

<a id="delegationtype.string"></a>
##### String

```go
func (d DelegationType) String() string
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | string |  |


---

<a id="delegationwithdraw"></a>

### DelegationWithdraw

```go

type DelegationWithdraw struct

```

DelegationWithdraw represents a pending withdrawal from a delegation.
This struct tracks undelegated amounts that are subject to lockup periods
and manages the collection process once the lockup period expires.

#### Methods

<a id="delegationwithdraw.clone"></a>
##### Clone

```go
func (d *DelegationWithdraw) Clone() *DelegationWithdraw
```

Clone creates a deep copy of the delegation withdraw.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | *DelegationWithdraw |  |

<a id="delegationwithdraw.collectabletime"></a>
##### CollectableTime

```go
func (d *DelegationWithdraw) CollectableTime() int64
```

CollectableTime returns the timestamp when collection becomes available.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| int64 | int64 | collectable time |

<a id="delegationwithdraw.collectedamount"></a>
##### CollectedAmount

```go
func (d *DelegationWithdraw) CollectedAmount() int64
```

CollectedAmount returns the amount that has already been collected.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| int64 | int64 | collected amount |

<a id="delegationwithdraw.collectedat"></a>
##### CollectedAt

```go
func (d *DelegationWithdraw) CollectedAt() int64
```

CollectedAt returns the timestamp when collection occurred.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| int64 | int64 | collection timestamp |

<a id="delegationwithdraw.delegationid"></a>
##### DelegationID

```go
func (d *DelegationWithdraw) DelegationID() int64
```

DelegationID returns the unique identifier of the associated delegation.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| int64 | int64 | delegation ID |

<a id="delegationwithdraw.iscollected"></a>
##### IsCollected

```go
func (d *DelegationWithdraw) IsCollected() bool
```

IsCollected returns whether the withdrawal has been fully collected.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| bool | bool | true if fully collected, false otherwise |

<a id="delegationwithdraw.setcollected"></a>
##### SetCollected

```go
func (d *DelegationWithdraw) SetCollected(collected bool)
```

SetCollected sets the collected status.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| collected | bool | new collected status |

<a id="delegationwithdraw.setcollectedamount"></a>
##### SetCollectedAmount

```go
func (d *DelegationWithdraw) SetCollectedAmount(amount int64)
```

SetCollectedAmount sets the collected amount.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| amount | int64 | collected amount |

<a id="delegationwithdraw.setcollectedat"></a>
##### SetCollectedAt

```go
func (d *DelegationWithdraw) SetCollectedAt(collectedAt int64)
```

SetCollectedAt sets the collection timestamp.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| collectedAt | int64 | collection timestamp |

<a id="delegationwithdraw.undelegateamount"></a>
##### UnDelegateAmount

```go
func (d *DelegationWithdraw) UnDelegateAmount() int64
```

UnDelegateAmount returns the total amount that was undelegated.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| int64 | int64 | undelegated amount |

<a id="delegationwithdraw.undelegatedat"></a>
##### UnDelegatedAt

```go
func (d *DelegationWithdraw) UnDelegatedAt() int64
```

UnDelegatedAt returns the timestamp when the undelegation occurred.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| int64 | int64 | undelegation timestamp |

<a id="delegationwithdraw.undelegatedheight"></a>
##### UnDelegatedHeight

```go
func (d *DelegationWithdraw) UnDelegatedHeight() int64
```

UnDelegatedHeight returns the height when the undelegation occurred.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| int64 | int64 | undelegation height |


#### Constructors

- `func GetDelegationWithdraws(delegationID int64, offset int, count int) ([]*DelegationWithdraw, error)`
- `func NewDelegationWithdraw(delegationID int64, unDelegateAmount int64, createdHeight int64, createdAt int64, unDelegationLockupPeriod int64) *DelegationWithdraw`
- `func NewDelegationWithdrawWithoutLockup(delegationID int64, unDelegateAmount int64, createdHeight int64, createdAt int64) *DelegationWithdraw`

---

<a id="emissionrewardmanager"></a>

### EmissionRewardManager

```go

type EmissionRewardManager struct

```

EmissionRewardManager manages the distribution of emission rewards to stakers.

#### Methods

<a id="emissionrewardmanager.getaccumulatedrewardx128perstake"></a>
##### GetAccumulatedRewardX128PerStake

```go
func (e *EmissionRewardManager) GetAccumulatedRewardX128PerStake() *u256.Uint
```

GetAccumulatedRewardX128PerStake returns the accumulated reward per stake with 128-bit precision.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | *u256.Uint |  |

<a id="emissionrewardmanager.getaccumulatedtimestamp"></a>
##### GetAccumulatedTimestamp

```go
func (e *EmissionRewardManager) GetAccumulatedTimestamp() int64
```

GetAccumulatedTimestamp returns the last timestamp when rewards were accumulated.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int64 |  |

<a id="emissionrewardmanager.getdistributedamount"></a>
##### GetDistributedAmount

```go
func (e *EmissionRewardManager) GetDistributedAmount() int64
```

GetDistributedAmount returns the total amount of rewards distributed.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int64 |  |

<a id="emissionrewardmanager.getrewardstate"></a>
##### GetRewardState

```go
func (e *EmissionRewardManager) GetRewardState(addr string) (*EmissionRewardState, bool, error)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| addr | string |  |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | *EmissionRewardState |  |
|  | bool |  |
|  | error |  |

<a id="emissionrewardmanager.gettotalstakedamount"></a>
##### GetTotalStakedAmount

```go
func (e *EmissionRewardManager) GetTotalStakedAmount() int64
```

GetTotalStakedAmount returns the total amount of tokens staked in the system.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int64 |  |

<a id="emissionrewardmanager.setaccumulatedrewardx128perstake"></a>
##### SetAccumulatedRewardX128PerStake

```go
func (e *EmissionRewardManager) SetAccumulatedRewardX128PerStake(accumulatedRewardX128PerStake *u256.Uint)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| accumulatedRewardX128PerStake | *u256.Uint |  |

<a id="emissionrewardmanager.setaccumulatedtimestamp"></a>
##### SetAccumulatedTimestamp

```go
func (e *EmissionRewardManager) SetAccumulatedTimestamp(accumulatedTimestamp int64)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| accumulatedTimestamp | int64 |  |

<a id="emissionrewardmanager.setdistributedamount"></a>
##### SetDistributedAmount

```go
func (e *EmissionRewardManager) SetDistributedAmount(distributedAmount int64)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| distributedAmount | int64 |  |

<a id="emissionrewardmanager.setrewardstate"></a>
##### SetRewardState

```go
func (e *EmissionRewardManager) SetRewardState(address string, rewardState *EmissionRewardState)
```

SetRewardState sets the reward state for a specific address

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| address | string |  |
| rewardState | *EmissionRewardState |  |

<a id="emissionrewardmanager.setrewardstates"></a>
##### SetRewardStates

```go
func (e *EmissionRewardManager) SetRewardStates(rewardStates *avl.Tree)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| rewardStates | *avl.Tree |  |

<a id="emissionrewardmanager.settotalstakedamount"></a>
##### SetTotalStakedAmount

```go
func (e *EmissionRewardManager) SetTotalStakedAmount(totalStakedAmount int64)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| totalStakedAmount | int64 |  |


#### Constructors

- `func NewEmissionRewardManager() *EmissionRewardManager`

---

<a id="emissionrewardstate"></a>

### EmissionRewardState

```go

type EmissionRewardState struct

```

EmissionRewardState tracks emission reward information for an individual staker.
This struct maintains reward debt, accumulated rewards, and claiming history
to ensure accurate reward calculations and prevent double-claiming.

#### Methods

<a id="emissionrewardstate.getaccumulatedrewardamount"></a>
##### GetAccumulatedRewardAmount

```go
func (e *EmissionRewardState) GetAccumulatedRewardAmount() int64
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int64 |  |

<a id="emissionrewardstate.getaccumulatedtimestamp"></a>
##### GetAccumulatedTimestamp

```go
func (e *EmissionRewardState) GetAccumulatedTimestamp() int64
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int64 |  |

<a id="emissionrewardstate.getclaimedrewardamount"></a>
##### GetClaimedRewardAmount

```go
func (e *EmissionRewardState) GetClaimedRewardAmount() int64
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int64 |  |

<a id="emissionrewardstate.getclaimedtimestamp"></a>
##### GetClaimedTimestamp

```go
func (e *EmissionRewardState) GetClaimedTimestamp() int64
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int64 |  |

<a id="emissionrewardstate.getrewarddebtx128"></a>
##### GetRewardDebtX128

```go
func (e *EmissionRewardState) GetRewardDebtX128() *u256.Uint
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | *u256.Uint |  |

<a id="emissionrewardstate.getstakedamount"></a>
##### GetStakedAmount

```go
func (e *EmissionRewardState) GetStakedAmount() int64
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int64 |  |

<a id="emissionrewardstate.setaccumulatedrewardamount"></a>
##### SetAccumulatedRewardAmount

```go
func (e *EmissionRewardState) SetAccumulatedRewardAmount(accumulatedRewardAmount int64)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| accumulatedRewardAmount | int64 |  |

<a id="emissionrewardstate.setaccumulatedtimestamp"></a>
##### SetAccumulatedTimestamp

```go
func (e *EmissionRewardState) SetAccumulatedTimestamp(accumulatedTimestamp int64)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| accumulatedTimestamp | int64 |  |

<a id="emissionrewardstate.setclaimedrewardamount"></a>
##### SetClaimedRewardAmount

```go
func (e *EmissionRewardState) SetClaimedRewardAmount(claimedRewardAmount int64)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| claimedRewardAmount | int64 |  |

<a id="emissionrewardstate.setclaimedtimestamp"></a>
##### SetClaimedTimestamp

```go
func (e *EmissionRewardState) SetClaimedTimestamp(claimedTimestamp int64)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| claimedTimestamp | int64 |  |

<a id="emissionrewardstate.setrewarddebtx128"></a>
##### SetRewardDebtX128

```go
func (e *EmissionRewardState) SetRewardDebtX128(rewardDebtX128 *u256.Uint)
```

 Setters

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| rewardDebtX128 | *u256.Uint |  |

<a id="emissionrewardstate.setstakedamount"></a>
##### SetStakedAmount

```go
func (e *EmissionRewardState) SetStakedAmount(stakedAmount int64)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| stakedAmount | int64 |  |


#### Constructors

- `func NewEmissionRewardState(accumulatedRewardX128PerStake *u256.Uint) *EmissionRewardState`

---

<a id="igovstaker"></a>

### IGovStaker

```go

type IGovStaker interface

```

Main interface that combines all sub-interfaces

---

<a id="igovstakeradmin"></a>

### IGovStakerAdmin

```go

type IGovStakerAdmin interface

```

Admin interface for administrative functions

---

<a id="igovstakerdelegation"></a>

### IGovStakerDelegation

```go

type IGovStakerDelegation interface

```

Delegation operations interface

---

<a id="igovstakergetter"></a>

### IGovStakerGetter

```go

type IGovStakerGetter interface

```

Getter interface for read operations

---

<a id="igovstakerreward"></a>

### IGovStakerReward

```go

type IGovStakerReward interface

```

Reward management interface

---

<a id="igovstakerstore"></a>

### IGovStakerStore

```go

type IGovStakerStore interface

```

#### Constructors

- `func NewGovStakerStore(kvStore store.KVStore) IGovStakerStore`

---

<a id="launchpadprojectdeposits"></a>

### LaunchpadProjectDeposits

```go

type LaunchpadProjectDeposits struct

```

LaunchpadProjectDeposits manages deposit amounts for launchpad projects.
It tracks the total staked amount for each project identified by owner address.

#### Methods

<a id="launchpadprojectdeposits.getdeposits"></a>
##### GetDeposits

```go
func (lpd *LaunchpadProjectDeposits) GetDeposits() *avl.Tree
```

GetDeposits returns the entire deposits tree.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | *avl.Tree |  |

<a id="launchpadprojectdeposits.setdeposits"></a>
##### SetDeposits

```go
func (lpd *LaunchpadProjectDeposits) SetDeposits(deposits *avl.Tree)
```

SetDeposits sets the entire deposits tree.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| deposits | *avl.Tree |  |


#### Constructors

- `func NewLaunchpadProjectDeposits() *LaunchpadProjectDeposits`

---

<a id="protocolfeerewardmanager"></a>

### ProtocolFeeRewardManager

```go

type ProtocolFeeRewardManager struct

```

ProtocolFeeRewardManager manages the distribution of protocol fee rewards to stakers.
Unlike emission rewards, protocol fees can come from multiple tokens, requiring
separate tracking and distribution mechanisms for each token type.

#### Methods

<a id="protocolfeerewardmanager.getaccumulatedprotocolfeex128perstake"></a>
##### GetAccumulatedProtocolFeeX128PerStake

```go
func (p *ProtocolFeeRewardManager) GetAccumulatedProtocolFeeX128PerStake(token string) *u256.Uint
```

GetAccumulatedProtocolFeeX128PerStake returns the accumulated protocol fee per stake for a specific token.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| token | string | token path to get accumulated fee for |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| *u256.Uint | *u256.Uint | accumulated protocol fee per stake for the token (scaled by 2^128) |

<a id="protocolfeerewardmanager.getaccumulatedtimestamp"></a>
##### GetAccumulatedTimestamp

```go
func (p *ProtocolFeeRewardManager) GetAccumulatedTimestamp() int64
```

GetAccumulatedTimestamp returns the last timestamp when protocol fees were accumulated.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| int64 | int64 | last accumulated timestamp |

<a id="protocolfeerewardmanager.getallaccumulatedprotocolfeex128perstake"></a>
##### GetAllAccumulatedProtocolFeeX128PerStake

```go
func (p *ProtocolFeeRewardManager) GetAllAccumulatedProtocolFeeX128PerStake() map[string]*u256.Uint
```

GetAllAccumulatedProtocolFeeX128PerStake returns all accumulated protocol fees per stake

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | map[string]*u256.Uint |  |

<a id="protocolfeerewardmanager.getprotocolfeeamount"></a>
##### GetProtocolFeeAmount

```go
func (p *ProtocolFeeRewardManager) GetProtocolFeeAmount(token string) int64
```

GetProtocolFeeAmount returns the protocol fee amount for a specific token

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| token | string |  |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int64 |  |

<a id="protocolfeerewardmanager.getprotocolfeeamounts"></a>
##### GetProtocolFeeAmounts

```go
func (p *ProtocolFeeRewardManager) GetProtocolFeeAmounts() map[string]int64
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | map[string]int64 |  |

<a id="protocolfeerewardmanager.getrewardstate"></a>
##### GetRewardState

```go
func (p *ProtocolFeeRewardManager) GetRewardState(addr string) (*ProtocolFeeRewardState, bool, error)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| addr | string |  |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | *ProtocolFeeRewardState |  |
|  | bool |  |
|  | error |  |

<a id="protocolfeerewardmanager.gettotalstakedamount"></a>
##### GetTotalStakedAmount

```go
func (p *ProtocolFeeRewardManager) GetTotalStakedAmount() int64
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int64 |  |

<a id="protocolfeerewardmanager.setaccumulatedprotocolfeex128perstake"></a>
##### SetAccumulatedProtocolFeeX128PerStake

```go
func (p *ProtocolFeeRewardManager) SetAccumulatedProtocolFeeX128PerStake(accumulatedProtocolFeeX128PerStake map[string]*u256.Uint)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| accumulatedProtocolFeeX128PerStake | map[string]*u256.Uint |  |

<a id="protocolfeerewardmanager.setaccumulatedtimestamp"></a>
##### SetAccumulatedTimestamp

```go
func (p *ProtocolFeeRewardManager) SetAccumulatedTimestamp(accumulatedTimestamp int64)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| accumulatedTimestamp | int64 |  |

<a id="protocolfeerewardmanager.setprotocolfeeamounts"></a>
##### SetProtocolFeeAmounts

```go
func (p *ProtocolFeeRewardManager) SetProtocolFeeAmounts(protocolFeeAmounts map[string]int64)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| protocolFeeAmounts | map[string]int64 |  |

<a id="protocolfeerewardmanager.setrewardstate"></a>
##### SetRewardState

```go
func (p *ProtocolFeeRewardManager) SetRewardState(address string, rewardState *ProtocolFeeRewardState)
```

SetRewardState sets the reward state for a specific address

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| address | string |  |
| rewardState | *ProtocolFeeRewardState |  |

<a id="protocolfeerewardmanager.setrewardstates"></a>
##### SetRewardStates

```go
func (p *ProtocolFeeRewardManager) SetRewardStates(rewardStates *avl.Tree)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| rewardStates | *avl.Tree |  |

<a id="protocolfeerewardmanager.settotalstakedamount"></a>
##### SetTotalStakedAmount

```go
func (p *ProtocolFeeRewardManager) SetTotalStakedAmount(totalStakedAmount int64)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| totalStakedAmount | int64 |  |


#### Constructors

- `func NewProtocolFeeRewardManager() *ProtocolFeeRewardManager`

---

<a id="protocolfeerewardstate"></a>

### ProtocolFeeRewardState

```go

type ProtocolFeeRewardState struct

```

ProtocolFeeRewardState tracks protocol fee reward information for an individual staker across multiple tokens.
Unlike emission rewards which are single-token, protocol fees can come from various trading pairs,
requiring separate tracking and calculation for each token type.

#### Methods

<a id="protocolfeerewardstate.getaccumulatedrewardfortoken"></a>
##### GetAccumulatedRewardForToken

```go
func (p *ProtocolFeeRewardState) GetAccumulatedRewardForToken(token string) int64
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| token | string |  |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int64 |  |

<a id="protocolfeerewardstate.getaccumulatedrewards"></a>
##### GetAccumulatedRewards

```go
func (p *ProtocolFeeRewardState) GetAccumulatedRewards() map[string]int64
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | map[string]int64 |  |

<a id="protocolfeerewardstate.getaccumulatedtimestamp"></a>
##### GetAccumulatedTimestamp

```go
func (p *ProtocolFeeRewardState) GetAccumulatedTimestamp() int64
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int64 |  |

<a id="protocolfeerewardstate.getclaimedrewardfortoken"></a>
##### GetClaimedRewardForToken

```go
func (p *ProtocolFeeRewardState) GetClaimedRewardForToken(token string) int64
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| token | string |  |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int64 |  |

<a id="protocolfeerewardstate.getclaimedrewards"></a>
##### GetClaimedRewards

```go
func (p *ProtocolFeeRewardState) GetClaimedRewards() map[string]int64
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | map[string]int64 |  |

<a id="protocolfeerewardstate.getclaimedtimestamp"></a>
##### GetClaimedTimestamp

```go
func (p *ProtocolFeeRewardState) GetClaimedTimestamp() int64
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int64 |  |

<a id="protocolfeerewardstate.getrewarddebtx128"></a>
##### GetRewardDebtX128

```go
func (p *ProtocolFeeRewardState) GetRewardDebtX128() map[string]*u256.Uint
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | map[string]*u256.Uint |  |

<a id="protocolfeerewardstate.getrewarddebtx128fortoken"></a>
##### GetRewardDebtX128ForToken

```go
func (p *ProtocolFeeRewardState) GetRewardDebtX128ForToken(token string) *u256.Uint
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| token | string |  |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | *u256.Uint |  |

<a id="protocolfeerewardstate.getstakedamount"></a>
##### GetStakedAmount

```go
func (p *ProtocolFeeRewardState) GetStakedAmount() int64
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int64 |  |

<a id="protocolfeerewardstate.setaccumulatedrewardfortoken"></a>
##### SetAccumulatedRewardForToken

```go
func (p *ProtocolFeeRewardState) SetAccumulatedRewardForToken(token string, value int64)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| token | string |  |
| value | int64 |  |

<a id="protocolfeerewardstate.setaccumulatedrewards"></a>
##### SetAccumulatedRewards

```go
func (p *ProtocolFeeRewardState) SetAccumulatedRewards(accumulatedRewards map[string]int64)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| accumulatedRewards | map[string]int64 |  |

<a id="protocolfeerewardstate.setaccumulatedtimestamp"></a>
##### SetAccumulatedTimestamp

```go
func (p *ProtocolFeeRewardState) SetAccumulatedTimestamp(accumulatedTimestamp int64)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| accumulatedTimestamp | int64 |  |

<a id="protocolfeerewardstate.setclaimedrewardfortoken"></a>
##### SetClaimedRewardForToken

```go
func (p *ProtocolFeeRewardState) SetClaimedRewardForToken(token string, value int64)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| token | string |  |
| value | int64 |  |

<a id="protocolfeerewardstate.setclaimedrewards"></a>
##### SetClaimedRewards

```go
func (p *ProtocolFeeRewardState) SetClaimedRewards(claimedRewards map[string]int64)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| claimedRewards | map[string]int64 |  |

<a id="protocolfeerewardstate.setclaimedtimestamp"></a>
##### SetClaimedTimestamp

```go
func (p *ProtocolFeeRewardState) SetClaimedTimestamp(claimedTimestamp int64)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| claimedTimestamp | int64 |  |

<a id="protocolfeerewardstate.setrewarddebtx128"></a>
##### SetRewardDebtX128

```go
func (p *ProtocolFeeRewardState) SetRewardDebtX128(rewardDebtX128 map[string]*u256.Uint)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| rewardDebtX128 | map[string]*u256.Uint |  |

<a id="protocolfeerewardstate.setrewarddebtx128fortoken"></a>
##### SetRewardDebtX128ForToken

```go
func (p *ProtocolFeeRewardState) SetRewardDebtX128ForToken(token string, value *u256.Uint)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| token | string |  |
| value | *u256.Uint |  |

<a id="protocolfeerewardstate.setstakedamount"></a>
##### SetStakedAmount

```go
func (p *ProtocolFeeRewardState) SetStakedAmount(stakedAmount int64)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| stakedAmount | int64 |  |


#### Constructors

- `func NewProtocolFeeRewardState(accumulatedProtocolFeeX128PerStake map[string]*u256.Uint) *ProtocolFeeRewardState`

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

Size returns the number of entries in the tree.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int |  |


#### Constructors

- `func NewUintTree() *UintTree`
