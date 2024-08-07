package gns

import (
	"std"
	"strings"

	"gno.land/p/demo/grc/grc20"
	"gno.land/p/demo/ownable"
	"gno.land/p/demo/ufmt"
	pusers "gno.land/p/demo/users"

	"gno.land/r/demo/users"

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
	toAddr := users.Resolve(to)
	checkErr(token.Transfer(toAddr, amount))
}

func Approve(spender pusers.AddressOrName, amount uint64) {
	spenderAddr := users.Resolve(spender)
	checkErr(token.Approve(spenderAddr, amount))
}

func TransferFrom(from, to pusers.AddressOrName, amount uint64) {
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

	for i := lastMintedHeight + 1; i <= nowHeight; i++ {
		amount := GetAmountByHeight(i)
		amountToMint += amount

		year := GetHalvingYearByHeight(i)
		halvingYearMintAmount[year] += amount

		lastBlock := halvingYearBlock[year]
		if i == lastBlock {
			// halvingYearAmount[year] = amountToMint
			// halvingYearMintAmount[year] = amountToMint
			println(" > GNS_LAST_year:", year)
			println(" > GNS_LAST_processing height:", i)
			println(" > GNS_LAST_halvingYearAmount[1]:\t", halvingYearAmount[1])
			println(" > GNS_LAST_halvingYearMintAmount[1]:\t", halvingYearMintAmount[1])
			leftForThisYear := halvingYearAmount[year] - halvingYearMintAmount[year]
			println(" > GNS_LAST_leftForThisYear:", leftForThisYear)
			println()

			amountToMint += leftForThisYear
			halvingYearMintAmount[year] += leftForThisYear
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

func checkErr(err error) {
	if err != nil {
		panic(err.Error())
	}
}
