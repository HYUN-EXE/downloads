# 유틸리티 다운로드 사이트

- 홈페이지: <https://hyun-utilities.pages.dev/>
- 공개 배포 저장소: <https://github.com/HYUN-EXE/downloads>
- VideoCutter 배포: <https://github.com/HYUN-EXE/VideoCutter-Releases>
- GifMaker 배포: <https://github.com/HYUN-EXE/GifMaker-Releases>
- SmcR 배포: <https://github.com/HYUN-EXE/SimpleMacro-Releases>
- 포맷 복원 도우미 배포: <https://github.com/HYUN-EXE/FormatRestoreHelper-Releases>
- TetherBrowser 배포: <https://github.com/HYUN-EXE/TetherBrowser-Releases>
- 확장자변환기(FormatChanger) 배포: <https://github.com/HYUN-EXE/FormatChanger-Releases>
- 비공개 애플리케이션 소스는 이 저장소에 포함하지 않습니다.

GitHub의 `main` 브랜치가 Cloudflare Pages에 연결되어 있어 홈페이지 변경사항을 푸시하면 자동으로 배포됩니다.

## 배포 규칙

배포 파일은 Git 커밋에 추가하지 않고 GitHub Releases에만 첨부합니다. `artifacts/`, ZIP 및 SHA-256 파일은 `.gitignore` 처리되어 있습니다.

### VideoCutter

- Release 태그: `v1.0.0`, `v1.1.0`과 같은 버전 형식
- 자동 업데이트 자산: `latest.yml`, `VideoCutter_Setup_버전.exe`, 대응 `.blockmap`
- 사용자 다운로드 자산: `VideoCutter_Setup.exe`, `VideoCutter_Setup.exe.sha256`
- 이전 고정 링크 호환 자산: `VideoCutter_Setup.zip`, `VideoCutter_Setup.zip.sha256`
- 생성된 electron-builder 자산은 이름이나 내용을 변경하지 않습니다.

### GifMaker

- Release 태그: `gifmaker-v1.0.0`과 같은 앱 이름 포함 형식
- 사용자 다운로드 자산: `GifMaker_Setup.exe`, `GifMaker_Setup.exe.sha256` (설치 프로그램)
- 자동 업데이트 전송 자산: `GifMaker_Setup.zip`, `GifMaker_Setup.zip.sha256`, `update.json`
- ZIP과 해시를 Release에 먼저 업로드한 다음 `update.json`을 마지막으로 커밋합니다.

### SmcR

- 사용자 다운로드 자산: `SmcR_Setup.exe`, `SmcR_Setup.exe.sha256`

### 포맷 복원 도우미

- 사용자 다운로드 자산: `FormatRestoreHelper_Setup.exe`
- 자동 업데이트 전송 자산: `FormatRestoreHelper_Setup.zip`, `update.json`
- 해시 자산 없음

### TetherBrowser

- 사용자 다운로드 자산: `TetherBrowser_Setup.exe`
- 자동 업데이트 전송 자산: `TetherBrowser_Setup.zip`, `update.json`
- 해시 자산 없음

### 확장자변환기(FormatChanger)

- Release 태그: `v0.1.0`과 같은 버전 형식
- 사용자 다운로드 자산: `FormatChanger_Setup.exe`, `FormatChanger_Setup.exe.sha256` (설치 프로그램, ffmpeg 포함)
- 자동 업데이트 전송 자산: `FormatChanger_Setup.zip`, `FormatChanger_Setup.zip.sha256`, `update.json` (Release 자산, `releases/latest/download/update.json`으로 읽음)
- ZIP과 해시·설치 파일을 먼저 올리고 `update.json`을 마지막에 올립니다.

## 무결성 확인

위 앱별 절은 각 Release에 무엇을 올려야 하는지를 정합니다. 그중 해시 자산이 있는 프로그램만 다운로드 확인 창에 `설치파일이름.sha256` 링크가 뜨며, 페이지에 무엇을 노출할지는 `index.html`의 다운로드 앵커에 붙은 `data-hash` 속성이 정합니다. 해시를 새로 올리거나 내리면 앱별 절과 이 속성을 함께 맞춰야 합니다.

## 인증

GitHub CLI 로그인 정보는 Windows 자격 증명 저장소에서 관리합니다. GitHub 토큰, API 키, 환경변수 파일은 이 저장소나 Release에 포함하지 않습니다.

```powershell
& "C:\Program Files\GitHub CLI\gh.exe" auth login --hostname github.com --git-protocol ssh --web
```
