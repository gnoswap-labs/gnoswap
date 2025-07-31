package gns

import (
	"std"
	"strings"

	"gno.land/p/demo/grc/grc20"
	"gno.land/p/demo/ownable"
	"gno.land/p/demo/ufmt"

	"gno.land/r/demo/grc20reg"
	"gno.land/r/gnoswap/v1/access"
	"gno.land/r/gnoswap/v1/halt"
)

const (
	MAXIMUM_SUPPLY      = int64(1_000_000_000_000_000)
	INITIAL_MINT_AMOUNT = int64(100_000_000_000_000)
	MAX_EMISSION_AMOUNT = int64(900_000_000_000_000) // MAXIMUM_SUPPLY - INITIAL_MINT_AMOUNT
)

var (
	adminAddr            = getAdminAddress()
	token, privateLedger = grc20.NewToken("Gnoswap", "GNS", 6)
	UserTeller           = token.CallerTeller()
	owner                = ownable.NewWithAddress(adminAddr)

	leftEmissionAmount   int64 // amount of GNS can be minted for emission
	mintedEmissionAmount int64 // amount of GNS that has been minted for emission
	lastMintedHeight     int64 // last block height that gns was minted for emission

	burnAmount int64 // amount of GNS that has been burned
)

func init() {
	privateLedger.Mint(owner.Owner(), INITIAL_MINT_AMOUNT)
	grc20reg.Register(cross, token, "")

	// Initial amount set to 900_000_000_000_000 (MAXIMUM_SUPPLY - INITIAL_MINT_AMOUNT).
	// leftEmissionAmount will decrease as tokens are minted.
	setLeftEmissionAmount(MAX_EMISSION_AMOUNT)
	setMintedEmissionAmount(0)
	setLastMintedHeight(std.ChainHeight())
	burnAmount = 0
}

func Name() string                               { return token.GetName() }
func Symbol() string                             { return token.GetSymbol() }
func Decimals() int                              { return token.GetDecimals() }
func TotalSupply() int64                         { return token.TotalSupply() }
func KnownAccounts() int                         { return token.KnownAccounts() }
func BalanceOf(owner std.Address) int64          { return token.BalanceOf(owner) }
func Allowance(owner, spender std.Address) int64 { return token.Allowance(owner, spender) }

func MintGns(cur realm, address std.Address) int64 {
	halt.AssertIsNotHaltedEmission()
	
	caller := std.PreviousRealm().Address()
	access.AssertIsEmission(caller)

	lastGNSMintedHeight := LastMintedHeight()
	currentHeight := std.ChainHeight()

	// skip minting process if following conditions are met
	// - if gns for current block is already minted
	// - if last minted height is same or later than emission end height
	if lastGNSMintedHeight == currentHeight || lastGNSMintedHeight >= GetEndHeight() {
		return 0
	}

	// calculate gns amount to mint
	amountToMint := calculateAmountToMint(lastGNSMintedHeight+1, currentHeight)
	err := validEmissionAmount(amountToMint)
	if err != nil {
		panic(err)
	}

	// update
	setLastMintedHeight(currentHeight)
	setMintedEmissionAmount(MintedEmissionAmount() + amountToMint)
	setLeftEmissionAmount(LeftEmissionAmount() - amountToMint)

	// mint calculated amount to address
	err = privateLedger.Mint(address, amountToMint)
	if err != nil {
		panic(err.Error())
	}

	previousRealm := std.PreviousRealm()
	std.Emit(
		"MintGNS",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"mintedBlockHeight", formatInt(currentHeight),
		"mintedGNSAmount", formatInt(amountToMint),
		"accumMintedGNSAmount", formatInt(MintedEmissionAmount()),
		"accumLeftMintGNSAmount", formatInt(LeftEmissionAmount()),
	)

	return amountToMint
}

func Burn(cur realm, from std.Address, amount int64) {
	owner.AssertOwnedByCurrent()
	checkErr(privateLedger.Burn(from, amount))

	burnAmount += amount

	previousRealm := std.PreviousRealm()
	std.Emit(
		"Burn",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"burnedBlockHeight", formatInt(std.ChainHeight()),
		"burnFrom", from.String(),
		"burnedGNSAmount", formatInt(amount),
		"accumBurnedGNSAmount", formatInt(BurnAmount()),
	)
}

func Transfer(cur realm, to std.Address, amount int64) {
	userTeller := token.CallerTeller()
	checkErr(userTeller.Transfer(to, amount))
}

func Approve(cur realm, spender std.Address, amount int64) {
	userTeller := token.CallerTeller()
	checkErr(userTeller.Approve(spender, amount))
}

