package fuzzing

import (
	"testing"

	_ "gno.land/r/onbloc/bar"
	_ "gno.land/r/onbloc/foo"
)

type Params interface {
	IsValid() bool
	ToString() string
}

type Result struct {
	seed              uint64
	params            map[int]Params
	paramsValidStates map[int]bool
	errorMessages     map[int]string
	unexpectedResults map[int]bool
}

func (r *Result) SuccessCount() int {
	return r.TotalCount() - r.UnexpectedResultsCount()
}

func (r *Result) UnexpectedResultsCount() int {
	return len(r.unexpectedResults)
}

func (r *Result) TotalCount() int {
	return len(r.params)
}

func (r *Result) ErrorMessagesCount() int {
	return len(r.errorMessages)
}

func (r *Result) ErrorMessages() map[int]string {
	return r.errorMessages
}

func (r *Result) IsValidState(iteration int) bool {
	return r.paramsValidStates[iteration]
}

func (r *Result) AddParams(iteration int, params Params) {
	r.params[iteration] = params
	r.paramsValidStates[iteration] = params.IsValid()
}

func (r *Result) AddErrorMessage(iteration int, message string) {
	r.errorMessages[iteration] = message
}

func (r *Result) AddUnexpectedResult(iteration int) {
	r.unexpectedResults[iteration] = true
}

func (r *Result) PrintLog(t *testing.T) {
	t.Logf("Total Count: %d", r.TotalCount())
	t.Logf("Success: %d", r.SuccessCount())
	t.Logf("Errors: %d", r.ErrorMessagesCount())
	t.Logf("Unexpected Results: %d", r.UnexpectedResultsCount())

	t.Logf("\n=== Error Messages ===")

	if r.ErrorMessagesCount() > 0 {
		for i, _ := range r.errorMessages {
			t.Logf("Iteration %d: %s\n - params: %s", i, r.errorMessages[i], r.params[i].ToString())
		}
	} else {
		t.Logf(" - No error messages")
	}

	t.Logf("\n=== Unexpected Result Logs ===")

	if r.UnexpectedResultsCount() > 0 {

		for i, _ := range r.unexpectedResults {
			if r.paramsValidStates[i] {
				t.Logf("Iteration %d: %s\n - params: %s", i, r.errorMessages[i], r.params[i].ToString())
			} else {
				t.Logf("Iteration %d: %s\n - params: %s", i, "should be failed but passed", r.params[i].ToString())
			}
		}
	} else {
		t.Logf(" - No unexpected results")
	}
}

func NewFuzzingResult(seed uint64) *Result {
	return &Result{
		seed:              seed,
		params:            make(map[int]Params),
		paramsValidStates: make(map[int]bool),
		errorMessages:     make(map[int]string),
		unexpectedResults: make(map[int]bool),
	}
}
