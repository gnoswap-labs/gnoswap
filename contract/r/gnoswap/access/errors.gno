package access

const (
	errInvalidAddress               = "invalid address for role %s: %s"
	errRoleDoesNotExist             = "role does not exist"
	errRoleNotFound                 = "role %s not found"
	errRoleDoesNotExistWithName     = "role %s does not exist"
	errUnauthorized                 = "unauthorized: caller %s is not %s"
	errUnauthorizedAdminOrGov       = "unauthorized: caller %s is not admin or governance"
	errUnauthorizedAnyRole          = "unauthorized: caller %s is not any of the roles %v"
	errUnauthorizedRBAC             = "unauthorized: caller %s is not rbac"
	errInvalidAddressShort          = "invalid address: %s"
	errCallerNotUser                = "caller is not user"
)
