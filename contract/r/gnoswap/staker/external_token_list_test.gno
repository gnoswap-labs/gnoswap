package staker

import (
	"std"
	"testing"

	"gno.land/p/demo/ufmt"
	"gno.land/p/gnoswap/consts"
)

func TestAddToken(t *testing.T) {
	allowedTokens = make([]string, 0, len(defaultAllowed))
	allowedTokens = defaultAllowed

	tests := []struct {
		name      string
		tokenPath string
		wantErr   bool
	}{
		{
			name:      "new token addition",
			tokenPath: "gno.land/r/gnoswap/v1/token1",
			wantErr:   false,
		},
		{
			name:      "existing token addition",
			tokenPath: consts.GNS_PATH,
			wantErr:   false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			testing.SetRealm(adminRealm)
			func() {
				testing.SetRealm(std.NewCodeRealm("gno.land/r/gnoswap/v1/staker"))
				AddToken(cross, tt.tokenPath)
			}()

			if !tt.wantErr {
				if !contains(allowedTokens, tt.tokenPath) {
					t.Errorf("AddToken() = token is not added to the list")
				}
			}
		})
	}
}

func TestRemoveToken(t *testing.T) {
	allowedTokens = make([]string, 0, len(defaultAllowed))
	allowedTokens = defaultAllowed
	customToken := "gno.land/r/gnoswap/v1/custom"
	allowedTokens = append(allowedTokens, customToken)

	tests := []struct {
		name      string
		tokenPath string
		wantErr   bool
	}{
		{
			name:      "custom token removal",
			tokenPath: customToken,
			wantErr:   false,
		},
		{
			name:      "default token removal attempt",
			tokenPath: consts.GNS_PATH,
			wantErr:   true,
		},
		{
			name:      "non-existent token removal attempt",
			tokenPath: "gno.land/r/gnoswap/v1/nonexistent",
			wantErr:   false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			testing.SetRealm(adminRealm)
			func() {
				testing.SetRealm(std.NewCodeRealm("gno.land/r/gnoswap/v1/staker"))
				defer func() {
					if r := recover(); r != nil {
						if !tt.wantErr {
							t.Errorf("RemoveToken() = unexpected error: %v", r)
						}
					}
				}()
				RemoveToken(cross, tt.tokenPath)
			}()

			if !tt.wantErr {
				if contains(allowedTokens, tt.tokenPath) {
					t.Errorf("RemoveToken() = token is not removed from the list")
				}
			}
		})
	}
}

func TestModifyTokenList(t *testing.T) {
	allowedTokens = make([]string, 0, len(defaultAllowed))
	allowedTokens = defaultAllowed

	tests := []struct {
		name      string
		tokenPath string
		validator TokenValidator
		executor  TokenExecutor
		wantErr   bool
	}{
		{
			name:      "valid token addition",
			tokenPath: "gno.land/r/gnoswap/v1/token1",
			validator: nil,
			executor:  addTokenExecutor,
			wantErr:   false,
		},
		{
			name:      "validation failure",
			tokenPath: consts.GNS_PATH,
			validator: func(tokenPath string) error {
				return ufmt.Errorf("validation failure")
			},
			executor: addTokenExecutor,
			wantErr:  true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			testing.SetRealm(adminRealm)
			func() {
				testing.SetRealm(std.NewCodeRealm("gno.land/r/gnoswap/v1/staker"))
				err := modifyTokenList(tt.tokenPath, tt.validator, tt.executor)
				if (err != nil) != tt.wantErr {
					t.Errorf("modifyTokenList() error = %v, wantErr %v", err, tt.wantErr)
				}
			}()
		})
	}
}
