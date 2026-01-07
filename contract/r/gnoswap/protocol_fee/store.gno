package protocol_fee

import (
	"errors"

	"gno.land/p/gnoswap/store"
	"gno.land/p/nt/avl"
	"gno.land/p/nt/ufmt"
)

type StoreKey string

func (s StoreKey) String() string {
	return string(s)
}

const (
	// By default, devOps will get 0% of the protocol fee (which means gov/staker will get 100% of the protocol fee)
	// This percentage can be modified through governance.
	StoreKeyDevOpsPct StoreKey = "devOpsPct"

	// dust claim min/max amount (global)
	StoreKeyDustClaimMinAmount StoreKey = "dustClaimMinAmount"
	StoreKeyDustClaimMaxAmount StoreKey = "dustClaimMaxAmount"

	// accumulated amount distributed to gov/staker by token path
	StoreKeyAccuToGovStaker StoreKey = "accuToGovStaker" // tokenPath -> amount
	StoreKeyAccuToDevOps    StoreKey = "accuToDevOps"    // tokenPath -> amount

	// distributedToDevOpsHistory and distributedToGovStakerHistory are used to keep track of the distribution history
	StoreKeyDistributedToGovStakerHistory StoreKey = "distributedToGovStakerHistory" // tokenPath -> amount
	StoreKeyDistributedToDevOpsHistory    StoreKey = "distributedToDevOpsHistory"    // tokenPath -> amount

	// tokenListWithAmounts is used to keep track of the token list with amount
	StoreKeyTokenListWithAmounts StoreKey = "tokenListWithAmounts" // tokenPath -> amount
)

