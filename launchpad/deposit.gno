package launchpad

import (
	"errors"
	"std"
	"strconv"
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

	// project -> tier -> []depositId
	depositsByProject = make(map[string]map[string][]string)

	// user -> []depositId
	depositsByUser = make(map[std.Address][]string)

	//  user -> project -> []depositId
	depositsByUserByProject = make(map[std.Address]map[string][]string)

	// depositState contains all deposit-related indices
	depositState DepositState
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
	Project       Project
	Tier          Tier
	TierType      string
	CurrentHeight uint64
	CurrentTime   uint64
}

// DepositGns deposit gns to the project's tier
// gns will be locked in `launchpad` contract
// xgns will be minted to the `launchpad` contract
// Returns depositId
// ref: https://docs.gnoswap.io/contracts/launchpad/launchpad_deposit.gno#depositgns
func DepositGns(targetProjectTierId string, amount uint64) string {
	assertOnlyNotHalted()
	assertValidAmount(amount)

	projectId, tierType := splitProjectIdAndTier(targetProjectTierId)
	project, err := getProject(projectId)
	if err != nil {
		panic(err.Error())
	}

	currentHeight := uint64(std.GetHeight())
	if !project.isActivated(currentHeight) {
		panic(addDetailToError(errInactiveProject, projectId))
	}
	caller := getPrevAddr()
	project.checkDepositConditions(caller)

	tier, err := project.Tier(convertTierTypeStrToUint64(tierType))
	if err != nil {
		panic(err.Error())
	}

	if !tier.isActivated(currentHeight) {
		panic(addDetailToError(errInactiveTier, tierType))
	}

	en.MintAndDistributeGns()

	now := uint64(time.Now().Unix())
	info := ProjectTierInfo{
		Project:       project,
		Tier:          tier,
		TierType:      tierType,
		CurrentHeight: currentHeight,
		CurrentTime:   now,
	}
	deposit, err := createDeposit(info, amount)
	if err != nil {
		panic(addDetailToError(errInvalidInput, err.Error()))
	}
	updateDeposit(deposit)

	if tier.isFirstDeposit() {
		// update StartHeight, StartTime, TierAmountPerBlockX128
		tier.updateStarted(info.CurrentHeight, info.CurrentTime)
		duration := tier.Ended().height - info.CurrentHeight
		tier.SetTierAmountPerBlockX128(calcRewardPerBlockX128(tier.TierAmount(), duration))

		prevAddr, prevPkgPath := getPrev()
		std.Emit(
			"FirstDepositForProjectTier",
			"prevAddr", prevAddr,
			"prevRealm", prevPkgPath,
			"targetProjectTierId", targetProjectTierId,
			"amount", strconv.FormatUint(amount, 10),
			"depositId", deposit.id,
			"claimableHeight", strconv.FormatUint(deposit.claimableHeight, 10),
			"claimableTime", strconv.FormatUint(deposit.claimableTime, 10),
			"tierAmountPerBlockX128", tier.TierAmountPerBlockX128().ToString(),
		)

		rewardState := NewRewardState(tier.tierAmountPerBlockX128, tier.started.height, tier.ended.height)
		rewardStates.Set(info.Project.id, info.TierType, rewardState)
	}

	reward := tier.Reward()
	rewardPerDeposit, err := reward.calculateRewardPerDeposit(tier.TierAmountPerBlockX128(), tier.ActualDepositAmount())
	if err != nil {
		panic(err.Error())
	}
	reward.addRewardPerDeposit(rewardPerDeposit)
	reward.SetLastHeight(currentHeight)

	rewardInfo := NewRewardInfo(
		reward.AccumRewardPerDeposit(),
		deposit.Amount(),
		0,
		0,
		deposit.DepositHeight(),
		tier.Ended().height,
		currentHeight)
	reward.Info().Set(deposit.ID(), rewardInfo)
	tier.SetReward(reward)
	tier.SetTotalDepositAmount(tier.TotalDepositAmount() + amount)
	tier.SetActualDepositAmount(tier.ActualDepositAmount() + amount)
	tier.SetTotalParticipant(tier.TotalParticipant() + 1)
	tier.SetActualParticipant(tier.ActualParticipant() + 1)

	project.setTier(convertTierTypeStrToUint64(tierType), tier)
	project.Stats().SetTotalDeposit(project.Stats().TotalDeposit() + amount)
	project.Stats().SetActualDeposit(project.Stats().ActualDeposit() + amount)
	project.Stats().SetTotalParticipant(project.Stats().TotalParticipant() + 1)
	project.Stats().SetActualParticipant(project.Stats().ActualParticipant() + 1)

	projects[projectId] = project

	rewardState, err := rewardStates.Get(projectId, tierType)
	if err != nil {
		panic(addDetailToError(
			errInvalidRewardState, err.Error()))
	}
	rewardState.AddStake(uint64(std.GetHeight()), deposit.id, amount)

	// Update gov_staker to calculate project's recipient's reward
	gs.SetAmountByProjectWallet(project.recipient, amount, true)

	// gns will be locked in `launchpad` contract
	gns.TransferFrom(
		a2u(getPrevAddr()),
		a2u(std.Address(consts.LAUNCHPAD_ADDR)),
		amount,
	)
	xgns.Mint(a2u(std.Address(consts.LAUNCHPAD_ADDR)), amount)

	// Emit deposit event
	prevAddr, prevPkgPath := getPrev()
	std.Emit(
		"DepositGns",
		"prevAddr", prevAddr,
		"prevRealm", prevPkgPath,
		"targetProjectTierId", targetProjectTierId,
		"amount", strconv.FormatUint(amount, 10),
		"depositId", deposit.id,
		"claimableHeight", strconv.FormatUint(deposit.claimableHeight, 10),
		"claimableTime", strconv.FormatUint(deposit.claimableTime, 10),
	)

	return deposit.id
}

