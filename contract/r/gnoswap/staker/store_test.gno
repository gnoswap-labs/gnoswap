package staker

import (
	"chain/runtime"
	"testing"

	"gno.land/p/gnoswap/store"
	"gno.land/p/nt/uassert"
)

func TestSetWarmupTemplateValidation(t *testing.T) {
	// Use a fresh KV store to avoid polluting other tests.
	testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/staker"))
	kv := store.NewKVStore(runtime.CurrentRealm().Address())
	st := NewStakerStore(kv)

	valid := DefaultWarmupTemplate()
	err := st.SetWarmupTemplate(valid)
	uassert.NoError(t, err)

	tests := []struct {
		name   string
		mutate func([]Warmup) []Warmup
	}{
		{
			name: "zero ratio rejected",
			mutate: func(ws []Warmup) []Warmup {
				ws[0].WarmupRatio = 0
				return ws
			},
		},
		{
			name: "over 100 ratio rejected",
			mutate: func(ws []Warmup) []Warmup {
				ws[1].WarmupRatio = 101
				return ws
			},
		},
		{
			name: "empty template rejected",
			mutate: func(_ []Warmup) []Warmup {
				return []Warmup{}
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			invalid := tt.mutate(append([]Warmup(nil), valid...))
			err := st.SetWarmupTemplate(invalid)
			uassert.Error(t, err)

			// Ensure the valid template remains unchanged after failure.
			current := st.GetWarmupTemplate()
			uassert.Equal(t, valid[0].WarmupRatio, current[0].WarmupRatio)
		})
	}
}
