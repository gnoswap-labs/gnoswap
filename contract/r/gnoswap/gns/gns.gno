package gns

import (
	"std"
	"strings"
	"time"

	"gno.land/p/demo/grc/grc20"
	"gno.land/p/demo/ownable"
	"gno.land/p/demo/ufmt"

	"gno.land/r/demo/grc20reg"
	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/halt"
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
	lastMintedTimestamp  int64 // last block time that gns was minted for emission

	burnAmount int64 // amount of GNS that has been burned
)

func init() {
	privateLedger.Mint(owner.Owner(), INITIAL_MINT_AMOUNT)
	grc20reg.Register(cross, token, "")

	// Initial amount set to 900_000_000_000_000 (MAXIMUM_SUPPLY - INITIAL_MINT_AMOUNT).
	// leftEmissionAmount will decrease as tokens are minted.
	setLeftEmissionAmount(MAX_EMISSION_AMOUNT)
	setMintedEmissionAmount(0)
	setLastMintedTimestamp(std.ChainHeight())
	burnAmount = 0
}

// Name returns the name of the GNS token.
//
// Returns:
//   - string: "Gnoswap"
func Name() string { return token.GetName() }

// Symbol returns the symbol of the GNS token.
//
// Returns:
//   - string: "GNS"
func Symbol() string { return token.GetSymbol() }

// Decimals returns the number of decimal places for GNS token.
//
// Returns:
//   - int: 6 (1 GNS = 1,000,000 base units)
func Decimals() int { return token.GetDecimals() }

// TotalSupply returns the total supply of GNS tokens in circulation.
//
// This includes both the initial mint and all emission-minted tokens,
// minus any burned tokens.
//
// Returns:
//   - int64: Total GNS supply in base units
func TotalSupply() int64 { return token.TotalSupply() }

// KnownAccounts returns the number of addresses that have held GNS.
//
// Returns:
//   - int: Count of unique addresses that have interacted with GNS
func KnownAccounts() int { return token.KnownAccounts() }

// BalanceOf returns the GNS balance of a specific address.
//
// Parameters:
//   - owner: Address to query balance for
//
// Returns:
//   - int64: GNS balance in base units
func BalanceOf(owner std.Address) int64 { return token.BalanceOf(owner) }

// Allowance returns the amount of GNS that a spender is allowed to transfer from an owner.
//
// Parameters:
//   - owner: Address that owns the tokens
//   - spender: Address allowed to spend the tokens
//
// Returns:
//   - int64: Approved amount in base units
func Allowance(owner, spender std.Address) int64 { return token.Allowance(owner, spender) }

// MintGns mints new GNS tokens according to the emission schedule.
//
// This function is called by the emission contract to mint new GNS tokens based on
// the halving schedule. It calculates the appropriate amount to mint based on time
// elapsed since the last mint, respecting the emission curve and maximum supply.
//
// Parameters:
//   - cur realm: Current execution context realm
//   - address: Address to receive the minted tokens (emission contract)
//
// Returns:
//   - int64: Amount of GNS tokens minted
//
// Panics:
//   - System is halted
//   - Caller is not the emission contract
//   - Emission amount would exceed maximum supply
//
// Note:
//   - Only mints once per timestamp
//   - Follows halving schedule (halves every 4 years)
//   - Stops minting after reaching maximum supply
//   - Updates lastMintedTimestamp and emission tracking
//
// Events:
//
//	Emits MintGNS event with mint details
func MintGns(cur realm, address std.Address) int64 {
	halt.AssertIsNotHaltedEmission()

	caller := std.PreviousRealm().Address()
	access.AssertIsEmission(caller)

	lastGNSMintedTimestamp := LastMintedTimestamp()
	currentTime := time.Now().Unix()

	// skip minting process if following conditions are met
	// - if gns for current block is already minted
	// - if last minted height is same or later than emission end height
	if lastGNSMintedTimestamp == currentTime || lastGNSMintedTimestamp >= GetEmissionEndTimestamp() {
		return 0
	}

	// calculate gns amount to mint
	amountToMint := calculateAmountToMint(lastGNSMintedTimestamp+1, currentTime)
	err := validEmissionAmount(amountToMint)
	if err != nil {
		panic(err)
	}

	// update
	setLastMintedTimestamp(currentTime)
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
		"mintedBlockTime", formatInt(currentTime),
		"mintedGNSAmount", formatInt(amountToMint),
		"accumMintedGNSAmount", formatInt(MintedEmissionAmount()),
		"accumLeftMintGNSAmount", formatInt(LeftEmissionAmount()),
	)

	return amountToMint
}

