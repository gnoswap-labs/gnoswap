package gns

import (
	"std"
	"strings"
	"time"

	"gno.land/p/demo/tokens/grc20"
	"gno.land/p/nt/ownable"
	"gno.land/p/nt/ufmt"

	"gno.land/r/demo/defi/grc20reg"
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
func Name() string { return token.GetName() }

// Symbol returns the symbol of the GNS token.
func Symbol() string { return token.GetSymbol() }

// Decimals returns the number of decimal places for GNS token.
func Decimals() int { return token.GetDecimals() }

// TotalSupply returns the total supply of GNS tokens in circulation.
func TotalSupply() int64 { return token.TotalSupply() }

// KnownAccounts returns the number of addresses that have held GNS.
func KnownAccounts() int { return token.KnownAccounts() }

// BalanceOf returns the GNS balance of a specific address.
func BalanceOf(owner std.Address) int64 { return token.BalanceOf(owner) }

// Allowance returns the amount of GNS that a spender is allowed to transfer from an owner.
func Allowance(owner, spender std.Address) int64 { return token.Allowance(owner, spender) }

// MintGns mints new GNS tokens according to the emission schedule.
//
// Parameters:
//   - address: recipient address for minted tokens
//
// Returns amount minted.
// Only callable by emission contract.
func MintGns(cur realm, address std.Address) int64 {
	halt.AssertIsNotHaltedEmission()

	caller := std.PreviousRealm().Address()
	access.AssertIsEmission(caller)

	lastGNSMintedTimestamp := LastMintedTimestamp()
	currentTime := time.Now().Unix()

	// Skip if already minted this timestamp or emission ended.
	if lastGNSMintedTimestamp == currentTime || lastGNSMintedTimestamp >= GetEmissionEndTimestamp() {
		return 0
	}

	amountToMint := calculateAmountToMint(lastGNSMintedTimestamp+1, currentTime)
	err := validEmissionAmount(amountToMint)
	if err != nil {
		panic(err)
	}

	setLastMintedTimestamp(currentTime)
	setMintedEmissionAmount(MintedEmissionAmount() + amountToMint)
	setLeftEmissionAmount(LeftEmissionAmount() - amountToMint)

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
// Parameters:
//   - from: address to burn tokens from
//   - amount: amount to burn
//
// Only callable by contract owner.
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

// Transfer transfers GNS tokens from caller to recipient.
//
// Parameters:
//   - to: recipient address
//   - amount: amount to transfer
func Transfer(cur realm, to std.Address, amount int64) {
	userTeller := token.CallerTeller()
	checkErr(userTeller.Transfer(to, amount))
}

// Approve allows spender to transfer GNS tokens from caller's account.
//
// Parameters:
//   - spender: address authorized to spend
//   - amount: maximum amount spender can transfer
func Approve(cur realm, spender std.Address, amount int64) {
	userTeller := token.CallerTeller()
	checkErr(userTeller.Approve(spender, amount))
}

// TransferFrom transfers GNS tokens on behalf of owner.
//
// Parameters:
//   - from: token owner address
//   - to: recipient address
//   - amount: amount to transfer
func TransferFrom(cur realm, from, to std.Address, amount int64) {
	userTeller := token.CallerTeller()
	checkErr(userTeller.TransferFrom(from, to, amount))
}

// Render returns token information for web interface.
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

// checkErr panics if error is not nil.
func checkErr(err error) {
	if err != nil {
		panic(err.Error())
	}
}

// calculateAmountToMint calculates GNS tokens to mint for given timestamp range.
func calculateAmountToMint(fromTimestamp, toTimestamp int64) int64 {
	endTimestamp := GetEmissionEndTimestamp()
	if toTimestamp > endTimestamp {
		toTimestamp = endTimestamp
	}

	if fromTimestamp > toTimestamp {
		return 0
	}

	startTimestamp := getEmissionState().getStartTimestamp()
	if fromTimestamp < startTimestamp {
		fromTimestamp = startTimestamp
	}

	if toTimestamp < startTimestamp {
		return 0
	}

	fromYear := getEmissionState().getCurrentYear(fromTimestamp)
	toYear := getEmissionState().getCurrentYear(toTimestamp)

	if fromYear == 0 || toYear == 0 {
		return 0
	}

	totalAmountToMint := int64(0)

	for year := fromYear; year <= toYear; year++ {
		yearEndTimestamp := GetHalvingYearEndTimestamp(year)
		currentToTimestamp := i64Min(toTimestamp, yearEndTimestamp)

		seconds := currentToTimestamp - fromTimestamp + 1
		if seconds <= 0 {
			break
		}

		amountPerSecond := GetAmountPerSecondPerHalvingYear(year)

		yearAmountToMint := amountPerSecond * seconds

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

		fromTimestamp = currentToTimestamp + 1

		if fromTimestamp > toTimestamp {
			break
		}
	}

	return totalAmountToMint
}

// isLastSecondOfHalvingYear returns true if timestamp is the last second of a halving year.
func isLastSecondOfHalvingYear(timestamp int64) bool {
	year := getEmissionState().getCurrentYear(timestamp)
	lastSecond := GetHalvingYearEndTimestamp(year)

	return timestamp == lastSecond
}

// handleLeftEmissionAmount returns the remaining emission amount for a halving year.
func handleLeftEmissionAmount(year, amount int64) int64 {
	return GetHalvingYearLeftAmount(year) - amount
}

// skipIfSameHeight returns true if last minted height equals current height,
// preventing multiple mints in the same block.
func skipIfSameHeight(lastMintedHeight, currentHeight int64) bool {
	return lastMintedHeight == currentHeight
}

// BurnAmount returns the total amount of GNS tokens burned.
func BurnAmount() int64 { return burnAmount }

// LastMintedTimestamp returns the timestamp of the last GNS emission mint.
func LastMintedTimestamp() int64 { return lastMintedTimestamp }

// LeftEmissionAmount returns the remaining GNS tokens available for emission.
func LeftEmissionAmount() int64 { return leftEmissionAmount }

// MintedEmissionAmount returns the total GNS tokens minted through emission,
// excluding the initial mint amount.
func MintedEmissionAmount() int64 { return mintedEmissionAmount }

// setLastMintedTimestamp sets the timestamp of the last emission mint.
func setLastMintedTimestamp(timestamp int64) { lastMintedTimestamp = timestamp }

// setLeftEmissionAmount sets the remaining emission amount.
func setLeftEmissionAmount(amount int64) { leftEmissionAmount = amount }

// setMintedEmissionAmount sets the total minted emission amount.
func setMintedEmissionAmount(amount int64) { mintedEmissionAmount = amount }
