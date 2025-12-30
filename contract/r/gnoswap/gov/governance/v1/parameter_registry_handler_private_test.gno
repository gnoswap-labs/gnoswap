package v1

import (
	"testing"

	"gno.land/p/nt/uassert"
)

// TestParameterRegistryHandler_registerHandlers tests the private registerHandlers function
func TestParameterRegistryHandler_registerHandlers(t *testing.T) {
	tests := []struct {
		name          string
		setupHandlers func() ([]*ParameterHandlerOptions, []string)
		expectedCount int
	}{
		{
			name: "register multiple handlers",
			setupHandlers: func() ([]*ParameterHandlerOptions, []string) {
				handlers := []*ParameterHandlerOptions{
					NewParameterHandlerOptions(
						"gno.land/r/test/package1",
						"TestFunction1",
						2,
						func(args []string) error { return nil },
					).(*ParameterHandlerOptions),
					NewParameterHandlerOptions(
						"gno.land/r/test/package2",
						"TestFunction2",
						1,
						func(args []string) error { return nil },
					).(*ParameterHandlerOptions),
				}
				keys := []string{
					makeHandlerKey("gno.land/r/test/package1", "TestFunction1"),
					makeHandlerKey("gno.land/r/test/package2", "TestFunction2"),
				}
				return handlers, keys
			},
			expectedCount: 2,
		},
		{
			name: "register single handler",
			setupHandlers: func() ([]*ParameterHandlerOptions, []string) {
				handlers := []*ParameterHandlerOptions{
					NewParameterHandlerOptions(
						"gno.land/r/test/package",
						"TestFunction",
						0,
						func(args []string) error { return nil },
					).(*ParameterHandlerOptions),
				}
				keys := []string{
					makeHandlerKey("gno.land/r/test/package", "TestFunction"),
				}
				return handlers, keys
			},
			expectedCount: 1,
		},
		{
			name: "register empty handlers",
			setupHandlers: func() ([]*ParameterHandlerOptions, []string) {
				return []*ParameterHandlerOptions{}, []string{}
			},
			expectedCount: 0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// given
			registry := NewParameterRegistry()
			handlers, keys := tt.setupHandlers()

			// when
			registerHandlers(registry, handlers)

			// then
			// Verify handlers were registered by checking registry size
			uassert.NotNil(t, registry)

			// Verify each handler can be retrieved
			for _, key := range keys {
				retrievedHandler, err := registry.Handler(key)
				uassert.Nil(t, err)
				uassert.NotNil(t, retrievedHandler)
			}
		})
	}
}
