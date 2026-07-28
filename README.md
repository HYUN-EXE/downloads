# 유틸리티 다운로드 사이트

GitHub Pages에는 이 폴더의 정적 홈페이지 파일만 배포하고, 프로그램 ZIP은 GitHub Releases에 업로드합니다.

## 공개 저장소 만들기

GitHub 계정 `HYUN-EXE`에 `downloads`라는 이름의 **Public** 저장소를 빈 저장소로 만듭니다.
저장소 생성 화면에서 README, `.gitignore`, License는 추가하지 않습니다.

그다음 이 폴더에서 실행합니다.

```powershell
git init
git add .gitignore index.html styles.css assets README.md
git commit -m "Create download website"
git branch -M main
git remote add origin git@github.com:HYUN-EXE/downloads.git
git push -u origin main
```

GitHub 저장소의 `Settings > Pages`에서 다음과 같이 설정합니다.

- Source: `Deploy from a branch`
- Branch: `main`
- Folder: `/ (root)`

배포 주소는 `https://hyun-exe.github.io/downloads/`입니다.

## 프로그램 ZIP 업로드

페이지의 다운로드 주소는 프로그램별 고정 Release 태그를 사용합니다.

- GifMaker: `gifmaker-latest`
- VideoCutter: `videocutter-latest`

GitHub CLI를 처음 한 번 설치하고 로그인합니다.

```powershell
winget install --id GitHub.cli
gh auth login
```

최초 Release 생성:

```powershell
gh release create gifmaker-latest `
  "artifacts\GifMaker_Setup.zip" `
  "artifacts\GifMaker_Setup.zip.sha256" `
  --repo HYUN-EXE/downloads `
  --target main `
  --title "GifMaker 최신 버전" `
  --notes "GifMaker Windows 배포 파일"

gh release create videocutter-latest `
  "artifacts\VideoCutter_Setup.zip" `
  "artifacts\VideoCutter_Setup.zip.sha256" `
  --repo HYUN-EXE/downloads `
  --target main `
  --title "VideoCutter 최신 버전" `
  --notes "VideoCutter Windows 배포 파일"
```

이후 새 빌드로 교체:

```powershell
gh release upload gifmaker-latest `
  "artifacts\GifMaker_Setup.zip" `
  "artifacts\GifMaker_Setup.zip.sha256" `
  --repo HYUN-EXE/downloads `
  --clobber

gh release upload videocutter-latest `
  "artifacts\VideoCutter_Setup.zip" `
  "artifacts\VideoCutter_Setup.zip.sha256" `
  --repo HYUN-EXE/downloads `
  --clobber
```

`artifacts` 폴더는 `.gitignore` 처리되어 있으므로 홈페이지 저장소의 Git 커밋에는 포함되지 않습니다.
