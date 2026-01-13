# Dust Min Unit Test Report

## 목적
`dustMinAmount` 기본값을 10으로 둘 때와 최소 단위(0.000001, base unit=1)일 때의
변환 결과를 비교해서 정책 결정을 위한 근거를 확보했습니다.

## 테스트 환경
- 시나리오: `contract/r/scenario/dust_converter/dust_min_unit_probe_filetest.gno`
- 풀: bar-GNS, baz-GNS (fee 500)
- 유동성: 기본 1,000,000 / 1,000,000, 극단 tick 케이스 포함
- 호출: `ConvertDustToGns(target=GNS)`

## 관찰 결과
- **Min=1, amount=1** → `totalOut: 0` (DrySwap 결과 0으로 스킵)
- **Min=10, amount=1** → `totalOut: 0` (min 조건으로 스킵)
- **Min=1, amount=10** → `totalOut: 8`
- **Extreme tick, amount=1** → `totalOut: 0` (DrySwap 결과 0)
- **Extreme tick, amount=1000** → `totalOut: 997008`

## 해석
- 최소 단위(1, 0.000001)는 정상/극단 풀 모두 DrySwap 결과가 0으로 스킵됨.
- min=1은 기능적으로 동작하지만, 실제 변환 성공률은 낮음.
- 실질적인 변환을 기대하려면 10 이상 설정이 안전.
- 극단 가격에서는 충분히 큰 수량(예: 1000)으로 유의미한 출력이 발생.

## 제안
- 기본값은 **Min=10, Max=10**으로 고정 (PoC 기준)
- 추후 정책 변경은 setter로 조정 가능
