package staker

import (
	"math"
)

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

// Withdraws returns all withdraws across all time buckets
func (d *Delegation) Withdraws() []*DelegationWithdraw {
	result := make([]*DelegationWithdraw, 0)
	d.withdraws.Iterate(0, math.MaxInt64, func(time int64, value any) bool {
		if slice, ok := value.([]*DelegationWithdraw); ok {
			result = append(result, slice...)
		}
		return false
	})
	return result
}

// IterateWithdrawsByTime iterates through withdraws grouped by collectableTime
// Only iterates over time range [start, end]
func (d *Delegation) IterateWithdrawsByTime(start, end int64, fn func(time int64, withdraws []*DelegationWithdraw) bool) {
	d.withdraws.Iterate(start, end, func(time int64, value any) bool {
		if slice, ok := value.([]*DelegationWithdraw); ok {
			return fn(time, slice)
		}
		return false
	})
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

// RemoveWithdrawsAtTime removes all withdraws at the given collectableTime
func (d *Delegation) RemoveWithdrawsAtTime(collectableTime int64) {
	d.withdraws.Remove(collectableTime)
}

// UpdateWithdrawsAtTime updates the withdraw slice at the given collectableTime
// If the slice is empty, the time bucket is removed from the tree
func (d *Delegation) UpdateWithdrawsAtTime(collectableTime int64, withdraws []*DelegationWithdraw) {
	if len(withdraws) == 0 {
		d.withdraws.Remove(collectableTime)
	} else {
		d.withdraws.Set(collectableTime, withdraws)
	}
}
