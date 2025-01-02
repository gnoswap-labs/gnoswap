package launchpad

import (
    u256 "gno.land/p/gnoswap/uint256"
    "gno.land/p/demo/avl"
)

// ProjectStore stores project-related metadata
type ProjectStore struct {
	// all projects
	projects *avl.Tree // key: project ID, value: *Project

	// project information by tier
	projectsByTier *avl.Tree // key: tier, value: []string(projectIds)

	// project information by status
	projectsByStatus *avl.Tree // key: status, value: []string(projectIds)
}
