package launchpad

import (
	"std"

	u256 "gno.land/p/gnoswap/uint256"
)

type TimeInfo struct {
	height uint64
	time uint64
}

type ProjectStats struct {
    totalDeposit    uint64 // won't be decreased
    actualDeposit   uint64 // will be decreased if deposit collected 'CollectDepositGns()'
    totalParticipant uint64 // accu, won't be decreased
    actualParticipant uint64 // will be decreased if deposit collected 'CollectDepositGns()'
    totalCollected   uint64 // collect reward amount
}

type RefundInfo struct {
	amount uint64
	height uint64
	time uint64
}

type Project struct {
	id            string // 'tokenPath:createdHeight'
	name          string
	tokenPath     string
	depositAmount uint64
	recipient     std.Address // string
	conditions map[string]Condition // tokenPath -> Condition

	tiers map[uint64]Tier
	tiersRatios map[uint64]uint64

	created TimeInfo
	started TimeInfo
	ended TimeInfo // same with tier 180's data

	stats ProjectStats

	refund RefundInfo
}

type Tier struct {
	id                    string // '{projectId}:duration' // duartion == 30, 90, 180
	collectWaitDuration   uint64 // block
	tierAmount            uint64
	tierAmountPerBlockX96 *u256.Uint

	started TimeInfo // first deposit height
	ended TimeInfo

	totalDepositAmount  uint64
	actualDepositAmount uint64

	totalParticipant  uint64
	actualParticipant uint64

	userCollectedAmount uint64
	calculatedAmount    uint64
}

type Condition struct {
	tokenPath string
	minAmount uint64
}

type Deposit struct {
	id string // 'projectId:tier:depositor:height'

	projectId string
	tier      string // 30, 60, 180 // instead of tierId
	depositor std.Address
	// amount    uint64

	depositHeight uint64
	depositTime   uint64

	depositCollectHeight uint64
	depositCollectTime   uint64

	claimableHeight uint64
	claimableTime   uint64

	// rewardAmount        uint64 // calculated, not collected
	rewardCollected     uint64 // accu, collected
	rewardCollectHeight uint64 // last collected height
	rewardCollectTime   uint64 // last collected time
}
