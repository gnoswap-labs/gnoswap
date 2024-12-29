package gns

import (
	"std"
	"strings"

	"gno.land/p/demo/grc/grc20"
	"gno.land/p/demo/ownable"
	"gno.land/p/demo/ufmt"
	pusers "gno.land/p/demo/users"

	"gno.land/r/demo/grc20reg"
	"gno.land/r/demo/users"

	"gno.land/r/gnoswap/v1/consts"
)

const (
	MAXIMUM_SUPPLY      = uint64(1_000_000_000_000_000)
	INITIAL_MINT_AMOUNT = uint64(100_000_000_000_000)
	MAX_EMISSION_AMOUNT = uint64(900_000_000_000_000) // MAXIMUM_SUPPLY - INITIAL_MINT_AMOUNT
)

var (
	owner *ownable.Ownable

	Token         *grc20.Token
	privateLedger *grc20.PrivateLedger
	UserTeller    grc20.Teller

	leftEmissionAmount   uint64
	mintedEmissionAmount uint64
	lastMintedHeight     int64

	burnAmount uint64
)

func init() {
	owner = ownable.NewWithAddress(consts.ADMIN)

	Token, privateLedger = grc20.NewToken("Gnoswap", "GNS", 6)
	UserTeller = Token.CallerTeller()

	privateLedger.Mint(owner.Owner(), INITIAL_MINT_AMOUNT)
	getter := func() *grc20.Token { return Token }
	grc20reg.Register(getter, "")

	// Initial amount set to 900_000_000_000_000 (MAXIMUM_SUPPLY - INITIAL_MINT_AMOUNT).
	// leftEmissionAmount will decrease as tokens are minted.
	leftEmissionAmount = MAX_EMISSION_AMOUNT

	lastMintedHeight = std.GetHeight()
}

func MintGns(address pusers.AddressOrName) uint64 {
	lastMintedHeight := GetLastMintedHeight()
	currentHeight := std.GetHeight()

	// skip minting process if following conditions are met
	// - if gns for current block is already minted
	// - if last minted height is same or later than emission end height
	if lastMintedHeight == currentHeight || lastMintedHeight >= GetEndHeight() {
		return 0
	}

	assertShouldNotBeHalted()
	assertCallerIsEmission()

	// calculate gns amount to mint
	amountToMint := calculateAmountToMint(lastMintedHeight+1, currentHeight)

	// update
	setLastMintedHeight(currentHeight)
	setMintedEmissionAmount(GetMintedEmissionAmount() + amountToMint)
	setLeftEmissionAmount(GetLeftEmissionAmount() - amountToMint)

	// mint calculated amount to address
	err := privateLedger.Mint(users.Resolve(address), amountToMint)
	if err != nil {
		panic(err.Error())
	}

	return amountToMint
}

func Burn(from pusers.AddressOrName, amount uint64) {
	owner.AssertCallerIsOwner()
	fromAddr := users.Resolve(from)
	checkErr(privateLedger.Burn(fromAddr, amount))

	burnAmount += amount
}

func TotalSupply() uint64 {
	return UserTeller.TotalSupply()
}

func BalanceOf(owner pusers.AddressOrName) uint64 {
	ownerAddr := users.Resolve(owner)
	return UserTeller.BalanceOf(ownerAddr)
}

func Allowance(owner, spender pusers.AddressOrName) uint64 {
	ownerAddr := users.Resolve(owner)
	spenderAddr := users.Resolve(spender)
	return UserTeller.Allowance(ownerAddr, spenderAddr)
}

func Transfer(to pusers.AddressOrName, amount uint64) {
	toAddr := users.Resolve(to)
	checkErr(UserTeller.Transfer(toAddr, amount))
}

func Approve(spender pusers.AddressOrName, amount uint64) {
	spenderAddr := users.Resolve(spender)
	checkErr(UserTeller.Approve(spenderAddr, amount))
}

func TransferFrom(from, to pusers.AddressOrName, amount uint64) {
	fromAddr := users.Resolve(from)
	toAddr := users.Resolve(to)
	checkErr(UserTeller.TransferFrom(fromAddr, toAddr, amount))
}

