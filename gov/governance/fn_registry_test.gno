package governance

import (
	"testing"

	"gno.land/r/gnoswap/v1/consts"
)

func TestCreateParameterHandlers(t *testing.T) {
	registry := createParameterHandlers()

	if registry == nil {
		t.Fatal("registry is nil")
	}

	tests := []struct {
		name     string
		path     string
		function string
		params   []string
		wantErr  bool
	}{
		{
			name:     "invalid params",
			path:     consts.COMMON_PATH,
			function: "SetHalt",
			params:   []string{},
			wantErr:  true,
		},
		{
			name:     "Router SetSwapFee: Pass",
			path:     consts.ROUTER_PATH,
			function: "SetSwapFee",
			params:   []string{"1000"},
			wantErr:  false,
		},
		{
			name:     "set deposit gns amount",
			path:     consts.STAKER_PATH,
			function: "SetDepositGnsAmount",
			params:   []string{"1000"},
			wantErr:  false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			handler, _ := registry.Get(tt.path, tt.function)

			err := handler(tt.params)
			if (err != nil) != tt.wantErr {
				t.Errorf("unexpected error: %v", err)
			}
		})
	}
}
