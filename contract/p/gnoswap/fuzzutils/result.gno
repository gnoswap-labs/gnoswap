package fuzzutils

import "gno.land/p/gnoswap/fuzz"

type Params interface {
	// IsValid reports whether the parameter set represents a case expected to satisfy the property.
	//
	// Returns:
	//   - bool: True when the parameters are expected to be valid for the property under test; false when the case is expected to fail.
	IsValid() bool
	// ToString returns a stable human-readable representation of the parameter set for logs.
	//
	// Returns:
	//   - string: Text describing the parameter values associated with a fuzz iteration.
	ToString() string
}

type Result struct {
	seed              uint64
	params            map[int]Params
	paramsValidStates map[int]bool
	errorMessages     map[int]string
	unexpectedResults map[int]bool
}

// SuccessCount returns the number of iterations without an unexpected outcome.
//
// Returns:
//   - int: Total recorded iterations minus the number marked unexpected.
func (r *Result) SuccessCount() int {
	return r.TotalCount() - r.UnexpectedResultsCount()
}

// UnexpectedResultsCount returns how many iterations disagreed with their expected validity.
//
// Returns:
//   - int: Number of entries recorded as unexpected results.
func (r *Result) UnexpectedResultsCount() int {
	return len(r.unexpectedResults)
}

// TotalCount returns the number of iterations with recorded parameters.
//
// Returns:
//   - int: Number of entries in the parameter map.
func (r *Result) TotalCount() int {
	return len(r.params)
}

// ErrorMessagesCount returns the number of iterations with recorded error messages.
//
// Returns:
//   - int: Number of entries in the error-message map.
func (r *Result) ErrorMessagesCount() int {
	return len(r.errorMessages)
}

// ErrorMessages returns the recorded iteration error messages.
//
// Returns:
//   - map[int]string: The internal map from iteration number to error text; the map is returned directly, not copied.
func (r *Result) ErrorMessages() map[int]string {
	return r.errorMessages
}

// IsValidState reports the expected validity recorded for an iteration.
//
// Parameters:
//   - iteration: Iteration number whose expected validity was recorded.
//
// Returns:
//   - bool: The stored expected-validity state for iteration; false when the iteration has no recorded true state.
func (r *Result) IsValidState(iteration int) bool {
	return r.paramsValidStates[iteration]
}

// AddParams records an iteration's generated parameters and expected validity.
//
// Parameters:
//   - iteration: Iteration number used as the key for the generated parameters and validity state.
//   - params: Parameter object that supplies the expected validity and string representation for this iteration.
func (r *Result) AddParams(iteration int, params Params) {
	r.params[iteration] = params
	r.paramsValidStates[iteration] = params.IsValid()
}

// AddErrorMessage associates an error message with an iteration.
//
// Parameters:
//   - iteration: Iteration number associated with the error.
//   - message: Error text to store for the iteration.
func (r *Result) AddErrorMessage(iteration int, message string) {
	r.errorMessages[iteration] = message
}

// AddUnexpectedResult marks an iteration whose observed outcome disagreed with its expected validity.
//
// Parameters:
//   - iteration: Iteration number to mark as having an unexpected result.
func (r *Result) AddUnexpectedResult(iteration int) {
	r.unexpectedResults[iteration] = true
}

// PrintLog writes aggregate counts and per-iteration error/unexpected-result details to t.
//
// Parameters:
//   - t: Test logger receiving the formatted result report.
func (r *Result) PrintLog(t fuzz.TestingT) {
	t.Logf("Total Count: %d", r.TotalCount())
	t.Logf("Success: %d", r.SuccessCount())
	t.Logf("Errors: %d", r.ErrorMessagesCount())
	t.Logf("Unexpected Results: %d", r.UnexpectedResultsCount())

	t.Logf("\n=== Error Messages ===")

	if r.ErrorMessagesCount() > 0 {
		for i := range r.errorMessages {
			paramStr := "failed load"

			if r.params[i] != nil {
				paramStr = r.params[i].ToString()
			}

			t.Logf("Iteration %d: %s\n - params: %s", i, r.errorMessages[i], paramStr)
		}
	} else {
		t.Logf(" - No error messages")
	}

	t.Logf("\n=== Unexpected Result Logs ===")

	if r.UnexpectedResultsCount() > 0 {
		for i := range r.unexpectedResults {
			paramStr := "failed load"

			if r.params[i] != nil {
				paramStr = r.params[i].ToString()
			}

			if r.paramsValidStates[i] {
				t.Logf("Iteration %d: %s\n - params: %s", i, r.errorMessages[i], paramStr)
			} else {
				t.Logf("Iteration %d: %s\n - params: %s", i, "should be failed but passed", paramStr)
			}
		}
	} else {
		t.Logf(" - No unexpected results")
	}
}

// NewFuzzResult creates an empty result accumulator for a fuzz run.
//
// Parameters:
//   - seed: Seed associated with the fuzz run.
//
// Returns:
//   - *Result: Result accumulator with seed stored and all tracking maps initialized empty.
func NewFuzzResult(seed uint64) *Result {
	return &Result{
		seed:              seed,
		params:            make(map[int]Params),
		paramsValidStates: make(map[int]bool),
		errorMessages:     make(map[int]string),
		unexpectedResults: make(map[int]bool),
	}
}
