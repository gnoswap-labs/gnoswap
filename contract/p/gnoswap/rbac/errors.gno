package rbac

import "errors"

var (
	ErrNoPendingOwner      = errors.New("no pending owner")
	ErrUnauthorized        = errors.New("caller is not owner")
	ErrPendingUnauthorized = errors.New("caller is not pending owner")
	ErrInvalidAddress      = errors.New("new owner address is invalid")

	ErrRoleDoesNotExist         = errors.New("role does not exist")
	ErrRoleAlreadyExists        = errors.New("role already exists")
	ErrCannotRegisterSystemRole = errors.New("cannot register system role")
	ErrCannotRemoveSystemRole   = errors.New("cannot remove system role")
)
