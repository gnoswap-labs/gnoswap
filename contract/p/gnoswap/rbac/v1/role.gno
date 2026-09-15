package rbac

const zeroAddress = address("")

// Role represents a role with a name and an assigned address.
type Role struct {
	// name represents the role's identifier
	name    string
	address address
}

// NewRole creates a new Role instance with roleName.
//
// Parameters:
//   - roleName: Role identifier stored in the new Role without normalization.
//   - addr: Address stored as the role's initial assignment without validation.
//
// Returns:
//   - *Role: New role containing roleName and its initially assigned addr.
func NewRole(roleName string, addr address) *Role {
	return &Role{
		name:    roleName,
		address: addr,
	}
}

// Name returns the role's name.
//
// Returns:
//   - string: Role identifier stored in the Role.
func (r *Role) Name() string { return r.name }

// Address returns the address assigned to this role. Returns empty address if no address is assigned.
//
// Returns:
//   - address: Address currently assigned to the role, or the empty address when unassigned.
func (r *Role) Address() address {
	return r.address
}

// IsEmpty returns true if no address is assigned to this role.
//
// Returns:
//   - bool: true when the stored role address equals the empty address; false when an address is assigned.
func (r *Role) IsEmpty() bool {
	return r.Address() == zeroAddress
}

// IsAuthorized returns true if addr matches the role's assigned address.
//
// Parameters:
//   - addr: Address to compare with the role's stored assignment.
//
// Returns:
//   - bool: true when addr exactly equals the assigned address; false otherwise.
func (r *Role) IsAuthorized(addr address) bool {
	return r.Address() == addr
}

// setAddress assigns addr to this role.
func (r *Role) setAddress(addr address) {
	r.address = addr
}
