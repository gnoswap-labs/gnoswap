package halt

import (
	"gno.land/p/demo/ufmt"
)

type Manager struct {
	currentLevel HaltLevel
	levels       map[LevelID]HaltLevel
	operations   map[OpType]Operation
}

type ManagerOption func(*Manager)

func WithOperations(ops []Operation) ManagerOption {
	return func(m *Manager) {
		for _, op := range ops {
			m.RegisterOperation(op)
		}
	}
}

func WithLevels(lvs HaltLevels) ManagerOption {
	return func(m *Manager) {
		for _, lv := range lvs {
			m.RegisterHaltLevel(lv)
		}
	}
}

func WithInitialLevel(lv LevelID) ManagerOption {
	return func(m *Manager) {
		if err := m.SetCurrentLevel(lv); err != nil {
			panic(err)
		}
	}
}

func NewManager(opts ...ManagerOption) *Manager {
	m := &Manager{
		levels:     make(map[LevelID]HaltLevel),
		operations: make(map[OpType]Operation),
	}

	for _, opt := range opts {
		opt(m)
	}

	return m
}

var (
	defaultOperations = []struct {
		opType OpType
		name   string
		desc   string
	}{
		{OpTypeSwap, rawSwap, "Token swap operation"},
		{OpTypeLiquidity, rawLiquidity, "Liquidity provision operations"},
		{OpTypeWithdraw, rawWithdraw, "Withdrawal operations"},
	}

	defaultLevels = []struct {
		id      LevelID
		name    string
		desc    string
		allowed map[OpType]bool
	}{
		{
			LvNoHalt,
			rawNoHalt,
			"Normal operation",
			map[OpType]bool{
				OpTypeSwap:      true,
				OpTypeLiquidity: true,
				OpTypeWithdraw:  true,
			},
		},
		{
			LvSwapHalt,
			rawSwapHalt,
			"Swaps disabled",
			map[OpType]bool{
				OpTypeSwap:      false,
				OpTypeLiquidity: true,
				OpTypeWithdraw:  true,
			},
		},
		{
			LvEmergencyHalt,
			rawEmergencyHalt,
			"Only withdrawals allowed",
			map[OpType]bool{
				OpTypeSwap:      false,
				OpTypeLiquidity: false,
				OpTypeWithdraw:  true,
			},
		},
	}
)

// DefaultManager creates a new default halt manager.
// Call this function in a realm-level contract to create global state.
func DefaultManager() *Manager {
	m := &Manager{
		levels:     make(map[LevelID]HaltLevel),
		operations: make(map[OpType]Operation),
	}

	// register default operations
	for _, op := range defaultOperations {
		m.RegisterOperation(NewOperation(op.opType, op.name, op.desc))
	}

	// register default halt levels
	for _, level := range defaultLevels {
		m.RegisterHaltLevel(NewHaltLevel(level.id, level.name, level.desc, level.allowed))
	}

	if err := m.SetCurrentLevel(LvNoHalt); err != nil {
		panic(err)
	}

	return m
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
