package grc20wrapper

import (
	"gno.land/r/demo/users"

	"gno.land/r/demo/token01"
	"gno.land/r/demo/token02"
	"gno.land/r/demo/token03"
	"gno.land/r/demo/token04"
	"gno.land/r/demo/token05"
	"gno.land/r/demo/token06"
	"gno.land/r/demo/token07"
	"gno.land/r/demo/token08"
	"gno.land/r/demo/token09"
	"gno.land/r/demo/token10"

	pRegistry "gno.land/r/demo/pool"
	rRegistry "gno.land/r/demo/router"
	sRegistry "gno.land/r/demo/staker"
)

// START
type Token1TokenInterface struct{}

func (Token1TokenInterface) Transfer() func(to users.AddressOrName, amount uint64) {
	return token01.Transfer
}

func (Token1TokenInterface) TransferFrom() func(from, to users.AddressOrName, amount uint64) {
	return token01.TransferFrom
}

func (Token1TokenInterface) BalanceOf() func(owner users.AddressOrName) uint64 {
	return token01.BalanceOf
}

func (Token1TokenInterface) Approve() func(spender users.AddressOrName, amount uint64) {
	return token01.Approve
}

var _ pRegistry.GRC20Interface = Token1TokenInterface{}
var _ rRegistry.GRC20Interface = Token1TokenInterface{}
var _ sRegistry.GRC20Interface = Token1TokenInterface{}

// START
type Token2TokenInterface struct{}

func (Token2TokenInterface) Transfer() func(to users.AddressOrName, amount uint64) {
	return token02.Transfer
}

func (Token2TokenInterface) TransferFrom() func(from, to users.AddressOrName, amount uint64) {
	return token02.TransferFrom
}

func (Token2TokenInterface) BalanceOf() func(owner users.AddressOrName) uint64 {
	return token02.BalanceOf
}

func (Token2TokenInterface) Approve() func(spender users.AddressOrName, amount uint64) {
	return token02.Approve
}

var _ pRegistry.GRC20Interface = Token2TokenInterface{}
var _ rRegistry.GRC20Interface = Token2TokenInterface{}
var _ sRegistry.GRC20Interface = Token2TokenInterface{}

// START
type Token3TokenInterface struct{}

func (Token3TokenInterface) Transfer() func(to users.AddressOrName, amount uint64) {
	return token03.Transfer
}

func (Token3TokenInterface) TransferFrom() func(from, to users.AddressOrName, amount uint64) {
	return token03.TransferFrom
}

func (Token3TokenInterface) BalanceOf() func(owner users.AddressOrName) uint64 {
	return token03.BalanceOf
}

func (Token3TokenInterface) Approve() func(spender users.AddressOrName, amount uint64) {
	return token03.Approve
}

var _ pRegistry.GRC20Interface = Token3TokenInterface{}
var _ rRegistry.GRC20Interface = Token3TokenInterface{}
var _ sRegistry.GRC20Interface = Token3TokenInterface{}

// START
type Token4TokenInterface struct{}

func (Token4TokenInterface) Transfer() func(to users.AddressOrName, amount uint64) {
	return token04.Transfer
}

func (Token4TokenInterface) TransferFrom() func(from, to users.AddressOrName, amount uint64) {
	return token04.TransferFrom
}

func (Token4TokenInterface) BalanceOf() func(owner users.AddressOrName) uint64 {
	return token04.BalanceOf
}

func (Token4TokenInterface) Approve() func(spender users.AddressOrName, amount uint64) {
	return token04.Approve
}

var _ pRegistry.GRC20Interface = Token4TokenInterface{}
var _ rRegistry.GRC20Interface = Token4TokenInterface{}
var _ sRegistry.GRC20Interface = Token4TokenInterface{}

// START
type Token5TokenInterface struct{}

func (Token5TokenInterface) Transfer() func(to users.AddressOrName, amount uint64) {
	return token05.Transfer
}

func (Token5TokenInterface) TransferFrom() func(from, to users.AddressOrName, amount uint64) {
	return token05.TransferFrom
}

func (Token5TokenInterface) BalanceOf() func(owner users.AddressOrName) uint64 {
	return token05.BalanceOf
}

