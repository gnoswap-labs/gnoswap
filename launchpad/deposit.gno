package launchpad

// alter version of launchpad_deposit

import (
	"errors"
	"std"
	"time"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/ufmt"
	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/gnoswap/v1/consts"

	"gno.land/r/gnoswap/v1/gns"
	"gno.land/r/gnoswap/v1/gov/xgns"
)

var (
	depositStore *DepositStore
)

func init() {
	depositStore = NewDepositStore()
}

// DepositStore stores deposit-related metadata
type DepositStore struct {
	// all deposits
	deposits *avl.Tree // deposit ID -> *Deposit

	// deposits by project
	depositsByProject *avl.Tree // project ID + tier -> []string(depositIds)

	// deposits by user
	depositsByUser *avl.Tree // user address -> []string(depositIds)

	// deposits by user & project
	depositsByUserProject *avl.Tree // user address + project ID -> []string(depositIds)
}

func NewDepositStore() *DepositStore {
	return &DepositStore{
		deposits: avl.NewTree(),
		depositsByProject: avl.NewTree(),
		depositsByUser: avl.NewTree(),
		depositsByUserProject: avl.NewTree(),
	}
}

// DepositManager implements the deposit manager
type DepositManager interface {
	// AddDeposit adds a deposit to the store
	AddDeposit(projectid string, user std.Address, amount uint64, tier string) (string, error)

	// GetDeposit returns the deposit by depositId
	GetDeposit(depositId string) (*Deposit, error)

	// GetUserDeposits retrieves all of the user's deposits
	GetUserDeposits(user std.Address) ([]*Deposit, error)

	// GetProjectDeposits retrieves all of the project's deposits
	GetProjectDeposits(projectId string) ([]*Deposit, error)

	// CollectDeposit collects the deposit
	CollectDeposit(depositId string, user std.Address) (uint64, error)
}

func (ds *DepositStore) AddDeposit(projectId string, user std.Address, amount uint64, tier string) (string, error) {
	project, exists := projects[projectId]
	if !exists {
		return "", ufmt.Errorf("project(%s) not found", projectId)
	}

	if err := satisfyDepositConditions(project); err != nil {
		return "", err
	}

	if !isProjectActive(project) {
		return "", ufmt.Errorf("project(%s) is not active", projectId)
	}

	tierInfo := getTier(project, tier)
	if !isTierActive(project, tierInfo) {
		return "", ufmt.Errorf("tier(%s) is not active", tier)
	}

	if alreadyDepositedSameTier(ds, user, projectId, tier) {
		return "", ufmt.Errorf("already deposited in the same project(%s) tier(%s)", projectId, tier)
	}

	depositId := generateDepositId(projectId, tier, user)

	// calculate claimable height & time
	claimableHeight, claimableTime := calculateClaimableTiming(tierInfo)

	deposit := &Deposit{
		id:              depositId,
		projectId:       projectId,
		tier:           tier,
		depositor:       user,
		amount:         amount,
		depositHeight:   uint64(std.GetHeight()),
		depositTime:    uint64(time.Now().Unix()),
		claimableHeight: claimableHeight,
		claimableTime:   claimableTime,
	}

	// store deposit
	ds.deposits.Set(depositId, deposit)

	// update indices
	ds.updateIndices(deposit)

	// update project stats
	ds.updateProjectStats(deposit, project, tierInfo, true)

	prevAddr, prevPkgPath := getPrev()
	std.Emit(
		"AddDeposit",
		"prevAddr", prevAddr,
		"prevPkgPath", prevPkgPath,
		"projectId", projectId,
		"tier", tier,
		"amount", ufmt.Sprintf("%d", amount),
		"depositId", depositId,
		"claimableHeight", ufmt.Sprintf("%d", claimableHeight),
		"claimableTime", ufmt.Sprintf("%d", claimableTime),
	)

	return depositId, nil
}