func Render(path string) string {
	parts := strings.Split(path, "/")
	c := len(parts)

	switch {
	case path == "":
		return Token.RenderHome()
	case c == 2 && parts[0] == "balance":
		owner := pusers.AddressOrName(parts[1])
		ownerAddr := users.Resolve(owner)
		balance := UserTeller.BalanceOf(ownerAddr)
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
func calculateAmountToMint(fromHeight, toHeight int64) uint64 {
	fromYear := GetHalvingYearByHeight(fromHeight)

	// if toHeight is greater than emission end height, set toHeight to emission end height
	if toHeight > GetEndHeight() {
		toHeight = GetEndHeight()
	}
	toYear := GetHalvingYearByHeight(toHeight)

	totalAmountToMint := uint64(0)

	for year := fromYear; year <= toYear; year++ {
		yearEndHeight := GetHalvingYearEndBlock(year)
		mintUntilHeight := i64Min(yearEndHeight, toHeight)

		// how many blocks to calculate
		blocks := uint64(mintUntilHeight-fromHeight) + 1

		// amount of gns to mint for each block for current year
		singleBlockAmount := GetAmountPerBlockPerHalvingYear(year)

		// amount of gns to mint for current year
		yearAmountToMint := singleBlockAmount * blocks

		// if last block of halving year, handle left emission amount
		if isLastBlockOfHalvingYear(mintUntilHeight) {
			yearAmountToMint += handleLeftEmissionAmount(year, yearAmountToMint)
		}
		totalAmountToMint += yearAmountToMint
		setHalvingYearMintAmount(year, GetHalvingYearMintAmount(year)+yearAmountToMint)

		// update fromHeight for next year (if necessary)
		fromHeight = mintUntilHeight + 1
	}

	assertTooManyEmission(totalAmountToMint)
	return totalAmountToMint
}

// isLastBlockOfHalvingYear returns true if the current block is the last block of a halving year.
func isLastBlockOfHalvingYear(height int64) bool {
	year := GetHalvingYearByHeight(height)
	lastBlock := GetHalvingYearEndBlock(year)

	return height == lastBlock
}

// handleLeftEmissionAmount handles the left emission amount for a halving year.
// It calculates the left emission amount by subtracting the halving year mint amount from the halving year amount.
func handleLeftEmissionAmount(year int64, amount uint64) uint64 {
	return GetHalvingYearMaxAmount(year) - GetHalvingYearMintAmount(year) - amount
}

// skipIfSameHeight returns true if the current block height is the same as the last minted height.
// This prevents multiple gns minting inside the same block.
func skipIfSameHeight(lastMintedHeight, currentHeight int64) bool {
	return lastMintedHeight == currentHeight
}

// skipIfEmissionEnded returns true if the emission has ended.
func skipIfEmissionEnded(height int64) bool {
	if isEmissionEnded(height) {
		return true
	}

	return false
}

// GetLastMintedHeight returns the last block height that gns was minted.
func GetLastMintedHeight() int64 {
	return lastMintedHeight
}

// GetLeftEmissionAmount returns the amount of GNS can be minted.
func GetLeftEmissionAmount() uint64 {
	return leftEmissionAmount
}

// GetBurnAmount returns the amount of GNS that has been burned.
func GetBurnAmount() uint64 {
	return burnAmount
}

// GetMintedEmissionAmount returns the amount of GNS that has been minted by the emission contract.
// It does not include initial minted amount.
func GetMintedEmissionAmount() uint64 {
	return mintedEmissionAmount
}

func setLastMintedHeight(height int64) {
	lastMintedHeight = height
}

func setLeftEmissionAmount(amount uint64) {
	leftEmissionAmount = amount
}

func setMintedEmissionAmount(amount uint64) {
	mintedEmissionAmount = amount
}

// assertTooManyEmission asserts if the amount of gns to mint is too many.
// It checks if the amount of gns to mint is greater than the left emission amount or the total emission amount.
func assertTooManyEmission(amount uint64) {
	if amount > GetLeftEmissionAmount() || (amount+GetMintedEmissionAmount()) > MAX_EMISSION_AMOUNT {
		panic(addDetailToError(
			errTooManyEmission,
			ufmt.Sprintf("amount: %d", amount),
		))
	}
}
