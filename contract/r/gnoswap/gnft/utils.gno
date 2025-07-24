package gnft

import (
	"math/rand"
	"std"
	"time"

	"gno.land/p/demo/grc/grc721"
	"gno.land/p/demo/ufmt"
	prabc "gno.land/p/gnoswap/rbac"

	"gno.land/r/gnoswap/v1/access"
	"gno.land/r/gnoswap/v1/rbac"
)

func getPositionAddress() std.Address {
	addr, exists := access.GetAddress(prabc.ROLE_POSITION.String())
	if !exists {
		return rbac.DefaultRoleAddresses[prabc.ROLE_POSITION]
	}

	return addr
}

// tid converts uint64 to grc721.TokenID.
//
// Input:
//   - id: the uint64 to convert
//
// Output:
//   - grc721.TokenID: the converted token ID
func tid(id uint64) grc721.TokenID {
	return grc721.TokenID(ufmt.Sprintf("%d", id))
}

// generateRandInstnace generates a new random instance
// Returns:
//   - *rand.Rand: A new random instance
func generateRandInstance() *rand.Rand {
	seed1 := time.Now().Unix() + TotalSupply()
	seed2 := time.Now().UnixNano() + TotalSupply()
	pcg := rand.NewPCG(uint64(seed1), uint64(seed2))
	return rand.New(pcg)
}

// checkErr helper function to panic if an error occurs
// Parameters:
//   - err: The error to check
func checkErr(err error) {
	if err != nil {
		panic(err.Error())
	}
}
