# Dependency System Usage Example

이 문서는 dependency 시스템의 실제 사용 예제를 보여줍니다.

## 시나리오

Position 컨트랙트에서 Pool 컨트랙트의 `Mint` 함수를 호출하는 예제입니다.

## Step 1: Pool 컨트랙트 구현 및 배포 (v1)

```go
// contract/r/gnoswap/pool/v1/pool.gno
package pool_v1

import (
    "std"
    "gno.land/r/gnoswap/dependency"
)

// Mint creates a new pool position
func Mint(caller std.Realm, args ...interface{}) interface{} {
    // args[0]: poolId string
    // args[1]: amount uint64
    poolId := args[0].(string)
    amount := args[1].(uint64)

    // Pool v1 specific logic
    // ...

    return "minted-" + poolId
}

// init registers this contract version and its functions
func init() {
    realm := std.CurrentRealm()

    // Step 1: Register contract version
    dependency.RegisterContractVersion(
        dependency.ContractPool,
        1, // version
        realm,
        []dependency.Dependency{
            // pool v1 has no dependencies in this example
        },
    )

    // Step 2: Register functions
    dependency.RegisterFunction(dependency.FunctionRegistration{
        Contract: dependency.ContractPool,
        Version:  1,
        Function: "Mint",
        Handler:  Mint,
    })

    dependency.RegisterFunction(dependency.FunctionRegistration{
        Contract: dependency.ContractPool,
        Version:  1,
        Function: "Burn",
        Handler:  Burn,
    })
}

func Burn(caller std.Realm, args ...interface{}) interface{} {
    // Burn logic...
    return "burned"
}
```

## Step 2: Position 컨트랙트 구현 및 배포 (v1)

```go
// contract/r/gnoswap/position/v1/position.gno
package position_v1

import (
    "std"
    "gno.land/r/gnoswap/dependency"
)

// CreatePosition creates a new position by calling Pool.Mint
func CreatePosition(poolId string, amount uint64) string {
    // Call Pool.Mint through dependency system
    // The dependency system will automatically route to Pool v1
    result := dependency.Call(
        dependency.ContractPool,
        "Mint",
        poolId,
        amount,
    )

    return result.(string)
}

// init registers this contract version with its dependencies
func init() {
    realm := std.CurrentRealm()

    // Register position v1 with dependency on pool v1
    dependency.RegisterContractVersion(
        dependency.ContractPosition,
        1,
        realm,
        []dependency.Dependency{
            {
                Contract: dependency.ContractPool,
                Version:  1, // position v1 depends on pool v1
            },
        },
    )
}
```

## Step 3: Pool v2 배포 (새로운 기능 추가)

```go
// contract/r/gnoswap/pool/v2/pool.gno
package pool_v2

import (
    "std"
    "gno.land/r/gnoswap/dependency"
)

// Mint creates a new pool position (v2 with TWAP)
func Mint(caller std.Realm, args ...interface{}) interface{} {
    poolId := args[0].(string)
    amount := args[1].(uint64)

    // Pool v2 specific logic with TWAP
    // ...

    return "minted-v2-" + poolId
}

func init() {
    realm := std.CurrentRealm()

    dependency.RegisterContractVersion(
        dependency.ContractPool,
        2, // version 2
        realm,
        []dependency.Dependency{},
    )

    dependency.RegisterFunction(dependency.FunctionRegistration{
        Contract: dependency.ContractPool,
        Version:  2,
        Function: "Mint",
        Handler:  Mint,
    })

    dependency.RegisterFunction(dependency.FunctionRegistration{
        Contract: dependency.ContractPool,
        Version:  2,
        Function: "Burn",
        Handler:  Burn,
    })
}

func Burn(cross std.Realm, args ...interface{}) interface{} {
    // Burn v2 logic...
    return "burned-v2"
}
```

## Step 4: Position v2 배포 (Pool v2 사용)

```go
// contract/r/gnoswap/position/v2/position.gno
package position_v2

import (
    "std"
    "gno.land/r/gnoswap/dependency"
)

// CreatePosition creates a new position using Pool v2
func CreatePosition(poolId string, amount uint64) string {
    // Same code as v1, but dependency system routes to Pool v2
    result := dependency.Call(
        dependency.ContractPool,
        "Mint",
        poolId,
        amount,
    )

    return result.(string)
}

func init() {
    realm := std.CurrentRealm()

    // Register position v2 with dependency on pool v2
    dependency.RegisterContractVersion(
        dependency.ContractPosition,
        2,
        realm,
        []dependency.Dependency{
            {
                Contract: dependency.ContractPool,
                Version:  2, // position v2 depends on pool v2
            },
        },
    )
}
```

## 동작 원리

### Position v1이 Pool을 호출할 때

```
Position v1: CreatePosition("pool-1", 1000)
    │
    └─> dependency.Call(ContractPool, "Mint", "pool-1", 1000)
            │
            ├─> 1. std.PrevRealm() → Position v1 realm 확인
            ├─> 2. GetContractByRealm() → Position v1 식별
            ├─> 3. GetDependencies(Position, 1) → [Pool v1]
            ├─> 4. GetFunctionHandler(Pool, 1, "Mint") → Pool v1 Mint handler
            └─> 5. Execute: Pool v1 Mint handler
                    │
                    └─> Result: "minted-pool-1"
```

