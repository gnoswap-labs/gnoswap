package e2e

import (
	"fmt"
	"regexp"
	"sort"
	"strings"
	"time"
)

const (
	defaultSqrtPrice = "79228162514264337593543950337"
	maxApproveAmount = "9223372036854775806"
	poolFeeTier      = "3000"
)

func (s *E2ETestSuite) TestZZGnoswapPoolAndPositionWithIBCVoucher() {
	r := s.Require()

	poolAddr := s.mustEvalAddress(`gno.land/r/gnoswap/access.MustGetAddress("pool")`)
	positionAddr := s.mustEvalAddress(`gno.land/r/gnoswap/access.MustGetAddress("position")`)

	transferAmount := int64(30000000)
	denom := "uatone"

	beforeAtomOne, err := queryAtomOneBalance(s.cfg.AtomoneREST, s.atomOneSenderAddress, denom)
	r.NoError(err)

	msg := buildMsgSendPacket(
		s.atomoneClientID,
		s.atomOneSenderAddress,
		s.gnoSenderAddress,
		denom,
		transferAmount,
		time.Now().Add(time.Hour).Unix(),
	)
	s.signAndBroadcastAtomOneTx(s.atomOneSenderAddress, msg)

	afterAtomOne, err := queryAtomOneBalance(s.cfg.AtomoneREST, s.atomOneSenderAddress, denom)
	r.NoError(err)
	r.Equal(beforeAtomOne-transferAmount, afterAtomOne)

	ibcDenomHash := computeIBCDenomHash(s.gnoClientID, denom)
	ibcDenom := "ibc/" + ibcDenomHash
	uatoneTokenPath := "gno.land/r/aib/ibc/apps/transfer." + ibcDenom

	var afterVoucher int64
	r.Eventually(func() bool {
		bal, qErr := queryGnoGRC20Balance(s.gnoContainer, s.cfg.GnoGnokeyRemote, s.gnoSenderAddress, ibcDenom)
		if qErr != nil {
			return false
		}
		afterVoucher = bal
		return afterVoucher >= transferAmount
	}, time.Minute, time.Second)

	s.signAndBroadcastGnoCall("test", "gno.land/r/gnoswap/common", "Approve", "", uatoneTokenPath, poolAddr, maxApproveAmount)
	s.signAndBroadcastGnoCall("test", "gno.land/r/gnoswap/gns", "Approve", "", poolAddr, maxApproveAmount)
	s.signAndBroadcastGnoCall("test", "gno.land/r/gnoland/wugnot", "Approve", "", poolAddr, maxApproveAmount)
	s.signAndBroadcastGnoCall("test", "gno.land/r/gnoland/wugnot", "Approve", "", positionAddr, maxApproveAmount)

	s.signAndBroadcastGnoCall("test", "gno.land/r/gnoswap/pool", "CreatePool", "",
		uatoneTokenPath,
		"gno.land/r/gnoland/wugnot",
		poolFeeTier,
		defaultSqrtPrice,
	)

	poolPath := buildPoolPath(uatoneTokenPath, "gno.land/r/gnoland/wugnot", poolFeeTier)
	r.Eventually(func() bool {
		content, qErr := gnoQEval(s.gnoContainer, s.cfg.GnoGnokeyRemote,
			fmt.Sprintf(`gno.land/r/gnoswap/pool.ExistsPoolPath(%q)`, poolPath))
		if qErr != nil {
			return false
		}
		return strings.Contains(content, "true")
	}, time.Minute, time.Second)

	deadline := fmt.Sprint(time.Now().Add(time.Hour).Unix())
	s.signAndBroadcastGnoCall("test", "gno.land/r/gnoswap/position", "Mint", "20000000ugnot",
		uatoneTokenPath,
		"ugnot",
		poolFeeTier,
		"-887220",
		"887220",
		"20000000",
		"20000000",
		"1",
		"1",
		deadline,
		s.gnoSenderAddress,
		s.gnoSenderAddress,
		"",
	)

	r.Eventually(func() bool {
		content, qErr := gnoQEval(s.gnoContainer, s.cfg.GnoGnokeyRemote,
			fmt.Sprintf(`gno.land/r/gnoswap/pool.GetPoolPositionCount(%q)`, poolPath))
		if qErr != nil {
			return false
		}
		intRe := regexp.MustCompile(`\d+`)
		return intRe.FindString(content) == "1"
	}, time.Minute, time.Second)
}

func (s *E2ETestSuite) mustEvalAddress(expr string) string {
	content, err := gnoQEval(s.gnoContainer, s.cfg.GnoGnokeyRemote, expr)
	s.Require().NoError(err)

	addrRe := regexp.MustCompile(`g1[0-9a-z]+`)
	addr := addrRe.FindString(content)
	s.Require().NotEmpty(addr, "unexpected address output: %s", content)
	return addr
}

func buildPoolPath(tokenA, tokenB, fee string) string {
	tokens := []string{tokenA, tokenB}
	sort.Strings(tokens)
	return tokens[0] + ":" + tokens[1] + ":" + fee
}
