package protocol_fee

import (
	"errors"

	bptree "gno.land/p/nt/bptree/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/p/gnoswap/gnsmath/v1"
	"gno.land/p/gnoswap/store"
	"gno.land/p/gnoswap/utils/v1"
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

	// accrualEpoch, accrualBuckets and accrualPendingTokens track the gov/staker share
	// per token path and accrual epoch until gov/staker folds it into its accumulator.
	StoreKeyAccrualEpoch         StoreKey = "accrualEpoch"
	StoreKeyAccrualBuckets       StoreKey = "accrualBuckets"       // tokenPath -> (epoch -> amount)
	StoreKeyAccrualPendingTokens StoreKey = "accrualPendingTokens" // tokenPath -> true
)

const (
	defaultDevOpsPct = int64(0)
	errSpoofedRealm  = "rlm does not match the current crossing frame"
)

// NewBPTreeN allocates a BP-tree under /r/gnoswap/protocol_fee's realm context
// so tree.Set leaf-slot writes clear the readonly-taint gate regardless of
// which realm (protocol_fee/v1, mock, tests) calls Set. Callers must allocate
// protocol_fee trees through here rather than bptree.NewBPTreeN directly.
func NewBPTreeN(fanout int) *bptree.BPTree {
	return bptree.NewBPTreeN(fanout)
}

type protocolFeeStore struct {
	kvStore store.KVStore
}

// handle devOpsPct store data
func (s *protocolFeeStore) HasDevOpsPctStoreKey() bool {
	return s.kvStore.Has(StoreKeyDevOpsPct.String())
}

func (s *protocolFeeStore) InitializeDevOpsPct(_ int, rlm realm) error {
	if !rlm.IsCurrent() {
		return errors.New(errSpoofedRealm)
	}

	return s.kvStore.Set(0, rlm, StoreKeyDevOpsPct.String(), defaultDevOpsPct)
}

func (s *protocolFeeStore) GetDevOpsPct() int64 {
	devOpsPct, err := s.kvStore.GetInt64(StoreKeyDevOpsPct.String())
	if err != nil {
		panic(err)
	}

	return devOpsPct
}

func (s *protocolFeeStore) SetDevOpsPct(_ int, rlm realm, pct int64) error {
	if !rlm.IsCurrent() {
		return errors.New(errSpoofedRealm)
	}

	return s.kvStore.Set(0, rlm, StoreKeyDevOpsPct.String(), pct)
}

// handle accuToGovStaker store data
func (s *protocolFeeStore) HasAccuToGovStakerStoreKey() bool {
	return s.kvStore.Has(StoreKeyAccuToGovStaker.String())
}

func (s *protocolFeeStore) InitializeAccuToGovStaker(_ int, rlm realm) error {
	if !rlm.IsCurrent() {
		return errors.New(errSpoofedRealm)
	}

	return s.kvStore.Set(0, rlm, StoreKeyAccuToGovStaker.String(), NewBPTreeN(16))
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

	result := accuToGovStaker.Get(tokenPath)
	if result == nil {
		return 0, false
	}

	amount, ok := result.(int64)
	if !ok {
		panic(ufmt.Errorf("failed to cast result to int64: %T", result))
	}

	return amount, true
}

func (s *protocolFeeStore) SetAccuToGovStakerItem(_ int, rlm realm, tokenPath string, amount int64) error {
	if !rlm.IsCurrent() {
		return errors.New(errSpoofedRealm)
	}

	accuToGovStaker, err := s.kvStore.GetBPTree(StoreKeyAccuToGovStaker.String())
	if err != nil {
		return err
	}

	accuToGovStaker.Set(tokenPath, amount)

	return s.kvStore.Set(0, rlm, StoreKeyAccuToGovStaker.String(), accuToGovStaker)
}

// handle accuToDevOps store data
func (s *protocolFeeStore) HasAccuToDevOpsStoreKey() bool {
	return s.kvStore.Has(StoreKeyAccuToDevOps.String())
}

func (s *protocolFeeStore) InitializeAccuToDevOps(_ int, rlm realm) error {
	if !rlm.IsCurrent() {
		return errors.New(errSpoofedRealm)
	}

	return s.kvStore.Set(0, rlm, StoreKeyAccuToDevOps.String(), NewBPTreeN(16))
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

	result := accuToDevOps.Get(tokenPath)
	if result == nil {
		return 0, false
	}

	amount, ok := result.(int64)
	if !ok {
		panic(ufmt.Errorf("failed to cast result to int64: %T", result))
	}

	return amount, true
}

