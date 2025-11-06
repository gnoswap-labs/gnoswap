// Copyright 2019 Gregory Petrosyan <gregory.petrosyan@gmail.com>
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package fuzz

import (
	"fmt"
	"testing"
)

const (
	small             = 5
	defaultChecks     = 1
	invalidChecksMult = 10
)

func assert(ok bool) {
	if !ok {
		panic("assertion failed")
	}
}

func assertf(ok bool, format string, args ...any) {
	if !ok {
		panic(fmt.Sprintf(format, args...))
	}
}

type invalidData string
type stopTest string

// T is similar to testing.T, but with extra bookkeeping for property-based tests.
type T struct {
	s        bitStream
	draws    int
	refDraws []any
	failed   stopTest
}

func newT(s bitStream, refDraws ...any) *T {
	return &T{
		s:        s,
		draws:    0,
		refDraws: refDraws,
		failed:   "",
	}
}

// Logf logs a formatted message.
func (t *T) Logf(format string, args ...any) {
	// In Gno, we can't use log.Logger, so we just format the message
	_ = fmt.Sprintf(format, args...)
}

// Log logs a message.
func (t *T) Log(args ...any) {
	// In Gno, we can't use log.Logger
	_ = fmt.Sprint(args...)
}

// Skipf is equivalent to Logf followed by SkipNow.
func (t *T) Skipf(format string, args ...any) {
	t.Logf(format, args...)
	t.skip(fmt.Sprintf(format, args...))
}

// Skip is equivalent to Log followed by SkipNow.
func (t *T) Skip(args ...any) {
	t.Log(args...)
	t.skip(fmt.Sprint(args...))
}

// SkipNow marks the current test case as invalid.
// If too many test cases are skipped, the test will fail due to
// inability to generate enough valid test cases.
//
// The test case or action will be treated like it had never been drawn
// and will not be shown in test logs.
// Therefore, to avoid confusing test failures later on,
// SkipNow must not be called after the action has already mutated shared state.
//
// Prefer Generator.Filter to SkipNow, and prefer generators that always produce
// valid test cases to Filter.
func (t *T) SkipNow() {
	t.skip("(*T).SkipNow() called")
}

// Errorf is equivalent to Logf followed by Fail.
func (t *T) Errorf(format string, args ...any) {
	t.Logf(format, args...)
	t.fail(false, fmt.Sprintf(format, args...))
}

// Error is equivalent to Log followed by Fail.
func (t *T) Error(args ...any) {
	t.Log(args...)
	t.fail(false, fmt.Sprint(args...))
}

// Fatalf is equivalent to Logf followed by FailNow.
func (t *T) Fatalf(format string, args ...any) {
	t.Logf(format, args...)
	t.fail(true, fmt.Sprintf(format, args...))
}

// Fatal is equivalent to Log followed by FailNow.
func (t *T) Fatal(args ...any) {
	t.Log(args...)
	t.fail(true, fmt.Sprint(args...))
}

// FailNow marks the test as failed and stops execution immediately.
func (t *T) FailNow() {
	t.fail(true, "(*T).FailNow() called")
}

// Fail marks the test as failed but continues execution.
func (t *T) Fail() {
	t.fail(false, "(*T).Fail() called")
}

// Failed returns whether the test has failed.
func (t *T) Failed() bool {
	return t.failed != ""
}

func (t *T) skip(msg string) {
	panic(invalidData(msg))
}

func (t *T) fail(now bool, msg string) {
	t.failed = stopTest(msg)
	if now {
		panic(t.failed)
	}
}

func (t *T) failOnError() {
	if t.failed != "" {
		panic(t.failed)
	}
}

// Check runs property-based tests by generating random test cases.
// It fails the test if it finds a test case that falsifies the property.
//
// The property function receives a *T which provides generator methods
// via Draw() and can be used to mark the test as failed.
//
// Example:
//
//	func TestProperty(t *testing.T) {
//	    fuzz.Check(t, func(ft *fuzz.T) {
//	        x := fuzz.Int64Range(0, 100).Draw(ft, "x").(int64)
//	        y := fuzz.Int64Range(0, 100).Draw(ft, "y").(int64)
//
//	        // Property: x + y should equal y + x (commutative)
//	        if x + y != y + x {
//	            ft.Fatalf("commutativity failed: %d + %d != %d + %d", x, y, y, x)
//	        }
//	    })
//	}
func Check(t *testing.T, prop func(*T)) {
	CheckN(t, defaultChecks, prop)
}

// CheckN runs property-based tests with a specific number of checks.
// It's like Check but allows you to specify how many random test cases to generate.
func CheckN(t *testing.T, checks int, prop func(*T)) {
	seed := baseSeed()

	valid := 0
	invalid := 0

	for valid < checks && invalid < checks*invalidChecksMult {
		iter := valid + invalid
		testSeed := seed + uint64(iter)

		s := newRandomBitStream(testSeed, false)
		ft := newT(s)

		err := checkOnce(ft, prop)

		if err == nil {
			valid++
		} else if isInvalidData(err) {
			invalid++
		} else {
			// Test failed
			t.Fatalf("[fuzz] failed after %d valid tests (seed %d): %v", valid, testSeed, err)
			return
		}
	}

	if valid == checks {
		t.Logf("[fuzz] OK, passed %d tests", valid)
	} else {
		t.Errorf("[fuzz] only generated %d valid tests from %d total", valid, valid+invalid)
	}
}

// checkOnce runs the property function once and catches panics
func checkOnce(ft *T, prop func(*T)) (err any) {
	defer func() {
		if r := recover(); r != nil {
			err = r
		}
	}()

	prop(ft)
	ft.failOnError()

	return nil
}

// isInvalidData checks if the error is an invalidData type
func isInvalidData(err any) bool {
	_, ok := err.(invalidData)
	return ok
}
