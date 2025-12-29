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
	withdraws        *UintTree // key: collectableTime, value: []*DelegationWithdraw
}

// NewDelegation creates a new delegation
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
		withdraws:        NewUintTree(),
	}
}

// Basic getters
func (d *Delegation) ID() int64             { return d.id }
func (d *Delegation) DelegateFrom() address { return d.delegateFrom }
func (d *Delegation) DelegateTo() address   { return d.delegateTo }
func (d *Delegation) CreatedAt() int64      { return d.createdAt }

// Amount getters
func (d *Delegation) TotalDelegatedAmount() int64 { return d.delegateAmount }
func (d *Delegation) UnDelegatedAmount() int64    { return d.unDelegateAmount }
func (d *Delegation) CollectedAmount() int64      { return d.collectedAmount }

// Withdraws returns the underlying withdraws tree
func (d *Delegation) Withdraws() *UintTree {
	return d.withdraws
}

// Setters
func (d *Delegation) SetUnDelegateAmount(amount int64) {
	d.unDelegateAmount = amount
}

func (d *Delegation) SetCollectedAmount(amount int64) {
	d.collectedAmount = amount
}

func (d *Delegation) AddWithdraw(withdraw *DelegationWithdraw) {
	collectableTime := withdraw.CollectableTime()

	// Get existing slice for this time, or create new one
	var withdraws []*DelegationWithdraw
	if value, exists := d.withdraws.Get(collectableTime); exists {
		withdraws = value.([]*DelegationWithdraw)
	} else {
		withdraws = make([]*DelegationWithdraw, 0, 1)
	}

	// Append new withdraw and update tree
	withdraws = append(withdraws, withdraw)
	d.withdraws.Set(collectableTime, withdraws)
}
