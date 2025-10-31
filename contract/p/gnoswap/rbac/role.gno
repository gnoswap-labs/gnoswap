package rbac

const maxVersionSize = int(9223372036854775807)

var zeroAddress = address("")

// Role represents a role with a name and an assigned address.
type Role struct {
	// name represents the role's identifier
	name    string
	address address
}

// NewRole creates a new Role instance with roleName.
func NewRole(roleName string, addr address) *Role {
	return &Role{
		name:    roleName,
		address: addr,
	}
}

// Name returns the role's name.
func (r *Role) Name() string { return r.name }

// Address returns the address assigned to this role. Returns empty address if no address is assigned.
func (r *Role) Address() address {
	return r.address
}

// IsEmpty returns true if no address is assigned to this role.
func (r *Role) IsEmpty() bool {
	return r.Address() == zeroAddress
}

// IsAuthorized returns true if addr matches the role's assigned address.
func (r *Role) IsAuthorized(addr address) bool {
	return r.Address() == addr
}

// setAddress assigns addr to this role.
func (r *Role) setAddress(addr address) {
	r.address = addr
}
