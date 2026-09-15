package launchpad

// Deposit represents a deposit made by a user in a launchpad project.
//
// This struct contains the necessary data and methods to manage and distribute
// rewards for a specific deposit.
//
// Fields:
// - depositor (std.Address): The address of the depositor.
// - id (string): The unique identifier for the deposit.
// - projectID (string): The ID of the project associated with the deposit.
// - tier (int64): The tier duration of the deposit (30, 90, or 180 days).
// - depositAmount (int64): The amount of the deposit.
// - withdrawnHeight (int64): The height at which the deposit was withdrawn.
// - withdrawnTime (int64): The Unix timestamp when the deposit was withdrawn.
// - createdHeight (int64): The block height at which the deposit was created.
// - createdAt (int64): The Unix timestamp when the deposit was created.
// - endTime (int64): The Unix timestamp when the deposit ends.
type Deposit struct {
	depositor address

	id              string
	projectID       string
	tier            int64 // 30, 90, 180 // instead of tierId
	depositAmount   int64
	withdrawnHeight int64
	withdrawnTime   int64
	createdHeight   int64
	createdAt       int64
	endTime         int64
}

// ID returns the unique identifier stored for the deposit.
//
// Returns:
//   - id: deposit identifier used to retrieve this deposit from launchpad state.
func (d Deposit) ID() string {
	return d.id
}

// SetID updates the unique identifier stored for the deposit.
//
// Parameters:
//   - id: new identifier to associate with the deposit.
func (d *Deposit) SetID(id string) {
	d.id = id
}

// ProjectID returns the identifier of the launchpad project associated with the deposit.
//
// Returns:
//   - projectID: associated launchpad project identifier.
func (d Deposit) ProjectID() string {
	return d.projectID
}

// SetProjectID updates the launchpad project identifier associated with the deposit.
//
// Parameters:
//   - projectID: identifier of the launchpad project to associate with the deposit.
func (d *Deposit) SetProjectID(projectID string) {
	d.projectID = projectID
}

// Tier returns the deposit's tier duration.
//
// Returns:
//   - tier: tier duration in days; launchpad tiers use 30, 90, or 180.
func (d Deposit) Tier() int64 {
	return d.tier
}

// SetTier updates the tier duration recorded for the deposit.
//
// Parameters:
//   - tier: tier duration in days; valid launchpad tiers are 30, 90, or 180.
func (d *Deposit) SetTier(tier int64) {
	d.tier = tier
}

// Depositor returns the address that made the deposit.
//
// Returns:
//   - depositor: account address recorded as the deposit owner.
func (d Deposit) Depositor() address {
	return d.depositor
}

// SetDepositor updates the account address recorded as the deposit owner.
//
// Parameters:
//   - depositor: account address to record as the deposit owner.
func (d *Deposit) SetDepositor(depositor address) {
	d.depositor = depositor
}

// DepositAmount returns the amount recorded for the deposit.
//
// Returns:
//   - depositAmount: amount of GNS deposited for the associated project.
func (d Deposit) DepositAmount() int64 {
	return d.depositAmount
}

// SetDepositAmount updates the amount recorded for the deposit.
//
// Parameters:
//   - depositAmount: amount of GNS to record as deposited for the associated project.
func (d *Deposit) SetDepositAmount(depositAmount int64) {
	d.depositAmount = depositAmount
}

// CreatedHeight returns the block height at which the deposit was created.
//
// Returns:
//   - createdHeight: creation block height stored on the deposit.
func (d Deposit) CreatedHeight() int64 {
	return d.createdHeight
}

// SetCreatedHeight updates the block height recorded for deposit creation.
//
// Parameters:
//   - createdHeight: block height at which the deposit was created.
func (d *Deposit) SetCreatedHeight(createdHeight int64) {
	d.createdHeight = createdHeight
}

// CreatedAt returns the Unix timestamp at which the deposit was created.
//
// Returns:
//   - createdAt: creation timestamp in Unix seconds.
func (d Deposit) CreatedAt() int64 {
	return d.createdAt
}

// SetCreatedAt updates the Unix timestamp recorded for deposit creation.
//
// Parameters:
//   - createdAt: creation timestamp in Unix seconds.
func (d *Deposit) SetCreatedAt(createdAt int64) {
	d.createdAt = createdAt
}

// WithdrawnTime returns the Unix timestamp recorded for withdrawal.
//
// Returns:
//   - withdrawnTime: withdrawal timestamp in Unix seconds; zero before withdrawal is recorded.
func (d Deposit) WithdrawnTime() int64 {
	return d.withdrawnTime
}

