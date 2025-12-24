package v1

import (
	"testing"

	"gno.land/p/nt/avl"
	"gno.land/p/nt/uassert"
)

type tokenListInitStore struct {
	*mockProtocolFeeStore
	hasTokenList bool
}

func newTokenListInitStore() *tokenListInitStore {
	base := newMockProtocolFeeStore().(*mockProtocolFeeStore)
	base.tokenListWithAmounts = nil

	return &tokenListInitStore{
		mockProtocolFeeStore: base,
		hasTokenList:         false,
	}
}

func (s *tokenListInitStore) HasTokenListWithAmountsStoreKey() bool {
	return s.hasTokenList
}

func (s *tokenListInitStore) InitializeTokenListWithAmount() error {
	s.tokenListWithAmounts = avl.NewTree()
	s.hasTokenList = true
	return nil
}

func TestInitStoreDataInitializesTokenListWithAmounts(t *testing.T) {
	store := newTokenListInitStore()
	uassert.False(t, store.HasTokenListWithAmountsStoreKey())

	err := initStoreData(store)
	uassert.NoError(t, err)

	uassert.True(t, store.HasTokenListWithAmountsStoreKey())
	tree := store.GetTokenListWithAmounts()
	uassert.NotNil(t, tree)
	uassert.Equal(t, tree.Size(), 0)
}