func CollectDepositGns() uint64 {
	caller := getPrevAddr()
	depositList, ok := depositsByUser[caller]
	if depositList == nil || !ok {
		panic(addDetailToError(
			errNotExistDeposit,
			ufmt.Sprintf("no deposit list for user(%s)", caller),
		))
	}

	return processCollectedDeposits(depositList, "")
}

func CollectDepositGnsByProjectId(projectId string) uint64 {
	assertValidProjectId(projectId)

	_, exists := projects[projectId]
	if !exists {
		panic(addDetailToError(
			errInvalidProjectId,
			ufmt.Sprintf("%s", projectId),
		))
	}

	caller := getPrevAddr()
	depositList, ok := depositsByUserByProject[caller][projectId]
	if depositList == nil || !ok {
		panic(addDetailToError(
			errNotExistDeposit,
			ufmt.Sprintf("no deposit list for project(%s)", projectId),
		))
	}

	return processCollectedDeposits(depositList, projectId)
}

func CollectDepositGnsByDepositId(depositId string) uint64 {
	assertOnlyNotHalted()
	assertValidProjectId(depositId)

	caller := getPrevAddr()
	// Validate deposit collection request
	deposit, project, err := validateDepositCollection(depositId, caller)
	if err != nil {
		panic(addDetailToError(errInvalidInput, err.Error()))
	}

	en.MintAndDistributeGns()

	project = projects[deposit.projectId] // get updated project

	// Process deposit collection
	height := uint64(std.GetHeight())
	amount, err := processDeposit(&deposit, &project, height)
	if err != nil {
		panic(err.Error())
	}

	// Update gov_staker contract
	gs.SetAmountByProjectWallet(project.recipient, amount, false)

	// Emit collection event
	prevAddr, prevPkgPath := getPrev()
	std.Emit(
		"CollectDepositGnsByDepositId",
		"prevAddr", prevAddr,
		"prevRealm", prevPkgPath,
		"depositId", depositId,
		"amount", strconv.FormatUint(amount, 10),
	)

	// Process token transfers if amount > 0
	if amount > 0 {
		xgns.Burn(a2u(consts.LAUNCHPAD_ADDR), amount)
		gns.Transfer(a2u(caller), amount)
		return amount
	}

	return 0
}

