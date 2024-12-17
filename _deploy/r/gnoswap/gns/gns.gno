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
	lastMintedHeight = std.GetHeight()
)

var (
	leftEmissionAmount   = MAX_EMISSION_AMOUNT
	mintedEmissionAmount = uint64(0)
)

var (
	Token, privateLedger = grc20.NewToken("Gnoswap", "GNS", 6)
	UserTeller           = Token.CallerTeller()
	owner                = ownable.NewWithAddress(consts.ADMIN)
)

func init() {
	privateLedger.Mint(owner.Owner(), INITIAL_MINT_AMOUNT)
	getter := func() *grc20.Token { return Token }
	grc20reg.Register(getter, "")
}

// MintedEmissionAmount returns the amount of GNS that has been minted by the emission contract.
// It does not include initial minted amount.
func MintedEmissionAmount() uint64 {
	return TotalSupply() - INITIAL_MINT_AMOUNT
}

func MintGns(address pusers.AddressOrName) uint64 {
	lastMintedHeight := GetLastMintedHeight()
	currentHeight := std.GetHeight()

	// skip minting process if gns for current block is already minted
	if skipIfSameHeight(lastMintedHeight, currentHeight) {
		return 0
	}

	assertShouldNotBeHalted()
	assertCallerIsEmission()

	// calculate gns amount to mint, and the mint to the target address
	amountToMint := calculateAmountToMint(lastMintedHeight+1, currentHeight)
	err := privateLedger.Mint(users.Resolve(address), amountToMint)
	if err != nil {
		panic(err.Error())
	}

	// update
	setLastMintedHeight(currentHeight)
	setMintedEmissionAmount(GetMintedEmissionAmount() + amountToMint)
	setLeftEmissionAmount(GetLeftEmissionAmount() - amountToMint)

	return amountToMint
}

func Burn(from pusers.AddressOrName, amount uint64) {
	owner.AssertCallerIsOwner()
	fromAddr := users.Resolve(from)
	checkErr(privateLedger.Burn(fromAddr, amount))
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

// helper functions

// calculateAmountToMint calculates the amount of gns to mint
// It calculates the amount of gns to mint for each halving year for block range.
// It also handles the left emission amount if the current block range includes halving year end block.
func calculateAmountToMint(fromHeight, toHeight int64) uint64 {
	fromYear := GetHalvingYearByHeight(fromHeight)
	toYear := GetHalvingYearByHeight(toHeight)

	if isEmissionEnded(fromYear) || isEmissionEnded(toYear) {
		return 0
	}

	totalAmountToMint := uint64(0)

	for i := fromYear; i <= toYear; i++ {
		yearEndHeight := GetHalvingYearBlock(i)
		mintUntilHeight := i64Min(yearEndHeight, toHeight)

		// how many blocks to calculate
		blocks := uint64(mintUntilHeight-fromHeight) + 1

		// amount of gns to mint for each block for current year
		singleBlockAmount := GetAmountByHeight(yearEndHeight)

		// amount of gns to mint for current year
		yearAmountToMint := singleBlockAmount * blocks

		// if last block of halving year, handle left emission amount
		if isLastBlockOfHalvingYear(mintUntilHeight) {
			yearAmountToMint += handleLeftEmissionAmount(i, yearAmountToMint)
		}
		totalAmountToMint += yearAmountToMint
		SetHalvingYearMintAmount(i, GetHalvingYearMintAmount(i)+yearAmountToMint)

		// update fromHeight for next year (if necessary)
		fromHeight = mintUntilHeight + 1
	}

	return totalAmountToMint
}

// isLastBlockOfHalvingYear returns true if the current block is the last block of a halving year.
func isLastBlockOfHalvingYear(height int64) bool {
	year := GetHalvingYearByHeight(height)
	lastBlock := GetHalvingYearBlock(year)

	return height == lastBlock
}

// handleLeftEmissionAmount handles the left emission amount for a halving year.
// It calculates the left emission amount by subtracting the halving year mint amount from the halving year amount.
func handleLeftEmissionAmount(year int64, amount uint64) uint64 {
	return GetHalvingYearAmount(year) - GetHalvingYearMintAmount(year) - amount
}

// skipIfSameHeight returns true if the current block height is the same as the last minted height.
// This prevents multiple gns minting inside the same block.
func skipIfSameHeight(lastMintedHeight, currentHeight int64) bool {
	if lastMintedHeight == currentHeight {
		return true
	}

	return false
}

// isEmissionEnded returns true if the emission is ended.
// It returns false if the emission is not ended.
func isEmissionEnded(year int64) bool {
	if 1 <= year && year <= 12 {
		return false
	}

	return true
}

// Getter
func GetLastMintedHeight() int64 {
	return lastMintedHeight
}

func GetLeftEmissionAmount() uint64 {
	return leftEmissionAmount
}

func GetMintedEmissionAmount() uint64 {
	return mintedEmissionAmount
}

// Setter
func setLastMintedHeight(height int64) {
	lastMintedHeight = height
}

func setLeftEmissionAmount(amount uint64) {
	leftEmissionAmount = amount
}

func setMintedEmissionAmount(amount uint64) {
	mintedEmissionAmount = amount
}