// SetWithdrawnTime updates the Unix timestamp recorded for withdrawal.
//
// Parameters:
//   - withdrawnTime: withdrawal timestamp in Unix seconds.
func (d *Deposit) SetWithdrawnTime(withdrawnTime int64) {
	d.withdrawnTime = withdrawnTime
}

// WithdrawnHeight returns the block height recorded for withdrawal.
//
// Returns:
//   - withdrawnHeight: withdrawal block height; zero before withdrawal is recorded.
func (d Deposit) WithdrawnHeight() int64 {
	return d.withdrawnHeight
}

// SetWithdrawnHeight updates the block height recorded for withdrawal.
//
// Parameters:
//   - withdrawnHeight: block height at which the deposit was withdrawn.
func (d *Deposit) SetWithdrawnHeight(withdrawnHeight int64) {
	d.withdrawnHeight = withdrawnHeight
}

// EndTime returns the Unix timestamp at which the deposit's tier ends.
//
// Returns:
//   - endTime: tier end timestamp in Unix seconds.
func (d Deposit) EndTime() int64 {
	return d.endTime
}

// SetEndTime updates the Unix timestamp at which the deposit's tier ends.
//
// Parameters:
//   - endTime: tier end timestamp in Unix seconds.
func (d *Deposit) SetEndTime(endTime int64) {
	d.endTime = endTime
}

// ProjectTierID returns the composite identifier for the deposit's project tier.
//
// Returns:
//   - projectTierID: identifier formed from the project ID and tier duration.
func (d Deposit) ProjectTierID() string {
	return MakeProjectTierID(d.projectID, d.tier)
}

// IsDepositor reports whether an address matches the deposit owner.
//
// Parameters:
//   - address: account address to compare with the recorded depositor.
//
// Returns:
//   - matches: true when the supplied address has the same string representation as the depositor; false otherwise.
func (d Deposit) IsDepositor(address address) bool {
	return d.depositor.String() == address.String()
}

// IsEnded reports whether the deposit's tier end time is before the supplied time.
//
// Parameters:
//   - currentTime: current Unix timestamp in seconds used for the end-time comparison.
//
// Returns:
//   - ended: true when endTime is strictly less than currentTime; false at or before the end time.
func (d Deposit) IsEnded(currentTime int64) bool {
	return d.endTime < currentTime
}

// IsWithdrawn reports whether both withdrawal markers have been recorded.
//
// Returns:
//   - withdrawn: true when both withdrawnHeight and withdrawnTime are greater than zero; false when either marker is zero.
func (d Deposit) IsWithdrawn() bool {
	return d.withdrawnTime > 0 && d.withdrawnHeight > 0
}

// SetWithdrawn records the block height and Unix timestamp of withdrawal.
//
// Parameters:
//   - withdrawnHeight: block height at which the deposit was withdrawn.
//   - withdrawnTime: withdrawal timestamp in Unix seconds.
func (d *Deposit) SetWithdrawn(withdrawnHeight int64, withdrawnTime int64) {
	d.withdrawnHeight = withdrawnHeight
	d.withdrawnTime = withdrawnTime
}

// MakeDeposit returns a new Deposit value with the given values.
//
// Parameters:
//   - depositID: unique identifier to assign to the new deposit.
//   - projectID: launchpad project identifier associated with the deposit.
//   - tier: tier duration in days; launchpad tiers use 30, 90, or 180.
//   - depositor: account address making the deposit.
//   - depositAmount: amount of GNS deposited for the project.
//   - createdHeight: block height at which the deposit was created.
//   - createdTime: creation timestamp in Unix seconds.
//   - endTime: tier end timestamp in Unix seconds.
//
// Returns:
//   - deposit: new Deposit populated with the supplied fields and zero withdrawal markers.
func MakeDeposit(
	depositID string,
	projectID string,
	tier int64,
	depositor address,
	depositAmount int64,
	createdHeight int64,
	createdTime int64,
	endTime int64,
) Deposit {
	return Deposit{
		id:              depositID,
		projectID:       projectID,
		tier:            tier,
		depositor:       depositor,
		depositAmount:   depositAmount,
		withdrawnHeight: 0,
		createdHeight:   createdHeight,
		createdAt:       createdTime,
		endTime:         endTime,
	}
}

// DefaultDeposit returns the zero Deposit value.
//
// Returns:
//   - deposit: zero-valued Deposit with no identifier, amounts, timestamps, or withdrawal markers.
func DefaultDeposit() Deposit {
	return Deposit{}
}
