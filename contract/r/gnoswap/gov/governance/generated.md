# governance

`import "gno.land/r/gnoswap/gov/governance"`

Package governance implements proposal lifecycle management and voting.
It supports text proposals, parameter changes, and community pool spending.
Proposals go through creation, voting, and execution phases with configurable
parameters for voting delays, periods, and thresholds.


## Index

- [Cancel](#cancel)
- [Execute](#execute)
- [ExistsProposal](#existsproposal)
- [ExistsVotingInfo](#existsvotinginfo)
- [GetConfigVersionByProposalId](#getconfigversionbyproposalid)
- [GetCurrentProposalID](#getcurrentproposalid)
- [GetCurrentVotingWeightSnapshot](#getcurrentvotingweightsnapshot)
- [GetDescriptionByProposalId](#getdescriptionbyproposalid)
- [GetImplementationPackagePath](#getimplementationpackagepath)
- [GetLatestConfigVersion](#getlatestconfigversion)
- [GetMaxSmoothingPeriod](#getmaxsmoothingperiod)
- [GetNayByProposalId](#getnaybyproposalid)
- [GetOldestActiveProposalSnapshotTime](#getoldestactiveproposalsnapshottime)
- [GetProposalCount](#getproposalcount)
- [GetProposalCreatedAt](#getproposalcreatedat)
- [GetProposalCreatedHeight](#getproposalcreatedheight)
- [GetProposalIDs](#getproposalids)
- [GetProposalStatusByProposalId](#getproposalstatusbyproposalid)
- [GetProposerByProposalId](#getproposerbyproposalid)
- [GetQuorumAmountByProposalId](#getquorumamountbyproposalid)
- [GetTitleByProposalId](#gettitlebyproposalid)
- [GetUserProposalCount](#getuserproposalcount)
- [GetUserProposalIDs](#getuserproposalids)
- [GetVoteStatus](#getvotestatus)
- [GetVoteWeight](#getvoteweight)
- [GetVotedAt](#getvotedat)
- [GetVotedHeight](#getvotedheight)
- [GetVotingInfoAddresses](#getvotinginfoaddresses)
- [GetVotingInfoCount](#getvotinginfocount)
- [GetYeaByProposalId](#getyeabyproposalid)
- [ProposeCommunityPoolSpend](#proposecommunitypoolspend)
- [ProposeParameterChange](#proposeparameterchange)
- [ProposeText](#proposetext)
- [Reconfigure](#reconfigure)
- [RegisterInitializer](#registerinitializer)
- [UpgradeImpl](#upgradeimpl)
- [Vote](#vote)
- [CommunityPoolSpendInfo](#communitypoolspendinfo)
- [Config](#config)
- [Counter](#counter)
- [ExecutionInfo](#executioninfo)
- [GovStakerAccessor](#govstakeraccessor)
- [IGovernance](#igovernance)
- [IGovernanceGetter](#igovernancegetter)
- [IGovernanceManager](#igovernancemanager)
- [IGovernanceStore](#igovernancestore)
- [ParameterChangeInfo](#parameterchangeinfo)
- [Proposal](#proposal)
- [ProposalActionStatus](#proposalactionstatus)
- [ProposalData](#proposaldata)
- [ProposalMetadata](#proposalmetadata)
- [ProposalScheduleStatus](#proposalschedulestatus)
- [ProposalStatus](#proposalstatus)
- [ProposalStatusType](#proposalstatustype)
- [ProposalType](#proposaltype)
- [ProposalVoteStatus](#proposalvotestatus)
- [StoreKey](#storekey)
- [VotingInfo](#votinginfo)


## Functions

<a id="cancel"></a>

### Cancel

```go

func Cancel(cur realm, proposalId int64) int64

```

Cancel cancels a proposal before voting begins.
Only callable by the proposer.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| cur | realm |  |
| proposalId | int64 | ID of the proposal to cancel |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| int64 | int64 | cancellation result code |

---

<a id="execute"></a>

### Execute

```go

func Execute(cur realm, proposalId int64) int64

```

Execute executes a passed proposal that is in the execution window.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| cur | realm |  |
| proposalId | int64 | ID of the proposal to execute |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| int64 | int64 | execution result code |

---

<a id="existsproposal"></a>

### ExistsProposal

```go

func ExistsProposal(proposalID int64) bool

```

ExistsProposal checks if a proposal exists.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| proposalID | int64 | ID of the proposal |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| exists | bool | true if proposal exists |

---

<a id="existsvotinginfo"></a>

### ExistsVotingInfo

```go

func ExistsVotingInfo(proposalID int64, addr address) bool

```

ExistsVotingInfo checks if a voting info exists for a user on a proposal.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| proposalID | int64 | ID of the proposal |
| addr | address | voter address |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| exists | bool | true if voting info exists |

---

<a id="getconfigversionbyproposalid"></a>

### GetConfigVersionByProposalId

```go

func GetConfigVersionByProposalId(proposalId int64) (int64, error)

```

GetConfigVersionByProposalId returns the config version used by a proposal.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| proposalId | int64 | ID of the proposal |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| configVersion | int64 | config version number |
| err | error | error if not found |

---

<a id="getcurrentproposalid"></a>

### GetCurrentProposalID

```go

func GetCurrentProposalID() int64

```

GetCurrentProposalID returns the current proposal ID counter.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| proposalId | int64 | current proposal ID counter |

---

<a id="getcurrentvotingweightsnapshot"></a>

### GetCurrentVotingWeightSnapshot

```go

func GetCurrentVotingWeightSnapshot() (int64, int64, error)

```

GetCurrentVotingWeightSnapshot returns the current voting weight snapshot.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| snapshotHeight | int64 | snapshot block height |
| snapshotTime | int64 | snapshot timestamp |
| err | error | error if retrieval fails |

---

<a id="getdescriptionbyproposalid"></a>

### GetDescriptionByProposalId

```go

func GetDescriptionByProposalId(proposalId int64) (string, error)

```

GetDescriptionByProposalId returns the description of a proposal.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| proposalId | int64 | ID of the proposal |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| description | string | proposal description |
| err | error | error if not found |

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

<a id="getlatestconfigversion"></a>

### GetLatestConfigVersion

```go

func GetLatestConfigVersion() int64

```

GetLatestConfigVersion returns the current config version.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| version | int64 | current config version number |

---

<a id="getmaxsmoothingperiod"></a>

### GetMaxSmoothingPeriod

```go

func GetMaxSmoothingPeriod() int64

```

GetMaxSmoothingPeriod returns the maximum smoothing period for delegation history cleanup.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| period | int64 | maximum smoothing period in seconds |

---

<a id="getnaybyproposalid"></a>

### GetNayByProposalId

```go

func GetNayByProposalId(proposalId int64) (int64, error)

```

GetNayByProposalId returns the no vote weight of a proposal.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| proposalId | int64 | ID of the proposal |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| nay | int64 | total no vote weight |
| err | error | error if not found |

---

<a id="getoldestactiveproposalsnapshottime"></a>

### GetOldestActiveProposalSnapshotTime

```go

func GetOldestActiveProposalSnapshotTime() (int64, bool)

```

GetOldestActiveProposalSnapshotTime returns the oldest snapshot time among active proposals.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| snapshotTime | int64 | oldest snapshot timestamp |
| exists | bool | true if active proposals exist |

---

<a id="getproposalcount"></a>

### GetProposalCount

```go

func GetProposalCount() int

```

GetProposalCount returns the total number of proposals.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| count | int | total number of proposals |

---

<a id="getproposalcreatedat"></a>

### GetProposalCreatedAt

```go

func GetProposalCreatedAt(proposalId int64) (int64, error)

```

GetProposalCreatedAt returns the creation timestamp of a proposal.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| proposalId | int64 | ID of the proposal |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| timestamp | int64 | creation timestamp |
| err | error | error if not found |

---

<a id="getproposalcreatedheight"></a>

### GetProposalCreatedHeight

```go

func GetProposalCreatedHeight(proposalId int64) (int64, error)

```

GetProposalCreatedHeight returns the creation block height of a proposal.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| proposalId | int64 | ID of the proposal |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| height | int64 | creation block height |
| err | error | error if not found |

---

<a id="getproposalids"></a>

### GetProposalIDs

```go

func GetProposalIDs(offset int, count int) []int64

```

GetProposalIDs returns a paginated list of proposal IDs.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| offset | int | starting index |
| count | int | number of IDs to return |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| proposalIds | []int64 | list of proposal IDs |

---

<a id="getproposalstatusbyproposalid"></a>

### GetProposalStatusByProposalId

```go

func GetProposalStatusByProposalId(proposalId int64) (string, error)

```

GetProposalStatusByProposalId returns the current status of a proposal.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| proposalId | int64 | ID of the proposal |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| status | string | proposal status string |
| err | error | error if not found |

---

<a id="getproposerbyproposalid"></a>

### GetProposerByProposalId

```go

func GetProposerByProposalId(proposalId int64) (address, error)

```

GetProposerByProposalId returns the proposer address of a proposal.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| proposalId | int64 | ID of the proposal |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| proposer | address | proposer address |
| err | error | error if not found |

---

<a id="getquorumamountbyproposalid"></a>

### GetQuorumAmountByProposalId

```go

func GetQuorumAmountByProposalId(proposalId int64) (int64, error)

```

GetQuorumAmountByProposalId returns the quorum requirement for a proposal.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| proposalId | int64 | ID of the proposal |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| quorum | int64 | required quorum amount |
| err | error | error if not found |

---

<a id="gettitlebyproposalid"></a>

### GetTitleByProposalId

```go

func GetTitleByProposalId(proposalId int64) (string, error)

```

GetTitleByProposalId returns the title of a proposal.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| proposalId | int64 | ID of the proposal |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| title | string | proposal title |
| err | error | error if not found |

---

<a id="getuserproposalcount"></a>

### GetUserProposalCount

```go

func GetUserProposalCount(user address) int

```

GetUserProposalCount returns the number of proposals created by a user.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| user | address | user address |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| count | int | number of proposals created by user |

---

<a id="getuserproposalids"></a>

### GetUserProposalIDs

```go

func GetUserProposalIDs(user address, offset int, count int) []int64

```

GetUserProposalIDs returns a paginated list of proposal IDs created by a user.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| user | address | user address |
| offset | int | starting index |
| count | int | number of IDs to return |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| proposalIds | []int64 | list of proposal IDs |

---

<a id="getvotestatus"></a>

### GetVoteStatus

```go

func GetVoteStatus(proposalId int64) (quorum int64, maxVotingWeight int64, yesWeight int64, noWeight int64, err error)

```

GetVoteStatus returns the vote status of a proposal.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| proposalId | int64 | ID of the proposal |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| quorum | int64 | minimum vote weight required for proposal to pass |
| maxVotingWeight | int64 | maximum possible voting weight |
| yesWeight | int64 | total weight of "yes" votes |
| noWeight | int64 | total weight of "no" votes |
| err | error | error if not found |

---

<a id="getvoteweight"></a>

### GetVoteWeight

```go

func GetVoteWeight(proposalID int64, addr address) (int64, error)

```

GetVoteWeight returns the voting weight of an address for a proposal.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| proposalID | int64 | ID of the proposal |
| addr | address | voter address |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| weight | int64 | voting weight |
| err | error | error if not found |

---

<a id="getvotedat"></a>

### GetVotedAt

```go

func GetVotedAt(proposalID int64, addr address) (int64, error)

```

GetVotedAt returns the timestamp when an address voted on a proposal.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| proposalID | int64 | ID of the proposal |
| addr | address | voter address |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| timestamp | int64 | time when voted |
| err | error | error if not found |

---

<a id="getvotedheight"></a>

### GetVotedHeight

```go

func GetVotedHeight(proposalID int64, addr address) (int64, error)

```

GetVotedHeight returns the block height when an address voted on a proposal.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| proposalID | int64 | ID of the proposal |
| addr | address | voter address |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| height | int64 | block height when voted |
| err | error | error if not found |

---

<a id="getvotinginfoaddresses"></a>

### GetVotingInfoAddresses

```go

func GetVotingInfoAddresses(proposalID int64, offset int, count int) []address

```

GetVotingInfoAddresses returns a paginated list of voter addresses for a proposal.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| proposalID | int64 | ID of the proposal |
| offset | int | starting index |
| count | int | number of addresses to return |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| addresses | []address | list of voter addresses |

---

<a id="getvotinginfocount"></a>

### GetVotingInfoCount

```go

func GetVotingInfoCount(proposalID int64) int

```

GetVotingInfoCount returns the number of voters for a proposal.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| proposalID | int64 | ID of the proposal |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| count | int | number of voters |

---

<a id="getyeabyproposalid"></a>

### GetYeaByProposalId

```go

func GetYeaByProposalId(proposalId int64) (int64, error)

```

GetYeaByProposalId returns the yes vote weight of a proposal.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| proposalId | int64 | ID of the proposal |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| yea | int64 | total yes vote weight |
| err | error | error if not found |

---

<a id="proposecommunitypoolspend"></a>

### ProposeCommunityPoolSpend

```go

func ProposeCommunityPoolSpend(cur realm, title string, description string, to address, tokenPath string, amount int64) int64

```

ProposeCommunityPoolSpend creates a new community pool spending proposal.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| cur | realm |  |
| title | string | proposal title |
| description | string | detailed proposal description |
| to | address | recipient address |
| tokenPath | string | token path to transfer |
| amount | int64 | amount to transfer |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| int64 | int64 | ID of the created proposal |

---

<a id="proposeparameterchange"></a>

### ProposeParameterChange

```go

func ProposeParameterChange(cur realm, title string, description string, numToExecute int64, executions string) int64

```

ProposeParameterChange creates a new parameter change proposal.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| cur | realm |  |
| title | string | proposal title |
| description | string | detailed proposal description |
| numToExecute | int64 | number of executions to perform |
| executions | string | encoded execution messages |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| int64 | int64 | ID of the created proposal |

---

<a id="proposetext"></a>

### ProposeText

```go

func ProposeText(cur realm, title string, description string) int64

```

ProposeText creates a new text proposal for general governance decisions.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| cur | realm |  |
| title | string | proposal title |
| description | string | detailed proposal description |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| int64 | int64 | ID of the created proposal |

---

<a id="reconfigure"></a>

### Reconfigure

```go

func Reconfigure(cur realm, votingStartDelay int64, votingPeriod int64, votingWeightSmoothingDuration int64, quorum int64, proposalCreationThreshold int64, executionDelay int64, executionWindow int64) int64

```

Reconfigure updates the governance configuration parameters.
Only callable by admin or governance.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| cur | realm |  |
| votingStartDelay | int64 | delay before voting starts (seconds) |
| votingPeriod | int64 | voting duration (seconds) |
| votingWeightSmoothingDuration | int64 | weight smoothing duration (seconds) |
| quorum | int64 | minimum voting weight required (percentage) |
| proposalCreationThreshold | int64 | minimum weight to create proposal |
| executionDelay | int64 | delay before execution (seconds) |
| executionWindow | int64 | execution time window (seconds) |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| int64 | int64 | new configuration version |

---

<a id="registerinitializer"></a>

### RegisterInitializer

```go

func RegisterInitializer(cur realm, initializer func(...))

```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| cur | realm |  |
| initializer | func(...) |  |

---

<a id="upgradeimpl"></a>

### UpgradeImpl

```go

func UpgradeImpl(cur realm, targetPackagePath string)

```

UpgradeImpl switches the active governance implementation to a different version.
This function allows seamless upgrades from one version to another without
data migration or downtime.

Security: Only admin or governance can perform upgrades.
The new implementation must have been previously registered via RegisterInitializer.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| cur | realm |  |
| targetPackagePath | string |  |

---

<a id="vote"></a>

### Vote

```go

func Vote(cur realm, proposalId int64, yes bool) string

```

Vote casts a vote on a proposal.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| cur | realm |  |
| proposalId | int64 | ID of the proposal to vote on |
| yes | bool | true for yes vote, false for no vote |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| string | string | voting result information |


## Types

<a id="communitypoolspendinfo"></a>

### CommunityPoolSpendInfo

```go

type CommunityPoolSpendInfo struct

```

CommunityPoolSpendInfo contains information for community pool spending proposals.

#### Methods

<a id="communitypoolspendinfo.amount"></a>
##### Amount

```go
func (i *CommunityPoolSpendInfo) Amount() int64
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int64 |  |

<a id="communitypoolspendinfo.clone"></a>
##### Clone

```go
func (i *CommunityPoolSpendInfo) Clone() *CommunityPoolSpendInfo
```

Clone creates a deep copy of the CommunityPoolSpendInfo.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | *CommunityPoolSpendInfo |  |

<a id="communitypoolspendinfo.to"></a>
##### To

```go
func (i *CommunityPoolSpendInfo) To() address
```

 Getter methods

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | address |  |

<a id="communitypoolspendinfo.tokenpath"></a>
##### TokenPath

```go
func (i *CommunityPoolSpendInfo) TokenPath() string
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | string |  |


#### Constructors

- `func GetProposalCommunityPoolSpendInfo(proposalID int64) (*CommunityPoolSpendInfo, error)`
- `func NewCommunityPoolSpendInfo(to address, tokenPath string, amount int64) *CommunityPoolSpendInfo`

---

<a id="config"></a>

### Config

```go

type Config struct

```

Config represents the configuration of the governor contract
All parameters in this struct can be modified through governance.

#### Fields

- `VotingStartDelay int64`
- `VotingPeriod int64`
- `VotingWeightSmoothingDuration int64`
- `Quorum int64`
- `ProposalCreationThreshold int64`
- `ExecutionDelay int64`
- `ExecutionWindow int64`

#### Methods

<a id="config.isvalid"></a>
##### IsValid

```go
func (c Config) IsValid(currentTime int64) error
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| currentTime | int64 |  |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | error |  |


#### Constructors

- `func GetConfig(configVersion int64) (Config, error)`
- `func GetLatestConfig() Config`

---

<a id="counter"></a>

### Counter

```go

type Counter struct

```

Counter manages unique incrementing IDs.

#### Methods

<a id="counter.get"></a>
##### Get

```go
func (c *Counter) Get() int64
```

Get returns the current ID without incrementing.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int64 |  |

<a id="counter.next"></a>
##### Next

```go
func (c *Counter) Next() int64
```

next increments and returns the next ID.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int64 |  |

<a id="counter.set"></a>
##### Set

```go
func (c *Counter) Set(id int64)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| id | int64 |  |


#### Constructors

- `func NewCounter() *Counter`

---

<a id="executioninfo"></a>

### ExecutionInfo

```go

type ExecutionInfo struct

```

ExecutionInfo contains information for parameter change execution.
Messages are encoded strings that specify function calls and parameters.

#### Methods

<a id="executioninfo.clone"></a>
##### Clone

```go
func (i *ExecutionInfo) Clone() *ExecutionInfo
```

Clone creates a deep copy of the ExecutionInfo.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | *ExecutionInfo |  |

<a id="executioninfo.msgs"></a>
##### Msgs

```go
func (i *ExecutionInfo) Msgs() []string
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | []string |  |

<a id="executioninfo.num"></a>
##### Num

```go
func (i *ExecutionInfo) Num() int64
```

 Getter methods

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int64 |  |


#### Constructors

- `func GetProposalExecutionInfo(proposalID int64) (*ExecutionInfo, error)`
- `func NewExecutionInfo(num int64, msgs []string) *ExecutionInfo`

---

<a id="govstakeraccessor"></a>

### GovStakerAccessor

```go

type GovStakerAccessor interface

```

GovStakerAccessor provides an interface for accessing gov staker functionality.
This abstraction allows for easier testing by enabling mock implementations.

---

<a id="igovernance"></a>

### IGovernance

```go

type IGovernance interface

```

---

<a id="igovernancegetter"></a>

### IGovernanceGetter

```go

type IGovernanceGetter interface

```

IGovernanceGetter provides read-only access to governance data.

---

<a id="igovernancemanager"></a>

### IGovernanceManager

```go

type IGovernanceManager interface

```

---

<a id="igovernancestore"></a>

### IGovernanceStore

```go

type IGovernanceStore interface

```

#### Constructors

- `func NewGovernanceStore(kvStore store.KVStore) IGovernanceStore`

---

<a id="parameterchangeinfo"></a>

### ParameterChangeInfo

```go

type ParameterChangeInfo struct

```

ParameterChangeInfo represents a single parameter change to be executed.

#### Methods

<a id="parameterchangeinfo.function"></a>
##### Function

```go
func (i *ParameterChangeInfo) Function() string
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | string |  |

<a id="parameterchangeinfo.params"></a>
##### Params

```go
func (i *ParameterChangeInfo) Params() []string
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | []string |  |

<a id="parameterchangeinfo.pkgpath"></a>
##### PkgPath

```go
func (i *ParameterChangeInfo) PkgPath() string
```

 Getter methods

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | string |  |


#### Constructors

- `func NewParameterChangeInfo(pkgPath string, function string, params []string) ParameterChangeInfo`

---

<a id="proposal"></a>

### Proposal

```go

type Proposal struct

```

Proposal represents a governance proposal with all its associated data and state.
This is the core structure that tracks proposal lifecycle from creation to execution.

#### Methods

<a id="proposal.clone"></a>
##### Clone

```go
func (p *Proposal) Clone() *Proposal
```

Clone creates a deep copy of the Proposal.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | *Proposal |  |

<a id="proposal.configversion"></a>
##### ConfigVersion

```go
func (p *Proposal) ConfigVersion() int64
```

ConfigVersion returns the governance configuration version used for this proposal.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int64 |  |

<a id="proposal.createdat"></a>
##### CreatedAt

```go
func (p *Proposal) CreatedAt() int64
```

CreatedAt returns the creation timestamp of the proposal.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int64 |  |

<a id="proposal.data"></a>
##### Data

```go
func (p *Proposal) Data() *ProposalData
```

Data returns the proposal data.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | *ProposalData |  |

<a id="proposal.description"></a>
##### Description

```go
func (p *Proposal) Description() string
```

Description returns the proposal description.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | string |  |

<a id="proposal.id"></a>
##### ID

```go
func (p *Proposal) ID() int64
```

ID returns the unique identifier of the proposal.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int64 |  |

<a id="proposal.iscommunitypoolspendtype"></a>
##### IsCommunityPoolSpendType

```go
func (p *Proposal) IsCommunityPoolSpendType() bool
```

IsCommunityPoolSpendType checks if this is a community pool spend proposal.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | bool |  |

<a id="proposal.isparameterchangetype"></a>
##### IsParameterChangeType

```go
func (p *Proposal) IsParameterChangeType() bool
```

IsParameterChangeType checks if this is a parameter change proposal.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | bool |  |

<a id="proposal.isproposer"></a>
##### IsProposer

```go
func (p *Proposal) IsProposer(addr address) bool
```

IsProposer checks if the given address is the proposer of this proposal.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| addr | address |  |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | bool |  |

<a id="proposal.istexttype"></a>
##### IsTextType

```go
func (p *Proposal) IsTextType() bool
```

IsTextType checks if this is a text proposal.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | bool |  |

<a id="proposal.metadata"></a>
##### Metadata

```go
func (p *Proposal) Metadata() *ProposalMetadata
```

Metadata returns the proposal metadata.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | *ProposalMetadata |  |

<a id="proposal.proposer"></a>
##### Proposer

```go
func (p *Proposal) Proposer() address
```

Proposer returns the address of the proposal creator.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | address |  |

<a id="proposal.snapshottime"></a>
##### SnapshotTime

```go
func (p *Proposal) SnapshotTime() int64
```

SnapshotTime returns the snapshot time for voting weight lookup.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int64 |  |

<a id="proposal.status"></a>
##### Status

```go
func (p *Proposal) Status() *ProposalStatus
```

Status returns the proposal status.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | *ProposalStatus |  |

<a id="proposal.title"></a>
##### Title

```go
func (p *Proposal) Title() string
```

Title returns the proposal title.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | string |  |

<a id="proposal.type"></a>
##### Type

```go
func (p *Proposal) Type() ProposalType
```

Type returns the type of this proposal.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | ProposalType |  |

<a id="proposal.votingmaxweight"></a>
##### VotingMaxWeight

```go
func (p *Proposal) VotingMaxWeight() int64
```

VotingMaxWeight returns maximum possible voting weight for this proposal.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int64 |  |

<a id="proposal.votingnoweight"></a>
##### VotingNoWeight

```go
func (p *Proposal) VotingNoWeight() int64
```

VotingNoWeight returns the total weight of "no" votes.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int64 |  |

<a id="proposal.votingquorumamount"></a>
##### VotingQuorumAmount

```go
func (p *Proposal) VotingQuorumAmount() int64
```

VotingQuorumAmount returns minimum vote weight required for proposal to pass.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int64 |  |

<a id="proposal.votingyesweight"></a>
##### VotingYesWeight

```go
func (p *Proposal) VotingYesWeight() int64
```

VotingYesWeight returns the total weight of "yes" votes.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int64 |  |


#### Constructors

- `func GetProposal(proposalID int64) (*Proposal, error)`
- `func NewProposal(proposalID int64, status *ProposalStatus, metadata *ProposalMetadata, data *ProposalData, proposerAddress address, configVersion int64, snapshotTime int64, createdAt int64, createdHeight int64) *Proposal`

---

<a id="proposalactionstatus"></a>

### ProposalActionStatus

```go

type ProposalActionStatus struct

```

ProposalActionStatus tracks the execution and cancellation status of a proposal.
This structure manages the action-related state including who performed actions and when.

#### Methods

<a id="proposalactionstatus.canceled"></a>
##### Canceled

```go
func (p *ProposalActionStatus) Canceled() bool
```

 Getter methods

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | bool |  |

<a id="proposalactionstatus.canceledat"></a>
##### CanceledAt

```go
func (p *ProposalActionStatus) CanceledAt() int64
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int64 |  |

<a id="proposalactionstatus.canceledby"></a>
##### CanceledBy

```go
func (p *ProposalActionStatus) CanceledBy() address
```

CanceledBy returns the address that canceled the proposal.
Only meaningful if IsCanceled() returns true.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| address | address | address of the canceller |

<a id="proposalactionstatus.canceledheight"></a>
##### CanceledHeight

```go
func (p *ProposalActionStatus) CanceledHeight() int64
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int64 |  |

<a id="proposalactionstatus.clone"></a>
##### Clone

```go
func (p *ProposalActionStatus) Clone() *ProposalActionStatus
```

Clone creates a deep copy of the ProposalActionStatus.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | *ProposalActionStatus |  |

<a id="proposalactionstatus.executable"></a>
##### Executable

```go
func (p *ProposalActionStatus) Executable() bool
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | bool |  |

<a id="proposalactionstatus.executed"></a>
##### Executed

```go
func (p *ProposalActionStatus) Executed() bool
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | bool |  |

<a id="proposalactionstatus.executedat"></a>
##### ExecutedAt

```go
func (p *ProposalActionStatus) ExecutedAt() int64
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int64 |  |

<a id="proposalactionstatus.executedby"></a>
##### ExecutedBy

```go
func (p *ProposalActionStatus) ExecutedBy() address
```

ExecutedBy returns the address that executed the proposal.
Only meaningful if IsExecuted() returns true.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| address | address | address of the executor |

<a id="proposalactionstatus.executedheight"></a>
##### ExecutedHeight

```go
func (p *ProposalActionStatus) ExecutedHeight() int64
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int64 |  |

<a id="proposalactionstatus.isexecutable"></a>
##### IsExecutable

```go
func (p *ProposalActionStatus) IsExecutable() bool
```

IsExecutable returns whether this proposal type can be executed.
Text proposals return false, while other types return true.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| bool | bool | true if proposal type supports execution |

<a id="proposalactionstatus.isexecuted"></a>
##### IsExecuted

```go
func (p *ProposalActionStatus) IsExecuted() bool
```

IsExecuted returns whether the proposal has been executed.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| bool | bool | true if proposal has been executed |

<a id="proposalactionstatus.setcanceled"></a>
##### SetCanceled

```go
func (p *ProposalActionStatus) SetCanceled(canceled bool)
```

 Setter methods

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| canceled | bool |  |

<a id="proposalactionstatus.setcanceledat"></a>
##### SetCanceledAt

```go
func (p *ProposalActionStatus) SetCanceledAt(canceledAt int64)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| canceledAt | int64 |  |

<a id="proposalactionstatus.setcanceledby"></a>
##### SetCanceledBy

```go
func (p *ProposalActionStatus) SetCanceledBy(canceledBy address)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| canceledBy | address |  |

<a id="proposalactionstatus.setcanceledheight"></a>
##### SetCanceledHeight

```go
func (p *ProposalActionStatus) SetCanceledHeight(canceledHeight int64)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| canceledHeight | int64 |  |

<a id="proposalactionstatus.setexecutable"></a>
##### SetExecutable

```go
func (p *ProposalActionStatus) SetExecutable(executable bool)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| executable | bool |  |

<a id="proposalactionstatus.setexecuted"></a>
##### SetExecuted

```go
func (p *ProposalActionStatus) SetExecuted(executed bool)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| executed | bool |  |

<a id="proposalactionstatus.setexecutedat"></a>
##### SetExecutedAt

```go
func (p *ProposalActionStatus) SetExecutedAt(executedAt int64)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| executedAt | int64 |  |

<a id="proposalactionstatus.setexecutedby"></a>
##### SetExecutedBy

```go
func (p *ProposalActionStatus) SetExecutedBy(executedBy address)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| executedBy | address |  |

<a id="proposalactionstatus.setexecutedheight"></a>
##### SetExecutedHeight

```go
func (p *ProposalActionStatus) SetExecutedHeight(executedHeight int64)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| executedHeight | int64 |  |


#### Constructors

- `func NewProposalActionStatus(executable bool) *ProposalActionStatus`

---

<a id="proposaldata"></a>

### ProposalData

```go

type ProposalData struct

```

ProposalData contains the type-specific data for a proposal.
This structure holds different data depending on the proposal type.

#### Methods

<a id="proposaldata.clone"></a>
##### Clone

```go
func (p *ProposalData) Clone() *ProposalData
```

Clone creates a deep copy of the ProposalData.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | *ProposalData |  |

<a id="proposaldata.communitypoolspend"></a>
##### CommunityPoolSpend

```go
func (p *ProposalData) CommunityPoolSpend() *CommunityPoolSpendInfo
```

CommunityPoolSpend returns the community pool spending information.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| *CommunityPoolSpendInfo | *CommunityPoolSpendInfo | community pool spending details |

<a id="proposaldata.execution"></a>
##### Execution

```go
func (p *ProposalData) Execution() *ExecutionInfo
```

Execution returns the execution information for parameter changes.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| *ExecutionInfo | *ExecutionInfo | parameter change execution details |

<a id="proposaldata.proposaltype"></a>
##### ProposalType

```go
func (p *ProposalData) ProposalType() ProposalType
```

ProposalType returns the type of this proposal.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| ProposalType | ProposalType | the proposal type |


#### Constructors

- `func NewProposalData(proposalType ProposalType, communityPoolSpend *CommunityPoolSpendInfo, execution *ExecutionInfo) *ProposalData`

---

<a id="proposalmetadata"></a>

### ProposalMetadata

```go

type ProposalMetadata struct

```

ProposalMetadata contains descriptive information about a proposal.
This includes the title and description that are displayed to voters.

#### Methods

<a id="proposalmetadata.clone"></a>
##### Clone

```go
func (p *ProposalMetadata) Clone() *ProposalMetadata
```

Clone creates a deep copy of the ProposalMetadata.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | *ProposalMetadata |  |

<a id="proposalmetadata.description"></a>
##### Description

```go
func (p *ProposalMetadata) Description() string
```

Description returns the proposal description.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| string | string | proposal description |

<a id="proposalmetadata.title"></a>
##### Title

```go
func (p *ProposalMetadata) Title() string
```

Title returns the proposal title.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| string | string | proposal title |


#### Constructors

- `func NewProposalMetadata(title string, description string) *ProposalMetadata`

---

<a id="proposalschedulestatus"></a>

### ProposalScheduleStatus

```go

type ProposalScheduleStatus struct

```

ProposalScheduleStatus represents the pre-calculated time schedule for a proposal.
This structure defines all the important timestamps in a proposal's lifecycle,
from creation through voting to execution and expiration.

#### Methods

<a id="proposalschedulestatus.activetime"></a>
##### ActiveTime

```go
func (p *ProposalScheduleStatus) ActiveTime() int64
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int64 |  |

<a id="proposalschedulestatus.clone"></a>
##### Clone

```go
func (p *ProposalScheduleStatus) Clone() *ProposalScheduleStatus
```

Clone creates a deep copy of the ProposalScheduleStatus.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | *ProposalScheduleStatus |  |

<a id="proposalschedulestatus.createtime"></a>
##### CreateTime

```go
func (p *ProposalScheduleStatus) CreateTime() int64
```

 Getter methods

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int64 |  |

<a id="proposalschedulestatus.executabletime"></a>
##### ExecutableTime

```go
func (p *ProposalScheduleStatus) ExecutableTime() int64
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int64 |  |

<a id="proposalschedulestatus.expiredtime"></a>
##### ExpiredTime

```go
func (p *ProposalScheduleStatus) ExpiredTime() int64
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int64 |  |

<a id="proposalschedulestatus.setactivetime"></a>
##### SetActiveTime

```go
func (p *ProposalScheduleStatus) SetActiveTime(activeTime int64)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| activeTime | int64 |  |

<a id="proposalschedulestatus.setcreatetime"></a>
##### SetCreateTime

```go
func (p *ProposalScheduleStatus) SetCreateTime(createTime int64)
```

 Setter methods

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| createTime | int64 |  |

<a id="proposalschedulestatus.setexecutabletime"></a>
##### SetExecutableTime

```go
func (p *ProposalScheduleStatus) SetExecutableTime(executableTime int64)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| executableTime | int64 |  |

<a id="proposalschedulestatus.setexpiredtime"></a>
##### SetExpiredTime

```go
func (p *ProposalScheduleStatus) SetExpiredTime(expiredTime int64)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| expiredTime | int64 |  |

<a id="proposalschedulestatus.setvotingendtime"></a>
##### SetVotingEndTime

```go
func (p *ProposalScheduleStatus) SetVotingEndTime(votingEndTime int64)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| votingEndTime | int64 |  |

<a id="proposalschedulestatus.votingendtime"></a>
##### VotingEndTime

```go
func (p *ProposalScheduleStatus) VotingEndTime() int64
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int64 |  |


#### Constructors

- `func NewProposalScheduleStatus(createTime int64, activeTime int64, votingEndTime int64, executableTime int64, expiredTime int64) *ProposalScheduleStatus`

---

<a id="proposalstatus"></a>

### ProposalStatus

```go

type ProposalStatus struct

```

ProposalStatus manages the complete status of a proposal including scheduling, voting, and actions.
This is the central status tracking structure that coordinates different aspects of proposal state.

#### Methods

<a id="proposalstatus.actionstatus"></a>
##### ActionStatus

```go
func (s *ProposalStatus) ActionStatus() *ProposalActionStatus
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | *ProposalActionStatus |  |

<a id="proposalstatus.clone"></a>
##### Clone

```go
func (s *ProposalStatus) Clone() *ProposalStatus
```

Clone creates a deep copy of the ProposalStatus.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | *ProposalStatus |  |

<a id="proposalstatus.noweight"></a>
##### NoWeight

```go
func (s *ProposalStatus) NoWeight() int64
```

NoWeight returns the total weight of "no" votes.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| int64 | int64 | total "no" vote weight |

<a id="proposalstatus.schedule"></a>
##### Schedule

```go
func (s *ProposalStatus) Schedule() *ProposalScheduleStatus
```

 Getter methods

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | *ProposalScheduleStatus |  |

<a id="proposalstatus.votestatus"></a>
##### VoteStatus

```go
func (s *ProposalStatus) VoteStatus() *ProposalVoteStatus
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | *ProposalVoteStatus |  |

<a id="proposalstatus.yesweight"></a>
##### YesWeight

```go
func (s *ProposalStatus) YesWeight() int64
```

YesWeight returns the total weight of "yes" votes.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| int64 | int64 | total "yes" vote weight |


#### Constructors

- `func NewProposalStatusBy(schedule *ProposalScheduleStatus, actionStatus *ProposalActionStatus, voteStatus *ProposalVoteStatus) *ProposalStatus`

---

<a id="proposalstatustype"></a>

### ProposalStatusType

```go

type ProposalStatusType int

```

ProposalStatusType represents the current status of a proposal in its lifecycle.
These statuses determine what actions are available for a proposal.

#### Methods

<a id="proposalstatustype.string"></a>
##### String

```go
func (s ProposalStatusType) String() string
```

String returns the string representation of ProposalStatusType for display purposes.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| string | string | human-readable status name |


---

<a id="proposaltype"></a>

### ProposalType

```go

type ProposalType string

```

ProposalType defines the different types of proposals supported by the governance system.
Each type has different execution behavior and validation requirements.

#### Methods

<a id="proposaltype.isexecutable"></a>
##### IsExecutable

```go
func (p ProposalType) IsExecutable() bool
```

IsExecutable determines whether this proposal type can be executed.
Text proposals are informational only and cannot be executed.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | bool |  |

<a id="proposaltype.string"></a>
##### String

```go
func (p ProposalType) String() string
```

String returns the human-readable string representation of the proposal type.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | string |  |


#### Constructors

- `func GetProposalTypeByProposalId(proposalId int64) (ProposalType, error)`

---

<a id="proposalvotestatus"></a>

### ProposalVoteStatus

```go

type ProposalVoteStatus struct

```

ProposalVoteStatus tracks the voting tallies and requirements for a proposal.
This structure manages vote counting, quorum calculation, and voting outcome determination.

#### Methods

<a id="proposalvotestatus.clone"></a>
##### Clone

```go
func (p *ProposalVoteStatus) Clone() *ProposalVoteStatus
```

Clone creates a deep copy of the ProposalVoteStatus.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | *ProposalVoteStatus |  |

<a id="proposalvotestatus.maxvotingweight"></a>
##### MaxVotingWeight

```go
func (p *ProposalVoteStatus) MaxVotingWeight() int64
```

 Getter methods

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int64 |  |

<a id="proposalvotestatus.noweight"></a>
##### NoWeight

```go
func (p *ProposalVoteStatus) NoWeight() int64
```

NoWeight returns the total weight of "no" votes.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| int64 | int64 | total "no" vote weight |

<a id="proposalvotestatus.quorumamount"></a>
##### QuorumAmount

```go
func (p *ProposalVoteStatus) QuorumAmount() int64
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int64 |  |

<a id="proposalvotestatus.setmaxvotingweight"></a>
##### SetMaxVotingWeight

```go
func (p *ProposalVoteStatus) SetMaxVotingWeight(maxVotingWeight int64)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| maxVotingWeight | int64 |  |

<a id="proposalvotestatus.setnoweight"></a>
##### SetNoWeight

```go
func (p *ProposalVoteStatus) SetNoWeight(no int64)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| no | int64 |  |

<a id="proposalvotestatus.setquorumamount"></a>
##### SetQuorumAmount

```go
func (p *ProposalVoteStatus) SetQuorumAmount(quorumAmount int64)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| quorumAmount | int64 |  |

<a id="proposalvotestatus.setyesweight"></a>
##### SetYesWeight

```go
func (p *ProposalVoteStatus) SetYesWeight(yes int64)
```

 Setter methods

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| yes | int64 |  |

<a id="proposalvotestatus.yesweight"></a>
##### YesWeight

```go
func (p *ProposalVoteStatus) YesWeight() int64
```

YesWeight returns the total weight of "yes" votes.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| int64 | int64 | total "yes" vote weight |


#### Constructors

- `func NewProposalVoteStatus(maxVotingWeight int64, quorumAmount int64) *ProposalVoteStatus`

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

<a id="votinginfo"></a>

### VotingInfo

```go

type VotingInfo struct

```

VotingInfo tracks voting-related information for a specific user on a specific proposal.
This structure maintains the user's voting eligibility, voting history, and voting power.

#### Methods

<a id="votinginfo.availablevoteweight"></a>
##### AvailableVoteWeight

```go
func (v *VotingInfo) AvailableVoteWeight() int64
```

AvailableVoteWeight returns the total voting weight available to this user.
This weight is determined at proposal creation time based on delegation snapshots.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| int64 | int64 | available voting weight |

<a id="votinginfo.clone"></a>
##### Clone

```go
func (v *VotingInfo) Clone() *VotingInfo
```

Clone creates a deep copy of the VotingInfo.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | *VotingInfo |  |

<a id="votinginfo.isvoted"></a>
##### IsVoted

```go
func (v *VotingInfo) IsVoted() bool
```

IsVoted checks if the user has already cast their vote.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| bool | bool | true if user has voted on this proposal |

<a id="votinginfo.setavailablevoteweight"></a>
##### SetAvailableVoteWeight

```go
func (v *VotingInfo) SetAvailableVoteWeight(availableVoteWeight int64)
```

 Setter methods

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| availableVoteWeight | int64 |  |

<a id="votinginfo.setvoted"></a>
##### SetVoted

```go
func (v *VotingInfo) SetVoted(voted bool)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| voted | bool |  |

<a id="votinginfo.setvotedat"></a>
##### SetVotedAt

```go
func (v *VotingInfo) SetVotedAt(votedAt int64)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| votedAt | int64 |  |

<a id="votinginfo.setvotedheight"></a>
##### SetVotedHeight

```go
func (v *VotingInfo) SetVotedHeight(votedHeight int64)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| votedHeight | int64 |  |

<a id="votinginfo.setvotedweight"></a>
##### SetVotedWeight

```go
func (v *VotingInfo) SetVotedWeight(votedWeight int64)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| votedWeight | int64 |  |

<a id="votinginfo.setvotedyes"></a>
##### SetVotedYes

```go
func (v *VotingInfo) SetVotedYes(votedYes bool)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| votedYes | bool |  |

<a id="votinginfo.votedat"></a>
##### VotedAt

```go
func (v *VotingInfo) VotedAt() int64
```

VotedAt returns the timestamp when the vote was cast.
Returns 0 if the user hasn't voted yet.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| int64 | int64 | timestamp when vote was cast |

<a id="votinginfo.votedheight"></a>
##### VotedHeight

```go
func (v *VotingInfo) VotedHeight() int64
```

VotedHeight returns the block height when the vote was cast.
Returns 0 if the user hasn't voted yet.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| int64 | int64 | block height when vote was cast |

<a id="votinginfo.votedno"></a>
##### VotedNo

```go
func (v *VotingInfo) VotedNo() bool
```

VotedNo checks if the user voted "no" on the proposal.
Only meaningful if IsVoted() returns true.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| bool | bool | true if user voted "no" |

<a id="votinginfo.votedweight"></a>
##### VotedWeight

```go
func (v *VotingInfo) VotedWeight() int64
```

VotedWeight returns the weight actually used when voting.
Returns 0 if the user hasn't voted yet.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| int64 | int64 | weight used for voting, or 0 if not voted |

<a id="votinginfo.votedyes"></a>
##### VotedYes

```go
func (v *VotingInfo) VotedYes() bool
```

VotedYes checks if the user voted "yes" on the proposal.
Only meaningful if IsVoted() returns true.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| bool | bool | true if user voted "yes" |

<a id="votinginfo.votingtype"></a>
##### VotingType

```go
func (v *VotingInfo) VotingType() string
```

VotingType returns a human-readable string representation of the vote choice.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| string | string | "yes" or "no" based on voting choice |


#### Constructors

- `func GetVotingInfo(proposalID int64, addr address) (*VotingInfo, error)`
- `func NewVotingInfo(availableVoteWeight int64) *VotingInfo`
