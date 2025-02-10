package halt

import (
	"gno.land/p/demo/ufmt"
)

type Manager struct {
	currentLevel HaltLevel
	levels       map[uint8]HaltLevel
	operations   map[OpType]Operation
}

func NewManager() *Manager {
	// TODO: Initialize with default levels
	// TODO: p? r?
	return &Manager{
		levels:     make(map[uint8]HaltLevel),
		operations: make(map[OpType]Operation),
	}
}

func (m *Manager) validateTransition(newLevel uint8) error {
	current := m.currentLevel.Level()
	if current == newLevel {
		return nil
	}

	// TODO: add halt-related checks (policy-related things)

	return nil
}

// SetCurrentLevel adds a new halt level to the manager.
func (m *Manager) SetCurrentLevel(lv uint8) error {
	newLevel, ok := m.levels[lv]
	if !ok {
		return ufmt.Errorf("invalid halt level: %d", lv)
	}
	if err := m.validateTransition(lv); err != nil {
		return err
	}
	m.currentLevel = newLevel
	return nil
}

// RegisterOperation adds a new operation to the manager.
func (m *Manager) RegisterOperation(op Operation) {
	m.operations[op.Type()] = op
}