func alreadyDepositedSameTier(ds *DepositStore, user std.Address, projectId, tier string) bool {
	userProjectKey := ufmt.Sprintf("%s:%s", user.String(), projectId)
	value, exists := ds.depositsByUserProject.Get(userProjectKey)
	if !exists {
		return false
	}

	depositIds := value.([]string)
	for _, id := range depositIds {
		deposit, _ := ds.GetDeposit(id)
		if deposit.tier == tier {
			return true
		}
	}

	return false
}

func (ds *DepositStore) GetDeposit(depositId string) (*Deposit, error) {
	value, exists := ds.deposits.Get(depositId)
	if !exists {
		return nil, ufmt.Errorf("deposit(%s) not found", depositId)
	}
	return value.(*Deposit), nil
}

func (ds *DepositStore) GetUserDeposits(user std.Address) ([]*Deposit, error) {
	value, exists := ds.depositsByUser.Get(user.String())
	if !exists {
		return make([]*Deposit, 0), nil
	}

	depositIds := value.([]string)
	deposits := make([]*Deposit, 0, len(depositIds))

	for _, id := range depositIds {
		if dpst, err := ds.GetDeposit(id); err == nil {
			deposits = append(deposits, dpst)
		}
	}

	return deposits, nil
}

func (ds *DepositStore) GetProjectDeposits(projectId string) ([]*Deposit, error) {
	deposits := make([]*Deposit, 0)

	// iterate over all tiers
	tiers := []string{"30", "60", "180"}
	for _, tier := range tiers {
		key := ufmt.Sprintf("%s:%d", projectId, tier)
		value, exists := ds.depositsByProject.Get(key)
		if !exists {
			continue
		}

		depositIds := value.([]string)
		for _, id := range depositIds {
			if dpst, err := ds.GetDeposit(id); err == nil {
				deposits = append(deposits, dpst)
			}
		}
	}

	return deposits, nil
}

func (ds *DepositStore) CollectDeposit(depositId string, user std.Address) (uint64, error) {
	dpst, err := ds.GetDeposit(depositId)
	if err != nil {
		return 0, err
	}

	if dpst.depositor != user {
		return 0, errors.New("unauthorized deposit collection")
	}

	if dpst.depositCollectHeight != 0 {
		return 0, errors.New("deposit already collected")
	}

	// update deposit
	dpst.depositCollectHeight = uint64(std.GetHeight())
	dpst.depositCollectTime = uint64(time.Now().Unix())
	ds.deposits.Set(depositId, dpst)

	project, exists := projects[dpst.projectId]
	if !exists {
		return 0, ufmt.Errorf("project(%s) not found", dpst.projectId)
	}

	tier := getTier(project, dpst.tier)
	if isTierActive(project, tier) {
		return 0, errors.New("cannot collect from active tier")
	}

	// upadte project stats
	ds.updateProjectStats(dpst, project, tier, false)

	// tranfer GNS
	if err := transferGNS(user, dpst.amount); err != nil {
		return 0, err
	}

	return dpst.amount, nil
}

// region: helper

func generateDepositId(pid, tier string, user std.Address) string {
	return ufmt.Sprintf("%s:%s:%s:%d", pid, tier, user.String(), std.GetHeight())
}

func calculateClaimableTiming(t Tier) (uint64, uint64) {
	currentHeight := uint64(std.GetHeight())
	currentTime := uint64(time.Now().Unix())

	claimableHeight := currentHeight + t.collectWaitDuration
	var waitDuration uint64
	switch t.id[len(t.id)-2:] {
	case "30":
		waitDuration = TIMESTAMP_3DAYS
	case "90":
		waitDuration = TIMESTAMP_7DAYS
	case "180":
		waitDuration = TIMESTAMP_14DAYS
	}
	claimableTime := currentTime + waitDuration

	claimHeight := common.U64Min(claimableHeight, t.endHeight)
	claimTime := common.U64Min(claimableTime, t.endTime)

	return claimHeight, claimTime
}

