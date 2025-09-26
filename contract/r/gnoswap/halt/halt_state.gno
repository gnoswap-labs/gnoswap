package halt

import "errors"

const maxVersionSize = 9223372036854775807

type HaltStateManager map[OpType]*HaltState

func (h HaltStateManager) GetOperationVersion(op OpType) (int, error) {
	state, err := h.getOperationHaltState(op)
	if err != nil {
		return 0, err
	}

	return state.LatestVersion(), nil
}

func (h HaltStateManager) IsOperationHalted(op OpType) (bool, error) {
	state, err := h.getOperationHaltState(op)
	if err != nil {
		return true, err
	}

	return state.IsHalted(state.LatestVersion())
}

func (h HaltStateManager) IsOperationHaltedWithVersion(op OpType, version int) (bool, error) {
	state, err := h.getOperationHaltState(op)
	if err != nil {
		return true, err
	}

	return state.IsHalted(version)
}

func (h HaltStateManager) ToConfig() HaltConfig {
	config := make(HaltConfig)

	for op, state := range h {
		halted, exists := state.getState(state.LatestVersion())
		if !exists {
			continue
		}

		config[op] = halted
	}

	return config
}

func (h HaltStateManager) getOperationHaltState(op OpType) (*HaltState, error) {
	state, exists := h[op]
	if !exists || state == nil {
		return nil, errors.New("operation not found")
	}

	return state, nil
}

func (h HaltStateManager) setOperationHaltState(op OpType, version int, halted bool) error {
	state, err := h.getOperationHaltState(op)
	if err != nil {
		return err
	}

	return state.setState(version, halted)
}

func (h HaltStateManager) setOperationHaltStateNextVersion(op OpType, halted bool) error {
	state, err := h.getOperationHaltState(op)
	if err != nil {
		return err
	}

	return state.nextState(halted)
}

func (h HaltStateManager) updateOperationHaltStatesByConfig(config HaltConfig) error {
	for op, halted := range config {
		version, err := h.GetOperationVersion(op)
		if err != nil {
			return err
		}

		if err := h.setOperationHaltState(op, version, halted); err != nil {
			return err
		}
	}

	return nil
}

type HaltState struct {
	values        map[int]bool
	latestVersion int
}

func (hs *HaltState) LatestVersion() int {
	return hs.latestVersion
}

func (hs *HaltState) IsHalted(version int) (bool, error) {
	versionState, exists := hs.getState(version)
	if !exists {
		return true, errors.New("version does not exist")
	}

	return versionState, nil
}

func (hs *HaltState) getState(version int) (bool, bool) {
	versionState, exists := hs.values[version]
	if !exists {
		return false, false
	}

	return versionState, true
}

func (hs *HaltState) setState(version int, halted bool) error {
	_, exists := hs.getState(version)
	if !exists {
		return errors.New("version does not exist")
	}

	hs.values[version] = halted

	return nil
}

func (hs *HaltState) nextState(halted bool) error {
	latestVersion := hs.latestVersion + 1
	if latestVersion >= maxVersionSize || latestVersion < 1 {
		return errCannotUpdateVersion
	}

	hs.latestVersion = latestVersion
	hs.values[hs.latestVersion] = halted

	return nil
}

func newHaltState(halted bool) *HaltState {
	currentVersion := 1
	defaultValues := map[int]bool{1: halted}

	return &HaltState{
		values:        defaultValues,
		latestVersion: currentVersion,
	}
}

func newHaltStateManagerByConfig(config HaltConfig) map[OpType]*HaltState {
	haltState := make(map[OpType]*HaltState)

	for _, op := range OpTypes() {
		halted, exists := config[op]
		if !exists {
			halted = true
		}

		haltState[op] = newHaltState(halted)
	}

	return haltState
}
