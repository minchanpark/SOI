# Spring Boot API → Flutter API 마이그레이션 가이드

## 개요

Spring Boot로 작성된 API를 OpenAPI Generator를 사용하여 Flutter Dart 클라이언트로 자동 생성하는 가이드입니다.

## 사전 요구사항

- ✅ OpenAPI Generator가 brew로 설치되어 있어야 함
- ✅ Swagger UI 접근: https://newdawnsoi.site/swagger-ui/index.html

---

## 단계별 가이드

### 1단계: OpenAPI Specification 다운로드

Swagger UI에서 OpenAPI 스펙 파일을 다운로드합니다.

```bash
# Swagger UI에서 직접 JSON/YAML 다운로드
curl -o api/openapi.json https://newdawnsoi.site/v3/api-docs

# 또는 YAML 형식으로 다운로드 (서버가 지원하는 경우)
curl -o api/openapi.yaml https://newdawnsoi.site/v3/api-docs.yaml
```

**수동 다운로드 방법:**

1. https://newdawnsoi.site/swagger-ui/index.html 접속
2. 상단의 `/v3/api-docs` 링크 클릭 또는 URL 입력
3. JSON 내용을 복사하여 `api/openapi.json`에 저장

---

### 2단계: OpenAPI Generator 설정 파일 생성

Flutter/Dart 클라이언트 생성을 위한 설정 파일을 작성합니다.

**`api/config.yaml` 생성:**

```yaml
# OpenAPI Generator 설정
generatorName: dart
outputDir: ./generated
inputSpec: ./openapi.json

# Dart 클라이언트 옵션
additionalProperties:
  pubName: soi_api_client
  pubVersion: 1.0.0
  pubDescription: "SOI API Client generated from Spring Boot API"
  nullableFields: true
  # Dio를 HTTP 클라이언트로 사용 (Firebase와의 호환성)
  useEnumExtension: true
```

---

### 3단계: Flutter API 클라이언트 자동 생성

OpenAPI Generator를 실행하여 Dart 코드를 생성합니다.

```bash
# api 디렉토리로 이동
cd api

# OpenAPI Generator 실행
openapi-generator generate \
  -i openapi.json \
  -g dart \
  -o generated \
  --additional-properties=pubName=soi_api_client,pubVersion=1.0.0,nullableFields=true,useEnumExtension=true

# 또는 config.yaml 사용
openapi-generator generate -c config.yaml
```

---

### 4단계: 생성된 코드 구조 확인

생성된 디렉토리 구조:

```
api/
├── openapi.json              # OpenAPI 스펙 파일
├── config.yaml               # Generator 설정
├── generated/                # 생성된 Flutter 클라이언트
│   ├── lib/
│   │   ├── api/             # API 엔드포인트 클래스들
│   │   ├── model/           # 데이터 모델 클래스들
│   │   └── api_client.dart  # HTTP 클라이언트
│   ├── pubspec.yaml         # 패키지 의존성
│   ├── README.md
│   └── ...
└── README.md                # 이 파일
```

---

### 5단계: 생성된 패키지 의존성 설치

```bash
# generated 디렉토리로 이동
cd generated

# Dart 패키지 의존성 설치
flutter pub get
```

---

### 6단계: 메인 프로젝트에 통합

SOI 프로젝트의 `pubspec.yaml`에 로컬 패키지로 추가:

```yaml
dependencies:
  # ... 기존 dependencies
  soi_api_client:
    path: ./api/generated
```

그 후 메인 프로젝트에서 의존성 설치:

```bash
# SOI 루트 디렉토리에서
flutter pub get
```

---

## 유지보수

### API 스펙 업데이트 시

Spring Boot API가 변경되면 다음 단계를 반복:

```bash
# 1. 최신 OpenAPI 스펙 다운로드
curl -o api/openapi.yaml https://newdawnsoi.site/v3/api-docs

# 2. 기존 generated 폴더 백업 (선택사항)
mv api/generated api/generated.backup

# 3. 코드 재생성
cd api
openapi-generator generate -c config.yaml

# 4. 패치 스크립트 실행 (필수!)
./patch_generated.sh

# 5. 의존성 재설치
cd generated
flutter pub get

# 6. 메인 프로젝트 의존성 업데이트
cd ../..
flutter pub get
```

---

## OpenAPI Generator 명령어 참고

### 도움말 확인

```bash
openapi-generator help generate
```

### Dart generator 옵션 확인

```bash
openapi-generator config-help -g dart
```

### 지원하는 generator 목록

