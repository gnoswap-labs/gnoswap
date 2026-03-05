package e2e

import (
	"fmt"
	"os"

	"github.com/joho/godotenv"
)

type Config struct {
	TestMnemonic    string
	RelayerMnemonic string
	AtomoneChainID  string
	GnoChainID      string
	AtomoneRPC      string
	AtomoneREST     string
	GnoGnokeyRemote string
	GnoREST         string
	RelayerGnoRPC   string
	IndexerQueryURL string
}

func LoadConfig() (*Config, error) {
	_ = godotenv.Load()

	cfg := &Config{
		TestMnemonic:    os.Getenv("TEST_MNEMONIC"),
		RelayerMnemonic: os.Getenv("RELAYER_MNEMONIC"),
		AtomoneChainID:  os.Getenv("ATOMONE_CHAIN_ID"),
		GnoChainID:      os.Getenv("GNO_CHAIN_ID"),
		AtomoneRPC:      os.Getenv("ATOMONE_RPC"),
		AtomoneREST:     os.Getenv("ATOMONE_REST"),
		GnoGnokeyRemote: os.Getenv("GNO_GNOKEY_REMOTE"),
		GnoREST:         os.Getenv("GNO_REST"),
		RelayerGnoRPC:   os.Getenv("RELAYER_GNO_RPC_URL"),
		IndexerQueryURL: os.Getenv("INDEXER_QUERY_URL"),
	}

	if cfg.TestMnemonic == "" {
		return nil, fmt.Errorf("TEST_MNEMONIC is required")
	}
	if cfg.RelayerMnemonic == "" {
		return nil, fmt.Errorf("RELAYER_MNEMONIC is required")
	}
	if cfg.AtomoneChainID == "" {
		cfg.AtomoneChainID = "atomone-e2e-1"
	}
	if cfg.GnoChainID == "" {
		cfg.GnoChainID = "dev"
	}
	if cfg.AtomoneRPC == "" {
		cfg.AtomoneRPC = "http://localhost:36657"
	}
	if cfg.AtomoneREST == "" {
		cfg.AtomoneREST = "http://localhost:1317"
	}
	if cfg.GnoGnokeyRemote == "" {
		cfg.GnoGnokeyRemote = "localhost:26657"
	}
	if cfg.GnoREST == "" {
		cfg.GnoREST = "http://localhost:8888"
	}
	if cfg.RelayerGnoRPC == "" {
		cfg.RelayerGnoRPC = "http://gno:26657"
	}
	if cfg.IndexerQueryURL == "" {
		cfg.IndexerQueryURL = "http://tx-indexer:8546/graphql/query"
	}

	return cfg, nil
}
