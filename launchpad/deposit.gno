package launchpad


import (
    "std"

	u256 "gno.land/p/gnoswap/uint256"
    "gno.land/p/demo/avl"
)

// DepositStore stores deposit-related metadata
type DepositStore struct {
	// all deposits
	deposits *avl.Tree // key: deposit ID, value: *Deposit

	// deposits by project
	depositsByProject *avl.Tree // key: <project ID, tier>, value: []string(depositIds)

	// deposits by user
	depositsByUser *avl.Tree // key: user address, value: []string(depositIds)

	// deposits by user & project
	depositsByUserProject *avl.Tree // key: <user address, project ID>, value: []string(depositIds)
}

// DepositManager implements the deposit manager
type DepositManager interface {
	// AddDeposit adds a deposit to the store
	AddDeposit(projectId string, user std.Address, amount uint64, tier string) (string, error)

	// GetDeposit returns the deposit by depositId
	GetDeposit(depositId string) (*Deposit, error)

	// GetUserDeposits retrieves all of the user's deposits
	GetUserDeposits(user std.Address) ([]*Deposit, error)

	// GetProjectDeposits retrieves all of the project's deposits
	GetProjectDeposits(projectId string) ([]*Deposit, error)

	// CollectDeposit collects the deposit
	CollectDeposit(depositId string, user std.Address) (uint64, error)

	// UpdateDepositReward updates the deposit's reward
	UpdateDepositReward(depositId string, reward *u256.Uint) error
}