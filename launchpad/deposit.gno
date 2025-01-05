package launchpad

import (
	"errors"
	"std"
	"time"

	"gno.land/p/demo/ufmt"
	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/gnoswap/v1/consts"
	en "gno.land/r/gnoswap/v1/emission"
	"gno.land/r/gnoswap/v1/gns"
	gs "gno.land/r/gnoswap/v1/gov/staker"
	"gno.land/r/gnoswap/v1/gov/xgns"
)

var (
	// depositId -> deposit
	deposits = make(map[string]Deposit)

	// proejct -> tier -> []depositId
	depositsByProject = make(map[string]map[string][]string)

	// user -> []depositId
	depositsByUser = make(map[std.Address][]string)

	//  user -> project -> []depositId
	depositsByUserByProject = make(map[std.Address]map[string][]string)
)

// DepositState represents the state of the deposits
type DepositState struct {
	Deposits              map[string]Deposit
	DepositsByProject     map[string]map[string][]string
	DepositsByUser        map[std.Address][]string
	DepositsByUserProject map[std.Address]map[string][]string
}

// ProjectTierInfo contains information about a project tier
type ProjectTierInfo struct {
	Project     Project
	Tier        Tier
	TierStr     string
	Height      uint64
	CurrentTime uint64
}

// validateProjectTier validates a project and its tier
func validateProjectTier(projectId string, tierStr string) (Project, Tier, error) {
	project, exists := projects[projectId]
	if !exists {
		return Project{}, Tier{}, errors.New(ufmt.Sprintf("project(%s) not found", projectId))
	}

	tier := getTier(project, tierStr)
	if !isProjectActive(project, uint64(std.GetHeight())) {
		return Project{}, Tier{}, errors.New("project is not active")
	}

	if !isTierActive(tier, uint64(std.GetHeight())) {
		return Project{}, Tier{}, errors.New("tier is not active")
	}

	return project, tier, nil
}

// isProjectActive checks if a project is currently active
func isProjectActive(project Project, height uint64) bool {
	return project.started.height <= height && height <= project.ended.height
}

// isTierActive checks if a tier is currently active
func isTierActive(tier Tier, height uint64) bool {
	return height <= tier.ended.height
}

// createDeposit creates a new deposit entry
func createDeposit(info ProjectTierInfo, amount uint64) (Deposit, error) {
	depositor := std.PrevRealm().Addr()
	depositId := ufmt.Sprintf("%s:%s:%s:%d", 
		info.Project.id, 
		info.TierStr, 
		depositor.String(), 
		info.Height,
	)

	claimableHeight, claimableTime := calculateClaimableTimes(info)

	deposit := Deposit{
		id:              depositId,
		projectId:       info.Project.id,
		tier:            info.TierStr,
		depositor:       depositor,
		amount:          amount,
		depositHeight:   info.Height,
		depositTime:     info.CurrentTime,
		claimableHeight: claimableHeight,
		claimableTime:   claimableTime,
	}

	return deposit, nil
}

// calculateClaimableTimes calculates the claimable height and time for a deposit
func calculateClaimableTimes(info ProjectTierInfo) (uint64, uint64) {
	var waitDuration uint64
	switch info.TierStr {
	case "30":
		waitDuration = TIMESTAMP_3DAYS
	case "90":
		waitDuration = TIMESTAMP_7DAYS
	case "180":
		waitDuration = TIMESTAMP_14DAYS
	}

	calcHeight := info.Height + info.Tier.collectWaitDuration
	calcTime := info.CurrentTime + waitDuration

	return min(calcHeight, info.Tier.ended.height),
		min(calcTime, info.Tier.ended.time)
}

