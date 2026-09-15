package staker

import bptree "gno.land/p/nt/bptree/v0"

// DelegationType represents the type of delegation operation
type DelegationType string

const (
	DelegateType   DelegationType = "DELEGATE"
	UnDelegateType DelegationType = "UNDELEGATE"
)

// String returns the textual operation name represented by the delegation type.
//
// Returns:
//   - string: "DELEGATE", "UNDELEGATE", or the underlying value for another type.
func (d DelegationType) String() string { return string(d) }

// IsDelegate reports whether the operation type is DelegateType.
//
// Returns:
//   - bool: true only when d represents a delegation operation.
func (d DelegationType) IsDelegate() bool { return d == DelegateType }

// IsUnDelegate reports whether the operation type is UnDelegateType.
//
// Returns:
//   - bool: true only when d represents an undelegation operation.
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
	withdraws        []DelegationWithdraw
}

// NewDelegation creates a delegation record with no undelegated or collected amount.
//
// Parameters:
//   - id: unique identifier assigned to this delegation record.
//   - delegateFrom: address whose tokens are delegated.
//   - delegateTo: address receiving the delegated voting power.
//   - delegateAmount: initial delegated token amount in the smallest token unit.
//   - createdHeight: block height at which the delegation was created.
//   - createdAt: Unix timestamp at which the delegation was created.
//
// Returns:
//   - *Delegation: initialized delegation with empty withdrawal history.
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
		withdraws:        make([]DelegationWithdraw, 0),
	}
}

// Basic getters
// ID returns the unique identifier of the delegation record.
//
// Returns:
//   - int64: delegation identifier assigned at creation.
func (d *Delegation) ID() int64 { return d.id }

// DelegateFrom returns the address that supplied the delegated tokens.
//
// Returns:
//   - address: delegator address recorded on the delegation.
func (d *Delegation) DelegateFrom() address { return d.delegateFrom }

// DelegateTo returns the address receiving the delegated voting power.
//
// Returns:
//   - address: delegatee address recorded on the delegation.
func (d *Delegation) DelegateTo() address { return d.delegateTo }

// CreatedAt returns the Unix timestamp recorded when the delegation was created.
//
// Returns:
//   - int64: creation timestamp in Unix seconds.
func (d *Delegation) CreatedAt() int64 { return d.createdAt }

// Amount getters
// TotalDelegatedAmount returns the current amount still actively delegated.
//
// Returns:
//   - int64: active delegated token amount in the smallest token unit.
func (d *Delegation) TotalDelegatedAmount() int64 { return d.delegateAmount }

// UnDelegatedAmount returns the amount moved into undelegation lockup.
//
// Returns:
//   - int64: token amount awaiting collection after its lockup period.
func (d *Delegation) UnDelegatedAmount() int64 { return d.unDelegateAmount }

// CollectedAmount returns the amount already collected from undelegation.
//
// Returns:
//   - int64: token amount released from this delegation.
func (d *Delegation) CollectedAmount() int64 { return d.collectedAmount }

// Withdraws getters
// Withdraws returns the delegation's withdrawal records.
//
// Returns:
//   - []DelegationWithdraw: withdrawal entries tracked for this delegation.
func (d *Delegation) Withdraws() []DelegationWithdraw { return d.withdraws }

// Setters
// SetUnDelegateAmount replaces the amount currently in undelegation lockup.
//
// Parameters:
//   - amount: token amount awaiting collection in the smallest token unit.
func (d *Delegation) SetUnDelegateAmount(amount int64) {
	d.unDelegateAmount = amount
}

// SetCollectedAmount replaces the amount already collected from this delegation.
//
// Parameters:
//   - amount: released token amount in the smallest token unit.
func (d *Delegation) SetCollectedAmount(amount int64) {
	d.collectedAmount = amount
}

// AddWithdraw appends a withdrawal record to the delegation history.
//
// Parameters:
//   - withdraw: withdrawal record to append, including its amount and unlock timing.
func (d *Delegation) AddWithdraw(withdraw DelegationWithdraw) {
	d.withdraws = append(d.withdraws, withdraw)
}

// SetWithdraw replaces one withdrawal record at the supplied slice index.
//
// Parameters:
//   - index: zero-based index of the withdrawal entry to replace.
//   - withdraw: replacement withdrawal record.
func (d *Delegation) SetWithdraw(index int, withdraw DelegationWithdraw) {
	d.withdraws[index] = withdraw
}

// SetWithdraws replaces the complete withdrawal history.
//
// Parameters:
//   - withdraws: withdrawal records to store for this delegation.
func (d *Delegation) SetWithdraws(withdraws []DelegationWithdraw) {
	d.withdraws = withdraws
}

// Clone returns a deep copy of the delegation and its withdrawal slice.
//
// Returns:
//   - *Delegation: copied delegation, or nil when the receiver is nil.
func (d *Delegation) Clone() *Delegation {
	if d == nil {
		return nil
	}

	clonedWithdraws := make([]DelegationWithdraw, len(d.withdraws))
	copy(clonedWithdraws, d.withdraws)

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

// NewDelegationTree creates an empty tree for delegatee-to-delegation-ID mappings.
//
// Returns:
//   - *bptree.BPTree: empty tree configured for delegation lookup entries.
func NewDelegationTree() *bptree.BPTree {
	return bptree.NewBPTreeN(16)
}

// NewUserDelegationTree creates an empty tree for user delegation mappings.
// Returns:
//   - *bptree.BPTree: empty tree configured for user delegation entries.
func NewUserDelegationTree() *bptree.BPTree {
	return bptree.NewBPTreeN(16)
}
