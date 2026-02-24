# SOI - 진정한 소통을 위한 폐쇄형 SNS

<div align="center">

**사진과 음성으로 감정을 전달하는 소셜 이미징 플랫폼**

*"텍스트가 아닌, 목소리와 사진으로 나누는 진솔한 이야기"*

[![Flutter](https://img.shields.io/badge/Flutter-3.7.0+-02569B?style=flat&logo=flutter)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Firebase-latest-FFCA28?style=flat&logo=firebase)](https://firebase.google.com)
[![Spring Boot](https://img.shields.io/badge/Spring%20Boot-API-6DB33F?style=flat&logo=spring)](https://spring.io)

</div>

---

## 📖 프로젝트 소개

### 🎯 시작 계기

현대 SNS는 '좋아요'와 짧은 텍스트로 소통이 단절되고 있습니다.  
**SOI**는 **진정한 감정 전달**을 목표로, 사진과 음성을 결합한 폐쇄형 소셜 플랫폼입니다.

### 💡 핵심 가치

\`\`\`
📸 사진으로 순간을 포착 + 🎤 음성으로 감정을 담다 = ❤️ 진정한 소통
\`\`\`

- **음성 + 사진**: 목소리로 전하는 진심 있는 이야기
- **폐쇄형 공유**: 친한 친구들끼리만 공유하는 안전한 공간
- **실시간 소통**: 음성 댓글로 주고받는 생생한 대화
- **카테고리 기반**: 친구별, 주제별로 추억을 정리

### 📱 주요 기능

1. **📷 사진 + 음성 메모**: 카메라로 찍은 사진에 음성 녹음
2. **🎙️ 음성 댓글 시스템**: 친구의 사진에 음성으로 댓글 남기기
3. **📂 카테고리 관리**: 그룹별 사진 앨범 생성 및 공유
4. **👥 친구 시스템**: 연락처 기반 친구 추가
5. **📱 실시간 동기화**: Firebase 기반 실시간 데이터 업데이트

---

## 🌿 브랜치 전략

이 프로젝트는 **2가지 버전**으로 개발되고 있습니다.

### 📂 브랜치 구조

\`\`\`
├── main (원본 - 수정 전 상태)
├── firebase-version (Firebase 중심 아키텍처)
└── api-version (Spring Boot API 중심 아키텍처)
\`\`\`

### 🔥 firebase-version

**Firebase 기반 회원가입 및 데이터 관리**

\`\`\`
기술 스택:
├─ Flutter + Dart (Frontend)
└─ Firebase (Backend)
   ├─ Authentication (전화번호 인증)
   ├─ Firestore (NoSQL 데이터베이스)
   └─ Storage (이미지/음성 파일)
\`\`\`

**특징:**
- 회원가입이 \`register_screen\`에서 즉시 수행
- Firebase 중심의 빠른 프로토타이핑
- 서버리스 아키텍처

### 🌐 api-version

**Spring Boot API 기반 회원가입 및 데이터 관리**

\`\`\`
기술 스택:
├─ Flutter + Dart (Frontend)
└─ Backend (하이브리드)
   ├─ Spring Boot REST API (회원가입, 사용자 관리)
   ├─ Firebase Firestore (실시간 데이터)
   └─ Firebase Storage (파일 관리)
\`\`\`

**특징:**
- 회원가입이 \`onboarding_main_screen\`에서 수행
- 백엔드 API와 Firebase 하이브리드 구조
- 확장 가능한 서버 아키텍처
- 약관 동의 데이터 체계적 관리

### 🔄 브랜치 작업 플로우

#### 🔥 Firebase 버전으로 작업할 때

\`\`\`bash
# 1. Firebase 브랜치로 전환
git checkout firebase-version

# 2. (선택사항) 다른 곳에서 작업한 내용이 있다면 최신 내용 받아오기
git pull origin firebase-version

# 3. 코드 수정...

# 4. 변경사항 저장
git add .
git commit -m "feat: Firebase 기능 추가"

# 5. 원격 저장소에 올리기
git push origin firebase-version
\`\`\`

#### 🌐 API 버전으로 작업할 때

\`\`\`bash
# 1. API 브랜치로 전환
git checkout api-version

# 2. (선택사항) 다른 곳에서 작업한 내용이 있다면 최신 내용 받아오기
git pull origin api-version

# 3. 코드 수정...

# 4. 변경사항 저장
git add .
git commit -m "feat: API 기능 추가"

# 5. 원격 저장소에 올리기
git push origin api-version
\`\`\`

#### ⚠️ 주의사항

**변경사항이 있는 상태에서 브랜치 전환 시**

만약 파일을 수정했는데 커밋하지 않은 상태에서 브랜치를 전환하려고 하면:

\`\`\`bash
# 에러 발생 가능
error: Your local changes to the following files would be overwritten by checkout
\`\`\`

**해결 방법 1: 변경사항 임시 저장**
\`\`\`bash
git stash              # 임시 저장
git checkout [브랜치명]  # 브랜치 전환
git stash pop          # 임시 저장한 것 복원
\`\`\`

**해결 방법 2: 커밋 후 전환**
\`\`\`bash
git add .
git commit -m "WIP: 작업 중"
git checkout [브랜치명]
\`\`\`

#### 🔄 다른 레포지토리에 동일한 브랜치 구조로 푸시하기
```bash
git add .
git commit -m "message"
git push newdawn firebase-version(newdawn의 firebase-version인 경우)
git push newdawn api-version(newdawn의 firebase-version인 경우)
git push origin firebase-version(minchan의 firebase-version인 경우)
git push origin api-version(minchan의 firebase-version인 경우)
```

---

## 🛠 기술 스택

### Frontend

| 기술 | 용도 | 버전 |
|------|------|------|
| **Flutter** | 크로스 플랫폼 UI 프레임워크 | 3.7.0+ |
| **Dart** | 프로그래밍 언어 | Latest |
| **Provider** | 상태 관리 (ChangeNotifier) | ^6.1.4 |

### Backend

#### Firebase (공통)

| 서비스 | 용도 |
|--------|------|
| **Authentication** | 전화번호 기반 SMS 인증 |
| **Firestore** | 실시간 NoSQL 데이터베이스 |
| **Storage** | 이미지 및 음성 파일 저장 |

#### Spring Boot API (api-version 전용)

| 기술 | 용도 |
|------|------|
| **Spring Boot** | REST API 서버 |
| **PostgreSQL / MySQL** | 관계형 데이터베이스 |
| **JWT** | 인증 토큰 (예정) |

### Native Platform

| 플랫폼 | 언어 | 구현 내용 |
|--------|------|-----------|
| **iOS** | Swift | 커스텀 카메라 플러그인 |
| **Android** | Kotlin | 플랫폼 채널 구현 |

---

## 🏗 아키텍처

### MVC + Provider 패턴

\`\`\`
lib/
├── models/          # 데이터 모델 & 비즈니스 로직
├── views/           # UI 화면 (Pages & Widgets)
│   ├── about_login/
│   ├── about_onboarding/
│   ├── camera/
│   ├── category/
│   └── home/
├── controllers/     # 상태 관리 (ChangeNotifier)
│   ├── auth_controller.dart
│   ├── category_controller.dart
│   ├── audio_controller.dart
│   └── comment_audio_controller.dart
├── services/        # 외부 서비스 연동
│   ├── user_service.dart (api-version)
│   └── camera_service.dart
├── api/             # API 통신 (api-version)
└── theme/           # 앱 디자인 시스템
\`\`\`

### 핵심 Controller

| Controller | 역할 |
|------------|------|
| \`AuthController\` | 사용자 인증, 로그인/로그아웃, 프로필 관리 |
| \`CategoryController\` | 카테고리 및 사진 CRUD |
| \`AudioController\` | 음성 녹음/재생 |
| \`CommentAudioController\` | 음성 댓글 시스템 |
| \`ContactController\` | 연락처 기반 친구 관리 |

---

## 📊 데이터베이스 구조

### Firestore Collections

\`\`\`javascript
users/
  {userId}/
    uid: String              // Firebase Auth UID
    id: String              // 사용자 닉네임
    name: String            // 실명
    phone: String           // 전화번호
    birth_date: String      // 생년월일
    profile_image: String   // 프로필 이미지 URL
    createdAt: Timestamp
    
categories/
  {categoryId}/
    name: String              // 카테고리 이름
    userId: Array<String>     // 참여자 UID 배열
    mates: Array<String>      // 참여자 닉네임 배열
    photoCount: Number        // 사진 개수
    
    photos/                   // 서브컬렉션
      {photoId}/
        userId: String
        imageUrl: String      // 이미지 URL
        audioUrl: String      // 음성 메모 URL
        
        comments/             // 서브컬렉션
          {userNickname}/
            audioUrl: String  // 음성 댓글 URL
\`\`\`

---

## ⚡ 핵심 기능

### 1. 인증 시스템
- 전화번호 기반 SMS 인증
- 플랫폼별 구분 처리 (Web: reCAPTCHA, Native: SMS)

### 2. 카메라 & 사진
- iOS/Android 네이티브 카메라 통합
- 이미지 압축 및 최적화
- 카테고리별 사진 분류

### 3. 음성 시스템
- 사진별 음성 메모 녹음
- 실시간 음성 댓글
- Firebase Storage 업로드

### 4. 소셜 기능
- 연락처 기반 친구 시스템
- 카테고리 기반 그룹 공유
- 실시간 데이터 동기화

### 5. 아카이빙
- 3가지 아카이브 뷰 (전체/개인/공유)
- 그리드 기반 갤러리 UI

---

## 📱 화면 구조

### 인증 플로우
\`\`\`
StartScreen → LoginScreen ↔ RegisterScreen 
→ AuthFinalScreen → OnboardingMainScreen → HomeNavigatorScreen
\`\`\`

### 메인 네비게이션
\`\`\`
HomeScreen (카테고리 목록)
├─ CategoryScreen (카테고리 상세)
│
CameraScreen (실시간 카메라)
└─ PhotoEditorScreen (사진 편집 + 음성 녹음)
│
ArchiveMainScreen (아카이브 탭)
\`\`\`

---

## � Git 브랜치 관리 가이드

### 📤 현재 레포지토리에 푸시하기

**기본적인 작업 후 원격 저장소에 푸시하는 방법**

#### Firebase 버전 푸시

```bash
# 1. firebase-version 브랜치로 전환
git checkout firebase-version

# 2. 변경사항 확인
git status

# 3. 변경된 파일 스테이징
git add .

# 4. 커밋
git commit -m "feat: 기능 추가 설명"

# 5. 원격 저장소에 푸시
git push origin firebase-version
```

#### API 버전 푸시

```bash
# 1. api-version 브랜치로 전환
git checkout api-version

# 2. 변경사항 확인
git status

# 3. 변경된 파일 스테이징
git add .

# 4. 커밋
git commit -m "feat: 기능 추가 설명"

# 5. 원격 저장소에 푸시
git push origin api-version
```

#### 유용한 Git 명령어

```bash
# 현재 브랜치 확인
git branch

# 모든 브랜치 확인 (원격 포함)
git branch -a

# 최신 변경사항 받아오기
git pull origin [브랜치명]

# 변경사항 임시 저장
git stash

# 임시 저장한 내용 복원
git stash pop

# 커밋 히스토리 확인
git log --oneline --graph --all

# 원격 저장소 정보 확인
git remote -v
```

---

## 🔄 다른 레포지토리에 브랜치 구조 복제하기

다른 Git 레포지토리(예: 팀 레포지토리)에도 동일한 브랜치 구조를 만들고 싶다면 아래 방법을 사용하세요.

### 옵션 A: 브랜치 복사 방식 (빠른 방법 ⭐)

**현재 레포지토리의 브랜치를 다른 레포지토리에 푸시하는 방법**

#### 1단계: 대상 레포지토리를 remote로 추가

```bash
# 현재 SOI 디렉토리에서 실행
git remote add target https://github.com/[조직명]/[레포명].git

# 예시: NewdawnSOI/SOI_FE 레포지토리에 추가
git remote add newdawn https://github.com/NewdawnSOI/SOI_FE.git

# remote 확인
git remote -v
```

#### 2단계: firebase-version 브랜치 푸시

```bash
# firebase-version 브랜치로 전환
git checkout firebase-version

# 대상 레포지토리에 푸시
git push target firebase-version

# 예시
git push newdawn firebase-version
```

#### 3단계: api-version 브랜치 푸시

```bash
# api-version 브랜치로 전환
git checkout api-version

# 대상 레포지토리에 푸시
git push target api-version

# 예시
git push newdawn api-version
```

#### 4단계: 푸시 확인

```bash
# 대상 레포지토리의 브랜치 확인
git ls-remote target

# 예시
git ls-remote newdawn
```

**✅ 완료!** 이제 대상 레포지토리에도 `firebase-version`과 `api-version` 브랜치가 생성되었습니다.

#### ⚠️ 주의사항

- 대상 레포지토리에 푸시 권한이 있어야 합니다
- 두 레포지토리의 코드가 호환되는지 확인하세요
- 필요시 대상 레포지토리에서 별도로 코드 수정 후 커밋하세요

---

## �🚀 시작하기

### 프로젝트 설정

\`\`\`bash
# 1. 저장소 클론
git clone https://github.com/minchanpark/SOI.git
cd SOI

# 2. 브랜치 선택
git checkout firebase-version  # Firebase 버전
# 또는
git checkout api-version       # API 버전

# 3. 의존성 설치
flutter pub get

# 4. iOS 의존성 (macOS만 해당)
cd ios && pod install && cd ..
\`\`\`

### 실행

\`\`\`bash
# iOS 시뮬레이터
flutter run -d ios

# Android 에뮬레이터
flutter run -d android

# Web
flutter run -d chrome
\`\`\`

---

## 📈 개발 현황

### 완료된 기능
✅ 전화번호 인증  
✅ 카메라 촬영 및 음성 녹음  
✅ 카테고리 관리  
✅ 음성 댓글 시스템  
✅ 친구 추가  
✅ 아카이브 시스템  

### 개발 예정
🔜 푸시 알림 시스템  
🔜 사진 좋아요 기능  
🔜 프로필 편집  
🔜 검색 기능  

---

## 👥 개발자

**민찬** - [@minchanpark](https://github.com/minchanpark)

---

<div align="center">

**SOI** - 진정한 소통을 위한 폐쇄형 SNS

*Made with ❤️ by minchanpark*

</div>
