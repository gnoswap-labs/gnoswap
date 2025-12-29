package rbac

import "chain"

const (
	OwnershipTransferEvent        = "OwnershipTransfer"
	OwnershipTransferStartedEvent = "OwnershipTransferStarted"
)

// Ownable2Step implements a two-step ownership transfer mechanism.
// It requires the new owner to explicitly accept ownership before the transfer is completed,
// preventing accidental transfers to incorrect addresses.
type Ownable2Step struct {
	owner        address
	pendingOwner address
}

// newOwnable2StepWithAddress creates a new Ownable2Step instance with addr as owner.
func newOwnable2StepWithAddress(addr address) *Ownable2Step {
	return &Ownable2Step{
		owner:        addr,
		pendingOwner: "",
	}
}

// TransferOwnership initiates ownership transfer by setting newOwner as pending owner.
// The new owner must call AcceptOwnership to complete the transfer.
// Only the current owner can call this function.
func (o *Ownable2Step) TransferOwnershipBy(newOwner, caller address) error {
	if !o.IsOwner(caller) {
		return ErrUnauthorized
	}

	if newOwner == "" || !newOwner.IsValid() {
		return ErrInvalidAddress
	}

	o.pendingOwner = newOwner

	chain.Emit(
		OwnershipTransferStartedEvent,
		"from", o.owner.String(),
		"to", newOwner.String(),
	)

	return nil
}

// AcceptOwnership completes the ownership transfer.
// Must be called by the pending owner. Panics if no pending owner exists or caller is not the pending owner.
func (o *Ownable2Step) AcceptOwnershipBy(caller address) error {
	if o.pendingOwner == "" {
		return ErrNoPendingOwner
	}

	if !o.IsPendingOwner(caller) {
		return ErrPendingUnauthorized
	}

	prevOwner := o.owner
	o.owner = o.pendingOwner
	o.pendingOwner = ""

	chain.Emit(
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
func (o *Ownable2Step) DropOwnershipBy(caller address) error {
	if !o.IsOwner(caller) {
		return ErrUnauthorized
	}

	prevOwner := o.owner
	o.owner = ""
	o.pendingOwner = ""

	chain.Emit(
		OwnershipTransferEvent,
		"from", prevOwner.String(),
		"to", "",
	)

	return nil
}

// Owner returns the current owner address. Returns empty address if ownership has been dropped.
func (o *Ownable2Step) Owner() address {
	return o.owner
}

// PendingOwner returns the pending owner address during ownership transfer. Returns empty address if no transfer is pending.
func (o *Ownable2Step) PendingOwner() address {
	return o.pendingOwner
}

// IsOwner returns true if the origin caller is the current owner.
func (o *Ownable2Step) IsOwner(caller address) bool {
	return o.owner == caller
}

// IsPendingOwner returns true if the origin caller is the pending owner.
func (o *Ownable2Step) IsPendingOwner(caller address) bool {
	return o.pendingOwner == caller
}