func (ds *DepositStore) updateIndices(dpst *Deposit) {
	projectTierKey := ufmt.Sprintf("%s:%s", dpst.projectId, dpst.tier)

	var projectDeposits []string
	if value, exists := ds.depositsByProject.Get(projectTierKey); exists {
		projectDeposits = value.([]string)
	}
	projectDeposits = append(projectDeposits, dpst.id)
	ds.depositsByProject.Set(projectTierKey, projectDeposits)

	// update depositsByUser
	userKey := dpst.depositor.String()
	var userDeposits []string
	if value, exists := ds.depositsByUser.Get(userKey); exists {
		userDeposits = value.([]string)
	}
	userDeposits = append(userDeposits, dpst.id)
	ds.depositsByUser.Set(userKey, userDeposits)

	// update depositsByUserProject
	userProjectKey := ufmt.Sprintf("%s:%s", userKey, dpst.projectId)
	var userProjectDeposits []string
	if value, exists := ds.depositsByUserProject.Get(userProjectKey); exists {
		userProjectDeposits = value.([]string)
	}
	userProjectDeposits = append(userProjectDeposits, dpst.id)
	ds.depositsByUserProject.Set(userProjectKey, userProjectDeposits)
}

func (ds *DepositStore) updateProjectStats(dpst *Deposit, project Project, tier Tier, isAdd bool) {
	if isAdd {
		// adding deposit
		tier.totalDepositAmount += dpst.amount
		tier.actualDepositAmount += dpst.amount
		tier.totalParticipant += 1
		tier.actualParticipant += 1

		project.totalDepositAmount += dpst.amount
		project.actualDepositAmount += dpst.amount
		project.totalParticipant += 1
		project.actualParticipant += 1
	} else {
		// removing deposit
		tier.actualDepositAmount -= dpst.amount
		tier.actualParticipant -= 1

		project.actualDepositAmount -= dpst.amount
		project.actualParticipant -= 1
	}

	// update project and tier
	project = setTier(project, dpst.tier, tier)
	projects[project.id] = project
}

func isProjectActive(p Project) bool {
	currentHeight := uint64(std.GetHeight())

	if currentHeight < p.startHeight || currentHeight > p.endHeight {
		return false
	}

	if p.refundedHeight != 0 {
		return false
	}

	return true
}

func isTierActive(p Project, tier Tier) bool {
	currentHeight := uint64(std.GetHeight())

	if !isProjectActive(p) {
		return false
	}

	// not started yet
	if tier.startHeight != 0 && currentHeight < tier.startHeight {
		return false
	}

	// ended
	if currentHeight > tier.endHeight {
		return false
	}

	// all deposits in the tier are collected
	if tier.tierAmount > 0 && tier.actualDepositAmount >= tier.tierAmount {
		return false
	}

	return true
}

// TODO: replace checkDepositConditions
func satisfyDepositConditions(p Project) error {
	if p.conditions == nil || len(p.conditions) == 0 {
		return nil
	}

	caller := std.PrevRealm().Addr()

	for token, cond := range p.conditions {
		if cond.minAmount == 0 {
			continue
		}

		var balance uint64
		switch token {
		case consts.GOV_XGNS_PATH:
			balance = xgns.BalanceOf(a2u(caller))
		default:
			if b, err := balanceOfByRegisterCall(token, caller); err != nil {
				return err
			} else {
				balance = b
			}
		}

		// validate minimum amount
		if balance < cond.minAmount {
			return ufmt.Errorf(
				"insufficient balance for token(%s): required %d, actual %d",
				token, cond.minAmount, balance,
			)
		}
	}

	return nil
}

func transferGNS(to std.Address, amount uint64) error {
	xgns.Burn(a2u(consts.LAUNCHPAD_ADDR), amount)
	gns.Transfer(a2u(to), amount)
	return nil
}

func balanceOfByRegisterCall(pkgPath string, owner std.Address) (uint64, error) {
	if pkgPath == consts.GNOT {
		pkgPath = consts.WRAPPED_WUGNOT
	}

	registeredTokens := common.ListRegisteredTokens()
	isRegistered := false

	for _, token := range registeredTokens {
		if token == pkgPath {
			isRegistered = true
			break
		}
	}

	if !isRegistered {
		return 0, ufmt.Errorf("token(%s) not registered", pkgPath)
	}

	token := common.GetToken(pkgPath)
	balance := token.BalanceOf(owner)

	return balance, nil
}
