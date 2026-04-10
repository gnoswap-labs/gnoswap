package halt

type HaltStateManager map[OpType]map[Action]bool

func (h HaltStateManager) IsActionHalted(domain OpType, action Action) (bool, error) {
	return h.getActionHalted(domain, action)
}

func (h HaltStateManager) ToConfig() HaltConfig {
	config := make(HaltConfig)
	for domain, actions := range h {
		config[domain] = make(map[Action]bool)
		for action, halted := range actions {
			config[domain][action] = halted
		}
	}
	return config
}

func (h HaltStateManager) getActionHalted(domain OpType, action Action) (bool, error) {
	if !domain.IsValid() {
		return false, makeErrorWithDetails(errInvalidOpType, domain.String())
	}
	if !action.IsValid() {
		return false, makeErrorWithDetails(errInvalidAction, action.String())
	}
	if !IsAllowedAction(domain, action) {
		return false, makeErrorWithDetails(errActionNotAllowed, policyKey(domain, action))
	}
	actions, exists := h[domain]
	if !exists {
		return false, makeErrorWithDetails(errPolicyNotFound, policyKey(domain, action))
	}
	halted, exists := actions[action]
	if !exists {
		return false, makeErrorWithDetails(errPolicyNotFound, policyKey(domain, action))
	}
	return halted, nil
}

func (h HaltStateManager) setActionHalted(domain OpType, action Action, halted bool) error {
	if !domain.IsValid() {
		return makeErrorWithDetails(errInvalidOpType, domain.String())
	}
	if !action.IsValid() {
		return makeErrorWithDetails(errInvalidAction, action.String())
	}
	if !IsAllowedAction(domain, action) {
		return makeErrorWithDetails(errActionNotAllowed, policyKey(domain, action))
	}
	if _, exists := h[domain]; !exists {
		h[domain] = make(map[Action]bool)
	}
	h[domain][action] = halted
	return nil
}

func (h HaltStateManager) updateByConfig(config HaltConfig) error {
	for domain, actions := range config {
		for action, halted := range actions {
			if err := h.setActionHalted(domain, action, halted); err != nil {
				return err
			}
		}
	}
	return nil
}

func newHaltStateManagerByConfig(config HaltConfig) HaltStateManager {
	haltState := make(HaltStateManager)
	for domain, actions := range allowedActionsByDomain {
		haltState[domain] = make(map[Action]bool)
		for action := range actions {
			halted := true
			if cfgActions, exists := config[domain]; exists {
				if cfgHalted, ok := cfgActions[action]; ok {
					halted = cfgHalted
				}
			}
			haltState[domain][action] = halted
		}
	}
	return haltState
}
