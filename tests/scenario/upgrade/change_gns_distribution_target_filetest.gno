// change gns distribution target for upgrade
package main

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/ufmt"

	"gno.land/p/gnoswap/consts"
	prbac "gno.land/p/gnoswap/rbac"

	"gno.land/r/gnoswap/v1/access"
	"gno.land/r/gnoswap/v1/emission"
	"gno.land/r/gnoswap/v1/gns"
	"gno.land/r/gnoswap/v1/rbac"
)

var t *testing.T

var (
	adminAddr, _ = access.GetAddress(prbac.ROLE_ADMIN.String())

	// current distribution targets
	stakerAddr, _        = access.GetAddress(prbac.ROLE_STAKER.String())
	govStakerAddr, _     = access.GetAddress(prbac.ROLE_GOV_STAKER.String())
	devOpsAddr, _        = access.GetAddress(prbac.ROLE_DEVOPS.String())
	communityPoolAddr, _ = access.GetAddress(prbac.ROLE_COMMUNITY_POOL.String())

	// new distribution targets for upgrade
	newGovStakerAddr     = testutils.TestAddress("newGovStakerAddr")
	newDevOpsAddr        = testutils.TestAddress("newDevOpsAddr")
	newCommunityPoolAddr = testutils.TestAddress("newCommunityPoolAddr")
	newStakerAddr        = testutils.TestAddress("newStakerAddr")
)

func main() {
	println("[SCENARIO] 1. Initialize emission")
	initEmission()
	println()

	ufmt.Println("[SCENARIO] 2. Mint to distribution target (before upgrade)")
	testing.SkipHeights(1)
	ufmt.Println("[INFO] current block height", std.ChainHeight())
	mintAndDistribute()
	println()

	println("[SCENARIO] 3. Change distribution target for upgrade")
	changeDistributionTarget()
	println()

	println("[SCENARIO] 4. Mint to distribution target (after upgrade)")
	testing.SkipHeights(1)
	println("[INFO] current block height", std.ChainHeight())
	mintAndDistribute()
	println()
}

func initEmission() {
	emission.MintAndDistributeGns(cross)
}

func mintAndDistribute() {
	testing.SetRealm(std.NewCodeRealm(consts.EMISSION_PATH))

	previousStakerBalance := gns.BalanceOf(stakerAddr)
	previousGovStakerBalance := gns.BalanceOf(govStakerAddr)
	previousDevOpsBalance := gns.BalanceOf(devOpsAddr)
	previousCommunityPoolBalance := gns.BalanceOf(communityPoolAddr)

	previousNewStakerBalance := gns.BalanceOf(newStakerAddr)
	previousNewGovStakerBalance := gns.BalanceOf(newGovStakerAddr)
	previousNewDevOpsBalance := gns.BalanceOf(newDevOpsAddr)
	previousNewCommunityPoolBalance := gns.BalanceOf(newCommunityPoolAddr)

	emission.MintAndDistributeGns(cross)

	stakerBalanceChange := gns.BalanceOf(stakerAddr) - previousStakerBalance
	govStakerBalanceChange := gns.BalanceOf(govStakerAddr) - previousGovStakerBalance
	devOpsBalanceChange := gns.BalanceOf(devOpsAddr) - previousDevOpsBalance
	communityPoolBalanceChange := gns.BalanceOf(communityPoolAddr) - previousCommunityPoolBalance

	newStakerBalanceChange := gns.BalanceOf(newStakerAddr) - previousNewStakerBalance
	newGovStakerBalanceChange := gns.BalanceOf(newGovStakerAddr) - previousNewGovStakerBalance
	newDevOpsBalanceChange := gns.BalanceOf(newDevOpsAddr) - previousNewDevOpsBalance
	newCommunityPoolBalanceChange := gns.BalanceOf(newCommunityPoolAddr) - previousNewCommunityPoolBalance

	totalMintedAmount := gns.GetMintedEmissionAmount()

	ufmt.Printf("[EXPECTED] total minted amount should be %d\n", totalMintedAmount)
	ufmt.Printf("[EXPECTED] (v1) staker balance change should be %d\n", stakerBalanceChange)
	ufmt.Printf("[EXPECTED] (v1) gov staker balance change should be %d\n", govStakerBalanceChange)
	ufmt.Printf("[EXPECTED] (v1) dev ops balance change should be %d\n", devOpsBalanceChange)
	ufmt.Printf("[EXPECTED] (v1) community pool balance change should be %d\n", communityPoolBalanceChange)
	ufmt.Printf("[EXPECTED] (new) staker balance change should be %d\n", newStakerBalanceChange)
	ufmt.Printf("[EXPECTED] (new) gov staker balance change should be %d\n", newGovStakerBalanceChange)
	ufmt.Printf("[EXPECTED] (new) dev ops balance change should be %d\n", newDevOpsBalanceChange)
	ufmt.Printf("[EXPECTED] (new) community pool balance change should be %d\n", newCommunityPoolBalanceChange)

}