### Position v2가 Pool을 호출할 때

```
Position v2: CreatePosition("pool-1", 1000)
    │
    └─> dependency.Call(ContractPool, "Mint", "pool-1", 1000)
            │
            ├─> 1. std.PrevRealm() → Position v2 realm 확인
            ├─> 2. GetContractByRealm() → Position v2 식별
            ├─> 3. GetDependencies(Position, 2) → [Pool v2]
            ├─> 4. GetFunctionHandler(Pool, 2, "Mint") → Pool v2 Mint handler
            └─> 5. Execute: Pool v2 Mint handler
                    │
                    └─> Result: "minted-v2-pool-1"
```

## 핵심 포인트

### 1. 함수 등록 (Pool 컨트랙트에서)

```go
dependency.RegisterFunction(dependency.FunctionRegistration{
    Contract: dependency.ContractPool,
    Version:  1,
    Function: "Mint",
    Handler:  Mint, // 실제 함수 참조
})
```

- Pool 컨트랙트가 배포될 때 자신의 함수들을 등록
- Handler는 실제 함수의 참조

### 2. 의존성 선언 (Position 컨트랙트에서)

```go
dependency.RegisterContractVersion(
    dependency.ContractPosition,
    1,
    realm,
    []dependency.Dependency{
        {
            Contract: dependency.ContractPool,
            Version:  1, // 어떤 버전의 Pool을 사용할지 명시
        },
    },
)
```

- Position이 어떤 버전의 Pool을 사용할지 선언

### 3. 함수 호출 (Position 컨트랙트에서)

```go
result := dependency.Call(
    dependency.ContractPool,  // 호출할 컨트랙트
    "Mint",                   // 호출할 함수
    poolId,                   // 인자 1
    amount,                   // 인자 2
)
```

- Dependency 시스템이 자동으로 올바른 버전의 함수를 찾아서 실행
- Position v1 → Pool v1 Mint
- Position v2 → Pool v2 Mint

## 장점

### 1. 버전 격리

- Position v1과 v2가 동시에 존재 가능
- 각자 자신이 의존하는 Pool 버전을 호출

### 2. 코드 변경 최소화

- Position의 호출 코드는 동일 (`dependency.Call(...)`)
- 버전 라우팅은 dependency 시스템이 처리

### 3. 타입 안정성

```go
// 컴파일 시점에 함수 시그니처 검증
func Mint(caller std.Realm, args ...interface{}) interface{} {
    // Type assertion으로 안전한 타입 변환
    poolId := args[0].(string)
    amount := args[1].(uint64)
    // ...
}
```

### 4. 무중단 업그레이드

- Pool v2 배포해도 v1은 계속 작동
- Position v1은 Pool v1 계속 사용
- 새로운 Position v2만 Pool v2 사용

## 실제 사용 흐름

```
┌─────────────────────────────────────────────┐
│ 1. Pool v1 배포                              │
│    - RegisterContractVersion(Pool, 1)       │
│    - RegisterFunction(Pool, 1, Mint)        │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│ 2. Position v1 배포                          │
│    - RegisterContractVersion(Position, 1)   │
│    - Dependencies: [Pool v1]                │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│ 3. Position v1 사용                          │
│    - dependency.Call(Pool, Mint, ...)       │
│    - 자동으로 Pool v1의 Mint 실행            │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│ 4. Pool v2 배포 (새로운 기능)                │
│    - RegisterContractVersion(Pool, 2)       │
│    - RegisterFunction(Pool, 2, Mint)        │
│    - Position v1은 여전히 Pool v1 사용       │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│ 5. Position v2 배포                          │
│    - RegisterContractVersion(Position, 2)   │
│    - Dependencies: [Pool v2]                │
│    - 동일한 코드로 Pool v2 Mint 호출         │
└─────────────────────────────────────────────┘
```

## 다중 의존성 예제

```go
// Router v1이 Pool v1과 Position v1을 함께 사용
dependency.RegisterContractVersion(
    dependency.ContractRouter,
    1,
    realm,
    []dependency.Dependency{
        {Contract: dependency.ContractPool, Version: 1},
        {Contract: dependency.ContractPosition, Version: 1},
    },
)

// Router에서 호출
func Swap() {
    // Pool v1의 함수 호출
    dependency.Call(dependency.ContractPool, "Swap", ...)

    // Position v1의 함수 호출
    dependency.Call(dependency.ContractPosition, "Update", ...)
}
```

## 에러 처리

```go
// 등록되지 않은 함수 호출 시
result := dependency.Call(
    dependency.ContractPool,
    "NonExistentFunction", // 등록되지 않은 함수
    args...,
)
// Panic: function not found for pool:v1

// 의존성이 없는 컨트랙트 호출 시
result := dependency.Call(
    dependency.ContractStaker, // Position의 dependency에 없음
    "Stake",
    args...,
)
// Panic: position:v1 does not depend on staker
```