func (s *protocolFeeStore) SetAccuToDevOpsItem(_ int, rlm realm, tokenPath string, amount int64) error {
	if !rlm.IsCurrent() {
		return errors.New(errSpoofedRealm)
	}

	accuToDevOps, err := s.kvStore.GetBPTree(StoreKeyAccuToDevOps.String())
	if err != nil {
		return err
	}

	accuToDevOps.Set(tokenPath, amount)

	return s.kvStore.Set(0, rlm, StoreKeyAccuToDevOps.String(), accuToDevOps)
}

// handle distributedToGovStakerHistory store data
func (s *protocolFeeStore) HasDistributedToGovStakerHistoryStoreKey() bool {
	return s.kvStore.Has(StoreKeyDistributedToGovStakerHistory.String())
}

func (s *protocolFeeStore) InitializeDistributedToGovStakerHistory(_ int, rlm realm) error {
	if !rlm.IsCurrent() {
		return errors.New(errSpoofedRealm)
	}

	return s.kvStore.Set(0, rlm, StoreKeyDistributedToGovStakerHistory.String(), NewBPTreeN(16))
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

	result := distributedToGovStakerHistory.Get(tokenPath)
	if result == nil {
		return 0, false
	}

	amount, ok := result.(int64)
	if !ok {
		panic(ufmt.Errorf("failed to cast result to int64: %T", result))
	}

	return amount, true
}

func (s *protocolFeeStore) SetDistributedToGovStakerHistoryItem(_ int, rlm realm, tokenPath string, amount int64) error {
	if !rlm.IsCurrent() {
		return errors.New(errSpoofedRealm)
	}

	distributedToGovStakerHistory, err := s.kvStore.GetBPTree(StoreKeyDistributedToGovStakerHistory.String())
	if err != nil {
		return err
	}

	distributedToGovStakerHistory.Set(tokenPath, amount)

	return s.kvStore.Set(0, rlm, StoreKeyDistributedToGovStakerHistory.String(), distributedToGovStakerHistory)
}

// handle distributedToDevOpsHistory store data
func (s *protocolFeeStore) HasDistributedToDevOpsHistoryStoreKey() bool {
	return s.kvStore.Has(StoreKeyDistributedToDevOpsHistory.String())
}

func (s *protocolFeeStore) InitializeDistributedToDevOpsHistory(_ int, rlm realm) error {
	if !rlm.IsCurrent() {
		return errors.New(errSpoofedRealm)
	}

	return s.kvStore.Set(0, rlm, StoreKeyDistributedToDevOpsHistory.String(), NewBPTreeN(16))
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

	result := distributedToDevOpsHistory.Get(tokenPath)
	if result == nil {
		return 0, false
	}

	amount, ok := result.(int64)
	if !ok {
		panic(ufmt.Errorf("failed to cast result to int64: %T", result))
	}

	return amount, true
}

func (s *protocolFeeStore) SetDistributedToDevOpsHistoryItem(_ int, rlm realm, tokenPath string, amount int64) error {
	if !rlm.IsCurrent() {
		return errors.New(errSpoofedRealm)
	}

	distributedToDevOpsHistory, err := s.kvStore.GetBPTree(StoreKeyDistributedToDevOpsHistory.String())
	if err != nil {
		return err
	}

	distributedToDevOpsHistory.Set(tokenPath, amount)

	return s.kvStore.Set(0, rlm, StoreKeyDistributedToDevOpsHistory.String(), distributedToDevOpsHistory)
}

// handle reservedTokens store data
//
// reservedTokens is the set of token paths that collected a fee not yet transferred out
// by DistributeProtocolFee. It is kept as a tree so that a single token can be added or
// settled without rewriting the whole set.
func (s *protocolFeeStore) HasReservedTokensStoreKey() bool {
	return s.kvStore.Has(StoreKeyReservedTokens.String())
}

func (s *protocolFeeStore) InitializeReservedTokens(_ int, rlm realm) error {
	if !rlm.IsCurrent() {
		return errors.New(errSpoofedRealm)
	}

	return s.kvStore.Set(0, rlm, StoreKeyReservedTokens.String(), NewBPTreeN(16))
}

func (s *protocolFeeStore) getReservedTokenTree() *bptree.BPTree {
	reservedTokens, err := s.kvStore.GetBPTree(StoreKeyReservedTokens.String())
	if err != nil {
		panic(err)
	}

	return reservedTokens
}

func (s *protocolFeeStore) GetReservedTokens() []string {
	return collectTreeKeys(s.getReservedTokenTree())
}

func (s *protocolFeeStore) HasReservedToken(tokenPath string) bool {
	return s.getReservedTokenTree().Has(tokenPath)
}

func (s *protocolFeeStore) AddReservedToken(_ int, rlm realm, tokenPath string) error {
	if !rlm.IsCurrent() {
		return errors.New(errSpoofedRealm)
	}

	reservedTokens := s.getReservedTokenTree()
	if reservedTokens.Has(tokenPath) {
		return nil
	}

	reservedTokens.Set(tokenPath, true)

	return s.kvStore.Set(0, rlm, StoreKeyReservedTokens.String(), reservedTokens)
}