// updateDepositIndices updates all deposit-related indices
func updateDepositIndices(deposit Deposit, state *DepositState) {
	// Update depositsByUser
	if state.DepositsByUser[deposit.depositor] == nil {
		state.DepositsByUser[deposit.depositor] = []string{}
	}
	state.DepositsByUser[deposit.depositor] = append(
		state.DepositsByUser[deposit.depositor], 
		deposit.id,
	)

	// Update depositsByProject
	if state.DepositsByProject[deposit.projectId] == nil {
		state.DepositsByProject[deposit.projectId] = make(map[string][]string)
	}
	if state.DepositsByProject[deposit.projectId][deposit.tier] == nil {
		state.DepositsByProject[deposit.projectId][deposit.tier] = []string{}
	}
	state.DepositsByProject[deposit.projectId][deposit.tier] = append(
		state.DepositsByProject[deposit.projectId][deposit.tier], 
		deposit.id,
	)

	// Update depositsByUserProject
	if state.DepositsByUserProject[deposit.depositor] == nil {
		state.DepositsByUserProject[deposit.depositor] = make(map[string][]string)
	}
	if state.DepositsByUserProject[deposit.depositor][deposit.projectId] == nil {
		state.DepositsByUserProject[deposit.depositor][deposit.projectId] = []string{}
	}
	state.DepositsByUserProject[deposit.depositor][deposit.projectId] = append(
		state.DepositsByUserProject[deposit.depositor][deposit.projectId], 
		deposit.id,
	)
}

// processFirstDeposit handles the first deposit for a project tier
func processFirstDeposit(info ProjectTierInfo) (Tier, error) {
	if info.Tier.totalParticipant != 0 {
		return info.Tier, nil
	}

	tier := info.Tier
	tier.started.height = info.Height
	tier.started.time = info.CurrentTime
	tier.tierAmountPerBlockX96 = calcProjectTiersRewardPerBlockX96(tier)

	return tier, nil
}

// DepositGns deposit gns to the project's tier
// gns will be locked in `launchpad` contract
// xgns will be minted to the `launchpad` contract
// Returns depositId
// ref: https://docs.gnoswap.io/contracts/launchpad/launchpad_deposit.gno#depositgns
func DepositGns(targetProjectTierId string, amount uint64) string {
	common.IsHalted()

	projectId, tierStr := getProjectIdAndTierFromTierId(targetProjectTierId)
	project, tier, err := validateProjectTier(projectId, tierStr)
	if err != nil {
		panic(err)
	}

	checkDepositConditions(project)

	en.MintAndDistributeGns()

	calculateDepositReward()
	project = projects[projectId] // get updates project
	tier = getTier(project, tierStr) // get updates tier

	// Update gov_staker to calculate project's recipient's reward
	gs.SetAmountByProjectWallet(project.recipient, amount, true)

	// gns will be locked in `launchpad` contract
	gns.TransferFrom(
		a2u(std.PrevRealm().Addr()),
		a2u(std.Address(consts.LAUNCHPAD_ADDR)),
		amount,
	)
	xgns.Mint(
		a2u(std.Address(consts.LAUNCHPAD_ADDR)),
		amount,
	)

	// Create deposit
	info := ProjectTierInfo{
		Project:     project,
		Tier:        tier,
		TierStr:     tierStr,
		Height:      uint64(std.GetHeight()),
		CurrentTime: uint64(time.Now().Unix()),
	}

	deposit, err := createDeposit(info, amount)
	if err != nil {
		panic(err)
	}

	// Update indices
	deposits[deposit.id] = deposit
	updateDepositIndices(deposit, &DepositState{
		Deposits:              deposits,
		DepositsByProject:     depositsByProject,
		DepositsByUser:        depositsByUser,
		DepositsByUserProject: depositsByUserByProject,
	})

	// Emit deposit event
	prevAddr, prevPkgPath := getPrev()
	std.Emit(
		"DepositGns",
		"prevAddr", prevAddr,
		"prevRealm", prevPkgPath,
		"targetProjectTierId", targetProjectTierId,
		"amount", ufmt.Sprintf("%d", amount),
		"depositId", deposit.id,
		"claimableHeight", ufmt.Sprintf("%d", deposit.claimableHeight),
		"claimableTime", ufmt.Sprintf("%d", deposit.claimableTime),
	)

	// Process first deposit if applicable
	updatedTier, err := processFirstDeposit(info)
	if err != nil {
		panic(err)
	}

	if updatedTier.started.height == info.Height {
		std.Emit(
			"FirstDepoistForProjectTier", // ????
			"prevAddr", prevAddr,
			"prevRealm", prevPkgPath,
			"targetProjectTierId", targetProjectTierId,
			"amount", ufmt.Sprintf("%d", amount),
			"depositId", deposit.id,
			"claimableHeight", ufmt.Sprintf("%d", deposit.claimableHeight),
			"claimableTime", ufmt.Sprintf("%d", deposit.claimableTime),
			"tierAmountPerBlockX96", updatedTier.tierAmountPerBlockX96.ToString(),
		)
	}

	// Update tier and project
	project = setTier(project, tierStr, updatedTier)
	project.stats.totalDeposit += amount
	project.stats.actualDeposit += amount
	project.stats.totalParticipant++
	project.stats.actualParticipant++
	projects[projectId] = project

	return deposit.id
}

