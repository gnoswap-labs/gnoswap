package launchpad

import (
	"std"

	u256 "gno.land/p/gnoswap/uint256"
)

type Project struct {
	id            string // 'tokenPath:createdHeight'
	name          string
	tokenPath     string
	depositAmount uint64
	recipient     std.Address // string

	conditions map[string]Condition // tokenPath -> Condition

	tier30Ratio uint64
	tier30      Tier

	tier90      Tier
	tier90Ratio uint64

	tier180      Tier
	tier180Ratio uint64

	createdHeight uint64
	createdTime   uint64

	startHeight uint64
	startTime   uint64

	endHeight uint64 // same with tier 180's data
	endTime   uint64 // same with tier 180's data

	totalDepositAmount  uint64 // won't be decreased
	actualDepositAmount uint64 // will be decreased if deposit collected 'CollectDepositGns()'

	totalParticipant  uint64 // accu, won't be decreased
	actualParticipant uint64 // will be decreased if deposit collected 'CollectDepositGns()'

	totalCollectedAmount uint64 // collect reward amount

	refundedAmount uint64
	refundedHeight uint64
	refundedTime   uint64
}

type Tier struct {
	id                    string // '{projectId}:duration' // duartion == 30, 90, 180
	collectWaitDuration   uint64 // block
	tierAmount            uint64
	tierAmountPerBlockX96 *u256.Uint

	startHeight uint64 // first deposit height
	startTime   uint64 // first deposit time
	endHeight   uint64
	endTime     uint64

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
	amount    uint64

	depositHeight uint64
	depositTime   uint64

	depositCollectHeight uint64
	depositCollectTime   uint64

	claimableHeight uint64
	claimableTime   uint64

	rewardAmount        uint64 // calculated, not collected
	rewardCollected     uint64 // accu, collected
	rewardCollectHeight uint64 // last collected height
	rewardCollectTime   uint64 // last collected time
}
