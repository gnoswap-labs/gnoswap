# GnoDoc 문서 모델 설계 (go/doc 기반)

이 문서는 `go/parser` + `go/doc` 결과를 HTML/Markdown 렌더러에 안정적으로 전달하기 위한 내부 문서 모델을 정의한다.
목표는 pkg.go.dev 스타일의 섹션 구성과 source 링크를 위한 위치 정보 보존이다.

## 설계 원칙
- go/doc의 구조를 최대한 보존하되 렌더링에 필요한 최소 스키마로 정규화한다.
- 모든 심볼은 공통 베이스(`DocNode`)를 통해 요약/본문/위치/예제/태그를 공유한다.
- 선언 위치는 파일/라인/컬럼 정보를 반드시 포함한다.
- export/unexport 여부는 렌더링 필터링과 색인에 모두 사용한다.
- Deprecated/Note/Example 등 doc 태그를 모델에서 독립적으로 다룬다.

## 핵심 타입 (제안 스키마)

### DocPackage
- 패키지 전체 정보를 담는 루트
- 필드
  - Name: string
  - ImportPath: string
  - ModulePath: string
  - Summary: string (첫 문장)
  - Doc: string (전체 문서, Markdown 원문)
  - Files: []SourceFile
  - Consts: []DocValueGroup
  - Vars: []DocValueGroup
  - Funcs: []DocFunc
  - Types: []DocType
  - Examples: []DocExample
  - Notes: []DocNote
  - Deprecated: []DocDeprecated
  - Index: []DocIndexItem

### DocNode (공통 베이스)
- 모든 심볼의 공통 메타
- 필드
  - Name: string
  - Kind: string (const/var/func/type/method/field)
  - Summary: string
  - Doc: string
  - Signature: string
  - Decl: string (원문 선언 텍스트, 선택)
  - Exported: bool
  - Pos: SourcePos
  - Examples: []DocExample
  - Notes: []DocNote
  - Deprecated: []DocDeprecated

### SourcePos
- 파일 위치 정보
- 필드
  - Filename: string
  - Line: int
  - Column: int

### SourceFile
- 렌더러의 파일 목록, source 링크 구성에 사용
- 필드
  - Name: string
  - Path: string

### DocValueGroup
- const/var 묶음 표현
- 필드
  - DocNode (Summary/Doc/Pos는 그룹 기준)
  - Specs: []DocValueSpec

### DocValueSpec
- const/var 개별 스펙
- 필드
  - DocNode
  - Type: string
  - Value: string

### DocFunc
- 함수 선언
- 필드
  - DocNode
  - Params: []DocParam
  - Results: []DocParam
  - Receiver: *DocReceiver (메서드일 경우)

### DocType
- 타입 선언
- 필드
  - DocNode
  - Kind: string (struct/interface/alias)
  - Fields: []DocField
  - Methods: []DocFunc
  - Constructors: []DocFunc

### DocField
- struct/interface 필드
- 필드
  - DocNode
  - Type: string
  - Tag: string

### DocParam
- 파라미터/리턴
- 필드
  - Name: string
  - Type: string

### DocReceiver
- 메서드 리시버
- 필드
  - Name: string
  - Type: string

### DocExample
- 예제 코드
- 필드
  - Name: string
  - Doc: string
  - Code: string
  - Output: string
  - Pos: SourcePos

### DocNote
- Note/Warning 등 태그 기반 노트
- 필드
  - Kind: string (Note/Warning/BUG/TODO 등)
  - Body: string
  - Pos: SourcePos

### DocDeprecated
- Deprecated 태그
- 필드
  - Body: string
  - Pos: SourcePos

### DocIndexItem
- 렌더러의 좌측 Index/TOC 구성
- 필드
  - Name: string
  - Kind: string
  - Anchor: string
  - Exported: bool

## go/doc 매핑 규칙
- go/doc.Package
  - Consts/Vars/Funcs/Types -> 각각 DocValueGroup/DocFunc/DocType로 변환
  - Examples -> DocExample
  - Notes -> DocNote (go/doc.Note.Kind 사용)
- DocNode.Summary
  - DocComment 첫 문장을 요약으로 추출
- DocDeprecated
  - DocComment에서 "Deprecated:" 접두어 추출
- DocIndexItem
  - 패키지/const/var/func/type/method 별로 anchor 생성

## 수용 조건 (Definition of Done)
- 패키지/타입/메서드/상수/변수/함수의 관계가 손실 없이 표현된다.
- 모든 심볼은 SourcePos를 보유한다.
- Examples/Deprecated/Notes가 모델에 존재한다.
- export/unexport 플래그로 필터링 가능하다.
- 렌더러가 이 모델만으로 HTML/Markdown을 생성할 수 있다.
