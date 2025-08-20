package txtar

import (
	"testing"

	"github.com/rogpeppe/go-internal/testscript"
)

// Example of basic usage
func ExampleNew() {
	// This is an example function, not an actual test
	var t *testing.T // In real usage, this would be provided by the test framework

	// Create a simple runner
	runner := New()
	runner.Run(t, "testdata")
}

// Example of advanced configuration
func ExampleNew_advanced() {
	var t *testing.T // In real usage, this would be provided by the test framework

	runner := New(
		// Use a specific gno binary
		WithGnoBinary("/usr/local/bin/gno"),

		// Set environment variables
		WithEnv("DEBUG", "true"),
		WithEnv("CUSTOM_PATH", "/custom/path"),

		// Enable verbose logging
		WithVerbose(true),

		// Custom setup logic
		WithSetup(func(env *testscript.Env) error {
			// Perform any additional setup
			env.Setenv("TEST_MODE", "integration")
			return nil
		}),
	)

	runner.Run(t, "testdata")
}