```bash
openapi-generator list
```

---

## 문제 해결

### 1. OpenAPI Generator 미설치 시

```bash
brew install openapi-generator
```

### 2. 생성된 코드에 MultipartFile 에러가 있는 경우

OpenAPI Generator의 Dart generator는 multipart 파일 배열 처리에 버그가 있을 수 있습니다.

**⚠️ 중요: 자동 생성된 코드는 절대 직접 수정하지 마세요!**
재생성 시 모든 수정사항이 사라집니다.

**해결 방법:**

#### 옵션 A: dart-dio generator 사용 (권장)

더 나은 HTTP 클라이언트와 multipart 처리를 제공합니다.

```bash
# config.yaml에서 generatorName을 dart-dio로 변경
# 기존 생성 코드 삭제 후 재생성
cd api
rm -rf generated
openapi-generator generate -c config.yaml
cd generated && flutter pub get
```

#### 옵션 B: Wrapper 클래스 작성 (권장)

생성된 코드를 직접 수정하지 말고, wrapper를 만들어 사용:

```dart
// lib/repositories/media_repository.dart
import 'package:soi_api_client/api.dart';
import 'package:http/http.dart' as http;
import 'dart:io';

class MediaRepository {
  final APIApi _api;

  MediaRepository(this._api);

  /// MultipartFile 생성 헬퍼
  Future<List<http.MultipartFile>> createMultipartFiles(
    List<File> files,
  ) async {
    final multipartFiles = <http.MultipartFile>[];
    for (var file in files) {
      final multipartFile = await http.MultipartFile.fromPath(
        'files',
        file.path,
      );
      multipartFiles.add(multipartFile);
    }
    return multipartFiles;
  }

  /// 미디어 업로드 (wrapper)
  Future<ApiResponseDtoListString?> uploadMedia({
    required String types,
    required int id,
    required List<File> files,
  }) async {
    final multipartFiles = await createMultipartFiles(files);
    return await _api.uploadMedia(types, id, multipartFiles);
  }
}
```

#### 옵션 C: 자동 패치 스크립트

생성 후 항상 실행할 패치 스크립트를 작성:

```bash
# api/patch_generated.sh 파일 생성
#!/bin/bash
echo "🔧 Patching generated code..."

# api_api.dart의 multipart 버그 수정
FILE="generated/lib/api/api_api.dart"
if [ -f "$FILE" ]; then
  # files.field 라인 제거
  sed -i '' '/mp.fields\[.*files.*\] = files.field;/d' "$FILE"
  # mp.files.add를 mp.files.addAll로 변경
  sed -i '' 's/mp.files.add(files);/mp.files.addAll(files);/g' "$FILE"
  echo "✅ Patch complete!"
else
  echo "❌ File not found: $FILE"
fi
```

**사용법:**

```bash
cd api
openapi-generator generate -c config.yaml
chmod +x patch_generated.sh
./patch_generated.sh
cd generated && flutter pub get
```

### 3. Firebase와의 통합

- 생성된 API 클라이언트는 Firebase Auth 토큰을 헤더에 추가하여 사용
- `AuthController`에서 토큰 관리 후 API 호출 시 전달

---

## 추가 참고사항

### Provider 패턴과 통합

SOI 프로젝트의 MVC 패턴에 맞춰 API 호출을 Repository 레이어에서 처리:

```dart
// lib/repositories/user_repository.dart
class UserRepository {
  final UserApi _userApi;

  UserRepository(ApiClient apiClient)
    : _userApi = UserApi(apiClient);

  Future<List<User>> fetchUsers() async {
    return await _userApi.getUsers();
  }
}
```

### 기존 Firebase 로직과 병행

- 기존 Firebase 로직은 유지
- Spring Boot API는 새로운 기능이나 복잡한 비즈니스 로직에 활용
- Repository 패턴으로 데이터 소스 추상화

---

## 생성 완료 체크리스트

- [ ] OpenAPI 스펙 파일 다운로드 완료
- [ ] `api/config.yaml` 설정 파일 생성
- [ ] Flutter 클라이언트 코드 생성 완료
- [ ] `api/generated/` 디렉토리 생성 확인
- [ ] 생성된 패키지 의존성 설치 완료
- [ ] 메인 프로젝트 `pubspec.yaml`에 추가
- [ ] API 클라이언트 테스트 완료
- [ ] Repository 패턴으로 통합 완료

---

**작성일:** 2025년 11월 4일  
**프로젝트:** SOI Flutter App  
**대상 API:** https://newdawnsoi.site
