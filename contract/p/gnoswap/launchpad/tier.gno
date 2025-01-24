package launchpad

type Tier struct {
	id                     string // '{projectId}:duration' // duartion == 30, 90, 180
	collectWaitDuration    uint64 // block
	tierAmount             uint64
	tierAmountPerBlockX128 *u256.Uint
	started                TimeInfo // first deposit height
	ended                  TimeInfo //
	totalDepositAmount     uint64   // accumulated deposit amount
	actualDepositAmount    uint64   // actual deposit amount
	totalParticipant       uint64   // accumulated participant
	actualParticipant      uint64   // actual participant
	userCollectedAmount    uint64   // total collected amount by user
	calculatedAmount       uint64   // total calculated amount
	reward                 Reward
}
