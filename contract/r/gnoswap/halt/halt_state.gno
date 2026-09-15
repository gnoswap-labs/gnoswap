package halt

type HaltStateManager map[OpType]bool

// IsOperationHalted returns the halt state for an operation type.
//
// Parameters:
//   - op: operation type whose halt flag is queried.
//
// Returns:
//   - halted: configured halt flag for op.
//   - error: nil when op exists; otherwise errOpTypeNotFound.
func (h HaltStateManager) IsOperationHalted(op OpType) (bool, error) {
	return h.getOperationHalted(op)
}

// ToConfig converts the HaltStateManager to an independent HaltConfig copy.
//
// Returns:
//   - config: copied operation-to-halt-flag map.
func (h HaltStateManager) ToConfig() HaltConfig {
	config := make(HaltConfig)
	for op, halted := range h {
		config[op] = halted
	}
	return config
}

// getOperationHalted retrieves the halt state for the specified operation type.
//
// Parameters:
//   - op: operation type whose configured halt flag is queried.
//
// Returns:
//   - halted: configured halt flag for op.
//   - error: nil when op exists; otherwise errOpTypeNotFound.
func (h HaltStateManager) getOperationHalted(op OpType) (bool, error) {
	halted, exists := h[op]
	if !exists {
		return false, makeErrorWithDetails(errOpTypeNotFound, op.String())
	}

	return halted, nil
}

// setOperationHalted updates one operation's halt flag.
//
// Parameters:
//   - op: operation type whose halt status is changed.
//   - halted: true to block the operation, false to allow it.
//
// Returns:
//   - error: nil when op is valid and updated; otherwise an invalid-operation error.
func (h HaltStateManager) setOperationHalted(op OpType, halted bool) error {
	if !op.IsValid() {
		return makeErrorWithDetails(errInvalidOpType, op.String())
	}

	h[op] = halted

	return nil
}

// updateOperationHaltsByConfig applies every entry in a halt configuration to the manager.
//
// Parameters:
//   - config: operation-to-halt-flag map whose entries overwrite the manager's values.
//
// Returns:
//   - error: nil when every configured operation is valid; otherwise the first update error.
func (h HaltStateManager) updateOperationHaltsByConfig(config HaltConfig) error {
	for op, halted := range config {
		if err := h.setOperationHalted(op, halted); err != nil {
			return err
		}
	}

	return nil
}

// newHaltStateManagerByConfig creates a manager covering every supported operation.
// Operations absent from config default to halted.
//
// Parameters:
//   - config: initial operation-to-halt-flag map; missing supported operations default to true.
//
// Returns:
//   - manager: new halt-state map containing every operation returned by OpTypes().
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
