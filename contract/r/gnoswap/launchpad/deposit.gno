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
// - tier (int64): The tier of the deposit.
// - depositAmount (int64): The amount of the deposit.
// - withdrawnHeight (int64): The height at which the deposit was withdrawn.
// - withdrawnTime (int64): The time when the deposit was withdrawn.
// - createdTime (int64): The time when the deposit was created.
// - endTime (int64): The time when the deposit ends.
type Deposit struct {
	depositor address

	id              string
	projectID       string
	tier            int64 // 30, 60, 180 // instead of tierId
	depositAmount   int64
	withdrawnHeight int64
	withdrawnTime   int64
	createdHeight   int64
	createdAt       int64
	endTime         int64
}

func (d *Deposit) ID() string {
	return d.id
}

func (d *Deposit) SetID(id string) {
	d.id = id
}

func (d *Deposit) ProjectID() string {
	return d.projectID
}

func (d *Deposit) SetProjectID(projectID string) {
	d.projectID = projectID
}

func (d *Deposit) Tier() int64 {
	return d.tier
}

func (d *Deposit) SetTier(tier int64) {
	d.tier = tier
}

func (d *Deposit) Depositor() address {
	return d.depositor
}

func (d *Deposit) SetDepositor(depositor address) {
	d.depositor = depositor
}

func (d *Deposit) DepositAmount() int64 {
	return d.depositAmount
}

func (d *Deposit) SetDepositAmount(depositAmount int64) {
	d.depositAmount = depositAmount
}

func (d *Deposit) CreatedHeight() int64 {
	return d.createdHeight
}

func (d *Deposit) SetCreatedHeight(createdHeight int64) {
	d.createdHeight = createdHeight
}

func (d *Deposit) CreatedAt() int64 {
	return d.createdAt
}

func (d *Deposit) SetCreatedAt(createdAt int64) {
	d.createdAt = createdAt
}

func (d *Deposit) WithdrawnTime() int64 {
	return d.withdrawnTime
}

func (d *Deposit) SetWithdrawnTime(withdrawnTime int64) {
	d.withdrawnTime = withdrawnTime
}

func (d *Deposit) WithdrawnHeight() int64 {
	return d.withdrawnHeight
}

func (d *Deposit) SetWithdrawnHeight(withdrawnHeight int64) {
	d.withdrawnHeight = withdrawnHeight
}

func (d *Deposit) EndTime() int64 {
	return d.endTime
}

func (d *Deposit) SetEndTime(endTime int64) {
	d.endTime = endTime
}

func (d *Deposit) ProjectTierID() string {
	return MakeProjectTierID(d.projectID, d.tier)
}

func (d *Deposit) IsDepositor(address address) bool {
	return d.depositor.String() == address.String()
}

func (d *Deposit) IsEnded(currentTime int64) bool {
	return d.endTime < currentTime
}

func (d *Deposit) IsWithdrawn() bool {
	return d.withdrawnTime > 0 && d.withdrawnHeight > 0
}

func (d *Deposit) SetWithdrawn(withdrawnHeight int64, withdrawnTime int64) {
	d.withdrawnHeight = withdrawnHeight
	d.withdrawnTime = withdrawnTime
}

// NewDeposit returns a pointer to a new Deposit with the given values.
func NewDeposit(
	depositID string,
	projectID string,
	tier int64,
	depositor address,
	depositAmount int64,
	createdHeight int64,
	createdTime int64,
	endTime int64,
) *Deposit {
	return &Deposit{
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
