package orderbook

import (
	"testing"
	"time"

	u256 "gno.land/p/gnoswap/uint256"
)

func TestNewOrderbook(t *testing.T) {
	ob := NewOrderbook("USDC", "BTC")

	if ob.quoteDenom != "USDC" {
		t.Errorf("expected quoteDenom=USDC, got %s", ob.quoteDenom)
	}
	if ob.baseDenom != "BTC" {
		t.Errorf("expected baseDenom=BTC, got %s", ob.baseDenom)
	}
	if !ob.active {
		t.Error("expected orderbook to be active")
	}
	if ob.nextOrderId != 0 {
		t.Errorf("expected nextOrderId=0, got %d", ob.nextOrderId)
	}
}

func TestTickState(t *testing.T) {
	ts := NewTickState()

	if !ts.askValues.TAL().IsZero() {
		t.Error("expected TAL to be zero")
	}
	if !ts.bidValues.CTV().IsZero() {
		t.Error("expected CTV to be zero")
	}
}

func TestLimitOrder(t *testing.T) {
	quantity := u256.NewUint(1000)
	etas := u256.NewUint(500)

	order := NewLimitOrder(
		0,
		1,
		OrderDirectionBid,
		"g1test",
		quantity,
		etas,
		50,
		time.Now(),
	)

	if order.tickId != 0 {
		t.Errorf("expected tickId=0, got %d", order.tickId)
	}
	if order.orderId != 1 {
		t.Errorf("expected orderId=1, got %d", order.orderId)
	}
	if order.orderDirection != OrderDirectionBid {
		t.Error("expected OrderDirectionBid")
	}
	if !order.quantity.Eq(quantity) {
		t.Error("quantity mismatch")
	}
	if !order.etas.Eq(etas) {
		t.Error("etas mismatch")
	}
	if order.claimBounty != 50 {
		t.Errorf("expected claimBounty=50, got %d", order.claimBounty)
	}
}

func TestTickToPrice(t *testing.T) {
	tests := []struct {
		tickId        int64
		shouldPanic   bool
	}{
		{0, false},
		{MIN_TICK, false},
		{MAX_TICK, false},
		{MIN_TICK - 1, true},
		{MAX_TICK + 1, true},
	}

	for _, tt := range tests {
		func() {
			defer func() {
				if r := recover(); r != nil {
					if !tt.shouldPanic {
						t.Errorf("tickToPrice(%d) panicked unexpectedly", tt.tickId)
					}
				} else if tt.shouldPanic {
					t.Errorf("tickToPrice(%d) should have panicked", tt.tickId)
				}
			}()

			price := tickToPrice(tt.tickId)
			if price.IsZero() && !tt.shouldPanic {
				t.Errorf("tickToPrice(%d) returned zero", tt.tickId)
			}
		}()
	}
}

func TestAmountToValue(t *testing.T) {
	amount := u256.NewUint(1000)
	tickId := int64(0)

	value := amountToValue(amount, tickId)

	if value.IsZero() {
		t.Error("value should not be zero")
	}
}

func TestMakeOrderbookKey(t *testing.T) {
	key := makeOrderbookKey("USDC", "BTC")
	expected := "USDC:BTC"

	if key != expected {
		t.Errorf("expected %s, got %s", expected, key)
	}
}

func TestMakeOrderKey(t *testing.T) {
	key := makeOrderKey(100, 5)
	expected := "100:5"

	if key != expected {
		t.Errorf("expected %s, got %s", expected, key)
	}
}

func TestOrderDirection(t *testing.T) {
	bid := OrderDirectionBid
	ask := OrderDirectionAsk

	if bid.String() != "bid" {
		t.Errorf("expected 'bid', got %s", bid.String())
	}
	if ask.String() != "ask" {
		t.Errorf("expected 'ask', got %s", ask.String())
	}
}

func TestTickValues(t *testing.T) {
	tv := NewTickValues()

	// Test initial values
	if !tv.TAL().IsZero() {
		t.Error("TAL should be zero initially")
	}
	if !tv.CTV().IsZero() {
		t.Error("CTV should be zero initially")
	}
	if !tv.ETAS().IsZero() {
		t.Error("ETAS should be zero initially")
	}

	// Test setters
	newTAL := u256.NewUint(100)
	newCTV := u256.NewUint(200)
	newETAS := u256.NewUint(50)

	tv.SetTAL(newTAL)
	tv.SetCTV(newCTV)
	tv.SetETAS(newETAS)

	if !tv.TAL().Eq(newTAL) {
		t.Error("TAL setter failed")
	}
	if !tv.CTV().Eq(newCTV) {
		t.Error("CTV setter failed")
	}
	if !tv.ETAS().Eq(newETAS) {
		t.Error("ETAS setter failed")
	}
}
