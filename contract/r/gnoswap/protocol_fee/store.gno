package protocol_fee

import (
	"errors"

	"gno.land/p/gnoswap/store"
	bptree "gno.land/p/nt/bptree/v0"
	ufmt "gno.land/p/nt/ufmt/v0"
)

type StoreKey string

func (s StoreKey) String() string {
	return string(s)
}

const (
	// By default, devOps will get 0% of the protocol fee (which means gov/staker will get 100% of the protocol fee)
	// This percentage can be modified through governance.
	StoreKeyDevOpsPct StoreKey = "devOpsPct"

	// accumulated amount distributed to gov/staker by token path
	StoreKeyAccuToGovStaker StoreKey = "accuToGovStaker" // tokenPath -> amount
	StoreKeyAccuToDevOps    StoreKey = "accuToDevOps"    // tokenPath -> amount

	// distributedToDevOpsHistory and distributedToGovStakerHistory are used to keep track of the distribution history
	StoreKeyDistributedToGovStakerHistory StoreKey = "distributedToGovStakerHistory" // tokenPath -> amount
	StoreKeyDistributedToDevOpsHistory    StoreKey = "distributedToDevOpsHistory"    // tokenPath -> amount

	// reservedTokens tracks token paths collected but not yet distributed.
	StoreKeyReservedTokens StoreKey = "reservedTokens"
)

const (
	defaultDevOpsPct = int64(0)
)

type protocolFeeStore struct {
	kvStore store.KVStore
}

// handle devOpsPct store data
func (s *protocolFeeStore) HasDevOpsPctStoreKey() bool {
	return s.kvStore.Has(StoreKeyDevOpsPct.String())
}

func (s *protocolFeeStore) InitializeDevOpsPct() error {
	return s.kvStore.Set(StoreKeyDevOpsPct.String(), defaultDevOpsPct)
}

func (s *protocolFeeStore) GetDevOpsPct() int64 {
	devOpsPct, err := s.kvStore.GetInt64(StoreKeyDevOpsPct.String())
	if err != nil {
		panic(err)
	}

	return devOpsPct
}

func (s *protocolFeeStore) SetDevOpsPct(pct int64) error {
	return s.kvStore.Set(StoreKeyDevOpsPct.String(), pct)
}

// handle accuToGovStaker store data
func (s *protocolFeeStore) HasAccuToGovStakerStoreKey() bool {
	return s.kvStore.Has(StoreKeyAccuToGovStaker.String())
}

func (s *protocolFeeStore) InitializeAccuToGovStaker() error {
	return s.kvStore.Set(StoreKeyAccuToGovStaker.String(), bptree.NewBPTreeN(16))
}

func (s *protocolFeeStore) GetAccuToGovStaker() *bptree.BPTree {
	accuToGovStaker, err := s.kvStore.GetBPTree(StoreKeyAccuToGovStaker.String())
	if err != nil {
		panic(err)
	}

	return accuToGovStaker
}

func (s *protocolFeeStore) GetAccuToGovStakerItem(tokenPath string) (int64, bool) {
	accuToGovStaker, err := s.kvStore.GetBPTree(StoreKeyAccuToGovStaker.String())
	if err != nil {
		panic(err)
	}

	result, ok := accuToGovStaker.Get(tokenPath)
	if !ok {
		return 0, false
	}

	amount, ok := result.(int64)
	if !ok {
		panic(ufmt.Errorf("failed to cast result to int64: %T", result))
	}

	return amount, true
}

func (s *protocolFeeStore) SetAccuToGovStakerItem(tokenPath string, amount int64) error {
	accuToGovStaker, err := s.kvStore.GetBPTree(StoreKeyAccuToGovStaker.String())
	if err != nil {
		return err
	}

	accuToGovStaker.Set(tokenPath, amount)

	return s.kvStore.Set(StoreKeyAccuToGovStaker.String(), accuToGovStaker)
}

// handle accuToDevOps store data
func (s *protocolFeeStore) HasAccuToDevOpsStoreKey() bool {
	return s.kvStore.Has(StoreKeyAccuToDevOps.String())
}

func (s *protocolFeeStore) InitializeAccuToDevOps() error {
	return s.kvStore.Set(StoreKeyAccuToDevOps.String(), bptree.NewBPTreeN(16))
}

func (s *protocolFeeStore) GetAccuToDevOps() *bptree.BPTree {
	accuToDevOps, err := s.kvStore.GetBPTree(StoreKeyAccuToDevOps.String())
	if err != nil {
		panic(err)
	}

	return accuToDevOps
}

func (s *protocolFeeStore) GetAccuToDevOpsItem(tokenPath string) (int64, bool) {
	accuToDevOps, err := s.kvStore.GetBPTree(StoreKeyAccuToDevOps.String())
	if err != nil {
		panic(err)
	}

	result, ok := accuToDevOps.Get(tokenPath)
	if !ok {
		return 0, false
	}

	amount, ok := result.(int64)
	if !ok {
		panic(ufmt.Errorf("failed to cast result to int64: %T", result))
	}

	return amount, true
}

func (s *protocolFeeStore) SetAccuToDevOpsItem(tokenPath string, amount int64) error {
	accuToDevOps, err := s.kvStore.GetBPTree(StoreKeyAccuToDevOps.String())
	if err != nil {
		return err
	}

	accuToDevOps.Set(tokenPath, amount)

	return s.kvStore.Set(StoreKeyAccuToDevOps.String(), accuToDevOps)
}

