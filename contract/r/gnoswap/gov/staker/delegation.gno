package staker

// DelegationType represents the type of delegation operation
type DelegationType string

const (
	DelegateType   DelegationType = "DELEGATE"
	UnDelegateType DelegationType = "UNDELEGATE"
)

func (d DelegationType) String() string     { return string(d) }
func (d DelegationType) IsDelegate() bool   { return d == DelegateType }
func (d DelegationType) IsUnDelegate() bool { return d == UnDelegateType }

// Delegation represents a delegation between two addresses
type Delegation struct {
	id               int64
	delegateAmount   int64
	unDelegateAmount int64
	collectedAmount  int64
	delegateFrom     address
	delegateTo       address
	createdHeight    int64
	createdAt        int64
	withdraws        []*DelegationWithdraw
}

// NewDelegation creates a new delegation.
//
// Parameters:
//   - id: unique delegation ID
//   - delegateFrom: delegator address
//   - delegateTo: delegatee address
//   - delegateAmount: amount of GNS to delegate
//   - createdHeight: block height when created
//   - createdAt: timestamp when created
//
// Returns:
//   - delegation: new delegation instance
func NewDelegation(
	id int64,
	delegateFrom, delegateTo address,
	delegateAmount, createdHeight, createdAt int64,
) *Delegation {
	return &Delegation{
		id:               id,
		delegateFrom:     delegateFrom,
		delegateTo:       delegateTo,
		delegateAmount:   delegateAmount,
		createdHeight:    createdHeight,
		createdAt:        createdAt,
		unDelegateAmount: 0,
		collectedAmount:  0,
		withdraws:        make([]*DelegationWithdraw, 0),
	}
}

// ID returns the unique delegation ID.
//
// Returns:
//   - id: delegation ID
func (d *Delegation) ID() int64 { return d.id }

// DelegateFrom returns the delegator address.
//
// Returns:
//   - address: delegator address
func (d *Delegation) DelegateFrom() address { return d.delegateFrom }

// DelegateTo returns the delegatee address.
//
// Returns:
//   - address: delegatee address
func (d *Delegation) DelegateTo() address { return d.delegateTo }

// CreatedAt returns the creation timestamp.
//
// Returns:
//   - timestamp: creation timestamp
func (d *Delegation) CreatedAt() int64 { return d.createdAt }

// TotalDelegatedAmount returns the total delegated amount.
//
// Returns:
//   - amount: total delegated amount
func (d *Delegation) TotalDelegatedAmount() int64 { return d.delegateAmount }

// UnDelegatedAmount returns the undelegated amount.
//
// Returns:
//   - amount: undelegated amount
func (d *Delegation) UnDelegatedAmount() int64 { return d.unDelegateAmount }

// CollectedAmount returns the collected amount.
//
// Returns:
//   - amount: collected amount
func (d *Delegation) CollectedAmount() int64 { return d.collectedAmount }

// Withdraws returns the list of delegation withdraws.
//
// Returns:
//   - withdraws: list of delegation withdraws
func (d *Delegation) Withdraws() []*DelegationWithdraw { return d.withdraws }

// SetUnDelegateAmount sets the undelegated amount.
//
// Parameters:
//   - amount: undelegated amount
func (d *Delegation) SetUnDelegateAmount(amount int64) {
	d.unDelegateAmount = amount
}

// SetCollectedAmount sets the collected amount.
//
// Parameters:
//   - amount: collected amount
func (d *Delegation) SetCollectedAmount(amount int64) {
	d.collectedAmount = amount
}

// AddWithdraw adds a withdrawal to the delegation.
//
// Parameters:
//   - withdraw: withdrawal to add
func (d *Delegation) AddWithdraw(withdraw *DelegationWithdraw) {
	d.withdraws = append(d.withdraws, withdraw)
}

// SetWithdraws sets the list of withdrawals.
//
// Parameters:
//   - withdraws: list of withdrawals
func (d *Delegation) SetWithdraws(withdraws []*DelegationWithdraw) {
	d.withdraws = withdraws
}

// Clone creates a deep copy of the delegation.
//
// Returns:
//   - delegation: cloned delegation instance
func (d *Delegation) Clone() *Delegation {
	if d == nil {
		return nil
	}

	clonedWithdraws := make([]*DelegationWithdraw, len(d.withdraws))
	for i, w := range d.withdraws {
		if w != nil {
			clonedWithdraws[i] = w.Clone()
		}
	}

	return &Delegation{
		id:               d.id,
		delegateAmount:   d.delegateAmount,
		unDelegateAmount: d.unDelegateAmount,
		collectedAmount:  d.collectedAmount,
		delegateFrom:     d.delegateFrom,
		delegateTo:       d.delegateTo,
		createdHeight:    d.createdHeight,
		createdAt:        d.createdAt,
		withdraws:        clonedWithdraws,
	}
}