// Burn permanently removes GNS tokens from circulation.
//
// This function destroys tokens, reducing the total supply. Only callable by
// the contract owner (governance). Used for deflationary mechanisms or
// protocol adjustments.
//
// Parameters:
//   - cur realm: Current execution context realm
//   - from: Address to burn tokens from
//   - amount: Amount of GNS to burn
//
// Panics:
//   - Caller is not the contract owner
//   - Insufficient balance to burn
//   - Amount is negative
//
// Events:
//
//	Emits Burn event with burn details
//
// Note:
//   - Permanently reduces total supply
//   - Updates burnAmount tracking
func Burn(cur realm, from std.Address, amount int64) {
	assertAddressIsPreviousRealm(from)

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
func calculateAmountToMint(fromTimestamp, toTimestamp int64) int64 {
	// if toHeight is greater than emission end height, set toHeight to emission end height
	endTimestamp := GetEmissionEndTimestamp()
	if toTimestamp > endTimestamp {
		toTimestamp = endTimestamp
	}

	if fromTimestamp > toTimestamp {
		return 0
	}

	// handle negative block height or block height before emission start
	startTimestamp := getEmissionState().getStartTimestamp()
	if fromTimestamp < startTimestamp {
		fromTimestamp = startTimestamp
	}

	if toTimestamp < startTimestamp {
		return 0
	}

	fromYear := getEmissionState().getCurrentYear(fromTimestamp)
	toYear := getEmissionState().getCurrentYear(toTimestamp)

	// if invalid halving year is returned, return 0
	if fromYear == 0 || toYear == 0 {
		return 0
	}

	totalAmountToMint := int64(0)

	for year := fromYear; year <= toYear; year++ {
		yearEndTimestamp := GetHalvingYearEndTimestamp(year)
		currentToTimestamp := i64Min(toTimestamp, yearEndTimestamp)

		// how many seconds to calculate
		seconds := currentToTimestamp - fromTimestamp + 1
		if seconds <= 0 {
			break
		}

		// amount of gns to mint for each second for current year
		amountPerSecond := GetAmountPerSecondPerHalvingYear(year)

		// amount of gns to mint for current year
		yearAmountToMint := amountPerSecond * seconds

		// if last block of halving year, handle left emission amount
		if currentToTimestamp >= yearEndTimestamp {
			leftover := handleLeftEmissionAmount(year, yearAmountToMint)
			yearAmountToMint += leftover
		}

		totalAmountToMint += yearAmountToMint

		getEmissionState().addHalvingYearAccumulatedAmount(year, yearAmountToMint)
		getEmissionState().subHalvingYearLeftAmount(year, yearAmountToMint)

		std.Emit(
			"CalculateAmountToMint",
			"fromTimestamp", formatInt(fromTimestamp),
			"toTimestamp", formatInt(currentToTimestamp),
			"year", formatInt(year),
			"amountPerSecond", formatInt(amountPerSecond),
		)

		// update fromHeight for next year (if necessary)
		fromTimestamp = currentToTimestamp + 1

		if fromTimestamp > toTimestamp {
			break
		}
	}

	return totalAmountToMint
}

// isLastSecondOfHalvingYear returns true if the current timestamp is the last second of a halving year.
func isLastSecondOfHalvingYear(timestamp int64) bool {
	year := getEmissionState().getCurrentYear(timestamp)
	lastSecond := GetHalvingYearEndTimestamp(year)

	return timestamp == lastSecond
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
func LastMintedTimestamp() int64 { return lastMintedTimestamp }

// LeftEmissionAmount returns the amount of GNS can be minted.
func LeftEmissionAmount() int64 { return leftEmissionAmount }

// MintedEmissionAmount returns the amount of GNS that has been minted by the emission contract.
// It does not include initial minted amount.
func MintedEmissionAmount() int64 { return mintedEmissionAmount }

func setLastMintedTimestamp(timestamp int64) { lastMintedTimestamp = timestamp }
func setLeftEmissionAmount(amount int64)     { leftEmissionAmount = amount }
func setMintedEmissionAmount(amount int64)   { mintedEmissionAmount = amount }
