package launchpad

import (
	"std"

	u256 "gno.land/p/gnoswap/uint256"
)

type Project struct {
	id            string // 'tokenPath:createdHeight'
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

	// startHeight uint64
	startTime uint64

	totalDepositAmount  uint64 // won't be decreased
	actualDepositAmount uint64 // will be decreased if deposit collected 'CollectDepositGns()'

	totalParticipant  uint64 // accu, won't be decreased
	actualParticipant uint64 // will be decreased if deposit collected 'CollectDepositGns()'

	totalCollectedAmount uint64 // collect reward amount
}

type Tier struct {
	id                     string // '{projectId}:duration' // duartion == 30, 90, 180
	collectWaitDuration    uint64
	tierAmount             uint64
	tierAmountPerSecondX96 *u256.Uint

	// start height/time is same as the project
	// endHeight uint64 // XXX: estimate ??
	endTime uint64

	// actual data
	// unlikely projects' totalDepositAmount or totalParticipant
	// below data will be decreased
	depositAmount uint64
	participant   uint64
}

type Condition struct {
	tokenPath string
	minAmount uint64
}

type Deposit struct {
	id string // 'projectId:tier:depositor:height'

	projectId string      //
	tier      string      // 30, 60, 180 // instead of tierId
	depositor std.Address // string
	amount    uint64

	depositHeight uint64
	depositAt     uint64 // timestamp

	// deposit
	depositCollectHeight uint64
	depositCollectAt     uint64 // timestamp

	// reward collect
	rewardAmount        uint64
	rewardCollectHeight uint64
	rewardCollectAt     uint64 // timestamp
}
