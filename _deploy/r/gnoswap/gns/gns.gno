package gns

import (
	"std"
	"strings"

	"gno.land/p/demo/grc/grc20"
	"gno.land/p/demo/ownable"
	"gno.land/p/demo/ufmt"
	pusers "gno.land/p/demo/users"

	"gno.land/r/demo/users"

	"gno.land/r/gnoswap/v2/common"
	"gno.land/r/gnoswap/v2/consts"
)

const MAXIMUM_SUPPLY = uint64(1_000_000_000_000_000) // 1B

var (
	banker *grc20.Banker
	admin  *ownable.Ownable
	token  grc20.Token
)

var (
	lastMintedHeight int64
	amountToEmission uint64
)

func init() {
	admin = ownable.NewWithAddress("g1lmvrrrr4er2us84h2732sru76c9zl2nvknha8c") // GNOSWAP_ADMIN
	banker = grc20.NewBanker("Gnoswap", "GNS", 6)

	banker.Mint(admin.Owner(), 100_000_000_000_000) // 100_000_000 GNS ≈ 0.1B
	token = banker.Token()

	amountToEmission = MAXIMUM_SUPPLY - uint64(100_000_000_000_000)

	lastMintedHeight = std.GetHeight()
}

func TotalSupply() uint64 { return token.TotalSupply() }

func TotalMinted() uint64 { return token.TotalSupply() - uint64(100_000_000_000_000) }

func BalanceOf(owner pusers.AddressOrName) uint64 {
	ownerAddr := users.Resolve(owner)
	return token.BalanceOf(ownerAddr)
}

func Allowance(owner, spender pusers.AddressOrName) uint64 {
	ownerAddr := users.Resolve(owner)
	spenderAddr := users.Resolve(spender)
	return token.Allowance(ownerAddr, spenderAddr)
}

func Transfer(to pusers.AddressOrName, amount uint64) {
	common.IsHalted()

	toAddr := users.Resolve(to)
	checkErr(token.Transfer(toAddr, amount))
}

func Approve(spender pusers.AddressOrName, amount uint64) {
	common.IsHalted()

	spenderAddr := users.Resolve(spender)
	checkErr(token.Approve(spenderAddr, amount))
}

func TransferFrom(from, to pusers.AddressOrName, amount uint64) {
	common.IsHalted()

	fromAddr := users.Resolve(from)
	toAddr := users.Resolve(to)
	checkErr(token.TransferFrom(fromAddr, toAddr, amount))
}

func Render(path string) string {
	parts := strings.Split(path, "/")
	c := len(parts)

	switch {
	case path == "":
		return banker.RenderHome()
	case c == 2 && parts[0] == "balance":
		owner := pusers.AddressOrName(parts[1])
		ownerAddr := users.Resolve(owner)
		balance := banker.BalanceOf(ownerAddr)
		return ufmt.Sprintf("%d\n", balance)
	default:
		return "404\n"
	}
}

// Mint
func Mint(address pusers.AddressOrName) {
	common.IsHalted()

	// only emission contract can call Mint
	caller := std.PrevRealm().Addr()
	if caller != consts.EMISSION_ADDR {
		panic("only emission contract can call Mint")
	}

	// if not yet initialized, mint 0 amount
	if initialized == false {
		println("GNS_not yet initialized")
		return
	}

	// calculate gns emission amount for every block, and send by single call
	// for this case, we assume that inside of block range gnoswap state hasn't changed.
	nowHeight := std.GetHeight()
	amountToMint := uint64(0)

	println("GNS_lastMintedHeight", lastMintedHeight)
	println("GNS_lastMintedHeight + 1", lastMintedHeight+1)
	println("GNS_nowHeight", nowHeight)
	println("GNS_now-lastMint", nowHeight-lastMintedHeight)

	if lastMintedHeight >= nowHeight {
		println("GNS_only one mint for each block")
		return
	}

	// If from, to block is at same halving year, no need iterate
	fromYear := GetHalvingYearByHeight(lastMintedHeight + 1)
	toYear := GetHalvingYearByHeight(nowHeight)
	println("GNS_fromYear:", fromYear)
	println("GNS_toYear:", toYear)

	if fromYear == toYear {
		println(" > GNS_SAME_YEAR")
		numBlock := uint64(nowHeight - lastMintedHeight)
		singleBlockAmount := GetAmountByHeight(nowHeight)
		println(" > GNS_singleBlockAmount:", singleBlockAmount)
		totalBlockAmount := singleBlockAmount * numBlock

		amountToMint += totalBlockAmount
		amountToMint = checkAndHandleIfLastBlockOfHalvingYear(nowHeight, amountToMint)

		halvingYearMintAmount[fromYear] += totalBlockAmount
	} else {
		println(" > GNS_DIFF_YEAR")
		for i := lastMintedHeight + 1; i <= nowHeight; i++ {
			println(" > GNS_processing height:\t\t\t", i)

			amount := GetAmountByHeight(i)
			println(" > GNS_amount_Orig:\t\t\t\t", amount)

			amount = checkAndHandleIfLastBlockOfHalvingYear(i, amount)
			println(" > GNS_amount_LastCheck:\t\t\t", amount)

			year := GetHalvingYearByHeight(i)
			println(" > GNS_year:\t\t\t\t\t", year)

			halvingYearMintAmount[year] += amount
			println(" > GNS_halvingYearMintAmount[year]:\t\t", halvingYearMintAmount[year])

			amountToMint += amount
			println(" > GNS_amountToMint:\t\t\t\t", amountToMint)

			println()
		}
	}

	err := banker.Mint(users.Resolve(address), amountToMint)
	if err != nil {
		panic(err.Error())
	}

	lastMintedHeight = nowHeight
	println("GNS_lastMintedHeight:", lastMintedHeight)
	println("GNS_amountToMint:", amountToMint)
}

func checkAndHandleIfLastBlockOfHalvingYear(height int64, amount uint64) uint64 {
	year := GetHalvingYearByHeight(height)
	lastBlock := halvingYearBlock[year]
	if height == lastBlock {
		println("  > GNS_LAST_processing height:\t\t\t", height)
		println("  > GNS_LAST_year:\t\t\t\t", year)
		println("  > GNS_LAST_halvingYearAmount[year]:\t\t", halvingYearAmount[year])
		println("  > GNS_LAST_halvingYearMintAmount[year]:\t", halvingYearMintAmount[year])

		leftForThisYear := halvingYearAmount[year] - halvingYearMintAmount[year]
		println("  > GNS_LAST_leftForThisYear:\t\t\t", leftForThisYear)

		println("  > GNS_LAST_amount_Before:\t\t\t", amount)
		amount = leftForThisYear
		println("  > GNS_LAST_amount_After(addLeft):\t\t", amount)

		return amount
	}

	return amount
}

func checkErr(err error) {
	if err != nil {
		panic(err.Error())
	}
}
