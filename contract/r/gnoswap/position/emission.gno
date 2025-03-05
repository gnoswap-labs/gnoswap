package position

import (
	br "gno.land/r/gnoswap/v1/brigde"
)

// mintAndDistributeGnsCallback executes the MintAndDistributeGns callback
func mintAndDistributeGnsCallback() uint64 {
	cb, exists := br.GetCallback(br.MINT_AND_DISTRIBUTE_GNS_KEY)
	if !exists {
		panic("MintAndDistributeGns callback is not set!")
	}

	mintCallback, ok := cb.(func() uint64)
	if !ok {
		panic("Invalid callback type for MintAndDistributeGns")
	}

	return mintCallback()
}
