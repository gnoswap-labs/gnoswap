package rbac

import (
	"std"
)

const (
	OwnershipTransferEvent        = "OwnershipTransfer"
	OwnershipTransferStartedEvent = "OwnershipTransferStarted"
)

// Ownable2Step implements a two-step ownership transfer mechanism.
// It requires the new owner to explicitly accept ownership before the transfer is completed,
// preventing accidental transfers to incorrect addresses.
type Ownable2Step struct {
	owner        std.Address
	pendingOwner std.Address
}

// newOwnable2StepWithAddress creates a new Ownable2Step instance with addr as owner.
func newOwnable2StepWithAddress(addr std.Address) *Ownable2Step {
	return &Ownable2Step{
		owner:        addr,
		pendingOwner: "",
	}
}

// TransferOwnership initiates ownership transfer by setting newOwner as pending owner.
// The new owner must call AcceptOwnership to complete the transfer.
// Only the current owner can call this function.
func (o *Ownable2Step) TransferOwnership(newOwner std.Address) error {
	if !o.OwnedByOriginCaller() {
		return ErrUnauthorized
	}

	if !newOwner.IsValid() {
		return ErrInvalidAddress
	}

	o.pendingOwner = newOwner

	std.Emit(
		OwnershipTransferStartedEvent,
		"from", o.owner.String(),
		"to", newOwner.String(),
	)

	return nil
}

// AcceptOwnership completes the ownership transfer.
// Must be called by the pending owner. Panics if no pending owner exists or caller is not the pending owner.
func (o *Ownable2Step) AcceptOwnership() error {
	if o.pendingOwner.String() == "" {
		return ErrNoPendingOwner
	}

	if std.OriginCaller() != o.pendingOwner {
		return ErrPendingUnauthorized
	}

	prevOwner := o.owner
	o.owner = o.pendingOwner
	o.pendingOwner = ""

	std.Emit(
		OwnershipTransferEvent,
		"from", prevOwner.String(),
		"to", o.owner.String(),
	)

	return nil
}

// DropOwnership removes the owner, disabling all owner-only actions.
// When used at the top level, it disables all owner-only functions.
// When embedded, it acts like a burn function, removing ownership from the struct.
// Only the current owner can call this function.
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

// Owner returns the current owner address. Returns empty address if ownership has been dropped.
func (o *Ownable2Step) Owner() std.Address {
	return o.owner
}

// PendingOwner returns the pending owner address during ownership transfer. Returns empty address if no transfer is pending.
func (o *Ownable2Step) PendingOwner() std.Address {
	return o.pendingOwner
}

// OwnedByOriginCaller returns true if the origin caller is the current owner.
func (o *Ownable2Step) OwnedByOriginCaller() bool {
	return std.OriginCaller() == o.owner
}
