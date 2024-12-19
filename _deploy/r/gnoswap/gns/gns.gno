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
	// - if last minted height is same as last height to mint ( 12 years passed )
	if lastMintedHeight == currentHeight || lastMintedHeight == GetEndHeight() {
		return 0
	}

	assertShouldNotBeHalted()
	assertCallerIsEmission()

	// calculate gns amount to mint, and the mint to the target address
	amountToMint := calculateAmountToMint(lastMintedHeight+1, currentHeight)

	// update
	setLastMintedHeight(currentHeight)
	setMintedEmissionAmount(GetMintedEmissionAmount() + amountToMint)
	setLeftEmissionAmount(GetLeftEmissionAmount() - amountToMint)

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

	if toHeight > GetEndHeight() {
		toHeight = GetEndHeight()
	}
	toYear := GetHalvingYearByHeight(toHeight)

	totalAmountToMint := uint64(0)

	for i := fromYear; i <= toYear; i++ {
		yearEndHeight := GetHalvingYearBlock(i)
		mintUntilHeight := i64Min(yearEndHeight, toHeight)

		// how many blocks to calculate
		blocks := uint64(mintUntilHeight-fromHeight) + 1

		// amount of gns to mint for each block for current year
		singleBlockAmount := GetAmountPerBlockPerHalvingYear(i)

		// amount of gns to mint for current year
		yearAmountToMint := singleBlockAmount * blocks

		// if last block of halving year, handle left emission amount
		if isLastBlockOfHalvingYear(mintUntilHeight) {
			yearAmountToMint += handleLeftEmissionAmount(i, yearAmountToMint)
		}
		totalAmountToMint += yearAmountToMint
		setHalvingYearMintAmount(i, GetHalvingYearMintAmount(i)+yearAmountToMint)

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
