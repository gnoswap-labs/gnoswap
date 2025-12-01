// Staker contract upgrade scenario test
package main

import (
	"testing"
	"time"

	prbac "gno.land/p/gnoswap/rbac"
	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/staker"

	_ "gno.land/r/gnoswap/staker/insecure_staker_callback"
	_ "gno.land/r/gnoswap/staker/v1"
)

var t = &testing.T{}

var (
	adminAddr, _ = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)
)

const (
	stakerV1Path   = "gno.land/r/gnoswap/staker/v1"
	stakerTestPath = "gno.land/r/gnoswap/staker/insecure_staker_callback"
)

func main() {
	println("[SCENARIO] 1. Initialize staker contract with v1")
	initializeV1()
	println()

	println("[SCENARIO] 2. Initialize emission")
	initEmission()
	println()

	println("[SCENARIO] 3. Check emission before upgrade")
	checkEmission()
	println()

	println("[SCENARIO] 4. Upgrade staker contract to test version with unauthorized caller")
	testStakerUpgrade()
	println()
}

func initEmission() {
	println("[INFO] Initializing emission")
	testing.SetRealm(adminRealm)
	emission.SetDistributionStartTime(cross, time.Now().Unix()+1)
	testing.SkipHeights(1)
}

func checkEmission() {
	println("[INFO] Checking emission")
	emissionAmountPerSecond := gns.GetEmissionAmountPerSecondByTimestamp(time.Now().Unix())
	ufmt.Printf("[EXPECTED] Emission amount per second: %d\n", emissionAmountPerSecond)
}

func initializeV1() {
	currentVersion := staker.GetImplementationPackagePath()
	ufmt.Printf("[INFO] Current implementation: %s\n", currentVersion)

	if currentVersion != stakerV1Path {
		ufmt.Println("[INFO] Setting implementation to v1")
		testing.SetRealm(adminRealm)
		staker.UpgradeImpl(cross, stakerV1Path)
		currentVersion = staker.GetImplementationPackagePath()
	}

	ufmt.Printf("[EXPECTED] Staker initialized with v1: %s\n", currentVersion)
	if currentVersion != stakerV1Path {
		panic(ufmt.Sprintf("Expected v1, got %s", currentVersion))
	}
}

func testStakerUpgrade() {
	// Verify current version is v1
	currentVersion := staker.GetImplementationPackagePath()
	ufmt.Printf("[INFO] Current version: %s\n", currentVersion)
	if currentVersion != stakerV1Path {
		panic(ufmt.Sprintf("Expected v1, got %s", currentVersion))
	}

	// Upgrade to test version
	ufmt.Println("[INFO] Upgrading staker contract to test version")
	testing.SetRealm(adminRealm)

	// Should panic with unauthorized caller message
	expectedMsg := "unauthorized: caller g1q6d4ns7zkr492rgl0pcgf5ajaf2dlz0nnptky3 is not emission"

	msg, hasPanic := handleCrossPanic(func() {
		staker.UpgradeImpl(cross, stakerTestPath)
	})

	if !hasPanic {
		panic("upgrade must panic with unauthorized caller message")
	}

	if msg != expectedMsg {
		panic(ufmt.Sprintf("expected unauthorized caller message, got %s", msg))
	}

	ufmt.Println("[EXPECTED] Staker upgrade with unauthorized caller panics correctly")
}

func handleCrossPanic(fn func()) (string, bool) {
	r := revive(fn)
	if r == nil {
		return "", false
	}

	if err, ok := r.(error); ok {
		return err.Error(), true
	}

	if s, ok := r.(string); ok {
		return s, true
	}

	return "unsupported panic type", true
}

// Output:
// [SCENARIO] 1. Initialize staker contract with v1
// [INFO] Current implementation: gno.land/r/gnoswap/staker/v1
// [EXPECTED] Staker initialized with v1: gno.land/r/gnoswap/staker/v1
//
// [SCENARIO] 2. Initialize emission
// [INFO] Initializing emission
//
// [SCENARIO] 3. Check emission before upgrade
// [INFO] Checking emission
// [EXPECTED] Emission amount per second: 7134703
//
// [SCENARIO] 4. Upgrade staker contract to test version with unauthorized caller
// [INFO] Current version: gno.land/r/gnoswap/staker/v1
// [INFO] Upgrading staker contract to test version
// [EXPECTED] Staker upgrade with unauthorized caller panics correctly
