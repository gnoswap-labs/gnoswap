package launchpad

import (
	"std"
	"strings"

	"gno.land/p/demo/ufmt"
)

// DepositState represents the state of the deposits
// TODO: This state type will control global deposit state.
type DepositState struct {
	deposits              map[string]Deposit
	depositsByUser        map[std.Address][]string
	depositsByProject     map[string]map[string][]string
	depositsByUserProject map[std.Address]map[string][]string
}

func (d *DepositState) GetDeposit(id string) (Deposit, bool) {
	deposit, exists := d.deposits[id]
	return deposit, exists
}

func (d *DepositState) MustGetDeposit(id string) Deposit {
	deposit, exists := d.GetDeposit(id)
	if !exists {
		panic(ufmt.Sprintf("deposit not found: %s", id))
	}
	return deposit
}

func NewDepositState() *DepositState {
	return &DepositState{
		deposits:              make(map[string]Deposit),
		depositsByProject:     make(map[string]map[string][]string),
		depositsByUser:        make(map[std.Address][]string),
		depositsByUserProject: make(map[std.Address]map[string][]string),
	}
}

type Deposit struct {
	id        string // 'projectId:tier:depositor:height'
	projectId string
	tier      string // 30, 60, 180 // instead of tierId
	depositor std.Address
	amount    uint64

	depositHeight        uint64
	depositTime          uint64
	depositCollectHeight uint64 // withdraw deposited gns height
	depositCollectTime   uint64 // withdraw deposited gns timestamp

	claimableHeight uint64 // claimable reward block height
	claimableTime   uint64 // claimable reward timestamp

	rewardAmount        uint64 // calculated, not collected
	rewardCollected     uint64 // accu, collected
	rewardCollectHeight uint64 // last collected height
	rewardCollectTime   uint64 // last collected time
}

var _ DepositInfo = (*Deposit)(nil)

// getters and setters
// TODO: remove unused getters and setters
func (d *Deposit) ID() string                 { return d.id }
func (d *Deposit) SetID(v string)             { d.id = v }
func (d *Deposit) ProjectID() string          { return d.projectId }
func (d *Deposit) SetProjectID(v string)      { d.projectId = v }
func (d *Deposit) Tier() string               { return d.tier }
func (d *Deposit) SetTier(v string)           { d.tier = v }
func (d *Deposit) Depositor() std.Address     { return d.depositor }
func (d *Deposit) SetDepositor(v std.Address) { d.depositor = v }
func (d *Deposit) Amount() uint64             { return d.amount }
func (d *Deposit) SetAmount(v uint64)         { d.amount = v }

func (d *Deposit) ClaimableHeight() uint64 { return d.claimableHeight }
func (d *Deposit) ClaimableTime() uint64   { return d.claimableTime }

func NewDeposit(
	id, projectId, tier string,
	depositor std.Address,
	amount, depositHeight, depositTime uint64,
	depositCollectHeight, depositCollectTime uint64,
	claimableHeight, claimableTime uint64,
	rewardAmount, rewardCollected uint64,
	rewardCollectHeight, rewardCollectTime uint64,
) *Deposit {
	return &Deposit{
		id:                   id,
		projectId:            projectId,
		tier:                 tier,
		depositor:            depositor,
		amount:               amount,
		depositHeight:        depositHeight,
		depositTime:          depositTime,
		depositCollectHeight: depositCollectHeight,
		depositCollectTime:   depositCollectTime,
		claimableHeight:      claimableHeight,
		claimableTime:        claimableTime,
		rewardAmount:         rewardAmount,
		rewardCollected:      rewardCollected,
		rewardCollectHeight:  rewardCollectHeight,
		rewardCollectTime:    rewardCollectTime,
	}
}

// splitProjectIdAndTier extracts the project ID and tier from a given tier ID.
//
// This function splits the provided `tierId` into three parts using the `:` separator and
// returns the first two parts as the project ID and the third part as the tier.
//
// Parameters:
// - tierId (string): The tier ID in the format "{projectId}:{tier}".
//
// Returns:
// - string: The project ID derived from the first two parts of the `tierId`.
// - string: The tier derived from the third part of the `tierId`.
// - error: If the tier ID is invalid, an error is returned.
func SplitProjectIdAndTier(tierId string) (string, string, error) {
	res := strings.Split(tierId, ":")
	if len(res) != 3 {
		return "", "", ufmt.Errorf("invalid tierId: %s", tierId)
	}

	return ufmt.Sprintf("%s:%s", res[0], res[1]), res[2], nil
}

// ParseTierDuration converts a tier type string to its corresponding uint64 value.
//
// This function maps tier strings ("30", "90", "180") to predefined constants (`TIER30`, `TIER90`, `TIER180`).
// If the input string is invalid, the function panics.
//
// Parameters:
// - tierType (string): The tier type as a string.
//
// Returns:
// - uint64: The corresponding uint64 constant for the tier type.
// - error: If the tierType is invalid, an error is returned.
func ParseTierDuration(tierType string) (uint64, error) {
	switch tierType {
	case "30":
		return TIER30, nil
	case "90":
		return TIER90, nil
	case "180":
		return TIER180, nil
	default:
		return 0, ufmt.Errorf("invalid tierType: %s", tierType)
	}
}

// FromTierTypeStr converts a tier type string ("30", "90", "180") to its corresponding uint64 tier value.
// Panics if the tier type is invalid.
func FromTierType(tierType string) (uint64, error) {
	switch tierType {
	case "30":
		return TIER30, nil
	case "90":
		return TIER90, nil
	case "180":
		return TIER180, nil
	default:
		return 0, ufmt.Errorf("invalid tierType: %s", tierType)
	}
}
