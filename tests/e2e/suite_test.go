package e2e

import (
	"context"
	"fmt"
	"strings"
	"testing"
	"time"

	"github.com/stretchr/testify/suite"
)

type E2ETestSuite struct {
	suite.Suite
	cfg                  *Config
	atomoneClientID      string
	gnoClientID          string
	atomOneSenderAddress string
	gnoSenderAddress     string
	atomoneContainer     string
	gnoContainer         string
}

func TestE2E(t *testing.T) {
	suite.Run(t, new(E2ETestSuite))
}

func (s *E2ETestSuite) SetupSuite() {
	cfg, err := LoadConfig()
	s.Require().NoError(err, "load config")
	s.cfg = cfg

	_, err = httpGet(cfg.AtomoneREST + "/cosmos/base/tendermint/v1beta1/node_info")
	s.Require().NoError(err, "atomone REST not reachable at %s", cfg.AtomoneREST)

	s.atomoneContainer, err = getContainerID("atomone")
	s.Require().NoError(err, "get atomone container ID")
	s.gnoContainer, err = getContainerID("gno")
	s.Require().NoError(err, "get gno container ID")

	_, err = gnoQuery(s.gnoContainer, cfg.GnoGnokeyRemote, "r/aib/ibc/core", "")
	s.Require().NoError(err, "gno node not reachable")

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	stdout, stderr, err := dockerExec(ctx, s.atomoneContainer,
		"atomoned", "keys", "show", "validator", "-a",
		"--keyring-backend", "test", "--home", "/root/.atomone")
	s.Require().NoError(err, "get validator address: %s", stderr)
	s.atomOneSenderAddress = strings.TrimSpace(stdout)
	s.Require().NotEmpty(s.atomOneSenderAddress)

	s.recoverGnoKey("test", cfg.TestMnemonic)
	s.gnoSenderAddress = s.gnoKeyAddress("test")
	s.waitForIBCClients()
}

func (s *E2ETestSuite) waitForIBCClients() {
	r := s.Require()

	r.Eventually(func() bool {
		id, err := queryAtomOneClientStates(s.cfg.AtomoneREST)
		if err != nil {
			return false
		}
		s.atomoneClientID = id
		return true
	}, 8*time.Minute, 2*time.Second, "IBC client on AtomOne not created in time")

	r.Eventually(func() bool {
		id, err := queryGnoClients(s.gnoContainer, s.cfg.GnoGnokeyRemote)
		if err != nil {
			return false
		}
		s.gnoClientID = id
		return true
	}, 8*time.Minute, 2*time.Second, "IBC client on Gno not created in time")

	r.Eventually(func() bool {
		_, err := queryGnoClientCounterparty(s.gnoContainer, s.cfg.GnoGnokeyRemote, s.gnoClientID)
		return err == nil
	}, 8*time.Minute, 2*time.Second, "counterparty not registered on Gno in time")
}

func (s *E2ETestSuite) recoverGnoKey(keyName, mnemonic string) {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	stdin := fmt.Sprintf("%s\n\n", mnemonic)
	_, stderr, err := dockerExecStdin(ctx, s.gnoContainer, stdin,
		"gnokey", "add", keyName, "--recover", "--insecure-password-stdin", "--force")
	s.Require().NoError(err, "gnokey add --recover: %s", stderr)
}

func (s *E2ETestSuite) gnoKeyAddress(keyName string) string {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	stdout, stderr, err := dockerExec(ctx, s.gnoContainer, "gnokey", "list")
	s.Require().NoError(err, "gnokey list: %s", stderr)

	for line := range strings.SplitSeq(stdout, "\n") {
		if strings.Contains(line, keyName) {
			idx := strings.Index(line, "addr: ")
			if idx >= 0 {
				rest := line[idx+len("addr: "):]
				return strings.Fields(rest)[0]
			}
		}
	}

	s.Require().Fail("key not found", "key %s not found in gnokey list output: %s", keyName, stdout)
	return ""
}