// processDepositCollection processes the collection of deposits
func processDepositCollection(
	dpsts []string,
	projectId string,
) (uint64, error) {
	totalAmount := uint64(0) // gnsToUser
	height := uint64(std.GetHeight())
	prevAddr, prevRealm := getPrev()

	for _, dpstId := range dpsts {
		dpst := deposits[dpstId]
		project, exists := projects[dpst.projectId]
		if !exists || projectId != "" && project.id != projectId {
			continue
		}

		tier := getTier(project, dpst.tier)
		if isTierActive(tier, height) || dpst.depositCollectHeight != 0 {
			continue
		}

		dpst.depositCollectHeight = height
		dpst.depositCollectTime = uint64(time.Now().Unix())
		deposits[dpst.id] = dpst

		totalAmount += dpst.amount

		gs.SetAmountByProjectWallet(project.recipient, dpst.amount, false)

		tier.actualDepositAmount -= dpst.amount
		tier.actualParticipant -= 1

		project = setTier(project, dpst.tier, tier)
		project.stats.actualDeposit -= dpst.amount
		project.stats.actualParticipant -= 1
		projects[dpst.projectId] = project

		if projectId != "" {
			std.Emit(
				"CollectDepositGnsByProjectId",
				"prevAddr", prevAddr,
				"prevRealm", prevRealm,
				"projectId", projectId,
				"depositId", dpstId,
				"amount", ufmt.Sprintf("%d", dpst.amount),
			)
		} else {
			std.Emit(
				"CollectDepositGns",
				"prevAddr", prevAddr,
				"prevRealm", prevRealm,
				"depositId", dpstId,
				"amount", ufmt.Sprintf("%d", dpst.amount),
			)
		}
	}

	return totalAmount, nil
}

func CollectDepositGns() uint64 {
	caller := std.PrevRealm().Addr()
	dpsts := depositsByUser[caller]
	return processCollectedDeposits(dpsts, "")
}

func CollectDepositGnsByProjectId(projectId string) uint64 {
	_, exists := projects[projectId]
	if !exists {
		return 0
	}

	caller := std.PrevRealm().Addr()
	deposits := depositsByUserByProject[caller][projectId]
	if deposits == nil {
		return 0
	}

	return processCollectedDeposits(deposits, projectId)
}

func processCollectedDeposits(dpsts []string, pid string) uint64 {
	common.IsHalted()
	en.MintAndDistributeGns()
	calculateDepositReward()

	amount, err := processDepositCollection(dpsts, pid)
	if err != nil {
		panic(err)
	}

	if amount > 0 {
		caller := std.PrevRealm().Addr()
		xgns.Burn(a2u(consts.LAUNCHPAD_ADDR), amount)
		gns.Transfer(a2u(caller), amount)
	}

	return amount
}

func validateDepositCollection(depositId string, caller std.Address) (Deposit, Project, error) {
    deposit, exists := deposits[depositId]
    if !exists {
        return Deposit{}, Project{}, errors.New("deposit not found")
    }

    project, exists := projects[deposit.projectId]
    if !exists {
        return Deposit{}, Project{}, errors.New("project not found")
    }

    if _, exists := depositsByUserByProject[caller]; !exists {
        return Deposit{}, Project{}, errors.New("no deposits for this user")
    }

    return deposit, project, nil
}

// receive deposit and project as an pointer to avoid copying
func processDeposit(deposit *Deposit, project *Project, height uint64) (uint64, error) {
    tier := getTier(*project, deposit.tier)
    if isTierActive(tier, height) {
        return 0, errors.New("tier is still active")
    }

    if deposit.depositCollectHeight != 0 {
        return 0, errors.New("deposit already collected")
    }

    // Update deposit status
    deposit.depositCollectHeight = height
    deposit.depositCollectTime = uint64(time.Now().Unix())
    deposits[deposit.id] = *deposit

    // Update project tier
    tier.actualDepositAmount -= deposit.amount
    tier.actualParticipant--

    // Update project
    *project = setTier(*project, deposit.tier, tier)
    project.stats.actualDeposit -= deposit.amount
    project.stats.actualParticipant--
    projects[deposit.projectId] = *project

    return deposit.amount, nil
}