func (Token5TokenInterface) Approve() func(spender users.AddressOrName, amount uint64) {
	return token05.Approve
}

var _ pRegistry.GRC20Interface = Token5TokenInterface{}
var _ rRegistry.GRC20Interface = Token5TokenInterface{}
var _ sRegistry.GRC20Interface = Token5TokenInterface{}

// START
type Token6TokenInterface struct{}

func (Token6TokenInterface) Transfer() func(to users.AddressOrName, amount uint64) {
	return token06.Transfer
}

func (Token6TokenInterface) TransferFrom() func(from, to users.AddressOrName, amount uint64) {
	return token06.TransferFrom
}

func (Token6TokenInterface) BalanceOf() func(owner users.AddressOrName) uint64 {
	return token06.BalanceOf
}

func (Token6TokenInterface) Approve() func(spender users.AddressOrName, amount uint64) {
	return token06.Approve
}

var _ pRegistry.GRC20Interface = Token6TokenInterface{}
var _ rRegistry.GRC20Interface = Token6TokenInterface{}
var _ sRegistry.GRC20Interface = Token6TokenInterface{}

// START
type Token7TokenInterface struct{}

func (Token7TokenInterface) Transfer() func(to users.AddressOrName, amount uint64) {
	return token07.Transfer
}

func (Token7TokenInterface) TransferFrom() func(from, to users.AddressOrName, amount uint64) {
	return token07.TransferFrom
}

func (Token7TokenInterface) BalanceOf() func(owner users.AddressOrName) uint64 {
	return token07.BalanceOf
}

func (Token7TokenInterface) Approve() func(spender users.AddressOrName, amount uint64) {
	return token07.Approve
}

var _ pRegistry.GRC20Interface = Token7TokenInterface{}
var _ rRegistry.GRC20Interface = Token7TokenInterface{}
var _ sRegistry.GRC20Interface = Token7TokenInterface{}

// START
type Token8TokenInterface struct{}

func (Token8TokenInterface) Transfer() func(to users.AddressOrName, amount uint64) {
	return token08.Transfer
}

func (Token8TokenInterface) TransferFrom() func(from, to users.AddressOrName, amount uint64) {
	return token08.TransferFrom
}

func (Token8TokenInterface) BalanceOf() func(owner users.AddressOrName) uint64 {
	return token08.BalanceOf
}

func (Token8TokenInterface) Approve() func(spender users.AddressOrName, amount uint64) {
	return token08.Approve
}

var _ pRegistry.GRC20Interface = Token8TokenInterface{}
var _ rRegistry.GRC20Interface = Token8TokenInterface{}
var _ sRegistry.GRC20Interface = Token8TokenInterface{}

// START
type Token9TokenInterface struct{}

func (Token9TokenInterface) Transfer() func(to users.AddressOrName, amount uint64) {
	return token09.Transfer
}

func (Token9TokenInterface) TransferFrom() func(from, to users.AddressOrName, amount uint64) {
	return token09.TransferFrom
}

func (Token9TokenInterface) BalanceOf() func(owner users.AddressOrName) uint64 {
	return token09.BalanceOf
}

func (Token9TokenInterface) Approve() func(spender users.AddressOrName, amount uint64) {
	return token09.Approve
}

var _ pRegistry.GRC20Interface = Token9TokenInterface{}
var _ rRegistry.GRC20Interface = Token9TokenInterface{}
var _ sRegistry.GRC20Interface = Token9TokenInterface{}

// START
type Token10TokenInterface struct{}

func (Token10TokenInterface) Transfer() func(to users.AddressOrName, amount uint64) {
	return token10.Transfer
}

func (Token10TokenInterface) TransferFrom() func(from, to users.AddressOrName, amount uint64) {
	return token10.TransferFrom
}

func (Token10TokenInterface) BalanceOf() func(owner users.AddressOrName) uint64 {
	return token10.BalanceOf
}

func (Token10TokenInterface) Approve() func(spender users.AddressOrName, amount uint64) {
	return token10.Approve
}

var _ pRegistry.GRC20Interface = Token10TokenInterface{}
var _ rRegistry.GRC20Interface = Token10TokenInterface{}
var _ sRegistry.GRC20Interface = Token10TokenInterface{}