func TransferFrom(cur realm, from, to std.Address, amount int64) {
	userTeller := token.CallerTeller()
	checkErr(userTeller.TransferFrom(from, to, amount))
}

func Render(path string) string {
	parts := strings.Split(path, "/")
	c := len(parts)

	switch {
	case path == "":
		return token.RenderHome()
	case c == 2 && parts[0] == "balance":
		owner := std.Address(parts[1])
		balance := token.BalanceOf(owner)
		return ufmt.Sprintf("%d\n", balance)
	default:
		return "404\n"
	}
}

func checkErr(err error) {
	if err != nil {
		panic(err.Error())
	}
}

// calculateAmountToMint calculates the amount of gns to mint
// It calculates the amount of gns to mint for each halving year for block range.
// It also handles the left emission amount if the current block range includes halving year end block.
func calculateAmountToMint(fromHeight, toHeight int64) int64 {
	// if toHeight is greater than emission end height, set toHeight to emission end height
	endH := GetEndHeight()
	if toHeight > endH {
		toHeight = endH
	}

	if fromHeight > toHeight {
		return 0
	}

	// handle negative block height or block height before emission start
	startHeight := getEmissionState().getStartHeight()
	if fromHeight < startHeight {
		fromHeight = startHeight
	}
	if toHeight < startHeight {
		return 0
	}

	fromYear := HalvingYearByHeight(fromHeight)
	toYear := HalvingYearByHeight(toHeight)

	// if invalid halving year is returned, return 0
	if fromYear == 0 || toYear == 0 {
		return 0
	}

	totalAmountToMint := int64(0)

	curFrom := fromHeight

	for year := fromYear; year <= toYear; year++ {
		yearEndHeight := GetHalvingYearEndBlock(year)
		mintUntilHeight := i64Min(yearEndHeight, toHeight)

		// how many blocks to calculate
		blocks := mintUntilHeight - curFrom + 1
		if blocks <= 0 {
			break
		}

		// amount of gns to mint for each block for current year
		singleBlockAmount := GetAmountPerBlockPerHalvingYear(year)

		// amount of gns to mint for current year
		yearAmountToMint := singleBlockAmount * blocks

		// if last block of halving year, handle left emission amount
		if mintUntilHeight >= yearEndHeight {
			leftover := handleLeftEmissionAmount(year, yearAmountToMint)
			yearAmountToMint += leftover
		}

		totalAmountToMint += yearAmountToMint

		setHalvingYearMintAmount(year, GetHalvingYearMintAmount(year)+yearAmountToMint)
		setHalvingYearLeftAmount(year, GetHalvingYearLeftAmount(year)-yearAmountToMint)

		std.Emit(
			"CalculateAmountToMint",
			"fromHeight", formatInt(curFrom),
			"toHeight", formatInt(mintUntilHeight),
			"year", formatInt(year),
			"singleBlockAmount", formatInt(singleBlockAmount),
		)

		// update fromHeight for next year (if necessary)
		curFrom = mintUntilHeight + 1
		if curFrom > toHeight {
			break
		}
	}

	return totalAmountToMint
}

// isLastBlockOfHalvingYear returns true if the current block is the last block of a halving year.
func isLastBlockOfHalvingYear(height int64) bool {
	year := HalvingYearByHeight(height)
	lastBlock := GetHalvingYearEndBlock(year)

	return height == lastBlock
}

// handleLeftEmissionAmount handles the left emission amount for a halving year.
// It calculates the left emission amount by subtracting the halving year mint amount from the halving year amount.
func handleLeftEmissionAmount(year, amount int64) int64 {
	return GetHalvingYearLeftAmount(year) - amount
}

// skipIfSameHeight returns true if the current block height is the same as the last minted height.
// This prevents multiple gns minting inside the same block.
func skipIfSameHeight(lastMintedHeight, currentHeight int64) bool {
	return lastMintedHeight == currentHeight
}

// BurnAmount returns the amount of GNS that has been burned.
func BurnAmount() int64 { return burnAmount }

// LastMintedHeight returns the last block height that gns was minted.
func LastMintedHeight() int64 { return lastMintedHeight }

// LeftEmissionAmount returns the amount of GNS can be minted.
func LeftEmissionAmount() int64 { return leftEmissionAmount }

// MintedEmissionAmount returns the amount of GNS that has been minted by the emission contract.
// It does not include initial minted amount.
func MintedEmissionAmount() int64 { return mintedEmissionAmount }

func setLastMintedHeight(height int64)     { lastMintedHeight = height }
func setLeftEmissionAmount(amount int64)   { leftEmissionAmount = amount }
func setMintedEmissionAmount(amount int64) { mintedEmissionAmount = amount }
