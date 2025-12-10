# Appendix

## A. Contract Addresses (Roles)

| 역할 | 설명 |
|------|------|
| admin | 시스템 관리자 |
| governance | 거버넌스 컨트랙트 |
| pool | Pool 도메인 |
| position | Position 도메인 |
| router | Router 도메인 |
| staker | Staker 도메인 |
| emission | Emission 컨트랙트 |
| gns | GNS 토큰 |
| protocol_fee | 프로토콜 수수료 |

## B. Fee Structure

| 수수료 | 값 | 설명 |
|--------|-----|------|
| Pool Creation | 100 GNS | 풀 생성 비용 |
| Swap Fee Tiers | 0.01~1% | 풀별 스왑 수수료 |
| Protocol Fee | 0-10% | 스왑 수수료 중 프로토콜 몫 |
| Router Fee | 0.15% | 라우터 수수료 |

## C. Key Constants

| 상수 | 값 | 설명 |
|------|-----|------|
| MIN_TICK | -887272 | 최소 틱 |
| MAX_TICK | 887272 | 최대 틱 |
| Q96 | 2^96 | 가격 정밀도 |
| MAX_FEE | 1000000 | 최대 수수료 (100%) |

---

*GnoSwap Architecture Document v1.0*