// splitProjectIdAndTier extracts the project ID and tier from a given tier ID.
//
// This function splits the provided `tierId` into three parts using the `:` separator and
// returns the first two parts as the project ID and the third part as the tier.
//
// Parameters:
// - tierId (string): The tier ID in the format "{projectId}:{tier}".
//
// Returns:
// - string: The project ID derived from the first two parts of the `tierId`.
// - string: The tier derived from the third part of the `tierId`.
func splitProjectIdAndTier(tierId string) (string, string) {
	res, err := common.Split(tierId, ":", 3)
	if err != nil {
		panic(addDetailToError(
			errInvalidTier,
			ufmt.Sprintf("invalid tierId: %s", tierId),
		))
	}

	return ufmt.Sprintf("%s:%s", res[0], res[1]), res[2]
}

// validateProjectTier validates a project and its tier
func validateProjectTier(projectId string, tierStr string) (Project, Tier, error) {
	project, exists := projects[projectId]
	if !exists {
		return Project{}, Tier{}, errors.New(ufmt.Sprintf("project(%s) not found", projectId))
	}

	currentHeight := uint64(std.GetHeight())

	project.Tiers()

	tier := getTier(project, tierStr)
	if !isProjectActive(project, currentHeight) {
		return Project{}, Tier{}, errors.New("project is not active")
	}

	if !isTierActive(tier, currentHeight) {
		return Project{}, Tier{}, errors.New("tier is not active")
	}

	return project, tier, nil
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

// checkDepositConditions validates whether the caller meets the deposit conditions of the given project.
//
// This function checks if the caller satisfies all conditions required for depositing into the specified project.
// Each condition specifies a minimum token balance that must be met. If any condition is not met, the function
// panics with an appropriate error message.
//
// Parameters:
// - project (Project): The project containing the deposit conditions to validate.
func checkDepositConditions(project Project) {
	if project.conditions == nil {
		return
	}

	caller := getPrevAddr()
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

func checkTierActive(project Project, tier Tier) bool {
	if tier.ended.height < uint64(std.GetHeight()) {
		return false
	}

	return true
}

func convertTierTypeStrToUint64(tierType string) uint64 {
	switch tierType {
	case "30":
		return TIER30
	case "90":
		return TIER90
	case "180":
		return TIER180
	default:
		panic(addDetailToError(
			errInvalidTier,
			ufmt.Sprintf("invalid tierType: %s", tierType),
		))
	}
}

func getTier(project Project, tierStr string) Tier {
	switch tierStr {
	case "30":
		return project.tiers[TIER30]
	case "90":
		return project.tiers[TIER90]
	case "180":
		return project.tiers[TIER180]
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
		project.tiers[TIER30] = tier
	case "90":
		project.tiers[TIER90] = tier
	case "180":
		project.tiers[TIER180] = tier
	default:
		panic(addDetailToError(
			errInvalidTier,
			ufmt.Sprintf("invalid tierStr: %s", tierStr),
		))
	}

	return project
}

func isPassedClaimableHeight(deposit Deposit, height uint64) bool {
	return deposit.claimableHeight <= height
}

func isAlreadyCollected(deposit Deposit) bool {
	return deposit.depositCollectHeight != 0
}

// isProjectActive checks if a project is currently active
func isProjectActive(project Project, height uint64) bool {
	return project.started.height <= height && height <= project.ended.height
}

// isTierActive checks if a tier is currently active
func isTierActive(tier Tier, height uint64) bool {
	return height <= tier.ended.height
}

// createDeposit creates a new deposit for a specific project tier and depositor.
//
// This function generates a unique deposit ID, calculates the claimable height and time,
// and initializes a `Deposit` object with the provided details.
//
// Parameters:
//   - info (ProjectTierInfo): Information about the project tier, including project details,
//     tier string, current block height, and current time.
//   - amount (uint64): The amount to be deposited.
//
// Returns:
// - Deposit: The newly created `Deposit` object containing all relevant details.
// - error: Returns an error if the deposit creation fails (currently always returns `nil`).
func createDeposit(info ProjectTierInfo, amount uint64) (Deposit, error) {
	// Validate input parameters
	if amount == 0 {
		return Deposit{}, errors.New(ufmt.Sprintf("deposit amount cannot be zero"))
	}
	if info.Project.id == "" || info.TierType == "" {
		return Deposit{}, errors.New(ufmt.Sprintf("invalid project or tier information"))
	}

	depositor := getPrevAddr()
	depositId := generateDepositId(info, depositor)
	claimableHeight, claimableTime := calculateClaimableTimes(info)

	deposit := Deposit{
		id:              depositId,
		projectId:       info.Project.id,
		tier:            info.TierType,
		depositor:       depositor,
		amount:          amount,
		depositHeight:   info.CurrentHeight,
		depositTime:     info.CurrentTime,
		claimableHeight: claimableHeight,
		claimableTime:   claimableTime,
	}

	return deposit, nil
}

func generateDepositId(info ProjectTierInfo, depositor std.Address) string {
	return ufmt.Sprintf("%s:%s:%s:%d", info.Project.id, info.TierType, depositor.String(), info.CurrentHeight)
}

// calculateClaimableTimes calculates the claimable height and time for a deposit
func calculateClaimableTimes(info ProjectTierInfo) (uint64, uint64) {
	var waitDuration uint64
	switch info.TierType {
	case "30":
		waitDuration = TIMESTAMP_3DAYS
	case "90":
		waitDuration = TIMESTAMP_7DAYS
	case "180":
		waitDuration = TIMESTAMP_14DAYS
	}

	calcHeight := info.CurrentHeight + info.Tier.collectWaitDuration
	calcTime := info.CurrentTime + waitDuration

	return minU64(calcHeight, info.Tier.ended.height),
		minU64(calcTime, info.Tier.ended.time)
}

func updateDeposit(deposit Deposit) {
	// Update deposits
	_, ok := deposits[deposit.id]
	if !ok {
		deposits[deposit.id] = deposit
	} else {
		panic(addDetailToError(
			errDuplicateDeposit,
			ufmt.Sprintf("deposit(%s) already exists", deposit.id),
		))
	}

	// Update depositsByUser
	if depositsByUser[deposit.depositor] == nil {
		depositsByUser[deposit.depositor] = []string{}
	}
	depositsByUser[deposit.depositor] = append(depositsByUser[deposit.depositor], deposit.id)

	// Update depositsByProject
	if depositsByProject[deposit.projectId] == nil {
		depositsByProject[deposit.projectId] = make(map[string][]string)
	}
	if depositsByProject[deposit.projectId][deposit.tier] == nil {
		depositsByProject[deposit.projectId][deposit.tier] = []string{}
	}
	depositsByProject[deposit.projectId][deposit.tier] = append(
		depositsByProject[deposit.projectId][deposit.tier],
		deposit.id,
	)

	// Update depositsByUserByProject
	if depositsByUserByProject[deposit.depositor] == nil {
		depositsByUserByProject[deposit.depositor] = make(map[string][]string)
	}
	if depositsByUserByProject[deposit.depositor][deposit.projectId] == nil {
		depositsByUserByProject[deposit.depositor][deposit.projectId] = []string{}
	}
	depositsByUserByProject[deposit.depositor][deposit.projectId] = append(
		depositsByUserByProject[deposit.depositor][deposit.projectId],
		deposit.id,
	)
}

// updateDepositIndices updates all deposit-related indices
func updateDepositIndices(deposit Deposit, state *DepositState) {
	// Update deposits
	_, ok := state.Deposits[deposit.id]
	if !ok {
		state.Deposits[deposit.id] = deposit
	} else {
		panic(addDetailToError(
			errDuplicateDeposit,
			ufmt.Sprintf("deposit(%s) already exists", deposit.id),
		))
	}

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
	info.Tier.totalParticipant++
	if info.Tier.totalParticipant > 1 {
		return info.Tier, nil
	}

	tier := info.Tier
	tier.started.height = info.CurrentHeight
	tier.started.time = info.CurrentTime
	tier.tierAmountPerBlockX128 = calcProjectTiersRewardPerBlockX128(tier)

	// should be update reward state here
	rewardState := NewRewardState(tier.tierAmountPerBlockX128, tier.started.height, tier.ended.height)
	rewardStates.Set(info.Project.id, info.TierType, rewardState)

	// Remove from projectTiersWithoutDeposit as it now has a deposit
	delete(projectTiersWithoutDeposit, tier.id)

	return tier, nil
}

// processDepositCollection processes the collection of deposits
func processDepositCollection(
	depositList []string,
	projectId string,
) (uint64, error) {
	totalAmount := uint64(0) // gnsToUser
	currentHeight := uint64(std.GetHeight())
	now := uint64(time.Now().Unix())
	prevAddr, prevPkgPath := getPrev()

	for _, depositId := range depositList {
		deposit := deposits[depositId]
		project, exists := projects[deposit.projectId]
		if !exists || projectId != "" && project.id != projectId {
			continue
		}

		tier := getTier(project, deposit.tier)
		if !isPassedClaimableHeight(deposit, currentHeight) || isAlreadyCollected(deposit) {
			continue
		}

		deposit.depositCollectHeight = currentHeight
		deposit.depositCollectTime = now
		deposits[deposit.id] = deposit

		totalAmount += deposit.amount

		gs.SetAmountByProjectWallet(project.recipient, deposit.amount, false)

		tier.actualDepositAmount -= deposit.amount
		tier.actualParticipant -= 1

		project = setTier(project, deposit.tier, tier)
		project.stats.actualDeposit -= deposit.amount
		project.stats.actualParticipant -= 1
		projects[deposit.projectId] = project

		if projectId != "" {
			std.Emit(
				"CollectDepositGnsByProjectId",
				"prevAddr", prevAddr,
				"prevRealm", prevPkgPath,
				"projectId", projectId,
				"depositId", depositId,
				"amount", strconv.FormatUint(deposit.amount, 10),
			)
		} else {
			std.Emit(
				"CollectDepositGns",
				"prevAddr", prevAddr,
				"prevRealm", prevPkgPath,
				"depositId", depositId,
				"amount", strconv.FormatUint(deposit.amount, 10),
			)
		}
	}

	return totalAmount, nil
}

func processCollectedDeposits(depositList []string, pid string) uint64 {
	assertOnlyNotHalted()
	en.MintAndDistributeGns()

	amount, err := processDepositCollection(depositList, pid)
	if err != nil {
		panic(err)
	}

	if amount > 0 {
		caller := getPrevAddr()
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

	projMap, userHasProject := depositsByUserByProject[caller]
	if !userHasProject {
		return Deposit{}, Project{}, errors.New("user has no deposits in any project")
	}

	depositIds, userHasDepositsInProject := projMap[deposit.projectId]
	if !userHasDepositsInProject {
		return Deposit{}, Project{}, errors.New("user has no deposits in this project")
	}

	if !containsString(depositIds, depositId) {
		return Deposit{}, Project{}, errors.New("user has no deposit with this id")
	}

	currentHeight := uint64(std.GetHeight())

	if !isPassedClaimableHeight(deposit, currentHeight) {
		return Deposit{}, Project{}, errors.New("not passed claimable block height yet")
	}

	if isAlreadyCollected(deposit) {
		return Deposit{}, Project{}, errors.New("deposit already collected")
	}

	return deposit, project, nil
}

// receive deposit and project as a pointer to avoid copying
func processDeposit(deposit *Deposit, project *Project, height uint64) (uint64, error) {
	tier := getTier(*project, deposit.tier)
	//if isTierActive(tier, height) {
	//	return 0, errors.New(addDetailToError(errActiveProject, "tier is still active"))
	//}

	if deposit.depositCollectHeight != 0 {
		return 0, errors.New(addDetailToError(errAlreadyCollected, ufmt.Sprintf("depositId (%s)", deposit.id)))
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
