# launchpad

`import "gno.land/r/gnoswap/launchpad"`



## Index

- [CollectDepositGns](#collectdepositgns)
- [CollectProtocolFee](#collectprotocolfee)
- [CollectRewardByDepositId](#collectrewardbydepositid)
- [CreateProject](#createproject)
- [DepositGns](#depositgns)
- [GetCurrentDepositId](#getcurrentdepositid)
- [GetDepositAmount](#getdepositamount)
- [GetDepositCount](#getdepositcount)
- [GetDepositCreatedAt](#getdepositcreatedat)
- [GetDepositCreatedHeight](#getdepositcreatedheight)
- [GetDepositEndTime](#getdepositendtime)
- [GetDepositProjectID](#getdepositprojectid)
- [GetDepositProjectTierID](#getdepositprojecttierid)
- [GetDepositTier](#getdeposittier)
- [GetDepositWithdrawnHeight](#getdepositwithdrawnheight)
- [GetDepositWithdrawnTime](#getdepositwithdrawntime)
- [GetImplementationPackagePath](#getimplementationpackagepath)
- [GetProjectActiveStatus](#getprojectactivestatus)
- [GetProjectCount](#getprojectcount)
- [GetProjectCreatedAt](#getprojectcreatedat)
- [GetProjectCreatedHeight](#getprojectcreatedheight)
- [GetProjectDepositAmount](#getprojectdepositamount)
- [GetProjectIDs](#getprojectids)
- [GetProjectName](#getprojectname)
- [GetProjectRecipient](#getprojectrecipient)
- [GetProjectTierDepositCount](#getprojecttierdepositcount)
- [GetProjectTierDepositIDs](#getprojecttierdepositids)
- [GetProjectTierDistributeAmountPerSecondX128](#getprojecttierdistributeamountpersecondx128)
- [GetProjectTierEndTime](#getprojecttierendtime)
- [GetProjectTierRewardAccumulatedDistributeAmount](#getprojecttierrewardaccumulateddistributeamount)
- [GetProjectTierRewardAccumulatedHeight](#getprojecttierrewardaccumulatedheight)
- [GetProjectTierRewardAccumulatedRewardPerDepositX128](#getprojecttierrewardaccumulatedrewardperdepositx128)
- [GetProjectTierRewardAccumulatedTime](#getprojecttierrewardaccumulatedtime)
- [GetProjectTierRewardClaimableDuration](#getprojecttierrewardclaimableduration)
- [GetProjectTierRewardDistributeAmountPerSecondX128](#getprojecttierrewarddistributeamountpersecondx128)
- [GetProjectTierRewardDistributeEndTime](#getprojecttierrewarddistributeendtime)
- [GetProjectTierRewardDistributeStartTime](#getprojecttierrewarddistributestarttime)
- [GetProjectTierRewardManagerCount](#getprojecttierrewardmanagercount)
- [GetProjectTierRewardTotalClaimedAmount](#getprojecttierrewardtotalclaimedamount)
- [GetProjectTierRewardTotalDistributeAmount](#getprojecttierrewardtotaldistributeamount)
- [GetProjectTierStartTime](#getprojecttierstarttime)
- [GetProjectTierTotalCollectedAmount](#getprojecttiertotalcollectedamount)
- [GetProjectTierTotalDepositAmount](#getprojecttiertotaldepositamount)
- [GetProjectTierTotalDepositCount](#getprojecttiertotaldepositcount)
- [GetProjectTierTotalDistributeAmount](#getprojecttiertotaldistributeamount)
- [GetProjectTierTotalWithdrawAmount](#getprojecttiertotalwithdrawamount)
- [GetProjectTierTotalWithdrawCount](#getprojecttiertotalwithdrawcount)
- [GetProjectTiersRatios](#getprojecttiersratios)
- [GetProjectTokenPath](#getprojecttokenpath)
- [MakeProjectID](#makeprojectid)
- [MakeProjectTierID](#makeprojecttierid)
- [RegisterInitializer](#registerinitializer)
- [TransferLeftFromProjectByAdmin](#transferleftfromprojectbyadmin)
- [UpgradeImpl](#upgradeimpl)
- [Counter](#counter)
- [Deposit](#deposit)
- [ILaunchpad](#ilaunchpad)
- [ILaunchpadDeposit](#ilaunchpaddeposit)
- [ILaunchpadGetter](#ilaunchpadgetter)
- [ILaunchpadProject](#ilaunchpadproject)
- [ILaunchpadStore](#ilaunchpadstore)
- [Project](#project)
- [ProjectCondition](#projectcondition)
- [ProjectTier](#projecttier)
- [RewardManager](#rewardmanager)
- [RewardState](#rewardstate)
- [StoreKey](#storekey)


## Functions

<a id="collectdepositgns"></a>

### CollectDepositGns

```go

func CollectDepositGns(cur realm, depositID string) (int64, error)

```

CollectDepositGns collects rewards from a deposit.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| cur | realm |  |
| depositID | string | ID of the deposit |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| amount | int64 | collected reward amount |
| err | error | error if collection fails |

---

<a id="collectprotocolfee"></a>

### CollectProtocolFee

```go

func CollectProtocolFee(cur realm)

```

CollectProtocolFee collects accumulated protocol fees from launchpad operations.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| cur | realm |  |

---

<a id="collectrewardbydepositid"></a>

### CollectRewardByDepositId

```go

func CollectRewardByDepositId(cur realm, depositID string) int64

```

CollectRewardByDepositId collects rewards from a deposit.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| cur | realm |  |
| depositID | string | ID of the deposit |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| amount | int64 | collected reward amount |

---

<a id="createproject"></a>

### CreateProject

```go

func CreateProject(cur realm, name string, tokenPath string, recipient address, depositAmount int64, conditionTokens string, conditionAmounts string, tier30Ratio int64, tier90Ratio int64, tier180Ratio int64, startTime int64) string

```

CreateProject creates a new launchpad project with tiered allocations.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| cur | realm |  |
| name | string | project name |
| tokenPath | string | path of the project token |
| recipient | address | recipient address for collected funds |
| depositAmount | int64 | total deposit amount for the project |
| conditionTokens | string | comma-separated token paths for conditions |
| conditionAmounts | string | comma-separated amounts for conditions |
| tier30Ratio | int64 | allocation ratio for 30-day tier |
| tier90Ratio | int64 | allocation ratio for 90-day tier |
| tier180Ratio | int64 | allocation ratio for 180-day tier |
| startTime | int64 | project start timestamp |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| projectId | string | created project ID |

---

<a id="depositgns"></a>

### DepositGns

```go

func DepositGns(cur realm, targetProjectTierID string, depositAmount int64, referrer string) string

```

DepositGns deposits GNS tokens to a launchpad project tier.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| cur | realm |  |
| targetProjectTierID | string | ID of the target project tier |
| depositAmount | int64 | amount of GNS to deposit |
| referrer | string | referrer address for reward tracking |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| depositId | string | created deposit ID |

---

<a id="getcurrentdepositid"></a>

### GetCurrentDepositId

```go

func GetCurrentDepositId() int64

```

GetCurrentDepositId returns the current deposit counter value.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| depositId | int64 | current deposit counter |

---

<a id="getdepositamount"></a>

### GetDepositAmount

```go

func GetDepositAmount(depositId string) (int64, error)

```

GetDepositAmount returns the deposit amount of a deposit by its ID.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| depositId | string | ID of the deposit |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| amount | int64 | deposit amount |
| err | error | error if not found |

---

<a id="getdepositcount"></a>

### GetDepositCount

```go

func GetDepositCount() int

```

GetDepositCount returns the total number of deposits.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| count | int | total number of deposits |

---

<a id="getdepositcreatedat"></a>

### GetDepositCreatedAt

```go

func GetDepositCreatedAt(depositId string) (int64, error)

```

GetDepositCreatedAt returns the created time of a deposit by its ID.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| depositId | string | ID of the deposit |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| timestamp | int64 | creation timestamp |
| err | error | error if not found |

---

<a id="getdepositcreatedheight"></a>

### GetDepositCreatedHeight

```go

func GetDepositCreatedHeight(depositId string) (int64, error)

```

GetDepositCreatedHeight returns the created height of a deposit by its ID.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| depositId | string | ID of the deposit |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| height | int64 | block height at creation |
| err | error | error if not found |

---

<a id="getdepositendtime"></a>

### GetDepositEndTime

```go

func GetDepositEndTime(depositId string) (int64, error)

```

GetDepositEndTime returns the end time of a deposit by its ID.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| depositId | string | ID of the deposit |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| timestamp | int64 | end timestamp |
| err | error | error if not found |

---

<a id="getdepositprojectid"></a>

### GetDepositProjectID

```go

func GetDepositProjectID(depositId string) (string, error)

```

GetDepositProjectID returns the project ID of a deposit by its ID.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| depositId | string | ID of the deposit |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| projectId | string | project ID |
| err | error | error if not found |

---

<a id="getdepositprojecttierid"></a>

### GetDepositProjectTierID

```go

func GetDepositProjectTierID(depositId string) (string, error)

```

GetDepositProjectTierID returns the project tier ID of a deposit by its ID.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| depositId | string | ID of the deposit |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| projectTierId | string | project tier ID |
| err | error | error if not found |

---

<a id="getdeposittier"></a>

### GetDepositTier

```go

func GetDepositTier(depositId string) (int64, error)

```

GetDepositTier returns the tier of a deposit by its ID.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| depositId | string | ID of the deposit |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| tier | int64 | tier level |
| err | error | error if not found |

---

<a id="getdepositwithdrawnheight"></a>

### GetDepositWithdrawnHeight

```go

func GetDepositWithdrawnHeight(depositId string) (int64, error)

```

GetDepositWithdrawnHeight returns the withdrawn height of a deposit by its ID.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| depositId | string | ID of the deposit |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| height | int64 | block height at withdrawal |
| err | error | error if not found |

---

<a id="getdepositwithdrawntime"></a>

### GetDepositWithdrawnTime

```go

func GetDepositWithdrawnTime(depositId string) (int64, error)

```

GetDepositWithdrawnTime returns the withdrawn time of a deposit by its ID.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| depositId | string | ID of the deposit |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| timestamp | int64 | withdrawal timestamp |
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

<a id="getprojectactivestatus"></a>

### GetProjectActiveStatus

```go

func GetProjectActiveStatus(projectId string) (bool, error)

```

GetProjectActiveStatus returns whether a project is currently active.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| projectId | string | ID of the project |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| active | bool | true if project is active |
| err | error | error if not found |

---

<a id="getprojectcount"></a>

### GetProjectCount

```go

func GetProjectCount() int

```

GetProjectCount returns the total number of projects.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| count | int | total number of projects |

---

<a id="getprojectcreatedat"></a>

### GetProjectCreatedAt

```go

func GetProjectCreatedAt(projectId string) (int64, error)

```

GetProjectCreatedAt returns the created time of a project by its ID.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| projectId | string | ID of the project |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| timestamp | int64 | creation timestamp |
| err | error | error if not found |

---

<a id="getprojectcreatedheight"></a>

### GetProjectCreatedHeight

```go

func GetProjectCreatedHeight(projectId string) (int64, error)

```

GetProjectCreatedHeight returns the created height of a project by its ID.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| projectId | string | ID of the project |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| height | int64 | block height at creation |
| err | error | error if not found |

---

<a id="getprojectdepositamount"></a>

### GetProjectDepositAmount

```go

func GetProjectDepositAmount(projectId string) (int64, error)

```

GetProjectDepositAmount returns the deposit amount of a project by its ID.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| projectId | string | ID of the project |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| amount | int64 | deposit amount |
| err | error | error if not found |

---

<a id="getprojectids"></a>

### GetProjectIDs

```go

func GetProjectIDs(offset int, count int) []string

```

GetProjectIDs returns a paginated list of project IDs.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| offset | int | starting index |
| count | int | number of IDs to return |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| projectIds | []string | list of project IDs |

---

<a id="getprojectname"></a>

### GetProjectName

```go

func GetProjectName(projectId string) (string, error)

```

GetProjectName returns the name of a project by its ID.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| projectId | string | ID of the project |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| name | string | project name |
| err | error | error if not found |

---

<a id="getprojectrecipient"></a>

### GetProjectRecipient

```go

func GetProjectRecipient(projectId string) (address, error)

```

GetProjectRecipient returns the recipient address of a project by its ID.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| projectId | string | ID of the project |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| recipient | address | recipient address |
| err | error | error if not found |

---

<a id="getprojecttierdepositcount"></a>

### GetProjectTierDepositCount

```go

func GetProjectTierDepositCount(projectId string, tier int64) int

```

GetProjectTierDepositCount returns the total number of deposits for a project tier.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| projectId | string | ID of the project |
| tier | int64 | tier level |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| count | int | number of deposits |

---

<a id="getprojecttierdepositids"></a>

### GetProjectTierDepositIDs

```go

func GetProjectTierDepositIDs(projectId string, tier int64, offset int, count int) []string

```

GetProjectTierDepositIDs returns a paginated list of deposit IDs for a project tier.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| projectId | string | ID of the project |
| tier | int64 | tier level |
| offset | int | starting index |
| count | int | number of IDs to return |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| depositIds | []string | list of deposit IDs |

---

<a id="getprojecttierdistributeamountpersecondx128"></a>

### GetProjectTierDistributeAmountPerSecondX128

```go

func GetProjectTierDistributeAmountPerSecondX128(projectId string, tier int64) (*u256.Uint, error)

```

GetProjectTierDistributeAmountPerSecondX128 returns the distribute amount per second (Q128) of a project tier.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| projectId | string | ID of the project |
| tier | int64 | tier level |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| amount | *u256.Uint | distribute amount per second in Q128 format |
| err | error | error if not found |

---

<a id="getprojecttierendtime"></a>

### GetProjectTierEndTime

```go

func GetProjectTierEndTime(projectId string, tier int64) (int64, error)

```

GetProjectTierEndTime returns the end time of a project tier.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| projectId | string | ID of the project |
| tier | int64 | tier level |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| timestamp | int64 | end timestamp |
| err | error | error if not found |

---

<a id="getprojecttierrewardaccumulateddistributeamount"></a>

### GetProjectTierRewardAccumulatedDistributeAmount

```go

func GetProjectTierRewardAccumulatedDistributeAmount(projectTierId string) (int64, error)

```

GetProjectTierRewardAccumulatedDistributeAmount returns the accumulated distribute amount of a reward manager.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| projectTierId | string | ID of the project tier |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| amount | int64 | accumulated distribute amount |
| err | error | error if not found |

---

<a id="getprojecttierrewardaccumulatedheight"></a>

### GetProjectTierRewardAccumulatedHeight

```go

func GetProjectTierRewardAccumulatedHeight(projectTierId string) (int64, error)

```

GetProjectTierRewardAccumulatedHeight returns the accumulated height of a reward manager.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| projectTierId | string | ID of the project tier |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| height | int64 | accumulated block height |
| err | error | error if not found |

---

<a id="getprojecttierrewardaccumulatedrewardperdepositx128"></a>

### GetProjectTierRewardAccumulatedRewardPerDepositX128

```go

func GetProjectTierRewardAccumulatedRewardPerDepositX128(projectTierId string) (*u256.Uint, error)

```

GetProjectTierRewardAccumulatedRewardPerDepositX128 returns the accumulated reward per deposit (Q128) of a reward manager.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| projectTierId | string | ID of the project tier |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| amount | *u256.Uint | accumulated reward per deposit in Q128 format |
| err | error | error if not found |

---

<a id="getprojecttierrewardaccumulatedtime"></a>

### GetProjectTierRewardAccumulatedTime

```go

func GetProjectTierRewardAccumulatedTime(projectTierId string) (int64, error)

```

GetProjectTierRewardAccumulatedTime returns the accumulated time of a reward manager.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| projectTierId | string | ID of the project tier |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| timestamp | int64 | accumulated timestamp |
| err | error | error if not found |

---

<a id="getprojecttierrewardclaimableduration"></a>

### GetProjectTierRewardClaimableDuration

```go

func GetProjectTierRewardClaimableDuration(projectTierId string) (int64, error)

```

GetProjectTierRewardClaimableDuration returns the reward claimable duration of a reward manager.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| projectTierId | string | ID of the project tier |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| duration | int64 | claimable duration in seconds |
| err | error | error if not found |

---

<a id="getprojecttierrewarddistributeamountpersecondx128"></a>

### GetProjectTierRewardDistributeAmountPerSecondX128

```go

func GetProjectTierRewardDistributeAmountPerSecondX128(projectTierId string) (*u256.Uint, error)

```

GetProjectTierRewardDistributeAmountPerSecondX128 returns the distribute amount per second (Q128) of a reward manager.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| projectTierId | string | ID of the project tier |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| amount | *u256.Uint | distribute amount per second in Q128 format |
| err | error | error if not found |

---

<a id="getprojecttierrewarddistributeendtime"></a>

### GetProjectTierRewardDistributeEndTime

```go

func GetProjectTierRewardDistributeEndTime(projectTierId string) (int64, error)

```

GetProjectTierRewardDistributeEndTime returns the distribute end time of a reward manager.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| projectTierId | string | ID of the project tier |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| timestamp | int64 | distribute end timestamp |
| err | error | error if not found |

---

<a id="getprojecttierrewarddistributestarttime"></a>

### GetProjectTierRewardDistributeStartTime

```go

func GetProjectTierRewardDistributeStartTime(projectTierId string) (int64, error)

```

GetProjectTierRewardDistributeStartTime returns the distribute start time of a reward manager.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| projectTierId | string | ID of the project tier |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| timestamp | int64 | distribute start timestamp |
| err | error | error if not found |

---

<a id="getprojecttierrewardmanagercount"></a>

### GetProjectTierRewardManagerCount

```go

func GetProjectTierRewardManagerCount() int

```

GetProjectTierRewardManagerCount returns the total number of reward managers.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| count | int | total number of reward managers |

---

<a id="getprojecttierrewardtotalclaimedamount"></a>

### GetProjectTierRewardTotalClaimedAmount

```go

func GetProjectTierRewardTotalClaimedAmount(projectTierId string) (int64, error)

```

GetProjectTierRewardTotalClaimedAmount returns the total claimed amount of a reward manager.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| projectTierId | string | ID of the project tier |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| amount | int64 | total claimed amount |
| err | error | error if not found |

---

<a id="getprojecttierrewardtotaldistributeamount"></a>

### GetProjectTierRewardTotalDistributeAmount

```go

func GetProjectTierRewardTotalDistributeAmount(projectTierId string) (int64, error)

```

GetProjectTierRewardTotalDistributeAmount returns the total distribute amount of a reward manager.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| projectTierId | string | ID of the project tier |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| amount | int64 | total distribute amount |
| err | error | error if not found |

---

<a id="getprojecttierstarttime"></a>

### GetProjectTierStartTime

```go

func GetProjectTierStartTime(projectId string, tier int64) (int64, error)

```

GetProjectTierStartTime returns the start time of a project tier.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| projectId | string | ID of the project |
| tier | int64 | tier level |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| timestamp | int64 | start timestamp |
| err | error | error if not found |

---

<a id="getprojecttiertotalcollectedamount"></a>

### GetProjectTierTotalCollectedAmount

```go

func GetProjectTierTotalCollectedAmount(projectId string, tier int64) (int64, error)

```

GetProjectTierTotalCollectedAmount returns the total collected amount of a project tier.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| projectId | string | ID of the project |
| tier | int64 | tier level |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| amount | int64 | total collected amount |
| err | error | error if not found |

---

<a id="getprojecttiertotaldepositamount"></a>

### GetProjectTierTotalDepositAmount

```go

func GetProjectTierTotalDepositAmount(projectId string, tier int64) (int64, error)

```

GetProjectTierTotalDepositAmount returns the total deposit amount of a project tier.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| projectId | string | ID of the project |
| tier | int64 | tier level |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| amount | int64 | total deposit amount |
| err | error | error if not found |

---

<a id="getprojecttiertotaldepositcount"></a>

### GetProjectTierTotalDepositCount

```go

func GetProjectTierTotalDepositCount(projectId string, tier int64) (int64, error)

```

GetProjectTierTotalDepositCount returns the total deposit count of a project tier.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| projectId | string | ID of the project |
| tier | int64 | tier level |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| count | int64 | total deposit count |
| err | error | error if not found |

---

<a id="getprojecttiertotaldistributeamount"></a>

### GetProjectTierTotalDistributeAmount

```go

func GetProjectTierTotalDistributeAmount(projectId string, tier int64) (int64, error)

```

GetProjectTierTotalDistributeAmount returns the total distribute amount of a project tier.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| projectId | string | ID of the project |
| tier | int64 | tier level |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| amount | int64 | total distribute amount |
| err | error | error if not found |

---

<a id="getprojecttiertotalwithdrawamount"></a>

### GetProjectTierTotalWithdrawAmount

```go

func GetProjectTierTotalWithdrawAmount(projectId string, tier int64) (int64, error)

```

GetProjectTierTotalWithdrawAmount returns the total withdraw amount of a project tier.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| projectId | string | ID of the project |
| tier | int64 | tier level |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| amount | int64 | total withdraw amount |
| err | error | error if not found |

---

<a id="getprojecttiertotalwithdrawcount"></a>

### GetProjectTierTotalWithdrawCount

```go

func GetProjectTierTotalWithdrawCount(projectId string, tier int64) (int64, error)

```

GetProjectTierTotalWithdrawCount returns the total withdraw count of a project tier.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| projectId | string | ID of the project |
| tier | int64 | tier level |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| count | int64 | total withdraw count |
| err | error | error if not found |

---

<a id="getprojecttiersratios"></a>

### GetProjectTiersRatios

```go

func GetProjectTiersRatios(projectId string) (map[int64]int64, error)

```

GetProjectTiersRatios returns the tiers ratios map of a project by its ID.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| projectId | string | ID of the project |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| ratios | map[int64]int64 | map of tier to ratio |
| err | error | error if not found |

---

<a id="getprojecttokenpath"></a>

### GetProjectTokenPath

```go

func GetProjectTokenPath(projectId string) (string, error)

```

GetProjectTokenPath returns the token path of a project by its ID.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| projectId | string | ID of the project |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| tokenPath | string | project token path |
| err | error | error if not found |

---

<a id="makeprojectid"></a>

### MakeProjectID

```go

func MakeProjectID(tokenPath string, createdHeight int64) string

```

MakeProjectID generates a unique project ID based on the given token path and the current block height.

The generated ID combines the `tokenPath` and the current block height in the following format:
"{tokenPath}:{height}"

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| tokenPath | string |  |
| createdHeight | int64 |  |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| string | string | A unique project ID in the format "tokenPath:height". |

---

<a id="makeprojecttierid"></a>

### MakeProjectTierID

```go

func MakeProjectTierID(projectID string, duration int64) string

```

MakeProjectTierID generates a unique tier ID based on the given project ID and the tier duration.

The generated ID combines the `projectId` and the `duration` in the following format:
"{projectId}:{duration}"

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| projectID | string |  |
| duration | int64 |  |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| string | string | A unique tier ID in the format "projectId:duration". |

---

<a id="registerinitializer"></a>

### RegisterInitializer

```go

func RegisterInitializer(cur realm, initializer func(...))

```

RegisterInitializer registers a new launchpad implementation version.
This function is called by each version (v1, v2, etc.) during initialization
to register their implementation with the proxy system.

The initializer function creates a new instance of the implementation
using the provided launchpadStore interface.

Security: Only contracts within the domain path can register initializers.
Each package path can only register once to prevent duplicate registrations.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| cur | realm |  |
| initializer | func(...) |  |

---

<a id="transferleftfromprojectbyadmin"></a>

### TransferLeftFromProjectByAdmin

```go

func TransferLeftFromProjectByAdmin(cur realm, projectID string, recipient address) int64

```

TransferLeftFromProjectByAdmin transfers the remaining rewards of a project to a specified recipient.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| cur | realm |  |
| projectID | string | ID of the project |
| recipient | address | recipient address for remaining rewards |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
| amount | int64 | transferred amount |

---

<a id="upgradeimpl"></a>

### UpgradeImpl

```go

func UpgradeImpl(cur realm, packagePath string)

```

UpgradeImpl switches the active launchpad implementation to a different version.
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

Next increments the counter and returns the next ID.

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

Deposit represents a deposit made by a user in a launchpad project.

This struct contains the necessary data and methods to manage and distribute
rewards for a specific deposit.

Fields:
- depositor (address): The address of the depositor.
- id (string): The unique identifier for the deposit.
- projectID (string): The ID of the project associated with the deposit.
- tier (int64): The tier of the deposit.
- depositAmount (int64): The amount of the deposit.
- withdrawnHeight (int64): The height at which the deposit was withdrawn.
- withdrawnTime (int64): The time when the deposit was withdrawn.
- createdTime (int64): The time when the deposit was created.
- endTime (int64): The time when the deposit ends.

#### Methods

<a id="deposit.clone"></a>
##### Clone

```go
func (d Deposit) Clone() *Deposit
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | *Deposit |  |

<a id="deposit.createdat"></a>
##### CreatedAt

```go
func (d *Deposit) CreatedAt() int64
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int64 |  |

<a id="deposit.createdheight"></a>
##### CreatedHeight

```go
func (d *Deposit) CreatedHeight() int64
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int64 |  |

<a id="deposit.depositamount"></a>
##### DepositAmount

```go
func (d *Deposit) DepositAmount() int64
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int64 |  |

<a id="deposit.depositor"></a>
##### Depositor

```go
func (d *Deposit) Depositor() address
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | address |  |

<a id="deposit.endtime"></a>
##### EndTime

```go
func (d *Deposit) EndTime() int64
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int64 |  |

<a id="deposit.id"></a>
##### ID

```go
func (d *Deposit) ID() string
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | string |  |

<a id="deposit.isdepositor"></a>
##### IsDepositor

```go
func (d *Deposit) IsDepositor(address address) bool
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| address | address |  |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | bool |  |

<a id="deposit.isended"></a>
##### IsEnded

```go
func (d *Deposit) IsEnded(currentTime int64) bool
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| currentTime | int64 |  |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | bool |  |

<a id="deposit.iswithdrawn"></a>
##### IsWithdrawn

```go
func (d *Deposit) IsWithdrawn() bool
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | bool |  |

<a id="deposit.projectid"></a>
##### ProjectID

```go
func (d *Deposit) ProjectID() string
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | string |  |

<a id="deposit.projecttierid"></a>
##### ProjectTierID

```go
func (d *Deposit) ProjectTierID() string
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | string |  |

<a id="deposit.setcreatedat"></a>
##### SetCreatedAt

```go
func (d *Deposit) SetCreatedAt(createdAt int64)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| createdAt | int64 |  |

<a id="deposit.setcreatedheight"></a>
##### SetCreatedHeight

```go
func (d *Deposit) SetCreatedHeight(createdHeight int64)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| createdHeight | int64 |  |

<a id="deposit.setdepositamount"></a>
##### SetDepositAmount

```go
func (d *Deposit) SetDepositAmount(depositAmount int64)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| depositAmount | int64 |  |

<a id="deposit.setdepositor"></a>
##### SetDepositor

```go
func (d *Deposit) SetDepositor(depositor address)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| depositor | address |  |

<a id="deposit.setendtime"></a>
##### SetEndTime

```go
func (d *Deposit) SetEndTime(endTime int64)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| endTime | int64 |  |

<a id="deposit.setid"></a>
##### SetID

```go
func (d *Deposit) SetID(id string)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| id | string |  |

<a id="deposit.setprojectid"></a>
##### SetProjectID

```go
func (d *Deposit) SetProjectID(projectID string)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| projectID | string |  |

<a id="deposit.settier"></a>
##### SetTier

```go
func (d *Deposit) SetTier(tier int64)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| tier | int64 |  |

<a id="deposit.setwithdrawn"></a>
##### SetWithdrawn

```go
func (d *Deposit) SetWithdrawn(withdrawnHeight int64, withdrawnTime int64)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| withdrawnHeight | int64 |  |
| withdrawnTime | int64 |  |

<a id="deposit.setwithdrawnheight"></a>
##### SetWithdrawnHeight

```go
func (d *Deposit) SetWithdrawnHeight(withdrawnHeight int64)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| withdrawnHeight | int64 |  |

<a id="deposit.setwithdrawntime"></a>
##### SetWithdrawnTime

```go
func (d *Deposit) SetWithdrawnTime(withdrawnTime int64)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| withdrawnTime | int64 |  |

<a id="deposit.tier"></a>
##### Tier

```go
func (d *Deposit) Tier() int64
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int64 |  |

<a id="deposit.withdrawnheight"></a>
##### WithdrawnHeight

```go
func (d *Deposit) WithdrawnHeight() int64
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int64 |  |

<a id="deposit.withdrawntime"></a>
##### WithdrawnTime

```go
func (d *Deposit) WithdrawnTime() int64
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int64 |  |


#### Constructors

- `func GetDeposit(depositId string) (*Deposit, error)`
- `func NewDeposit(depositID string, projectID string, tier int64, depositor address, depositAmount int64, createdHeight int64, createdTime int64, endTime int64) *Deposit`

---

<a id="ilaunchpad"></a>

### ILaunchpad

```go

type ILaunchpad interface

```

---

<a id="ilaunchpaddeposit"></a>

### ILaunchpadDeposit

```go

type ILaunchpadDeposit interface

```

---

<a id="ilaunchpadgetter"></a>

### ILaunchpadGetter

```go

type ILaunchpadGetter interface

```

---

<a id="ilaunchpadproject"></a>

### ILaunchpadProject

```go

type ILaunchpadProject interface

```

---

<a id="ilaunchpadstore"></a>

### ILaunchpadStore

```go

type ILaunchpadStore interface

```

#### Constructors

- `func NewLaunchpadStore(kvStore store.KVStore) ILaunchpadStore`

---

<a id="project"></a>

### Project

```go

type Project struct

```

Project represents a launchpad project.

This struct contains the necessary data and methods to manage and distribute
rewards for a specific project.

Fields:
- id (string): The unique identifier for the project, formatted as "{tokenPath}:{createdHeight}".
- name (string): The name of the project.
- tokenPath (string): The path of the token associated with the project.
- depositAmount (int64): The total amount of tokens deposited for the project.
- recipient (address): The address to receive the project's rewards.
- conditions (map[string]*ProjectCondition): A map of token paths to their associated conditions.
- tiers (map[int64]*ProjectTier): A map of tier durations to their associated tiers.
- tiersRatios (map[int64]int64): A map of tier durations to their associated ratios.
- createdBlockTimeInfo (BlockTimeInfo): The block time and height information for the creation of the project.

#### Methods

<a id="project.clone"></a>
##### Clone

```go
func (p Project) Clone() *Project
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | *Project |  |

<a id="project.conditions"></a>
##### Conditions

```go
func (p *Project) Conditions() map[string]*ProjectCondition
```

GetConditions returns the conditions map of the project.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | map[string]*ProjectCondition |  |

<a id="project.createdat"></a>
##### CreatedAt

```go
func (p *Project) CreatedAt() int64
```

GetCreatedAt returns the created time of the project.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int64 |  |

<a id="project.createdheight"></a>
##### CreatedHeight

```go
func (p *Project) CreatedHeight() int64
```

GetCreatedHeight returns the created height of the project.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int64 |  |

<a id="project.depositamount"></a>
##### DepositAmount

```go
func (p *Project) DepositAmount() int64
```

GetDepositAmount returns the deposit amount of the project.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int64 |  |

<a id="project.gettier"></a>
##### GetTier

```go
func (p *Project) GetTier(duration int64) (*ProjectTier, error)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| duration | int64 |  |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | *ProjectTier |  |
|  | error |  |

<a id="project.id"></a>
##### ID

```go
func (p *Project) ID() string
```

GetID returns the ID of the project.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | string |  |

<a id="project.isrecipient"></a>
##### IsRecipient

```go
func (p *Project) IsRecipient(recipient address) bool
```

IsRecipient returns true if the project recipient is the given address.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| recipient | address |  |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | bool |  |

<a id="project.name"></a>
##### Name

```go
func (p *Project) Name() string
```

GetName returns the name of the project.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | string |  |

<a id="project.recipient"></a>
##### Recipient

```go
func (p *Project) Recipient() address
```

GetRecipient returns the recipient address of the project.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | address |  |

<a id="project.setconditions"></a>
##### SetConditions

```go
func (p *Project) SetConditions(conditions map[string]*ProjectCondition)
```

SetConditions sets the conditions map of the project.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| conditions | map[string]*ProjectCondition |  |

<a id="project.setcreatedat"></a>
##### SetCreatedAt

```go
func (p *Project) SetCreatedAt(time int64)
```

SetCreatedAt sets the created time of the project.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| time | int64 |  |

<a id="project.setcreatedheight"></a>
##### SetCreatedHeight

```go
func (p *Project) SetCreatedHeight(height int64)
```

SetCreatedHeight sets the created height of the project.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| height | int64 |  |

<a id="project.setdepositamount"></a>
##### SetDepositAmount

```go
func (p *Project) SetDepositAmount(amount int64)
```

SetDepositAmount sets the deposit amount of the project.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| amount | int64 |  |

<a id="project.setid"></a>
##### SetID

```go
func (p *Project) SetID(id string)
```

SetID sets the ID of the project.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| id | string |  |

<a id="project.setname"></a>
##### SetName

```go
func (p *Project) SetName(name string)
```

SetName sets the name of the project.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| name | string |  |

<a id="project.setrecipient"></a>
##### SetRecipient

```go
func (p *Project) SetRecipient(recipient address)
```

SetRecipient sets the recipient address of the project.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| recipient | address |  |

<a id="project.settier"></a>
##### SetTier

```go
func (p *Project) SetTier(duration int64, tier *ProjectTier)
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| duration | int64 |  |
| tier | *ProjectTier |  |

<a id="project.settiers"></a>
##### SetTiers

```go
func (p *Project) SetTiers(tiers map[int64]*ProjectTier)
```

SetTiers sets the tiers map of the project.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| tiers | map[int64]*ProjectTier |  |

<a id="project.settiersratios"></a>
##### SetTiersRatios

```go
func (p *Project) SetTiersRatios(tiersRatios map[int64]int64)
```

SetTiersRatios sets the tiers ratios map of the project.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| tiersRatios | map[int64]int64 |  |

<a id="project.settokenpath"></a>
##### SetTokenPath

```go
func (p *Project) SetTokenPath(tokenPath string)
```

SetTokenPath sets the token path of the project.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| tokenPath | string |  |

<a id="project.tiers"></a>
##### Tiers

```go
func (p *Project) Tiers() map[int64]*ProjectTier
```

GetTiers returns the tiers map of the project.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | map[int64]*ProjectTier |  |

<a id="project.tiersratios"></a>
##### TiersRatios

```go
func (p *Project) TiersRatios() map[int64]int64
```

GetTiersRatios returns the tiers ratios map of the project.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | map[int64]int64 |  |

<a id="project.tokenpath"></a>
##### TokenPath

```go
func (p *Project) TokenPath() string
```

GetTokenPath returns the token path of the project.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | string |  |


#### Constructors

- `func GetProject(projectId string) (*Project, error)`
- `func NewProject(name string, tokenPath string, depositAmount int64, recipient address, createdHeight int64, createdAt int64) *Project`

---

<a id="projectcondition"></a>

### ProjectCondition

```go

type ProjectCondition struct

```

ProjectCondition represents a condition for a project.

This struct contains the necessary data and methods to manage and distribute
rewards for a specific project.

Fields:
- tokenPath (string): The path of the token associated with the project.
- minimumAmount (int64): The minimum amount of the token required for the project.

#### Methods

<a id="projectcondition.checkbalancecondition"></a>
##### CheckBalanceCondition

```go
func (p *ProjectCondition) CheckBalanceCondition(inputTokenPath string, inputAmount int64) error
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| inputTokenPath | string |  |
| inputAmount | int64 |  |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | error |  |

<a id="projectcondition.clone"></a>
##### Clone

```go
func (p ProjectCondition) Clone() *ProjectCondition
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | *ProjectCondition |  |

<a id="projectcondition.isavailable"></a>
##### IsAvailable

```go
func (p *ProjectCondition) IsAvailable() bool
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | bool |  |

<a id="projectcondition.minimumamount"></a>
##### MinimumAmount

```go
func (p *ProjectCondition) MinimumAmount() int64
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int64 |  |

<a id="projectcondition.tokenpath"></a>
##### TokenPath

```go
func (p *ProjectCondition) TokenPath() string
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | string |  |


#### Constructors

- `func GetProjectCondition(projectId string, tokenPath string) (*ProjectCondition, error)`
- `func NewProjectCondition(tokenPath string, minimumAmount int64) *ProjectCondition`
- `func NewProjectConditionsWithError(conditionTokens string, conditionAmounts string) ([]*ProjectCondition, error)`

---

<a id="projecttier"></a>

### ProjectTier

```go

type ProjectTier struct

```

ProjectTier represents a tier within a project.

This struct contains the necessary data and methods to manage and distribute
rewards for a specific tier of a project.

Fields:
- distributeAmountPerSecondX128 (u256.Uint): The amount of tokens to be distributed per second, represented as a Q128 fixed-point number.
- startTime (int64): The time for the start of the tier.
- endTime (int64): The time for the end of the tier.
- id (string): The unique identifier for the tier, formatted as "{projectID}:duration".
- totalDistributeAmount (int64): The total amount of tokens to be distributed for the tier.
- totalDepositAmount (int64): The total amount of tokens deposited for the tier.
- totalWithdrawAmount (int64): The total amount of tokens withdrawn from the tier.
- totalDepositCount (int64): The total number of deposits made to the tier.
- totalWithdrawCount (int64): The total number of withdrawals from the tier.
- totalCollectedAmount (int64): The total amount of tokens collected as rewards for the tier.

#### Methods

<a id="projecttier.clone"></a>
##### Clone

```go
func (pt ProjectTier) Clone() *ProjectTier
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | *ProjectTier |  |

<a id="projecttier.distributeamountpersecondx128"></a>
##### DistributeAmountPerSecondX128

```go
func (pt *ProjectTier) DistributeAmountPerSecondX128() *u256.Uint
```

DistributeAmountPerSecondX128 returns the distribute amount per second (Q128) of the project tier.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | *u256.Uint |  |

<a id="projecttier.endtime"></a>
##### EndTime

```go
func (pt *ProjectTier) EndTime() int64
```

EndTime returns the end time of the project tier.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int64 |  |

<a id="projecttier.id"></a>
##### ID

```go
func (pt *ProjectTier) ID() string
```

ID returns the ID of the project tier.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | string |  |

<a id="projecttier.isactivated"></a>
##### IsActivated

```go
func (pt *ProjectTier) IsActivated(currentTime int64) bool
```

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| currentTime | int64 |  |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | bool |  |

<a id="projecttier.isended"></a>
##### IsEnded

```go
func (pt *ProjectTier) IsEnded(currentTime int64) bool
```

IsEnded returns true if the project tier has ended.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| currentTime | int64 |  |

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | bool |  |

<a id="projecttier.setdistributeamountpersecondx128"></a>
##### SetDistributeAmountPerSecondX128

```go
func (pt *ProjectTier) SetDistributeAmountPerSecondX128(amount *u256.Uint)
```

SetDistributeAmountPerSecondX128 sets the distribute amount per second (Q128) of the project tier.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| amount | *u256.Uint |  |

<a id="projecttier.setendtime"></a>
##### SetEndTime

```go
func (pt *ProjectTier) SetEndTime(time int64)
```

SetEndTime sets the end time of the project tier.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| time | int64 |  |

<a id="projecttier.setid"></a>
##### SetID

```go
func (pt *ProjectTier) SetID(id string)
```

SetID sets the ID of the project tier.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| id | string |  |

<a id="projecttier.setstarttime"></a>
##### SetStartTime

```go
func (pt *ProjectTier) SetStartTime(time int64)
```

SetStartTime sets the start time of the project tier.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| time | int64 |  |

<a id="projecttier.settotalcollectedamount"></a>
##### SetTotalCollectedAmount

```go
func (pt *ProjectTier) SetTotalCollectedAmount(amount int64)
```

SetTotalCollectedAmount sets the total collected amount of the project tier.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| amount | int64 |  |

<a id="projecttier.settotaldepositamount"></a>
##### SetTotalDepositAmount

```go
func (pt *ProjectTier) SetTotalDepositAmount(amount int64)
```

SetTotalDepositAmount sets the total deposit amount of the project tier.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| amount | int64 |  |

<a id="projecttier.settotaldepositcount"></a>
##### SetTotalDepositCount

```go
func (pt *ProjectTier) SetTotalDepositCount(count int64)
```

SetTotalDepositCount sets the total deposit count of the project tier.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| count | int64 |  |

<a id="projecttier.settotaldistributeamount"></a>
##### SetTotalDistributeAmount

```go
func (pt *ProjectTier) SetTotalDistributeAmount(amount int64)
```

SetTotalDistributeAmount sets the total distribute amount of the project tier.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| amount | int64 |  |

<a id="projecttier.settotalwithdrawamount"></a>
##### SetTotalWithdrawAmount

```go
func (pt *ProjectTier) SetTotalWithdrawAmount(amount int64)
```

SetTotalWithdrawAmount sets the total withdraw amount of the project tier.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| amount | int64 |  |

<a id="projecttier.settotalwithdrawcount"></a>
##### SetTotalWithdrawCount

```go
func (pt *ProjectTier) SetTotalWithdrawCount(count int64)
```

SetTotalWithdrawCount sets the total withdraw count of the project tier.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| count | int64 |  |

<a id="projecttier.starttime"></a>
##### StartTime

```go
func (pt *ProjectTier) StartTime() int64
```

StartTime returns the start time of the project tier.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int64 |  |

<a id="projecttier.totalcollectedamount"></a>
##### TotalCollectedAmount

```go
func (pt *ProjectTier) TotalCollectedAmount() int64
```

TotalCollectedAmount returns the total collected amount of the project tier.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int64 |  |

<a id="projecttier.totaldepositamount"></a>
##### TotalDepositAmount

```go
func (pt *ProjectTier) TotalDepositAmount() int64
```

TotalDepositAmount returns the total deposit amount of the project tier.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int64 |  |

<a id="projecttier.totaldepositcount"></a>
##### TotalDepositCount

```go
func (pt *ProjectTier) TotalDepositCount() int64
```

TotalDepositCount returns the total deposit count of the project tier.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int64 |  |

<a id="projecttier.totaldistributeamount"></a>
##### TotalDistributeAmount

```go
func (pt *ProjectTier) TotalDistributeAmount() int64
```

TotalDistributeAmount returns the total distribute amount of the project tier.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int64 |  |

<a id="projecttier.totalwithdrawamount"></a>
##### TotalWithdrawAmount

```go
func (pt *ProjectTier) TotalWithdrawAmount() int64
```

TotalWithdrawAmount returns the total withdraw amount of the project tier.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int64 |  |

<a id="projecttier.totalwithdrawcount"></a>
##### TotalWithdrawCount

```go
func (pt *ProjectTier) TotalWithdrawCount() int64
```

TotalWithdrawCount returns the total withdraw count of the project tier.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int64 |  |


#### Constructors

- `func GetProjectTier(projectId string, tier int64) (*ProjectTier, error)`
- `func NewProjectTier(projectID string, tierDuration int64, totalDistributeAmount int64, startTime int64, endTime int64) *ProjectTier`

---

<a id="rewardmanager"></a>

### RewardManager

```go

type RewardManager struct

```

RewardManager manages the distribution of rewards for a project tier.

This struct contains the necessary data and methods to calculate and track
rewards for deposits associated with a project tier.

Fields:
- rewards (avl.Tree): A map of deposit IDs to their associated reward states.
- distributeAmountPerSecondX128 (u256.Uint): The amount of tokens to be distributed per second, represented as a Q128 fixed-point number.
- accumulatedRewardPerDepositX128 (u256.Uint): The accumulated reward per GNS stake, represented as a Q128 fixed-point number.
- totalDistributeAmount (int64): The total amount of tokens to be distributed.
- totalClaimedAmount (int64): The total amount of tokens claimed.
- distributeStartTime (int64): The start time of the reward calculation.
- distributeEndTime (int64): The end time of the reward calculation.
- accumulatedDistributeAmount (int64): The accumulated amount of tokens distributed.
- accumulatedHeight (int64): The last height when reward was calculated.
- rewardClaimableDuration (int64): The duration of reward claimable.

#### Methods

<a id="rewardmanager.accumulateddistributeamount"></a>
##### AccumulatedDistributeAmount

```go
func (rm *RewardManager) AccumulatedDistributeAmount() int64
```

AccumulatedDistributeAmount returns the accumulated distribute amount of the reward manager.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int64 |  |

<a id="rewardmanager.accumulatedheight"></a>
##### AccumulatedHeight

```go
func (rm *RewardManager) AccumulatedHeight() int64
```

AccumulatedHeight returns the accumulated height of the reward manager.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int64 |  |

<a id="rewardmanager.accumulatedrewardperdepositx128"></a>
##### AccumulatedRewardPerDepositX128

```go
func (rm *RewardManager) AccumulatedRewardPerDepositX128() *u256.Uint
```

AccumulatedRewardPerDepositX128 returns the accumulated reward per deposit (Q128) of the reward manager.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | *u256.Uint |  |

<a id="rewardmanager.accumulatedtime"></a>
##### AccumulatedTime

```go
func (rm *RewardManager) AccumulatedTime() int64
```

AccumulatedTime returns the accumulated time of the reward manager.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int64 |  |

<a id="rewardmanager.clone"></a>
##### Clone

```go
func (rm RewardManager) Clone() *RewardManager
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | *RewardManager |  |

<a id="rewardmanager.distributeamountpersecondx128"></a>
##### DistributeAmountPerSecondX128

```go
func (rm *RewardManager) DistributeAmountPerSecondX128() *u256.Uint
```

DistributeAmountPerSecondX128 returns the distribute amount per second (Q128) of the reward manager.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | *u256.Uint |  |

<a id="rewardmanager.distributeendtime"></a>
##### DistributeEndTime

```go
func (rm *RewardManager) DistributeEndTime() int64
```

DistributeEndTime returns the distribute end time of the reward manager.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int64 |  |

<a id="rewardmanager.distributestarttime"></a>
##### DistributeStartTime

```go
func (rm *RewardManager) DistributeStartTime() int64
```

DistributeStartTime returns the distribute start time of the reward manager.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int64 |  |

<a id="rewardmanager.rewardclaimableduration"></a>
##### RewardClaimableDuration

```go
func (rm *RewardManager) RewardClaimableDuration() int64
```

RewardClaimableDuration returns the reward claimable duration of the reward manager.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int64 |  |

<a id="rewardmanager.rewards"></a>
##### Rewards

```go
func (rm *RewardManager) Rewards() *avl.Tree
```

Rewards returns the rewards tree of the reward manager.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | *avl.Tree |  |

<a id="rewardmanager.setaccumulateddistributeamount"></a>
##### SetAccumulatedDistributeAmount

```go
func (rm *RewardManager) SetAccumulatedDistributeAmount(amount int64)
```

SetAccumulatedDistributeAmount sets the accumulated distribute amount of the reward manager.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| amount | int64 |  |

<a id="rewardmanager.setaccumulatedheight"></a>
##### SetAccumulatedHeight

```go
func (rm *RewardManager) SetAccumulatedHeight(height int64)
```

SetAccumulatedHeight sets the accumulated height of the reward manager.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| height | int64 |  |

<a id="rewardmanager.setaccumulatedrewardperdepositx128"></a>
##### SetAccumulatedRewardPerDepositX128

```go
func (rm *RewardManager) SetAccumulatedRewardPerDepositX128(amount *u256.Uint)
```

SetAccumulatedRewardPerDepositX128 sets the accumulated reward per deposit (Q128) of the reward manager.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| amount | *u256.Uint |  |

<a id="rewardmanager.setaccumulatedtime"></a>
##### SetAccumulatedTime

```go
func (rm *RewardManager) SetAccumulatedTime(time int64)
```

SetAccumulatedTime sets the accumulated time of the reward manager.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| time | int64 |  |

<a id="rewardmanager.setdistributeamountpersecondx128"></a>
##### SetDistributeAmountPerSecondX128

```go
func (rm *RewardManager) SetDistributeAmountPerSecondX128(amount *u256.Uint)
```

SetDistributeAmountPerSecondX128 sets the distribute amount per second (Q128) of the reward manager.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| amount | *u256.Uint |  |

<a id="rewardmanager.setdistributeendtime"></a>
##### SetDistributeEndTime

```go
func (rm *RewardManager) SetDistributeEndTime(time int64)
```

SetDistributeEndTime sets the distribute end time of the reward manager.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| time | int64 |  |

<a id="rewardmanager.setdistributestarttime"></a>
##### SetDistributeStartTime

```go
func (rm *RewardManager) SetDistributeStartTime(time int64)
```

SetDistributeStartTime sets the distribute start time of the reward manager.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| time | int64 |  |

<a id="rewardmanager.setrewardclaimableduration"></a>
##### SetRewardClaimableDuration

```go
func (rm *RewardManager) SetRewardClaimableDuration(duration int64)
```

SetRewardClaimableDuration sets the reward claimable duration of the reward manager.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| duration | int64 |  |

<a id="rewardmanager.setrewards"></a>
##### SetRewards

```go
func (rm *RewardManager) SetRewards(rewards *avl.Tree)
```

SetRewards sets the rewards tree of the reward manager.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| rewards | *avl.Tree |  |

<a id="rewardmanager.settotalclaimedamount"></a>
##### SetTotalClaimedAmount

```go
func (rm *RewardManager) SetTotalClaimedAmount(amount int64)
```

SetTotalClaimedAmount sets the total claimed amount of the reward manager.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| amount | int64 |  |

<a id="rewardmanager.settotaldistributeamount"></a>
##### SetTotalDistributeAmount

```go
func (rm *RewardManager) SetTotalDistributeAmount(amount int64)
```

SetTotalDistributeAmount sets the total distribute amount of the reward manager.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| amount | int64 |  |

<a id="rewardmanager.totalclaimedamount"></a>
##### TotalClaimedAmount

```go
func (rm *RewardManager) TotalClaimedAmount() int64
```

TotalClaimedAmount returns the total claimed amount of the reward manager.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int64 |  |

<a id="rewardmanager.totaldistributeamount"></a>
##### TotalDistributeAmount

```go
func (rm *RewardManager) TotalDistributeAmount() int64
```

TotalDistributeAmount returns the total distribute amount of the reward manager.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int64 |  |


#### Constructors

- `func GetProjectTierRewardManager(projectTierId string) (*RewardManager, error)`
- `func NewRewardManager(totalDistributeAmount int64, distributeStartTime int64, distributeEndTime int64, rewardCollectableDuration int64, currentHeight int64, currentTime int64) *RewardManager`

---

<a id="rewardstate"></a>

### RewardState

```go

type RewardState struct

```

RewardState represents the state of a reward for a deposit.
It contains the necessary data to manage and distribute rewards for a specific deposit.

#### Methods

<a id="rewardstate.accumulatedheight"></a>
##### AccumulatedHeight

```go
func (rs *RewardState) AccumulatedHeight() int64
```

AccumulatedHeight returns the accumulated height of the reward state.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int64 |  |

<a id="rewardstate.accumulatedrewardamount"></a>
##### AccumulatedRewardAmount

```go
func (rs *RewardState) AccumulatedRewardAmount() int64
```

AccumulatedRewardAmount returns the accumulated reward amount of the reward state.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int64 |  |

<a id="rewardstate.accumulatedtime"></a>
##### AccumulatedTime

```go
func (rs *RewardState) AccumulatedTime() int64
```

AccumulatedTime returns the accumulated time of the reward state.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int64 |  |

<a id="rewardstate.claimabletime"></a>
##### ClaimableTime

```go
func (rs *RewardState) ClaimableTime() int64
```

ClaimableTime returns the claimable time of the reward state.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int64 |  |

<a id="rewardstate.claimedamount"></a>
##### ClaimedAmount

```go
func (rs *RewardState) ClaimedAmount() int64
```

ClaimedAmount returns the claimed amount of the reward state.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int64 |  |

<a id="rewardstate.clone"></a>
##### Clone

```go
func (rs RewardState) Clone() *RewardState
```

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | *RewardState |  |

<a id="rewardstate.depositamount"></a>
##### DepositAmount

```go
func (rs *RewardState) DepositAmount() int64
```

DepositAmount returns the deposit amount of the reward state.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int64 |  |

<a id="rewardstate.distributeendtime"></a>
##### DistributeEndTime

```go
func (rs *RewardState) DistributeEndTime() int64
```

DistributeEndTime returns the distribute end time of the reward state.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int64 |  |

<a id="rewardstate.distributestarttime"></a>
##### DistributeStartTime

```go
func (rs *RewardState) DistributeStartTime() int64
```

DistributeStartTime returns the distribute start time of the reward state.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | int64 |  |

<a id="rewardstate.pricedebtx128"></a>
##### PriceDebtX128

```go
func (rs *RewardState) PriceDebtX128() *u256.Uint
```

PriceDebtX128 returns the price debt (Q128) of the reward state.

#### Returns

| Name | Type | Description |
| --- | --- | --- |
|  | *u256.Uint |  |

<a id="rewardstate.setaccumulatedheight"></a>
##### SetAccumulatedHeight

```go
func (rs *RewardState) SetAccumulatedHeight(height int64)
```

SetAccumulatedHeight sets the accumulated height of the reward state.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| height | int64 |  |

<a id="rewardstate.setaccumulatedrewardamount"></a>
##### SetAccumulatedRewardAmount

```go
func (rs *RewardState) SetAccumulatedRewardAmount(amount int64)
```

SetAccumulatedRewardAmount sets the accumulated reward amount of the reward state.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| amount | int64 |  |

<a id="rewardstate.setaccumulatedtime"></a>
##### SetAccumulatedTime

```go
func (rs *RewardState) SetAccumulatedTime(time int64)
```

SetAccumulatedTime sets the accumulated time of the reward state.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| time | int64 |  |

<a id="rewardstate.setclaimabletime"></a>
##### SetClaimableTime

```go
func (rs *RewardState) SetClaimableTime(time int64)
```

SetClaimableTime sets the claimable time of the reward state.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| time | int64 |  |

<a id="rewardstate.setclaimedamount"></a>
##### SetClaimedAmount

```go
func (rs *RewardState) SetClaimedAmount(amount int64)
```

SetClaimedAmount sets the claimed amount of the reward state.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| amount | int64 |  |

<a id="rewardstate.setdepositamount"></a>
##### SetDepositAmount

```go
func (rs *RewardState) SetDepositAmount(amount int64)
```

SetDepositAmount sets the deposit amount of the reward state.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| amount | int64 |  |

<a id="rewardstate.setdistributeendtime"></a>
##### SetDistributeEndTime

```go
func (rs *RewardState) SetDistributeEndTime(time int64)
```

SetDistributeEndTime sets the distribute end time of the reward state.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| time | int64 |  |

<a id="rewardstate.setdistributestarttime"></a>
##### SetDistributeStartTime

```go
func (rs *RewardState) SetDistributeStartTime(time int64)
```

SetDistributeStartTime sets the distribute start time of the reward state.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| time | int64 |  |

<a id="rewardstate.setpricedebtx128"></a>
##### SetPriceDebtX128

```go
func (rs *RewardState) SetPriceDebtX128(debt *u256.Uint)
```

SetPriceDebtX128 sets the price debt (Q128) of the reward state.

#### Parameters

| Name | Type | Description |
| --- | --- | --- |
| debt | *u256.Uint |  |


#### Constructors

- `func GetRewardState(projectTierId string, depositId string) (*RewardState, error)`
- `func NewRewardState(accumulatedRewardPerDepositX128 *u256.Uint, depositAmount int64, distributeStartTime int64, distributeEndTime int64, claimableTime int64) *RewardState`

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