const (
	defaultDevOpsPct = int64(0)
	defaultDustClaimMinAmount = int64(1)
	defaultDustClaimMaxAmount = int64(1<<63 - 1)
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

// handle dust claim min amount store data
func (s *protocolFeeStore) HasDustClaimMinAmountStoreKey() bool {
	return s.kvStore.Has(StoreKeyDustClaimMinAmount.String())
}

func (s *protocolFeeStore) InitializeDustClaimMinAmount() error {
	return s.kvStore.Set(StoreKeyDustClaimMinAmount.String(), defaultDustClaimMinAmount)
}

func (s *protocolFeeStore) GetDustClaimMinAmount() int64 {
	amount, err := s.kvStore.GetInt64(StoreKeyDustClaimMinAmount.String())
	if err != nil {
		panic(err)
	}

	return amount
}

func (s *protocolFeeStore) SetDustClaimMinAmount(amount int64) error {
	return s.kvStore.Set(StoreKeyDustClaimMinAmount.String(), amount)
}

// handle dust claim max amount store data
func (s *protocolFeeStore) HasDustClaimMaxAmountStoreKey() bool {
	return s.kvStore.Has(StoreKeyDustClaimMaxAmount.String())
}

func (s *protocolFeeStore) InitializeDustClaimMaxAmount() error {
	return s.kvStore.Set(StoreKeyDustClaimMaxAmount.String(), defaultDustClaimMaxAmount)
}

func (s *protocolFeeStore) GetDustClaimMaxAmount() int64 {
	amount, err := s.kvStore.GetInt64(StoreKeyDustClaimMaxAmount.String())
	if err != nil {
		panic(err)
	}

	return amount
}

func (s *protocolFeeStore) SetDustClaimMaxAmount(amount int64) error {
	return s.kvStore.Set(StoreKeyDustClaimMaxAmount.String(), amount)
}

// handle accuToGovStaker store data
func (s *protocolFeeStore) HasAccuToGovStakerStoreKey() bool {
	return s.kvStore.Has(StoreKeyAccuToGovStaker.String())
}

func (s *protocolFeeStore) InitializeAccuToGovStaker() error {
	return s.kvStore.Set(StoreKeyAccuToGovStaker.String(), avl.NewTree())
}

func (s *protocolFeeStore) GetAccuToGovStaker() *avl.Tree {
	accuToGovStaker, err := s.kvStore.GetTree(StoreKeyAccuToGovStaker.String())
	if err != nil {
		panic(err)
	}

	return accuToGovStaker
}

func (s *protocolFeeStore) GetAccuToGovStakerItem(tokenPath string) (int64, bool) {
	accuToGovStaker, err := s.kvStore.GetTree(StoreKeyAccuToGovStaker.String())
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
	accuToGovStaker, err := s.kvStore.GetTree(StoreKeyAccuToGovStaker.String())
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
	return s.kvStore.Set(StoreKeyAccuToDevOps.String(), avl.NewTree())
}

func (s *protocolFeeStore) GetAccuToDevOps() *avl.Tree {
	accuToDevOps, err := s.kvStore.GetTree(StoreKeyAccuToDevOps.String())
	if err != nil {
		panic(err)
	}

	return accuToDevOps
}

func (s *protocolFeeStore) GetAccuToDevOpsItem(tokenPath string) (int64, bool) {
	accuToDevOps, err := s.kvStore.GetTree(StoreKeyAccuToDevOps.String())
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
	accuToDevOps, err := s.kvStore.GetTree(StoreKeyAccuToDevOps.String())
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
	return s.kvStore.Set(StoreKeyDistributedToGovStakerHistory.String(), avl.NewTree())
}

func (s *protocolFeeStore) GetDistributedToGovStakerHistory() *avl.Tree {
	distributedToGovStakerHistory, err := s.kvStore.GetTree(StoreKeyDistributedToGovStakerHistory.String())
	if err != nil {
		panic(err)
	}

	return distributedToGovStakerHistory
}

func (s *protocolFeeStore) GetDistributedToGovStakerHistoryItem(tokenPath string) (int64, bool) {
	distributedToGovStakerHistory, err := s.kvStore.GetTree(StoreKeyDistributedToGovStakerHistory.String())
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
	distributedToGovStakerHistory, err := s.kvStore.GetTree(StoreKeyDistributedToGovStakerHistory.String())
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
	return s.kvStore.Set(StoreKeyDistributedToDevOpsHistory.String(), avl.NewTree())
}

func (s *protocolFeeStore) GetDistributedToDevOpsHistory() *avl.Tree {
	distributedToDevOpsHistory, err := s.kvStore.GetTree(StoreKeyDistributedToDevOpsHistory.String())
	if err != nil {
		panic(err)
	}

	return distributedToDevOpsHistory
}

func (s *protocolFeeStore) GetDistributedToDevOpsHistoryItem(tokenPath string) (int64, bool) {
	distributedToDevOpsHistory, err := s.kvStore.GetTree(StoreKeyDistributedToDevOpsHistory.String())
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
	distributedToDevOpsHistory, err := s.kvStore.GetTree(StoreKeyDistributedToDevOpsHistory.String())
	if err != nil {
		return err
	}

	distributedToDevOpsHistory.Set(tokenPath, amount)

	return s.kvStore.Set(StoreKeyDistributedToDevOpsHistory.String(), distributedToDevOpsHistory)
}

// handle tokenListWithAmounts store data
func (s *protocolFeeStore) HasTokenListWithAmountsStoreKey() bool {
	return s.kvStore.Has(StoreKeyTokenListWithAmounts.String())
}

func (s *protocolFeeStore) InitializeTokenListWithAmount() error {
	return s.kvStore.Set(StoreKeyTokenListWithAmounts.String(), make(map[string]int64))
}

func (s *protocolFeeStore) GetTokenListWithAmounts() map[string]int64 {
	result, err := s.kvStore.Get(StoreKeyTokenListWithAmounts.String())
	if err != nil {
		panic(err)
	}

	tokenListWithAmounts, ok := result.(map[string]int64)
	if !ok {
		panic(ufmt.Errorf("failed to cast result to map[string]int64: %T", result))
	}

	return tokenListWithAmounts
}

func (s *protocolFeeStore) SetTokenListWithAmounts(tokenListWithAmounts map[string]int64) error {
	if tokenListWithAmounts == nil {
		return errors.New("tokenListWithAmounts is nil")
	}

	return s.kvStore.Set(StoreKeyTokenListWithAmounts.String(), tokenListWithAmounts)
}

func (s *protocolFeeStore) GetTokenListWithAmountItem(tokenPath string) (int64, bool) {
	result, err := s.kvStore.Get(StoreKeyTokenListWithAmounts.String())
	if err != nil {
		panic(err)
	}

	tokenListWithAmounts, ok := result.(map[string]int64)
	if !ok {
		panic(ufmt.Errorf("failed to cast result to map[string]int64: %T", result))
	}

	amount, ok := tokenListWithAmounts[tokenPath]
	if !ok {
		return 0, false
	}

	return amount, true
}

func (s *protocolFeeStore) SetTokenListWithAmountItem(tokenPath string, amount int64) error {
	result, err := s.kvStore.Get(StoreKeyTokenListWithAmounts.String())
	if err != nil {
		return err
	}

	tokenListWithAmounts, ok := result.(map[string]int64)
	if !ok {
		return ufmt.Errorf("failed to cast result to map[string]int64: %T", result)
	}

	tokenListWithAmounts[tokenPath] = amount

	return s.kvStore.Set(StoreKeyTokenListWithAmounts.String(), tokenListWithAmounts)
}

// NewprotocolFeeStore creates a new protocol fee store instance with the provided KV store.
// This function is used by the upgrade system to create storage instances for each implementation.
func NewProtocolFeeStore(kvStore store.KVStore) IProtocolFeeStore {
	return &protocolFeeStore{
		kvStore: kvStore,
	}
}
