package halt

import "errors"

type HaltStates map[OpType]*HaltState

func (h HaltStates) IsOperationHalted(op OpType) (bool, error) {
	state, exists := h[op]
	if !exists || state == nil {
		return true, errors.New("operation not found")
	}

	return state.IsHalted(state.LatestVersion())
}

func (h HaltStates) IsOperationHaltedWithVersion(op OpType, version int) (bool, error) {
	state, exists := h[op]
	if !exists || state == nil {
		return true, errors.New("operation not found")
	}

	return state.IsHalted(version)
}

func (h HaltStates) ToConfig() HaltConfig {
	config := make(HaltConfig)

	for op, state := range h {
		halted, err := state.IsHalted(state.LatestVersion())
		if err != nil {
			continue
		}

		config[op] = halted
	}

	return config
}

func (h HaltStates) setOperationHaltState(op OpType, halted bool) error {
	state, exists := h[op]
	if !exists || state == nil {
		return errors.New("operation not found")
	}

	return state.setState(state.LatestVersion(), halted)
}

func (h HaltStates) setOperationHaltStateWithVersion(op OpType, version int, halted bool) error {
	state, exists := h[op]
	if !exists || state == nil {
		return errors.New("operation not found")
	}

	return state.setState(version, halted)
}

func (h HaltStates) nextOperationHaltState(op OpType, halted bool) error {
	state, exists := h[op]
	if !exists || state == nil {
		return errors.New("operation not found")
	}

	return state.nextState(halted)
}

func (h HaltStates) updateOperationHaltStatesByConfig(config HaltConfig) error {
	for op, halted := range config {
		if err := h.setOperationHaltState(op, halted); err != nil {
			return err
		}
	}

	return nil
}

type HaltState struct {
	values        []bool
	latestVersion int
	mutable       bool
}

func (hs *HaltState) LatestVersion() int {
	return hs.latestVersion
}

func (hs *HaltState) IsHalted(version int) (bool, error) {
	index, exists := hs.getIndex(version)
	if !exists {
		return true, errors.New("version does not exist")
	}

	return hs.values[index], nil
}

func (hs *HaltState) hasVersion(version int) bool {
	if version < 1 || version > hs.latestVersion {
		return false
	}

	return true
}

func (hs *HaltState) getIndex(version int) (int, bool) {
	if hs.hasVersion(version) {
		return version - 1, true
	}

	return 0, false
}

func (hs *HaltState) setState(version int, halted bool) error {
	index, exists := hs.getIndex(version)
	if !exists {
		return errors.New("version does not exist")
	}

	hs.values[index] = halted

	return nil
}

func (hs *HaltState) nextState(halted bool) error {
	if !hs.mutable {
		return errors.New("cannot modify immutable state")
	}

	hs.values = append(hs.values, halted)
	hs.latestVersion = len(hs.values)

	return nil
}

func newImmutableState(halted bool) *HaltState {
	currentVersion := 1
	defaultValues := []bool{halted}

	return &HaltState{
		values:        defaultValues,
		latestVersion: currentVersion,
		mutable:       false,
	}
}

func newMutableState(halted bool) *HaltState {
	currentVersion := 1
	defaultValues := []bool{halted}

	return &HaltState{
		values:        defaultValues,
		latestVersion: currentVersion,
		mutable:       true,
	}
}

func newHaltStateByConfig(config HaltConfig) map[OpType]*HaltState {
	haltState := make(map[OpType]*HaltState)

	for _, op := range OpTypes() {
		halted, exists := config[op]
		if !exists {
			halted = true
		}

		if op.IsImmutable() {
			haltState[op] = newImmutableState(halted)
		} else {
			haltState[op] = newMutableState(halted)
		}
	}

	return haltState
}
