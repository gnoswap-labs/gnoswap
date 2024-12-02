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

	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/gnoswap/v1/consts"
)

const MAXIMUM_SUPPLY = uint64(1_000_000_000_000_000) // 1B

var (
	lastMintedHeight int64
	amountToEmission uint64
)

var (
	Token, privateLedger = grc20.NewToken("Gnoswap", "GNS", 6)
	UserTeller           = Token.CallerTeller()
	owner                = ownable.NewWithAddress("g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d") // ADMIN
)

func init() {
	privateLedger.Mint(owner.Owner(), 100_000_000_000_000) // 100_000_000 GNS ≈ 0.1B
	getter := func() *grc20.Token { return Token }
	grc20reg.Register(getter, "")

	amountToEmission = MAXIMUM_SUPPLY - uint64(100_000_000_000_000)

	lastMintedHeight = std.GetHeight()
}

func GetAmountToEmission() uint64 { return amountToEmission }

func TotalSupply() uint64 {
	return UserTeller.TotalSupply()
}

func TotalMinted() uint64 {
	return UserTeller.TotalSupply() - uint64(100_000_000_000_000)
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

// Mint mints GNS to the address.
// Only emission contract can call Mint.
func Mint(address pusers.AddressOrName) uint64 {
	common.IsHalted()

	caller := std.PrevRealm().Addr()
	if caller != consts.EMISSION_ADDR {
		panic(addDetailToError(
			errNoPermission,
			ufmt.Sprintf("only emission contract(%s) can call Mint, called from %s", consts.EMISSION_ADDR, caller.String()),
		))
	}

	// if not yet initialized, mint 0 amount
	if initialized == false {
		return 0
	}

	// calculate gns emission amount for every block, and send by single call
	// for this case, we assume that inside of block range gnoswap state hasn't changed.
	nowHeight := std.GetHeight()
	amountToMint := uint64(0)

	if lastMintedHeight >= nowHeight {
		return 0
	}

	// If from, to block is at same halving year, no need iterate
	fromYear := GetHalvingYearByHeight(lastMintedHeight + 1)
	toYear := GetHalvingYearByHeight(nowHeight)

	if fromYear == toYear {
		numBlock := uint64(nowHeight - lastMintedHeight)
		singleBlockAmount := GetAmountByHeight(nowHeight)
		totalBlockAmount := singleBlockAmount * numBlock

		amountToMint += totalBlockAmount
		amountToMint = checkAndHandleIfLastBlockOfHalvingYear(nowHeight, amountToMint)

		halvingYearMintAmount[fromYear] += totalBlockAmount
	} else {
		for i := lastMintedHeight + 1; i <= nowHeight; i++ {
			amount := GetAmountByHeight(i)
			amount = checkAndHandleIfLastBlockOfHalvingYear(i, amount)
			year := GetHalvingYearByHeight(i)
			halvingYearMintAmount[year] += amount
			amountToMint += amount
		}
	}

	err := privateLedger.Mint(users.Resolve(address), amountToMint)
	if err != nil {
		panic(err.Error())
	}

	lastMintedHeight = nowHeight

	return amountToMint
}

func Burn(from pusers.AddressOrName, amount uint64) {
	owner.AssertCallerIsOwner()
	fromAddr := users.Resolve(from)
	checkErr(privateLedger.Burn(fromAddr, amount))
}

func checkAndHandleIfLastBlockOfHalvingYear(height int64, amount uint64) uint64 {
	year := GetHalvingYearByHeight(height)
	lastBlock := halvingYearBlock[year]
	if height == lastBlock {
		leftForThisYear := halvingYearAmount[year] - halvingYearMintAmount[year]
		amount = leftForThisYear
		return amount
	}

	return amount
}

func checkErr(err error) {
	if err != nil {
		panic(err.Error())
	}
}

// TODO:
//  1. when emission contract mint gns reward, last executed height should be get from gns contract.
//     mint function of gns contract and mintGns function of emission contract should be synchronized.
func GetLastMintedHeight() int64 {
	return lastMintedHeight
}
