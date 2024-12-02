package common

import (
	"testing"

	_ "gno.land/r/demo/wugnot"
)

func TestGetToken(t *testing.T) {
	t.Run("registered(by default)", func(t *testing.T) {
		token := GetToken("gno.land/r/demo/wugnot")
		if token == nil {
			t.Error("Expected non-nil teller for WUGNOT")
		}
	})

	t.Run("not registered", func(t *testing.T) {
		defer func() {
			if r := recover(); r == nil {
				t.Errorf("Expected panic for non-registered token")
			}
		}()
		GetToken("not_registered")
	})
}