func changeDistributionTarget() {
	testing.SetOriginCaller(adminAddr)

	rbac.UpdateRoleAddress(cross, prbac.ROLE_STAKER.String(), newStakerAddr)
	rbac.UpdateRoleAddress(cross, prbac.ROLE_GOV_STAKER.String(), newGovStakerAddr)
	rbac.UpdateRoleAddress(cross, prbac.ROLE_DEVOPS.String(), newDevOpsAddr)
	rbac.UpdateRoleAddress(cross, prbac.ROLE_COMMUNITY_POOL.String(), newCommunityPoolAddr)

	ufmt.Printf("[EXPECTED] staker address should be changed %s to %s\n", stakerAddr, newStakerAddr)
	ufmt.Printf("[EXPECTED] gov staker address should be changed %s to %s\n", govStakerAddr, newGovStakerAddr)
	ufmt.Printf("[EXPECTED] dev ops address should be changed %s to %s\n", devOpsAddr, newDevOpsAddr)
	ufmt.Printf("[EXPECTED] community pool address should be changed %s to %s\n", communityPoolAddr, newCommunityPoolAddr)
}

// Output:
// [SCENARIO] 1. Initialize emission
//
// [SCENARIO] 2. Mint to distribution target (before upgrade)
// [INFO] current block height 124
// [EXPECTED] total minted amount should be 14269406
// [EXPECTED] (v1) staker balance change should be 10702054
// [EXPECTED] (v1) gov staker balance change should be 0
// [EXPECTED] (v1) dev ops balance change should be 2853881
// [EXPECTED] (v1) community pool balance change should be 713470
// [EXPECTED] (new) staker balance change should be 0
// [EXPECTED] (new) gov staker balance change should be 0
// [EXPECTED] (new) dev ops balance change should be 0
// [EXPECTED] (new) community pool balance change should be 0
//
// [SCENARIO] 3. Change distribution target for upgrade
// [EXPECTED] staker address should be changed g1cceshmzzlmrh7rr3z30j2t5mrvsq9yccysw9nu to g1dejhw5m5v94k2ujpv3j8yh6lta047h6ly4ras8
// [EXPECTED] gov staker address should be changed g17e3ykyqk9jmqe2y9wxe9zhep3p7cw56davjqwa to g1dejhw3m0wefhgcttv4eyzerywf047h6ldvhvcq
// [EXPECTED] dev ops address should be changed g1mjvd83nnjee3z2g7683er55me9f09688pd4mj9 to g1dejhw3r9we8hqu6pv3j8yh6lta047h6lguneqv
// [EXPECTED] community pool address should be changed g100fnnlz5eh87p5hvwt8pf279lxaelm8k8md049 to g1dejhwsm0d4kh2mnfw3u4qmm0d3qkgerj7zt4z6
//
// [SCENARIO] 4. Mint to distribution target (after upgrade)
// [INFO] current block height 125
// [EXPECTED] total minted amount should be 28538812
// [EXPECTED] (v1) staker balance change should be 0
// [EXPECTED] (v1) gov staker balance change should be 0
// [EXPECTED] (v1) dev ops balance change should be 0
// [EXPECTED] (v1) community pool balance change should be 0
// [EXPECTED] (new) staker balance change should be 10702055
// [EXPECTED] (new) gov staker balance change should be 0
// [EXPECTED] (new) dev ops balance change should be 2853881
// [EXPECTED] (new) community pool balance change should be 713470
