package rbac

import (
	"std"
)

const (
	OwnershipTransferEvent = "OwnershipTransfer"
	OwnershipAcceptedEvent = "OwnershipAccepted"
)

// Ownable2Step is a two-step ownership transfer package
// It allows the current owner to set a new owner and the new owner will need to accept the ownership before it is transferred
type Ownable2Step struct {
	owner        std.Address
	pendingOwner std.Address
}

func newOwnable2StepWithAddress(addr std.Address) *Ownable2Step {
	return &Ownable2Step{
		owner:        addr,
		pendingOwner: "",
	}
}

// TransferOwnership initiate the transfer of the ownership to a new address by setting the PendingOwner
func (o *Ownable2Step) TransferOwnership(newOwner std.Address) error {
	if !o.OwnedByOriginCaller() {
		return ErrUnauthorized
	}

	if !newOwner.IsValid() {
		return ErrInvalidAddress
	}

	o.pendingOwner = newOwner

	std.Emit(
		OwnershipTransferEvent,
		"from", o.owner.String(),
		"to", newOwner.String(),
	)

	return nil
}

// AcceptOwnership accepts the pending ownership transfer
func (o *Ownable2Step) AcceptOwnership() error {
	if o.pendingOwner.String() == "" {
		return ErrNoPendingOwner
	}
	
	if std.OriginCaller() != o.pendingOwner {
		return ErrPendingUnauthorized
	}

	o.owner = o.pendingOwner
	o.pendingOwner = ""

	std.Emit(
		OwnershipAcceptedEvent,
		"from", o.owner.String(),
		"to", o.pendingOwner.String(),
	)

	return nil
}

// DropOwnership removes the owner, effectively disabling any owner-related actions
// Top-level usage: disables all only-owner actions/functions,
// Embedded usage: behaves like a burn functionality, removing the owner from the struct
func (o *Ownable2Step) DropOwnership() error {
	if !o.OwnedByOriginCaller() {
		return ErrUnauthorized
	}

	prevOwner := o.owner
	o.owner = ""
	o.pendingOwner = ""

	std.Emit(
		OwnershipTransferEvent,
		"from", prevOwner.String(),
		"to", "",
	)

	return nil
}

// Owner returns the owner address from Ownable
func (o *Ownable2Step) Owner() std.Address {
	return o.owner
}

// PendingOwner returns the pending owner address from Ownable2Step
func (o *Ownable2Step) PendingOwner() std.Address {
	return o.pendingOwner
}

// OwnedByOriginCaller checks if the caller of the function is the Realm's owner
func (o *Ownable2Step) OwnedByOriginCaller() bool {
	return std.OriginCaller() == o.owner
}

// AssertOwnedByOriginCaller panics if the caller is not the owner
func (o *Ownable2Step) AssertOwnedByOriginCaller() {
	if std.OriginCaller() != o.owner {
		panic(ErrUnauthorized)
	}
}