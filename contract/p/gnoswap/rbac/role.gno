package rbac

const maxVersionSize = int(9223372036854775807)

var zeroAddress = address("")

// Role represents a role with a name and an assigned address.
type Role struct {
	// name represents the role's identifier
	name          string
	addresses     map[int]string
	latestVersion int
}

// NewRole creates a new Role instance with roleName.
func NewRole(roleName string, addr address) *Role {
	return &Role{
		name:          roleName,
		addresses:     map[int]string{1: addr.String()},
		latestVersion: 1,
	}
}

// Name returns the role's name.
func (r *Role) Name() string { return r.name }

// Address returns the address assigned to this role. Returns empty address if no address is assigned.
func (r *Role) Address(version int) address {
	addr, exists := r.getAddress(version)
	if !exists {
		return zeroAddress
	}

	return address(addr)
}

func (r *Role) CurrentAddress() address {
	addr, exists := r.getAddress(r.latestVersion)
	if !exists {
		return zeroAddress
	}

	return address(addr)
}

// IsEmpty returns true if no address is assigned to this role.
func (r *Role) IsEmpty() bool {
	return r.CurrentAddress() == ""
}

// IsAuthorized returns true if addr matches the role's assigned address.
func (r *Role) IsAuthorized(addr address) bool {
	return r.CurrentAddress().String() == addr.String()
}

func (r *Role) getAddress(version int) (string, bool) {
	addr, exists := r.addresses[version]
	if exists {
		return addr, true
	}

	return "", false
}

// setAddress assigns addr to this role.
func (r *Role) setAddress(version int, addr address) error {
	_, exists := r.getAddress(version)
	if !exists {
		return ErrVersionDoesNotExist
	}

	r.addresses[version] = addr.String()

	return nil
}

func (r *Role) nextVersionAddress(addr address) error {
	latestVersion := r.latestVersion + 1
	if latestVersion >= maxVersionSize || latestVersion < 1 {
		return ErrCannotUpdateVersion
	}

	r.latestVersion = latestVersion
	r.addresses[r.latestVersion] = addr.String()

	return nil
}
