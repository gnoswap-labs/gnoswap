package v1

import (
	bptree "gno.land/p/nt/bptree/v0"
)

// UserDepositsResolver wraps the user-deposits BPTree (kept in store) with
// address/depositId-aware helpers. The tree stores composite keys
// "addr|paddedDepositId" -> bool sentinel; this resolver constructs prefix
// ranges for an address and decodes deposit ids from composite keys.
type UserDepositsResolver struct {
	tree *bptree.BPTree
}

// NewUserDepositsResolver creates a resolver over the given BPTree.
func NewUserDepositsResolver(tree *bptree.BPTree) *UserDepositsResolver {
	return &UserDepositsResolver{tree: tree}
}

// Size returns the total number of (address, depositId) entries.
func (self *UserDepositsResolver) Size() int {
	return self.tree.Size()
}

// userPositionCount returns the number of deposits for addrStr.
func (self *UserDepositsResolver) userPositionCount(addrStr string) uint64 {
	iterationStartKey, iterationEndKey := stakerDepositKeyRange(addrStr)
	count := uint64(0)

	self.tree.Iterate(iterationStartKey, iterationEndKey, func(_ string, _ any) bool {
		count++
		return false
	})

	return count
}

// IterateAll traverses all deposit ids for a specific address in deposit-id order.
func (self *UserDepositsResolver) IterateAll(address address, fn func(depositId uint64) bool) {
	iterationStartKey, iterationEndKey := stakerDepositKeyRange(address.String())
	addrPrefixLen := len(address.String()) + len(stakerDepositKeySeparator)

	self.tree.Iterate(iterationStartKey, iterationEndKey, func(key string, _ any) bool {
		depositIdStr := key[addrPrefixLen:]
		return fn(DecodeUint(depositIdStr))
	})
}

// IterateByOffset paginates deposit ids for a specific address.
func (self *UserDepositsResolver) IterateByOffset(address address, offset, count int, fn func(depositId uint64) bool) {
	if count <= 0 {
		return
	}

	if offset < 0 {
		offset = 0
	}

	iterationStartKey, iterationEndKey := stakerDepositKeyRange(address.String())
	addrPrefixLen := len(address.String()) + len(stakerDepositKeySeparator)
	skipped := 0
	emitted := 0

	self.tree.Iterate(iterationStartKey, iterationEndKey, func(key string, _ any) bool {
		if skipped < offset {
			skipped++
			return false
		}

		if emitted >= count {
			return true
		}

		emitted++
		depositIdStr := key[addrPrefixLen:]

		return fn(DecodeUint(depositIdStr))
	})
}

// addDeposit records a deposit id under the staker address.
func (self *UserDepositsResolver) addDeposit(address address, depositId uint64) {
	self.tree.Set(makeStakerDepositKey(address.String(), depositId), true)
}

// removeDeposit removes a deposit id under the staker address.
func (self *UserDepositsResolver) removeDeposit(address address, depositId uint64) {
	self.tree.Remove(makeStakerDepositKey(address.String(), depositId))
}
