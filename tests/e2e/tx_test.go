package e2e

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"
	"time"

	"github.com/cosmos/gogoproto/proto"

	"github.com/cosmos/cosmos-sdk/codec"
	codectypes "github.com/cosmos/cosmos-sdk/codec/types"
	sdk "github.com/cosmos/cosmos-sdk/types"
	txtypes "github.com/cosmos/cosmos-sdk/types/tx"
	transfertypes "github.com/cosmos/ibc-go/v10/modules/apps/transfer/types"
	channeltypesv2 "github.com/cosmos/ibc-go/v10/modules/core/04-channel/v2/types"
)

func (s *E2ETestSuite) signAndBroadcastGnoCall(keyName, pkgPath, funcName, sendCoins string, args ...string) {
	cmdArgs := []string{
		"gnokey", "maketx", "call",
		"-pkgpath", pkgPath,
		"-func", funcName,
		"-gas-fee", "1000000ugnot",
		"-gas-wanted", "90000000",
		"-broadcast",
		"-chainid", s.cfg.GnoChainID,
		"-remote", s.cfg.GnoGnokeyRemote,
		"-insecure-password-stdin",
	}
	if sendCoins != "" {
		cmdArgs = append(cmdArgs, "-send", sendCoins)
	}
	for _, arg := range args {
		cmdArgs = append(cmdArgs, "-args", arg)
	}
	cmdArgs = append(cmdArgs, keyName)

	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()

	stdout, stderr, err := dockerExecStdin(ctx, s.gnoContainer, "\n", cmdArgs...)
	s.Require().NoError(err, "gnokey maketx call: stdout=%s stderr=%s", stdout, stderr)
}

func (s *E2ETestSuite) signAndBroadcastAtomOneTx(signer string, msgs ...proto.Message) {
	unsignedTx := buildUnsignedTx(msgs, channeltypesv2.RegisterInterfaces)

	ctx := context.Background()

	_, stderr, err := dockerExecStdin(ctx, s.atomoneContainer, unsignedTx,
		"bash", "-c", "cat > /tmp/unsigned_tx.json")
	s.Require().NoError(err, "write unsigned tx: %s", stderr)

	signCtx, signCancel := context.WithTimeout(ctx, 30*time.Second)
	defer signCancel()
	_, stderr, err = dockerExec(signCtx, s.atomoneContainer,
		"atomoned", "tx", "sign", "/tmp/unsigned_tx.json",
		"--from", signer,
		"--chain-id", s.cfg.AtomoneChainID,
		"--keyring-backend", "test",
		"--home", "/root/.atomone",
		"--node", "tcp://localhost:26657",
		"--output-document", "/tmp/signed_tx.json",
	)
	s.Require().NoError(err, "sign tx: %s", stderr)

	bcastCtx, bcastCancel := context.WithTimeout(ctx, 30*time.Second)
	defer bcastCancel()
	stdout, stderr, err := dockerExec(bcastCtx, s.atomoneContainer,
		"atomoned", "tx", "broadcast", "/tmp/signed_tx.json",
		"--node", "tcp://localhost:26657",
		"--output", "json",
	)
	s.Require().NoError(err, "broadcast tx: %s", stderr)

	var bcastResult struct {
		TxHash string `json:"txhash"`
	}
	err = json.Unmarshal([]byte(strings.TrimSpace(stdout)), &bcastResult)
	s.Require().NoError(err, "parse broadcast result: %s", stdout)
	s.Require().NotEmpty(bcastResult.TxHash, "broadcast returned empty txhash")

	s.Require().Eventually(func() bool {
		qCtx, qCancel := context.WithTimeout(ctx, 10*time.Second)
		defer qCancel()
		stdout, _, err := dockerExec(qCtx, s.atomoneContainer,
			"atomoned", "q", "tx", bcastResult.TxHash,
			"--node", "tcp://localhost:26657",
			"--output", "json",
		)
		if err != nil {
			return false
		}
		var txResult struct {
			Code   int    `json:"code"`
			RawLog string `json:"raw_log"`
		}
		if err := json.Unmarshal([]byte(strings.TrimSpace(stdout)), &txResult); err != nil {
			return false
		}
		s.Require().Equal(0, txResult.Code, "tx failed: %s", txResult.RawLog)
		return true
	}, 30*time.Second, time.Second, "tx %s not confirmed", bcastResult.TxHash)
}

func buildMsgSendPacket(sourceClient, sender, receiver, denom string, amount, timeoutTimestamp int64) *channeltypesv2.MsgSendPacket {
	packetData := transfertypes.NewFungibleTokenPacketData(
		denom, fmt.Sprint(amount), sender, receiver, "",
	)
	bz, err := proto.Marshal(&packetData)
	if err != nil {
		panic(fmt.Sprintf("marshal FungibleTokenPacketData: %v", err))
	}

	payload := channeltypesv2.NewPayload(
		transfertypes.PortID, transfertypes.PortID,
		transfertypes.V1, transfertypes.EncodingProtobuf, bz,
	)
	return channeltypesv2.NewMsgSendPacket(
		sourceClient, uint64(timeoutTimestamp), sender, payload,
	)
}

func buildUnsignedTx(msgs []proto.Message, registerInterfaces ...func(codectypes.InterfaceRegistry)) string {
	ir := codectypes.NewInterfaceRegistry()
	for _, register := range registerInterfaces {
		register(ir)
	}
	cdc := codec.NewProtoCodec(ir)

	anyMsgs := make([]*codectypes.Any, len(msgs))
	for i, msg := range msgs {
		anyMsg, err := codectypes.NewAnyWithValue(msg)
		if err != nil {
			panic(fmt.Sprintf("pack message: %v", err))
		}
		anyMsgs[i] = anyMsg
	}

	tx := txtypes.Tx{
		Body: &txtypes.TxBody{
			Messages: anyMsgs,
		},
		AuthInfo: &txtypes.AuthInfo{
			Fee: &txtypes.Fee{
				Amount:   sdk.NewCoins(sdk.NewInt64Coin("uphoton", 10000)),
				GasLimit: 300000,
			},
		},
		Signatures: [][]byte{},
	}

	txJSON, err := cdc.MarshalJSON(&tx)
	if err != nil {
		panic(fmt.Sprintf("marshal tx: %v", err))
	}
	return string(txJSON)
}
