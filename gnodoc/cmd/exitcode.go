package cmd

// ExitCode represents CLI exit codes.
type ExitCode int

const (
	// ExitSuccess indicates successful execution.
	ExitSuccess ExitCode = 0

	// ExitError indicates a fatal error (input error, module detection failure, render failure).
	ExitError ExitCode = 1

	// ExitPartialError indicates partial file parsing failure.
	// Used when --ignore-parse-errors is set but some files failed.
	ExitPartialError ExitCode = 2
)

// String returns the string representation of the exit code.
func (c ExitCode) String() string {
	switch c {
	case ExitSuccess:
		return "success"
	case ExitError:
		return "error"
	case ExitPartialError:
		return "partial error"
	default:
		return "unknown"
	}
}