// handle distributedToGovStakerHistory store data
func (s *protocolFeeStore) HasDistributedToGovStakerHistoryStoreKey() bool {
	return s.kvStore.Has(StoreKeyDistributedToGovStakerHistory.String())
}

func (s *protocolFeeStore) InitializeDistributedToGovStakerHistory() error {
	return s.kvStore.Set(StoreKeyDistributedToGovStakerHistory.String(), bptree.NewBPTreeN(16))
}

func (s *protocolFeeStore) GetDistributedToGovStakerHistory() *bptree.BPTree {
	distributedToGovStakerHistory, err := s.kvStore.GetBPTree(StoreKeyDistributedToGovStakerHistory.String())
	if err != nil {
		panic(err)
	}

	return distributedToGovStakerHistory
}

func (s *protocolFeeStore) GetDistributedToGovStakerHistoryItem(tokenPath string) (int64, bool) {
	distributedToGovStakerHistory, err := s.kvStore.GetBPTree(StoreKeyDistributedToGovStakerHistory.String())
	if err != nil {
		panic(err)
	}

	result, ok := distributedToGovStakerHistory.Get(tokenPath)
	if !ok {
		return 0, false
	}

	amount, ok := result.(int64)
	if !ok {
		panic(ufmt.Errorf("failed to cast result to int64: %T", result))
	}

	return amount, true
}

func (s *protocolFeeStore) SetDistributedToGovStakerHistoryItem(tokenPath string, amount int64) error {
	distributedToGovStakerHistory, err := s.kvStore.GetBPTree(StoreKeyDistributedToGovStakerHistory.String())
	if err != nil {
		return err
	}

	distributedToGovStakerHistory.Set(tokenPath, amount)

	return s.kvStore.Set(StoreKeyDistributedToGovStakerHistory.String(), distributedToGovStakerHistory)
}

// handle distributedToDevOpsHistory store data
func (s *protocolFeeStore) HasDistributedToDevOpsHistoryStoreKey() bool {
	return s.kvStore.Has(StoreKeyDistributedToDevOpsHistory.String())
}

func (s *protocolFeeStore) InitializeDistributedToDevOpsHistory() error {
	return s.kvStore.Set(StoreKeyDistributedToDevOpsHistory.String(), bptree.NewBPTreeN(16))
}

func (s *protocolFeeStore) GetDistributedToDevOpsHistory() *bptree.BPTree {
	distributedToDevOpsHistory, err := s.kvStore.GetBPTree(StoreKeyDistributedToDevOpsHistory.String())
	if err != nil {
		panic(err)
	}

	return distributedToDevOpsHistory
}

func (s *protocolFeeStore) GetDistributedToDevOpsHistoryItem(tokenPath string) (int64, bool) {
	distributedToDevOpsHistory, err := s.kvStore.GetBPTree(StoreKeyDistributedToDevOpsHistory.String())
	if err != nil {
		panic(err)
	}

	result, ok := distributedToDevOpsHistory.Get(tokenPath)
	if !ok {
		return 0, false
	}

	amount, ok := result.(int64)
	if !ok {
		panic(ufmt.Errorf("failed to cast result to int64: %T", result))
	}

	return amount, true
}

func (s *protocolFeeStore) SetDistributedToDevOpsHistoryItem(tokenPath string, amount int64) error {
	distributedToDevOpsHistory, err := s.kvStore.GetBPTree(StoreKeyDistributedToDevOpsHistory.String())
	if err != nil {
		return err
	}

	distributedToDevOpsHistory.Set(tokenPath, amount)

	return s.kvStore.Set(StoreKeyDistributedToDevOpsHistory.String(), distributedToDevOpsHistory)
}

// handle reservedTokens store data
func (s *protocolFeeStore) HasReservedTokensStoreKey() bool {
	return s.kvStore.Has(StoreKeyReservedTokens.String())
}

func (s *protocolFeeStore) InitializeReservedTokens() error {
	return s.kvStore.Set(StoreKeyReservedTokens.String(), []string{})
}

func (s *protocolFeeStore) GetReservedTokens() []string {
	result, err := s.kvStore.Get(StoreKeyReservedTokens.String())
	if err != nil {
		panic(err)
	}

	reservedTokens, ok := result.([]string)
	if !ok {
		panic(ufmt.Errorf("failed to cast result to []string: %T", result))
	}

	return reservedTokens
}

func (s *protocolFeeStore) SetReservedTokens(reservedTokens []string) error {
	if reservedTokens == nil {
		return errors.New("reservedTokens is nil")
	}

	return s.kvStore.Set(StoreKeyReservedTokens.String(), reservedTokens)
}

func (s *protocolFeeStore) AddReservedToken(tokenPath string) error {
	reservedTokens := s.GetReservedTokens()
	for _, reservedToken := range reservedTokens {
		if reservedToken == tokenPath {
			return nil
		}
	}

	reservedTokens = append(reservedTokens, tokenPath)
	return s.SetReservedTokens(reservedTokens)
}

// NewprotocolFeeStore creates a new protocol fee store instance with the provided KV store.
// This function is used by the upgrade system to create storage instances for each implementation.
func NewProtocolFeeStore(kvStore store.KVStore) IProtocolFeeStore {
	return &protocolFeeStore{
		kvStore: kvStore,
	}
}