// RemoveReservedToken removes one tokenPath from the reserved-token set when present.
func (s *protocolFeeStore) RemoveReservedToken(_ int, rlm realm, tokenPath string) error {
	if !rlm.IsCurrent() {
		return errors.New(errSpoofedRealm)
	}

	reservedTokens := s.getReservedTokenTree()
	if _, removed := reservedTokens.Remove(tokenPath); !removed {
		return nil
	}

	return s.kvStore.Set(0, rlm, StoreKeyReservedTokens.String(), reservedTokens)
}

// handle accrualEpoch store data
//
// accrualEpoch numbers the intervals between gov/staker stake changes. gov/staker
// advances it on every stake change, so every fee that arrives is attributed to the
// stake distribution in force when it arrived.
func (s *protocolFeeStore) HasAccrualEpochStoreKey() bool {
	return s.kvStore.Has(StoreKeyAccrualEpoch.String())
}

func (s *protocolFeeStore) InitializeAccrualEpoch(_ int, rlm realm) error {
	if !rlm.IsCurrent() {
		return errors.New(errSpoofedRealm)
	}

	return s.kvStore.Set(0, rlm, StoreKeyAccrualEpoch.String(), int64(0))
}

func (s *protocolFeeStore) GetAccrualEpoch() int64 {
	accrualEpoch, err := s.kvStore.GetInt64(StoreKeyAccrualEpoch.String())
	if err != nil {
		panic(err)
	}

	return accrualEpoch
}

func (s *protocolFeeStore) SetAccrualEpoch(_ int, rlm realm, accrualEpoch int64) error {
	if !rlm.IsCurrent() {
		return errors.New(errSpoofedRealm)
	}

	return s.kvStore.Set(0, rlm, StoreKeyAccrualEpoch.String(), accrualEpoch)
}

// handle accrualBuckets store data
//
// accrualBuckets holds, per token path, the gov/staker share collected during each
// accrual epoch that gov/staker has not folded into its accumulator yet. Folding
// consumes the oldest buckets first, so a token is settled in epoch order.
func (s *protocolFeeStore) HasAccrualBucketsStoreKey() bool {
	return s.kvStore.Has(StoreKeyAccrualBuckets.String())
}

func (s *protocolFeeStore) InitializeAccrualBuckets(_ int, rlm realm) error {
	if !rlm.IsCurrent() {
		return errors.New(errSpoofedRealm)
	}

	return s.kvStore.Set(0, rlm, StoreKeyAccrualBuckets.String(), NewBPTreeN(16))
}

func (s *protocolFeeStore) getAccrualBucketTree() *bptree.BPTree {
	accrualBuckets, err := s.kvStore.GetBPTree(StoreKeyAccrualBuckets.String())
	if err != nil {
		panic(err)
	}

	return accrualBuckets
}

func (s *protocolFeeStore) getTokenAccrualBucketTree(accrualBuckets *bptree.BPTree, tokenPath string) *bptree.BPTree {
	result := accrualBuckets.Get(tokenPath)
	if result == nil {
		return nil
	}

	tokenBuckets, ok := result.(*bptree.BPTree)
	if !ok {
		panic(ufmt.Errorf("failed to cast result to *bptree.BPTree: %T", result))
	}

	return tokenBuckets
}

// GetAccrualBuckets returns up to limit of the oldest pending buckets of tokenPath in
// epoch order. A limit of zero or less returns every pending bucket.
func (s *protocolFeeStore) GetAccrualBuckets(tokenPath string, limit int) ([]int64, []int64) {
	epochs := []int64{}
	amounts := []int64{}

	tokenBuckets := s.getTokenAccrualBucketTree(s.getAccrualBucketTree(), tokenPath)
	if tokenBuckets == nil {
		return epochs, amounts
	}

	tokenBuckets.Iterate("", "", func(key string, value any) bool {
		if limit > 0 && len(epochs) >= limit {
			return true
		}

		amount, ok := value.(int64)
		if !ok {
			panic(ufmt.Errorf("failed to cast result to int64: %T", value))
		}

		epochs = append(epochs, decodeEpochKey(key))
		amounts = append(amounts, amount)

		return false
	})

	return epochs, amounts
}