func CollectDepositGnsByDepositId(depositId string) uint64 {
	common.IsHalted()
    caller := std.PrevRealm().Addr()

    // Validate deposit collection request
    deposit, project, err := validateDepositCollection(depositId, caller)
    if err != nil {
        return 0
    }

    en.MintAndDistributeGns()

    calculateDepositReward()
    project = projects[deposit.projectId] // get updated project

    // Process deposit collection
    height := uint64(std.GetHeight())
    amount, err := processDeposit(&deposit, &project, height)
    if err != nil {
        return 0
    }

    // Update gov_staker contract
    gs.SetAmountByProjectWallet(project.recipient, amount, false)

    // Emit collection event
    prevAddr, prevRealm := getPrev()
    std.Emit(
        "CollectDepositGnsByDepositId",
        "prevAddr", prevAddr,
        "prevRealm", prevRealm,
        "depositId", depositId,
        "amount", ufmt.Sprintf("%d", amount),
    )

    // Process token transfers if amount > 0
    if amount > 0 {
        xgns.Burn(a2u(consts.LAUNCHPAD_ADDR), amount)
        gns.Transfer(a2u(caller), amount)
        return amount
    }

    return 0
}

func getProjectIdFromTierId(tierId string) string {
	// input: gno.land/r/gnoswap/gns:123:30
	// output: gno.land/r/gnoswap/gns:123

	res, err := common.Split(tierId, ":", 3)
	if err != nil {
		panic(addDetailToError(
			errInvalidTier,
			ufmt.Sprintf("invalid tierId: %s", tierId),
		))
	}

	return ufmt.Sprintf("%s:%s", res[0], res[1])
}

func getProjectIdAndTierFromTierId(tierId string) (string, string) {
	res, err := common.Split(tierId, ":", 3)
	if err != nil {
		panic(addDetailToError(
			errInvalidTier,
			ufmt.Sprintf("invalid tierId: %s", tierId),
		))
	}

	return ufmt.Sprintf("%s:%s", res[0], res[1]), res[2]
}

func checkDepositConditions(project Project) {
	if project.conditions == nil {
		return
	}

	caller := std.PrevRealm().Addr()
	for _, condition := range project.conditions {
		if condition.minAmount == 0 {
			continue
		}
		
		// check balance
		var balance uint64
		if condition.tokenPath == consts.GOV_XGNS_PATH {
			balance = xgns.BalanceOf(a2u(caller))
		} else {
			balance = common.BalanceOf(condition.tokenPath, caller)
		}
		if balance < condition.minAmount {
			panic(addDetailToError(
				errNotEnoughBalance,
				ufmt.Sprintf("insufficient balance(%d) for token(%s)", balance, condition.tokenPath),
			))
		}
	}
}

// Deprecated: use isProjectActive instead
func checkProjectActive(project Project) bool {
	if project.started.height > uint64(std.GetHeight()) {
		// not started yet
		return false
	}

	if project.ended.height < uint64(std.GetHeight()) {
		// already ended
		return false
	}

	return true
}

// Deprecated: use isTierActive instead
func checkTierActive(project Project, tier Tier) bool {
	if tier.ended.height < uint64(std.GetHeight()) {
		return false
	}

	return true
}

func getTier(project Project, tierStr string) Tier {
	switch tierStr {
	case "30":
		return project.tiers[30]
	case "90":
		return project.tiers[90]
	case "180":
		return project.tiers[180]
	default:
		panic(addDetailToError(
			errInvalidTier,
			ufmt.Sprintf("invalid tierStr: %s", tierStr),
		))
	}
}

func setTier(project Project, tierStr string, tier Tier) Project {
	switch tierStr {
	case "30":
		project.tiers[30] = tier
	case "90":
		project.tiers[90] = tier
	case "180":
		project.tiers[180] = tier
	default:
		panic(addDetailToError(
			errInvalidTier,
			ufmt.Sprintf("invalid tierStr: %s", tierStr),
		))
	}

	return project
}
