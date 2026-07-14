package rbac

const (
	ErrNoPendingOwner      = "no pending owner"
	ErrUnauthorized        = "caller is not owner"
	ErrPendingUnauthorized = "caller is not pending owner"
	ErrInvalidAddress      = "invalid address"

	ErrInvalidRoleName        = "invalid role name"
	ErrRoleDoesNotExist       = "role does not exist"
	ErrRoleAlreadyExists      = "role already exists"
	ErrCannotRemoveSystemRole = "cannot remove system role"
)