// AddAccrualBucket adds amount to the bucket of tokenPath at epoch.
func (s *protocolFeeStore) AddAccrualBucket(_ int, rlm realm, tokenPath string, epoch int64, amount int64) error {
	if !rlm.IsCurrent() {
		return errors.New(errSpoofedRealm)
	}

	accrualBuckets := s.getAccrualBucketTree()
	tokenBuckets := s.getTokenAccrualBucketTree(accrualBuckets, tokenPath)
	if tokenBuckets == nil {
		tokenBuckets = NewBPTreeN(16)
		accrualBuckets.Set(tokenPath, tokenBuckets)
	}

	key := encodeEpochKey(epoch)
	existing := int64(0)
	if result := tokenBuckets.Get(key); result != nil {
		current, ok := result.(int64)
		if !ok {
			panic(ufmt.Errorf("failed to cast result to int64: %T", result))
		}
		existing = current
	}

	tokenBuckets.Set(key, gnsmath.SafeAddInt64(existing, amount))

	return s.kvStore.Set(0, rlm, StoreKeyAccrualBuckets.String(), accrualBuckets)
}

// RemoveAccrualBuckets drops the buckets of tokenPath at the given epochs. The token's
// tree is dropped as well once no bucket remains.
func (s *protocolFeeStore) RemoveAccrualBuckets(_ int, rlm realm, tokenPath string, epochs []int64) error {
	if !rlm.IsCurrent() {
		return errors.New(errSpoofedRealm)
	}

	accrualBuckets := s.getAccrualBucketTree()
	tokenBuckets := s.getTokenAccrualBucketTree(accrualBuckets, tokenPath)
	if tokenBuckets == nil {
		return nil
	}

	for _, epoch := range epochs {
		tokenBuckets.Remove(encodeEpochKey(epoch))
	}

	if tokenBuckets.Size() == 0 {
		accrualBuckets.Remove(tokenPath)
	}

	return s.kvStore.Set(0, rlm, StoreKeyAccrualBuckets.String(), accrualBuckets)
}

// handle accrualPendingTokens store data
//
// accrualPendingTokens is the set of token paths that still own at least one accrual
// bucket, so gov/staker can enumerate what it has to fold without scanning every token.
func (s *protocolFeeStore) HasAccrualPendingTokensStoreKey() bool {
	return s.kvStore.Has(StoreKeyAccrualPendingTokens.String())
}

func (s *protocolFeeStore) InitializeAccrualPendingTokens(_ int, rlm realm) error {
	if !rlm.IsCurrent() {
		return errors.New(errSpoofedRealm)
	}

	return s.kvStore.Set(0, rlm, StoreKeyAccrualPendingTokens.String(), NewBPTreeN(16))
}

func (s *protocolFeeStore) getAccrualPendingTokenTree() *bptree.BPTree {
	accrualPendingTokens, err := s.kvStore.GetBPTree(StoreKeyAccrualPendingTokens.String())
	if err != nil {
		panic(err)
	}

	return accrualPendingTokens
}

func (s *protocolFeeStore) GetAccrualPendingTokens() []string {
	return collectTreeKeys(s.getAccrualPendingTokenTree())
}

func (s *protocolFeeStore) AddAccrualPendingToken(_ int, rlm realm, tokenPath string) error {
	if !rlm.IsCurrent() {
		return errors.New(errSpoofedRealm)
	}

	accrualPendingTokens := s.getAccrualPendingTokenTree()
	if accrualPendingTokens.Has(tokenPath) {
		return nil
	}

	accrualPendingTokens.Set(tokenPath, true)

	return s.kvStore.Set(0, rlm, StoreKeyAccrualPendingTokens.String(), accrualPendingTokens)
}

// RemoveAccrualPendingToken drops one token from the set. It writes only when the
// token was listed.
func (s *protocolFeeStore) RemoveAccrualPendingToken(_ int, rlm realm, tokenPath string) error {
	if !rlm.IsCurrent() {
		return errors.New(errSpoofedRealm)
	}

	accrualPendingTokens := s.getAccrualPendingTokenTree()
	if _, removed := accrualPendingTokens.Remove(tokenPath); !removed {
		return nil
	}

	return s.kvStore.Set(0, rlm, StoreKeyAccrualPendingTokens.String(), accrualPendingTokens)
}

func collectTreeKeys(tree *bptree.BPTree) []string {
	keys := make([]string, 0, tree.Size())
	tree.Iterate("", "", func(key string, _ any) bool {
		keys = append(keys, key)
		return false
	})

	return keys
}

func encodeEpochKey(epoch int64) string {
	if epoch < 0 {
		panic(ufmt.Sprintf("negative epoch not supported: %d", epoch))
	}

	return utils.EncodeUint64(uint64(epoch))
}

func decodeEpochKey(key string) int64 {
	return gnsmath.SafeUint64ToInt64(utils.DecodeUint64(key))
}

// NewprotocolFeeStore creates a new protocol fee store instance with the provided KV store.
// This function is used by the upgrade system to create storage instances for each implementation.
func NewProtocolFeeStore(kvStore store.KVStore) IProtocolFeeStore {
	return &protocolFeeStore{
		kvStore: kvStore,
	}
}
