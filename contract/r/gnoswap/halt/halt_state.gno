package halt

import (
	"errors"

	"gno.land/p/nt/avl"
)

type HaltStateManager struct {
	states *avl.Tree
}

func (h *HaltStateManager) IsOperationHalted(op OpType) (bool, error) {
	return h.getOperationHalted(op)
}

func (h *HaltStateManager) ToConfig() HaltConfig {
	config := make(HaltConfig)

	h.states.Iterate("", "", func(key string, value any) bool {
		op := OpType(key)
		halted, err := h.getOperationHalted(op)
		if err != nil {
			return true
		}

		config[op] = halted
		return false
	})

	return config
}

func (h *HaltStateManager) getOperationHalted(op OpType) (bool, error) {
	haltedRaw, exists := h.states.Get(op.String())
	if !exists {
		return false, errors.New("operation not found")
	}

	halted, ok := haltedRaw.(bool)
	if !ok {
		return false, errors.New("failed to cast value to bool")
	}

	return halted, nil
}

func (h HaltStateManager) setOperationHalted(op OpType, halted bool) error {
	if !op.IsValid() {
		return makeErrorWithDetails(errInvalidOpType, op.String())
	}

	h.states.Set(op.String(), halted)

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
	haltState := HaltStateManager{
		states: avl.NewTree(),
	}

	for _, op := range OpTypes() {
		halted, exists := config[op]
		if !exists {
			halted = true
		}

		haltState.states.Set(op.String(), halted)
	}

	return haltState
}
