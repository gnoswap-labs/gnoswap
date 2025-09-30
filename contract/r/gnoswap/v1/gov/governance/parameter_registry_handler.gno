package governance

import "gno.land/p/nt/ufmt"

// ParameterRegistryHandler is an interface for handlers that need to manage state
// during parameter changes. This is an optional interface that handlers can implement
// if they need to save and restore state during governance operations.
type ParameterRegistryHandler interface {
	// GetState returns the current state that should be preserved
	GetState() interface{}
	// RestoreState restores the handler to the given state
	RestoreState(state interface{}) error
}

// stateManager handles state preservation for parameter handlers that implement
// the ParameterRegistryHandler interface. This allows for rollback capabilities
// during failed governance executions.
type stateManager struct {
	states map[string]*handlerState // Maps handler keys to their saved states
}

// newStateManager creates a new state manager instance.
//
// Returns:
//   - *stateManager: new state manager for parameter handlers
func newStateManager() *stateManager {
	return &stateManager{
		states: make(map[string]*handlerState),
	}
}

// SaveState preserves the current state of a parameter handler if it supports state management.
// Only handlers that implement ParameterRegistryHandler will have their state saved.
//
// Parameters:
//   - pkgPath: package path of the handler
//   - function: function name of the handler
//   - handler: the parameter handler instance
//
// Returns:
//   - error: always nil (state saving is optional)
func (sm *stateManager) SaveState(pkgPath, function string, handler ParameterHandler) error {
	key := makeHandlerKey(pkgPath, function)

	// Check if the handler implements the ParameterRegistryHandler interface
	if sh, ok := handler.(ParameterRegistryHandler); ok {
		// Save the current state for potential rollback
		sm.states[key] = &handlerState{
			pkgPath:  pkgPath,
			function: function,
			state:    sh.GetState(),
			handler:  handler,
		}
		return nil
	}

	// Handlers that do not implement the ParameterRegistryHandler interface do not need to save state
	return nil
}

// RestoreStates restores all saved handler states.
// This is used for rollback operations when governance execution fails.
//
// Returns:
//   - error: restoration error if any handler fails to restore
func (sm *stateManager) RestoreStates() error {
	for _, state := range sm.states {
		// Verify handler still implements the interface
		handler, ok := state.handler.(ParameterRegistryHandler)
		if !ok {
			return ufmt.Errorf("handler %s does not implement ParameterRegistryHandler", state.pkgPath)
		}

		// Restore the saved state
		err := handler.RestoreState(state.state)
		if err != nil {
			return ufmt.Errorf("failed to restore state for %s: %v",
				makeHandlerKey(state.pkgPath, state.function), err)
		}
	}

	return nil
}

// handlerState stores the preserved state information for a parameter handler.
type handlerState struct {
	pkgPath  string           // Package path of the handler
	function string           // Function name of the handler
	state    any              // Preserved state data
	handler  ParameterHandler // Reference to the handler instance
}

// registryHandler wraps existing functions as a ParameterHandler interface.
// This is a simple wrapper for functions that don't need state management.
type registryHandler struct {
	fn func(params []string) error // The wrapped function
}

// NewRegistryHandler creates a new registry handler wrapper around a function.
// This allows simple functions to be used as parameter handlers without implementing
// the full ParameterRegistryHandler interface.
//
// Parameters:
//   - fn: function to wrap as a parameter handler
//
// Returns:
//   - ParameterRegistryHandler: wrapped function that implements the interface
func NewRegistryHandler(fn func(params []string) error) ParameterRegistryHandler {
	return &registryHandler{fn}
}

// Execute runs the wrapped function with the provided parameters.
//
// Parameters:
//   - params: parameters to pass to the wrapped function
//
// Returns:
//   - error: execution error from the wrapped function
func (h *registryHandler) Execute(params []string) error {
	return h.fn(params)
}

// RestoreState is a no-op for simple registry handlers since they don't manage state.
//
// Parameters:
//   - state: state data (ignored)
//
// Returns:
//   - error: always nil
func (h *registryHandler) RestoreState(state interface{}) error {
	return nil
}

// GetState returns nil for simple registry handlers since they don't manage state.
//
// Returns:
//   - interface{}: always nil
func (h *registryHandler) GetState() interface{} {
	return nil
}
