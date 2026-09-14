package gns

// setupPreMint mints the initial GNS supply
// (INITIAL_MINT_AMOUNT = 100_000_000_000_000, i.e. 100M GNS with 6 decimals) at realm init.
//
// Non-production: the full amount is minted to the ADMIN role address.
//
// Production: the same total is split across two recipients (50M GNS each):
//   - gns-ecosystem: g1y7h659patawdy99mlufj9lp3t9cwpt8fq852zq
//   - gns-airdrop:   g1plxd74hnxyjvh309nfcndp53ypvv93yp5rd7dk
func setupPreMint(cur realm) {
	adminAddr := access.MustGetAddress(prabc.ROLE_ADMIN.String())
	err := privateLedger.Mint(adminAddr, INITIAL_MINT_AMOUNT)
	if err != nil {
		panic(err.Error())
	}
}
