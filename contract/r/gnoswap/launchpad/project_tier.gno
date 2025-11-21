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
	id                            string     // '{projectId}:duration' // duartion == 30, 90, 180
	totalDistributeAmount         int64
	totalDepositAmount            int64 // accumulated deposit amount
	totalWithdrawAmount           int64 // accumulated withdraw amount
	totalDepositCount             int64 // accumulated deposit count
	totalWithdrawCount            int64 // accumulated withdraw count
	totalCollectedAmount          int64 // total collected amount by user (reward)
	startTime                     int64
	endTime                       int64
}

// DistributeAmountPerSecondX128 returns the distribute amount per second (Q128) of the project tier.
func (pt *ProjectTier) DistributeAmountPerSecondX128() *u256.Uint {
	return pt.distributeAmountPerSecondX128
}

// SetDistributeAmountPerSecondX128 sets the distribute amount per second (Q128) of the project tier.
func (pt *ProjectTier) SetDistributeAmountPerSecondX128(amount *u256.Uint) {
	pt.distributeAmountPerSecondX128 = amount
}

// ID returns the ID of the project tier.
func (pt *ProjectTier) ID() string {
	return pt.id
}

// SetID sets the ID of the project tier.
func (pt *ProjectTier) SetID(id string) {
	pt.id = id
}

// TotalDistributeAmount returns the total distribute amount of the project tier.
func (pt *ProjectTier) TotalDistributeAmount() int64 {
	return pt.totalDistributeAmount
}

// SetTotalDistributeAmount sets the total distribute amount of the project tier.
func (pt *ProjectTier) SetTotalDistributeAmount(amount int64) {
	pt.totalDistributeAmount = amount
}

// TotalDepositAmount returns the total deposit amount of the project tier.
func (pt *ProjectTier) TotalDepositAmount() int64 {
	return pt.totalDepositAmount
}

// SetTotalDepositAmount sets the total deposit amount of the project tier.
func (pt *ProjectTier) SetTotalDepositAmount(amount int64) {
	pt.totalDepositAmount = amount
}

// TotalWithdrawAmount returns the total withdraw amount of the project tier.
func (pt *ProjectTier) TotalWithdrawAmount() int64 {
	return pt.totalWithdrawAmount
}

// SetTotalWithdrawAmount sets the total withdraw amount of the project tier.
func (pt *ProjectTier) SetTotalWithdrawAmount(amount int64) {
	pt.totalWithdrawAmount = amount
}

// TotalDepositCount returns the total deposit count of the project tier.
func (pt *ProjectTier) TotalDepositCount() int64 {
	return pt.totalDepositCount
}

// SetTotalDepositCount sets the total deposit count of the project tier.
func (pt *ProjectTier) SetTotalDepositCount(count int64) {
	pt.totalDepositCount = count
}

// TotalWithdrawCount returns the total withdraw count of the project tier.
func (pt *ProjectTier) TotalWithdrawCount() int64 {
	return pt.totalWithdrawCount
}

// SetTotalWithdrawCount sets the total withdraw count of the project tier.
func (pt *ProjectTier) SetTotalWithdrawCount(count int64) {
	pt.totalWithdrawCount = count
}

// TotalCollectedAmount returns the total collected amount of the project tier.
func (pt *ProjectTier) TotalCollectedAmount() int64 {
	return pt.totalCollectedAmount
}

// SetTotalCollectedAmount sets the total collected amount of the project tier.
func (pt *ProjectTier) SetTotalCollectedAmount(amount int64) {
	pt.totalCollectedAmount = amount
}

// StartTime returns the start time of the project tier.
func (pt *ProjectTier) StartTime() int64 {
	return pt.startTime
}

// SetStartTime sets the start time of the project tier.
func (pt *ProjectTier) SetStartTime(time int64) {
	pt.startTime = time
}

// EndTime returns the end time of the project tier.
func (pt *ProjectTier) EndTime() int64 {
	return pt.endTime
}

// SetEndTime sets the end time of the project tier.
func (pt *ProjectTier) SetEndTime(time int64) {
	pt.endTime = time
}

func (pt *ProjectTier) IsActivated(currentTime int64) bool {
	return pt.startTime <= currentTime && currentTime < pt.endTime
}

// IsEnded returns true if the project tier has ended.
func (pt *ProjectTier) IsEnded(currentTime int64) bool {
	return pt.endTime < currentTime
}

func (pt ProjectTier) Clone() *ProjectTier {
	return &ProjectTier{
		id:                            pt.id,
		totalDistributeAmount:         pt.totalDistributeAmount,
		distributeAmountPerSecondX128: pt.distributeAmountPerSecondX128.Clone(),
		startTime:                     pt.startTime,
		endTime:                       pt.endTime,
		totalDepositAmount:            pt.totalDepositAmount,
		totalWithdrawAmount:           pt.totalWithdrawAmount,
		totalDepositCount:             pt.totalDepositCount,
		totalWithdrawCount:            pt.totalWithdrawCount,
		totalCollectedAmount:          pt.totalCollectedAmount,
	}
}

// NewProjectTier returns a pointer to a new ProjectTier with the given values.
func NewProjectTier(
	projectID string,
	tierDuration int64,
	totalDistributeAmount int64,
	startTime int64,
	endTime int64,
) *ProjectTier {
	return &ProjectTier{
		id:                            MakeProjectTierID(projectID, tierDuration),
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
}

// MakeProjectTierID generates a unique tier ID based on the given project ID and the tier duration.
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
func MakeProjectTierID(projectID string, duration int64) string {
	return ufmt.Sprintf("%s:%d", projectID, duration)
}
