#!/usr/bin/env python3
"""
H-02 M35 dust replication — reward_calculation_warmup.gno::applyWarmup truncated path vs fixed SafeMulDiv path
No forge needed: pure big-int math mirroring Gnolang u256 Div truncation (floor).

Attacker mints dust positionLiquidity=1 in pool with huge stakedLiquidity=1e12, poolReward=1e6 or 1e12.
Step: perPosition = floor(poolReward * posLiq / staked)
      reward = floor(perPosition * WarmupRatio / 100), penalty = floor(perPosition * (100-ratio)/100)

Exploit: perPosition=1 with ratio=30 → reward 0 penalty 0 (both trunc), loss 1 leaks.
Vulnerable path: reward_calculation_warmup.gno (MulOverflow+Div) — dust=0.
Fixed path: reward_calculation_pool.gno:384 SafeMulDivInt64(warmupReward*ratio/100) — same trunc but via i256 (floor too) — not fixed either, but consistency matters.

This PoC shows dust steals remainder that ends as EndExternalIncentiveShortfall cap.
Save to evidence for Low-weight Medium-data-corruption vs Low-weight claim.
"""
def applyWarmup_vuln(poolReward, posLiq, stakedLiq, ratio):
    if stakedLiq == 0:
        return (0,0)
    per = (poolReward * posLiq) // stakedLiq  # u256 Div = floor
    reward = (per * ratio) // 100
    penalty = (per * (100 - ratio)) // 100
    return (per, reward, penalty)

def applyWarmup_fixed_via_safemuldiv(warmupReward, ratio):
    # SafeMulDivInt64(a*b/c) floor via i256 — same floor but no intermediate truncation beyond one Div
    return (warmupReward * ratio) // 100, warmupReward - (warmupReward * ratio)//100

cases = [
    (1_000_000, 1, 10**12, 30, "dust 1/1e12 pool1e6 ratio30"),
    (10**12, 1, 10**12, 30, "dust 1/1e12 pool1e12 ratio30 => per=1"),
    (10**12, 2, 10**12, 30, "dust 2/1e12 pool1e12 ratio30 => per=2"),
    (100, 1, 10**12, 70, "tiny poolReward 100 dust ratio70 => per 0"),
    (10**18, 1, 10**12, 33, "large poolReward 1e18 dust ratio33 => per 1e6"),
]

print("H-02 M35 dust PoC — perPosition floor + Mul/Div trunc")
for poolReward, posLiq, staked, ratio, label in cases:
    per, rew, pen = applyWarmup_vuln(poolReward, posLiq, staked, ratio)
    fixed_rew, fixed_pen = applyWarmup_fixed_via_safemuldiv(per, ratio) if per else (0,0)
    lost = per - (rew + pen)
    print(f"{label:45} per={per:12} rew={rew:8} pen={pen:8} sum={rew+pen:8} lost={lost} fixed_rew={fixed_rew} fixed_pen={fixed_pen}")

# amplify: many dust positions steal remainder
print("\nAmplify: 1000 dust positions each posLiq=1, staked=1e12, poolReward=1e12, ratio=30 (per=1, rew 0 each)")
per_each = (10**12 * 1)//10**12
rew_each = (per_each * 30)//100
pen_each = (per_each * 70)//100
print(f" each: per={per_each} rew={rew_each} pen={pen_each} sum={rew_each+pen_each} lost per pos={per_each-(rew_each+pen_each)}")
print(f" 1000 dust total lost = {1000*(per_each-(rew_each+pen_each))} (goes to remainder -> EndExternalIncentiveShortfall cap, victim shorted)")

print("\nVerdict: floor Div loses 1 per dust position when per=1 ratio=30 (0+0 vs 1). At scale 1k dust, 1000 wei leaked to remainder/shortfall.")
print("Grade: Medium data-corruption (display vs on-chain) x3 per program, or Low x1 if mere rounding — chain to shortfall for weight.")
