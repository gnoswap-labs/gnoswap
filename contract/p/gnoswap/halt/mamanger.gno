package halt

import (
	"gno.land/p/demo/ufmt"
)

type Manager struct {
	currentLevel HaltLevel
	levels       map[LevelID]HaltLevel
	operations   map[OpType]Operation
}

// DefaultManager creates a new default halt manager.
// Call this function in a realm-level contract to create global state.
func DefaultManager() *Manager {
	manager := &Manager{
		levels:     make(map[LevelID]HaltLevel),
		operations: make(map[OpType]Operation),
	}

	// basic operations
	manager.RegisterOperation(NewOperation(OpTypeSwap, "Swap", "Token swap operation"))
	manager.RegisterOperation(NewOperation(OpTypeLiquidity, "Liquidity", "Liquidity provision operations"))
	manager.RegisterOperation(NewOperation(OpTypeWithdraw, "Withdraw", "Withdrawal operations"))

	// basic halt level registry
	manager.RegisterHaltLevel(NewHaltLevel(LvNoHalt, "NoHalt", "Normal operation", map[OpType]bool{
		OpTypeSwap:      true,
		OpTypeLiquidity: true,
		OpTypeWithdraw:  true,
	}))

	manager.RegisterHaltLevel(NewHaltLevel(LvSwapHalt, "SwapHalt", "Swaps disabled", map[OpType]bool{
		OpTypeSwap:      false,
		OpTypeLiquidity: true,
		OpTypeWithdraw:  true,
	}))

	manager.RegisterHaltLevel(NewHaltLevel(LvEmergencyHalt, "EmergencyHalt", "Only withdrawals allowed", map[OpType]bool{
		OpTypeSwap:      false,
		OpTypeLiquidity: false,
		OpTypeWithdraw:  true,
	}))

	if err := manager.SetCurrentLevel(LvNoHalt); err != nil {
		panic(err)
	}

	return manager
}

// SetCurrentLevel adds a new halt level to the manager.
func (m *Manager) SetCurrentLevel(lv LevelID) error {
	newLevel, ok := m.levels[lv]
	if !ok {
		return ufmt.Errorf("invalid halt level: %d", lv)
	}
	m.currentLevel = newLevel
	return nil
}

// RegisterOperation adds a new operation to the manager.
func (m *Manager) RegisterOperation(op Operation) {
	m.operations[op.Type()] = op
}

func (m *Manager) RegisterHaltLevel(lv HaltLevel) {
	m.levels[lv.Level()] = lv
}

func (m *Manager) Status(o OpType) string {
	return m.currentLevel.Name()
}

func (m *Manager) Level() HaltLevel {
	return m.currentLevel
}
