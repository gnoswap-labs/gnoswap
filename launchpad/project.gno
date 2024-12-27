package launchpad

import (
    "std"
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

type ProjectManager interface {
	CreateProject(name string, tokenPath string, recipient std.Address, params ProjectParams) (string, error)
	GetProject(projectId string) (*Project, error)
	UpdateProject(projectId string, params ProjectParams) error
	GetProjectTiers(projectId string) (map[string]*Tier, error) // TODO: change type
	IsProjectActive(projectId string) bool
	GetProjectsByTier(tier string) ([]*Project, error)
	GetProjectsByStatus(status ProjectStatus) ([]*Project, error)
}