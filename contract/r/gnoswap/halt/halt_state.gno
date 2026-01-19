package halt

type HaltStateManager map[OpType]bool

func (h HaltStateManager) IsOperationHalted(op OpType) (bool, error) {
	return h.getOperationHalted(op)
}

// ToConfig converts the `HaltStateManager` to a HaltConfig.
func (h HaltStateManager) ToConfig() HaltConfig {
	config := make(HaltConfig)
	for op, halted := range h {
		config[op] = halted
	}
	return config
}

// getOperationHalted retrieves halt state for the specified operation type.
//
// Errors:
//   - errOpTypeNotFound: the specified operation type does not exist in the manager
func (h HaltStateManager) getOperationHalted(op OpType) (bool, error) {
	halted, exists := h[op]
	if !exists {
		return false, makeErrorWithDetails(errOpTypeNotFound, op.String())
	}

	return halted, nil
}

func (h HaltStateManager) setOperationHalted(op OpType, halted bool) error {
	if !op.IsValid() {
		return makeErrorWithDetails(errInvalidOpType, op.String())
	}

	h[op] = halted

	return nil
}

func (h HaltStateManager) updateOperationHaltsByConfig(config HaltConfig) error {
	for op, halted := range config {
		if err := h.setOperationHalted(op, halted); err != nil {
			return err
		}
	}

	return nil
}

func newHaltStateManagerByConfig(config HaltConfig) HaltStateManager {
	haltState := make(HaltStateManager)

	for _, op := range OpTypes() {
		halted, exists := config[op]
		if !exists {
			halted = true
		}

		haltState[op] = halted
	}

	return haltState
}
