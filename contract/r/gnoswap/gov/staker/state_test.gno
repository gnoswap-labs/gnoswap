package staker

import (
	"testing"

	"gno.land/p/nt/uassert"
	"gno.land/p/gnoswap/store"
)

// TestState_initializeDomainStore tests the private initializeDomainStore function
func TestState_initializeDomainStore(t *testing.T) {
	t.Run("initialize domain store", func(t *testing.T) {
		// given
		testKvStore := store.NewKVStore(currentAddress)

		// when
		result := initializeDomainStore(testKvStore)

		// then
		uassert.NotNil(t, result)
		_, ok := result.(IGovStakerStore)
		uassert.True(t, ok)
	})
}

// TestState_getImplementation tests the private getImplementation function
func TestState_getImplementation(t *testing.T) {
	t.Run("panic when implementation is nil", func(t *testing.T) {
		// given - save original implementation
		originalImpl := implementation
		implementation = nil

		// when & then - should panic
		defer func() {
			// restore original implementation
			implementation = originalImpl
		}()

		uassert.PanicsWithMessage(t, "implementation is not initialized", func() {
			getImplementation()
		})
	})

	t.Run("return implementation when set", func(t *testing.T) {
		// given - ensure implementation is set
		if implementation == nil {
			// Initialize if needed
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/staker/v1"))
			RegisterInitializer(cross, makeMockInitializer("v1"))
		}

		// when
		result := getImplementation()

		// then
		uassert.NotNil(t, result)
	})
}

// TestState_updateImplementation tests the private updateImplementation function
func TestState_updateImplementation(t *testing.T) {
	t.Run("error when no implementation in version manager", func(t *testing.T) {
		// given - reset state
		resetTestState(t)

		// when
		err := updateImplementation()

		// then
		uassert.NotNil(t, err)
		uassert.Equal(t, err.Error(), "implementation is not initialized")
	})

	t.Run("success when implementation exists", func(t *testing.T) {
		// given
		resetTestState(t)
		testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/staker/v1"))
		RegisterInitializer(cross, makeMockInitializer("v1"))

		// when
		err := updateImplementation()

		// then
		uassert.Nil(t, err)
		uassert.NotNil(t, implementation)
	})
}
