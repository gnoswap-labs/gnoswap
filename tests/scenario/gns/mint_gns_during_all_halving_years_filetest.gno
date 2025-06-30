// mint gns during all halving years
package main

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/ufmt"

	"gno.land/p/gnoswap/consts"
	"gno.land/r/gnoswap/v1/gns"

	_ "gno.land/r/gnoswap/v1/staker"

	"gno.land/r/gnoswap/v1/access"
)

var t *testing.T

var (
	user01Addr  = testutils.TestAddress("user01Addr")
	user01Realm = std.NewUserRealm(user01Addr)

	adminAddr, _ = access.GetAddress(access.ROLE_ADMIN)
)

const (
	halvingYear      = 12
	yearMs           = 31536000000 // 365 * 24 * 60 * 60 * 1000
	defaultBlockTime = 2000        // 2000ms
)

func main() {
	ufmt.Println("[SCENARIO] 1. Initialize emission")
	initEmission()
	println()

	ufmt.Println("[SCENARIO] 2. Mint GNS when initialized")
	mintGNS()
	println()

	blocksOfYear := yearMs / defaultBlockTime

	for year := 1; year <= halvingYear+1; year++ {
		scenarioIndex := (year-1)*2 + 3

		ufmt.Printf("[SCENARIO] %d. Skip a year (skip all blocks of %d year)\n", scenarioIndex, year)
		testing.SkipHeights(int64(blocksOfYear))
		println()

		ufmt.Printf("[SCENARIO] %d. Mint GNS when %d year end\n", scenarioIndex+1, year)
		mintGNS()
		println()
	}
}

func initEmission() {}

func mintGNS() {
	testing.SetRealm(std.NewCodeRealm(consts.EMISSION_PATH))

	mintedAmount := gns.MintGns(cross, user01Addr)
	totalMintedAmount := gns.GetMintedEmissionAmount()

	ufmt.Printf("[EXPECTED] minted amount should be %d\n", mintedAmount)
	ufmt.Printf("[EXPECTED] total minted amount should be %d\n", totalMintedAmount)
}

// Output:
// [SCENARIO] 1. Initialize emission
//
// [SCENARIO] 2. Mint GNS when initialized
// [EXPECTED] minted amount should be 0
// [EXPECTED] total minted amount should be 0
//
// [SCENARIO] 3. Skip a year (skip all blocks of 1 year)
//
// [SCENARIO] 4. Mint GNS when 1 year end
// [EXPECTED] minted amount should be 225000000000000
// [EXPECTED] total minted amount should be 225000000000000
//
// [SCENARIO] 5. Skip a year (skip all blocks of 2 year)
//
// [SCENARIO] 6. Mint GNS when 2 year end
// [EXPECTED] minted amount should be 225000000000000
// [EXPECTED] total minted amount should be 450000000000000
//
// [SCENARIO] 7. Skip a year (skip all blocks of 3 year)
//
// [SCENARIO] 8. Mint GNS when 3 year end
// [EXPECTED] minted amount should be 112500000000000
// [EXPECTED] total minted amount should be 562500000000000
//
// [SCENARIO] 9. Skip a year (skip all blocks of 4 year)
//
// [SCENARIO] 10. Mint GNS when 4 year end
// [EXPECTED] minted amount should be 112500000000000
// [EXPECTED] total minted amount should be 675000000000000
//
// [SCENARIO] 11. Skip a year (skip all blocks of 5 year)
//
// [SCENARIO] 12. Mint GNS when 5 year end
// [EXPECTED] minted amount should be 56250000000000
// [EXPECTED] total minted amount should be 731250000000000
//
// [SCENARIO] 13. Skip a year (skip all blocks of 6 year)
//
// [SCENARIO] 14. Mint GNS when 6 year end
// [EXPECTED] minted amount should be 56250000000000
// [EXPECTED] total minted amount should be 787500000000000
//
// [SCENARIO] 15. Skip a year (skip all blocks of 7 year)
//
// [SCENARIO] 16. Mint GNS when 7 year end
// [EXPECTED] minted amount should be 28125000000000
// [EXPECTED] total minted amount should be 815625000000000
//
// [SCENARIO] 17. Skip a year (skip all blocks of 8 year)
//
// [SCENARIO] 18. Mint GNS when 8 year end
// [EXPECTED] minted amount should be 28125000000000
// [EXPECTED] total minted amount should be 843750000000000
//
// [SCENARIO] 19. Skip a year (skip all blocks of 9 year)
//
// [SCENARIO] 20. Mint GNS when 9 year end
// [EXPECTED] minted amount should be 14062500000000
// [EXPECTED] total minted amount should be 857812500000000
//
// [SCENARIO] 21. Skip a year (skip all blocks of 10 year)
//
// [SCENARIO] 22. Mint GNS when 10 year end
// [EXPECTED] minted amount should be 14062500000000
// [EXPECTED] total minted amount should be 871875000000000
//
// [SCENARIO] 23. Skip a year (skip all blocks of 11 year)
//
// [SCENARIO] 24. Mint GNS when 11 year end
// [EXPECTED] minted amount should be 14062500000000
// [EXPECTED] total minted amount should be 885937500000000
//
// [SCENARIO] 25. Skip a year (skip all blocks of 12 year)
//
// [SCENARIO] 26. Mint GNS when 12 year end
// [EXPECTED] minted amount should be 14062500000000
// [EXPECTED] total minted amount should be 900000000000000
//
// [SCENARIO] 27. Skip a year (skip all blocks of 13 year)
//
// [SCENARIO] 28. Mint GNS when 13 year end
// [EXPECTED] minted amount should be 0
// [EXPECTED] total minted amount should be 900000000000000
//
