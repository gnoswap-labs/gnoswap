package halt

// HaltConfig stores halt state for each domain/action policy key.
type HaltConfig map[OpType]map[Action]bool

func (c HaltConfig) IsHalted(domain OpType, action Action) bool {
	actions, exists := c[domain]
	if !exists {
		return false
	}
	halted, exists := actions[action]
	if !exists {
		return false
	}
	return halted
}

func (c HaltConfig) Clone() HaltConfig {
	clone := make(HaltConfig)
	for domain, actions := range c {
		clone[domain] = make(map[Action]bool)
		for action, halted := range actions {
			clone[domain][action] = halted
		}
	}
	return clone
}

func (c HaltConfig) get(domain OpType, action Action) (bool, error) {
	if !domain.IsValid() {
		return false, makeErrorWithDetails(errInvalidOpType, domain.String())
	}
	if !action.IsValid() {
		return false, makeErrorWithDetails(errInvalidAction, action.String())
	}
	if !IsAllowedAction(domain, action) {
		return false, makeErrorWithDetails(errActionNotAllowed, policyKey(domain, action))
	}
	actions, exists := c[domain]
	if !exists {
		return false, makeErrorWithDetails(errPolicyNotFound, policyKey(domain, action))
	}
	halted, exists := actions[action]
	if !exists {
		return false, makeErrorWithDetails(errPolicyNotFound, policyKey(domain, action))
	}
	return halted, nil
}

func (c HaltConfig) set(domain OpType, action Action, halted bool) error {
	if !domain.IsValid() {
		return makeErrorWithDetails(errInvalidOpType, domain.String())
	}
	if !action.IsValid() {
		return makeErrorWithDetails(errInvalidAction, action.String())
	}
	if !IsAllowedAction(domain, action) {
		return makeErrorWithDetails(errActionNotAllowed, policyKey(domain, action))
	}
	if _, exists := c[domain]; !exists {
		c[domain] = make(map[Action]bool)
	}
	c[domain][action] = halted
	return nil
}

func newBaseConfig(defaultHalted bool) HaltConfig {
	config := make(HaltConfig)
	for domain, actions := range allowedActionsByDomain {
		config[domain] = make(map[Action]bool)
		for action := range actions {
			config[domain][action] = defaultHalted
		}
	}
	return config
}

func newNoneConfig() HaltConfig {
	return newBaseConfig(false)
}

func newSafeModeConfig() HaltConfig {
	config := newNoneConfig()
	for domain := range allowedActionsByDomain {
		if IsAllowedAction(domain, ActionWithdraw) {
			config[domain][ActionWithdraw] = true
		}
	}
	return config
}

func newEmergencyConfig() HaltConfig {
	config := newBaseConfig(true)
	config[OpTypeGovernance][ActionOperate] = false
	for domain := range allowedActionsByDomain {
		if IsAllowedAction(domain, ActionWithdraw) {
			config[domain][ActionWithdraw] = false
		}
	}
	return config
}

func newCompleteConfig() HaltConfig {
	return newBaseConfig(true)
}
