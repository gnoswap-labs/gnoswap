package e2e

import (
	"fmt"
	"time"
)

func (s *E2ETestSuite) TestIBCTransferAtomOneToGno() {
	var (
		r              = s.Require()
		transferAmount = int64(10)
		denom          = "uatone"
		sender         = s.atomOneSenderAddress
		receiver       = s.gnoSenderAddress
		timeout        = time.Now().Add(time.Hour).Unix()
	)

	beforeAtomOneBalance, err := queryAtomOneBalance(s.cfg.AtomoneREST, sender, denom)
	r.NoError(err, "query sender balance before transfer")

	msg := buildMsgSendPacket(
		s.atomoneClientID, sender, receiver,
		denom, transferAmount, timeout,
	)

	s.signAndBroadcastAtomOneTx(sender, msg)

	afterAtomOneBalance, err := queryAtomOneBalance(s.cfg.AtomoneREST, sender, denom)
	r.NoError(err, "query sender balance after transfer")
	r.Equal(beforeAtomOneBalance-transferAmount, afterAtomOneBalance, "sender balance did not decrease on AtomOne")

	ibcDenom := "ibc/" + computeIBCDenomHash(s.gnoClientID, denom)
	beforeGRC20, _ := queryGnoGRC20Balance(s.gnoContainer, s.cfg.GnoGnokeyRemote, receiver, ibcDenom)

	var afterGRC20 int64
	r.Eventually(func() bool {
		bal, err := queryGnoGRC20Balance(s.gnoContainer, s.cfg.GnoGnokeyRemote, receiver, ibcDenom)
		if err != nil {
			return false
		}
		afterGRC20 = bal
		return afterGRC20 == beforeGRC20+transferAmount
	}, time.Minute/2, time.Second, "GRC20 balance not received on Gno")

	sender = s.gnoSenderAddress
	receiver = s.atomOneSenderAddress
	beforeGRC20 = afterGRC20
	beforeAtomOneBalance = afterAtomOneBalance

	s.signAndBroadcastGnoCall(sender,
		"gno.land/r/aib/ibc/apps/transfer", "TransferGRC20",
		"",
		s.gnoClientID, receiver, ibcDenom, fmt.Sprint(transferAmount), fmt.Sprint(timeout),
	)

	r.Eventually(func() bool {
		bal, err := queryGnoGRC20Balance(s.gnoContainer, s.cfg.GnoGnokeyRemote, sender, ibcDenom)
		if err != nil {
			return false
		}
		afterGRC20 = bal
		return afterGRC20 == beforeGRC20-transferAmount
	}, time.Minute/2, time.Second, "sender balance did not decrease on Gno")

	r.Eventually(func() bool {
		bal, err := queryAtomOneBalance(s.cfg.AtomoneREST, receiver, denom)
		if err != nil {
			return false
		}
		afterAtomOneBalance = bal
		return afterAtomOneBalance == beforeAtomOneBalance+transferAmount
	}, time.Minute/2, time.Second, "atone balance not received on AtomOne")
}

func (s *E2ETestSuite) TestIBCTransferGnoToAtomOne() {
	var (
		r              = s.Require()
		transferAmount = int64(100)
		denom          = "ugnot"
		sender         = s.gnoSenderAddress
		receiver       = s.atomOneSenderAddress
		timeout        = time.Now().Add(time.Hour).Unix()
	)

	beforeGnoBalance, err := queryGnoBalance(s.gnoContainer, s.cfg.GnoGnokeyRemote, sender, denom)
	r.NoError(err, "query gno sender balance before transfer")

	s.signAndBroadcastGnoCall(sender,
		"gno.land/r/aib/ibc/apps/transfer", "Transfer",
		fmt.Sprintf("%d%s", transferAmount, denom),
		s.gnoClientID, receiver, fmt.Sprint(timeout),
	)

	var afterGnoBalance int64
	r.Eventually(func() bool {
		bal, err := queryGnoBalance(s.gnoContainer, s.cfg.GnoGnokeyRemote, sender, denom)
		if err != nil {
			return false
		}
		afterGnoBalance = bal
		return afterGnoBalance <= beforeGnoBalance-transferAmount
	}, time.Minute/2, time.Second, "sender balance did not decrease on Gno")

	ibcDenom := "ibc/" + computeIBCDenomHash(s.atomoneClientID, denom)
	beforeAtomOneBalance, _ := queryAtomOneBalance(s.cfg.AtomoneREST, receiver, ibcDenom)

	var afterAtomOneBalance int64
	r.Eventually(func() bool {
		bal, err := queryAtomOneBalance(s.cfg.AtomoneREST, receiver, ibcDenom)
		if err != nil {
			return false
		}
		afterAtomOneBalance = bal
		return afterAtomOneBalance == beforeAtomOneBalance+transferAmount
	}, time.Minute*2, time.Second, "IBC voucher balance not received on AtomOne")

	sender = s.atomOneSenderAddress
	receiver = s.gnoSenderAddress
	beforeAtomOneBalance = afterAtomOneBalance
	beforeGnoBalance = afterGnoBalance

	msg := buildMsgSendPacket(
		s.atomoneClientID, sender, receiver,
		fmt.Sprintf("transfer/%s/%s", s.atomoneClientID, denom),
		transferAmount, timeout,
	)

	s.signAndBroadcastAtomOneTx(sender, msg)

	afterAtomOneBalance, err = queryAtomOneBalance(s.cfg.AtomoneREST, sender, ibcDenom)
	r.NoError(err, "query sender balance after transfer")
	r.Equal(beforeAtomOneBalance-transferAmount, afterAtomOneBalance, "sender balance did not decrease on AtomOne")

	r.Eventually(func() bool {
		bal, err := queryGnoBalance(s.gnoContainer, s.cfg.GnoGnokeyRemote, receiver, denom)
		if err != nil {
			return false
		}
		afterGnoBalance = bal
		return afterGnoBalance == beforeGnoBalance+transferAmount
	}, time.Minute/2, time.Second, "gnot balance not received on Gno")
}
