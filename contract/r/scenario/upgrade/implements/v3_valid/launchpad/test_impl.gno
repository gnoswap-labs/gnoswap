// Simplified test implementation for launchpad contract upgrade testing
package v3_valid

import (
	"gno.land/r/gnoswap/launchpad"
	v1 "gno.land/r/gnoswap/launchpad/v1"
)

func NewV3ValidLaunchpad(store launchpad.ILaunchpadStore) launchpad.ILaunchpad {
	return &TestLaunchpad{
		instance: v1.NewLaunchpadV1(store),
	}
}

func init() {
	launchpad.RegisterInitializer(cross, func(store launchpad.ILaunchpadStore) launchpad.ILaunchpad {
		return NewV3ValidLaunchpad(store)
	})
}

// TestLaunchpad is a minimal test implementation that delegates to v1
type TestLaunchpad struct {
	instance launchpad.ILaunchpad
}

// ILaunchpadProject interface
func (t *TestLaunchpad) CreateProject(
	name string,
	tokenPath string,
	recipient address,
	depositAmount int64,
	conditionTokens string,
	conditionAmounts string,
	tier30Ratio int64,
	tier90Ratio int64,
	tier180Ratio int64,
	startTime int64,
) string {
	return t.instance.CreateProject(name, tokenPath, recipient, depositAmount, conditionTokens, conditionAmounts, tier30Ratio, tier90Ratio, tier180Ratio, startTime)
}

func (t *TestLaunchpad) TransferLeftFromProjectByAdmin(projectID string, recipient address) int64 {
	return t.instance.TransferLeftFromProjectByAdmin(projectID, recipient)
}

func (t *TestLaunchpad) CollectProtocolFee() {
	t.instance.CollectProtocolFee()
}

// ILaunchpadDeposit interface
func (t *TestLaunchpad) DepositGns(targetProjectTierID string, depositAmount int64, referrer string) string {
	return t.instance.DepositGns(targetProjectTierID, depositAmount, referrer)
}

func (t *TestLaunchpad) CollectDepositGns(depositID string) (int64, error) {
	return t.instance.CollectDepositGns(depositID)
}

// ILaunchpadApi interface
func (t *TestLaunchpad) ApiGetProjectAndTierStatisticsByProjectId(projectId string) string {
	return t.instance.ApiGetProjectAndTierStatisticsByProjectId(projectId)
}

func (t *TestLaunchpad) ApiGetProjectStatisticsByProjectId(projectId string) string {
	return t.instance.ApiGetProjectStatisticsByProjectId(projectId)
}

func (t *TestLaunchpad) ApiGetTierStatisticsByProjectId(projectId string) string {
	return t.instance.ApiGetTierStatisticsByProjectId(projectId)
}

func (t *TestLaunchpad) ApiGetProjectStatisticsByProjectTierId(tierId string) string {
	return t.instance.ApiGetProjectStatisticsByProjectTierId(tierId)
}

func (t *TestLaunchpad) ApiGetProjectActiveOf(projectId string) string {
	return t.instance.ApiGetProjectActiveOf(projectId)
}

func (t *TestLaunchpad) ApiGetDepositByDepositId(depositId string) string {
	return t.instance.ApiGetDepositByDepositId(depositId)
}

func (t *TestLaunchpad) ApiGetProjectRecipientRewardByProjectId(projectId string) string {
	return t.instance.ApiGetProjectRecipientRewardByProjectId(projectId)
}

func (t *TestLaunchpad) ApiGetProjectRecipientRewardByAddress(address address) string {
	return t.instance.ApiGetProjectRecipientRewardByAddress(address)
}
