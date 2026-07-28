# 유틸리티 다운로드 사이트

- 홈페이지: <https://hyun-utilities.pages.dev/>
- 공개 배포 저장소: <https://github.com/HYUN-EXE/downloads>
- VideoCutter 배포: <https://github.com/HYUN-EXE/VideoCutter-Releases>
- GifMaker 배포: <https://github.com/HYUN-EXE/GifMaker-Releases>
- SmcR 배포: <https://github.com/HYUN-EXE/SimpleMacro-Releases>
- 비공개 애플리케이션 소스는 이 저장소에 포함하지 않습니다.

GitHub의 `main` 브랜치가 Cloudflare Pages에 연결되어 있어 홈페이지 변경사항을 푸시하면 자동으로 배포됩니다.

## 배포 규칙

배포 파일은 Git 커밋에 추가하지 않고 GitHub Releases에만 첨부합니다. `artifacts/`, ZIP 및 SHA-256 파일은 `.gitignore` 처리되어 있습니다.

### VideoCutter

- Release 태그: `v1.0.0`, `v1.1.0`과 같은 버전 형식
- 자동 업데이트 자산: `latest.yml`, `VideoCutter_Setup_버전.exe`, 대응 `.blockmap`
- 사용자 다운로드 자산: `VideoCutter_Setup.zip`, `VideoCutter_Setup.zip.sha256`
- 생성된 electron-builder 자산은 이름이나 내용을 변경하지 않습니다.

### GifMaker

- Release 태그: `gifmaker-v1.0.0`과 같은 앱 이름 포함 형식
- 사용자 다운로드 자산: `GifMaker_Setup.zip`, `GifMaker_Setup.zip.sha256`
- 업데이트 메타데이터: `update.json`
- ZIP과 해시를 Release에 먼저 업로드한 다음 `update.json`을 마지막으로 커밋합니다.

## 인증

GitHub CLI 로그인 정보는 Windows 자격 증명 저장소에서 관리합니다. GitHub 토큰, API 키, 환경변수 파일은 이 저장소나 Release에 포함하지 않습니다.

```powershell
& "C:\Program Files\GitHub CLI\gh.exe" auth login --hostname github.com --git-protocol ssh --web
```
