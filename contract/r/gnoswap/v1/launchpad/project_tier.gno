package launchpad

import (
	"gno.land/p/nt/ufmt"

	u256 "gno.land/p/gnoswap/uint256"
)

// ProjectTier represents a tier within a project.
//
// This struct contains the necessary data and methods to manage and distribute
// rewards for a specific tier of a project.
//
// Fields:
// - distributeAmountPerSecondX128 (u256.Uint): The amount of tokens to be distributed per second, represented as a Q128 fixed-point number.
// - startTime (int64): The time for the start of the tier.
// - endTime (int64): The time for the end of the tier.
// - id (string): The unique identifier for the tier, formatted as "{projectID}:duration".
// - totalDistributeAmount (int64): The total amount of tokens to be distributed for the tier.
// - totalDepositAmount (int64): The total amount of tokens deposited for the tier.
// - totalWithdrawAmount (int64): The total amount of tokens withdrawn from the tier.
// - totalDepositCount (int64): The total number of deposits made to the tier.
// - totalWithdrawCount (int64): The total number of withdrawals from the tier.
// - totalCollectedAmount (int64): The total amount of tokens collected as rewards for the tier.
type ProjectTier struct {
	distributeAmountPerSecondX128 *u256.Uint // distribute amount per second, Q128
	startTime                     int64
	endTime                       int64

	id                    string // '{projectId}:duration' // duartion == 30, 90, 180
	totalDistributeAmount int64
	totalDepositAmount    int64 // accumulated deposit amount
	totalWithdrawAmount   int64 // accumulated withdraw amount
	totalDepositCount     int64 // accumulated deposit count
	totalWithdrawCount    int64 // accumulated withdraw count
	totalCollectedAmount  int64 // total collected amount by user (reward)
}

func (t *ProjectTier) ID() string {
	return t.id
}

func (t *ProjectTier) TotalDistributeAmount() int64 {
	return t.totalDistributeAmount
}

func (t *ProjectTier) TotalCollectedAmount() int64 {
	return t.totalCollectedAmount
}

func (t *ProjectTier) TotalDepositAmount() int64 {
	return t.totalDepositAmount
}

func (t *ProjectTier) TotalWithdrawAmount() int64 {
	return t.totalWithdrawAmount
}

func (t *ProjectTier) TotalDepositCount() int64 {
	return t.totalDepositCount
}

func (t *ProjectTier) TotalWithdrawCount() int64 {
	return t.totalWithdrawCount
}

func (t *ProjectTier) CurrentDepositCount() int64 {
	return t.totalDepositCount - t.totalWithdrawCount
}

func (t *ProjectTier) CurrentDepositAmount() int64 {
	return t.totalDepositAmount - t.totalWithdrawAmount
}

func (t *ProjectTier) DistributeAmountPerSecondX128() *u256.Uint {
	return t.distributeAmountPerSecondX128
}

func (t *ProjectTier) isActivated(currentTime int64) bool {
	return t.startTime <= currentTime && currentTime < t.endTime
}

func (t *ProjectTier) isEnded(currentTime int64) bool {
	return t.endTime < currentTime
}

func (t *ProjectTier) isFirstDeposit() bool {
	return t.totalDepositCount == 0
}

func (t *ProjectTier) StartTime() int64 {
	return t.startTime
}

func (t *ProjectTier) EndTime() int64 {
	return t.endTime
}

func (t *ProjectTier) deposit(deposit *Deposit) {
	t.totalDepositAmount += deposit.DepositAmount()
	t.totalDepositCount++
}

func (t *ProjectTier) withdraw(deposit *Deposit) {
	t.totalWithdrawAmount += deposit.DepositAmount()
	t.totalWithdrawCount++
}

func (t *ProjectTier) setStartTime(time int64) {
	t.startTime = time
}

func (t *ProjectTier) setEndTime(time int64) {
	t.endTime = time
}

func (t *ProjectTier) calculateLeftReward() int64 {
	return t.totalDistributeAmount - t.totalCollectedAmount
}

func (t *ProjectTier) updateDistributeAmountPerSecond() {
	// Use time duration instead of block count
	distributeTimeDuration := t.endTime - t.startTime
	if distributeTimeDuration <= 0 {
		return
	}

	totalDistributeAmountX128 := u256.Zero().Mul(u256.NewUintFromInt64(t.totalDistributeAmount), q128.Clone())
	// Divide by time duration in seconds
	distributeAmountPerSecondX128 := u256.Zero().Div(totalDistributeAmountX128, u256.NewUintFromInt64(distributeTimeDuration))

	t.distributeAmountPerSecondX128 = distributeAmountPerSecondX128
}

// NewProjectTier returns a pointer to a new ProjectTier with the given values.
func NewProjectTier(
	projectID string,
	tierDuration int64,
	totalDistributeAmount int64,
	startTime int64,
	endTime int64,
) *ProjectTier {
	tier := &ProjectTier{
		id:                            makeProjectTierID(projectID, tierDuration),
		totalDistributeAmount:         totalDistributeAmount,
		distributeAmountPerSecondX128: u256.Zero(),
		startTime:                     startTime,
		endTime:                       endTime,
		totalDepositAmount:            0,
		totalWithdrawAmount:           0,
		totalDepositCount:             0,
		totalWithdrawCount:            0,
		totalCollectedAmount:          0,
	}

	tier.updateDistributeAmountPerSecond()

	return tier
}

// makeProjectTierID generates a unique tier ID based on the given project ID and the tier duration.
//
// The generated ID combines the `projectId` and the `duration` in the following format:
// "{projectId}:{duration}"
//
// Parameters:
// - projectId (string): The unique ID of the project associated with the tier.
// - duration (uint64): The duration of the tier (e.g., 30, 90, 180 days).
//
// Returns:
// - string: A unique tier ID in the format "projectId:duration".
func makeProjectTierID(projectID string, duration int64) string {
	return ufmt.Sprintf("%s:%d", projectID, duration)
}
