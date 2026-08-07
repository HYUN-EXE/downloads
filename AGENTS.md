# downloads 저장소 작업 규칙

## 프런트엔드 스킬

- 홈페이지의 디자인, 리디자인, UI/UX 검토, 접근성·반응형·성능 감사 또는 시각적 다듬기 작업에는 저장소의 `.agents/skills/impeccable` 스킬을 적용한다.
- `.agents/skills/impeccable/SKILL.md` 또는 `.claude/skills/impeccable/SKILL.md`가 없으면 작업 전에 저장소 루트에서 `npx --yes impeccable@3.5.0 install --providers=claude,codex --scope=project`를 실행한 뒤 사용하는 에이전트의 스킬 지침을 읽고 진행한다.
- 백엔드 전용 작업이나 홈페이지 UI와 무관한 배포 파일 작업에는 이 스킬을 적용하지 않는다.

## 향후 신규 프로그램

- 새 프로그램을 다운로드 페이지에 추가하기 전에, 그 프로그램이 설치 프로그램(Inno Setup)과 자동 업데이트를 갖췄는지 확인한다.
- 아직 없다면 `HYUN-EXE/AppInstallerTemplate` 저장소(재사용 가능한 설치 프로그램 + 자동 업데이트 스캐폴드)를 먼저 참고해 적용할지 검토한다.
- 설계 배경: `AppInstallerTemplate` 저장소의 `docs/superpowers/specs/2026-07-29-installer-autoupdate-standard-design.md` 참고.

## 카드 추가 시 확인 사항

- 다운로드 버튼 href는 자동 업데이트 전송용 zip이 아니라 사용자가 최초 설치에 쓰는 파일(설치 프로그램이 있다면 `_Setup.exe`, 없다면 `_Setup.zip`)을 가리켜야 한다.
- 버튼 텍스트가 실제 파일 형식(EXE/ZIP)과 맞는지 확인한다.
- 다른 프로그램 카드나 디자인은 요청받지 않은 한 함께 수정하지 않는다.

## 외부 Agent Skill 공급망

- 조사·수정 전에 저장소 루트에서 `powershell -NoProfile -ExecutionPolicy Bypass -File ".agents/skills/skill-supply-chain/scripts/skill-manager.ps1" -Action Sync`를 한 번 실행한다.
- 작업에 특화된 절차가 실질적으로 필요하고 기존 스킬로 부족할 때만 `skill-supply-chain`으로 Cola Skill 후보와 GitHub 원본을 검수한다.
- 승인된 외부 스킬만 저장소 범위에 설치하고 정확한 Git commit과 SHA-256을 `.agents/skills.lock.json`에 고정한다. 전역 설치, 후보 코드 선실행, 미검수 자동 업데이트는 금지한다.
- 새 스킬을 설치했다면 해당 `SKILL.md`를 전부 읽은 뒤 본 작업을 시작한다.
