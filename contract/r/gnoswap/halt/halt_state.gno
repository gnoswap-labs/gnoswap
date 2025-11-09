package halt

import "errors"

type HaltStateManager map[OpType]bool

func (h HaltStateManager) IsOperationHalted(op OpType) (bool, error) {
	return h.getOperationHalted(op)
}

func (h HaltStateManager) ToConfig() HaltConfig {
	config := make(HaltConfig)

	for op := range h {
		halted, err := h.getOperationHalted(op)
		if err != nil {
			return config
		}

		config[op] = halted
	}

	return config
}

func (h HaltStateManager) getOperationHalted(op OpType) (bool, error) {
	halted, exists := h[op]
	if !exists {
		return false, errors.New("operation not found")
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
