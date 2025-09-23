# 나의 Hammerspoon 설정 (.hammerspoon)

macOS에서의 생산성과 편의성을 높이기 위해 사용하는 개인적인 [Hammerspoon](https://www.hammerspoon.org/) 설정 스크립트 저장소입니다. 반복적인 작업을 자동화하고, 저에게 꼭 맞는 단축키와 창 관리 기능을 만들어가는 것을 목표로 합니다.

## ✨ 주요 기능

이 설정에 포함된 핵심 기능들은 다음과 같습니다.

-   **창 관리 (Window Management)**
    -   단축키를 이용해 창을 화면의 좌/우/상/하 절반으로 정확하게 이동 및 리사이징
    -   전체 화면, 중앙 배치 등 자주 사용하는 창 레이아웃으로 빠르게 전환
-   **사용자 정의 단축키 (Custom Hotkeys)**
    -   자주 사용하는 애플리케이션을 빠르게 실행하거나 전환하는 단축키
    -   특정 기능을 수행하는 커스텀 단축키 설정
-   **키보드/마우스 편의 기능**
    -   키보드를 이용한 마우스 커서 이동 및 클릭 제어
    -   특정 키 리매핑을 통한 입력 효율 증대
-   **커스텀 알림 연동**
    -   직접 개발한 [GlassToaster](https://github.com/kkotdari/GlassToaster)와 연동하여, Wi-Fi 변경 등 특정 이벤트 발생 시 미려한 디자인의 토스트 알림을 표시

## 📂 파일 구조

-   `init.lua`: 모든 설정의 시작점이 되는 메인 파일입니다. 각 모듈을 불러옵니다.
-   `modules/`: 기능별로 스크립트를 분리하여 관리합니다. (예: `hotkeys.lua`, `window-management.lua`)

## 🚀 설치 및 사용법

1.  macOS에 [Hammerspoon](https://www.hammerspoon.org/)을 설치합니다.
2.  이 저장소를 `~/.hammerspoon` 디렉토리에 클론(clone)합니다.

    ```sh
    git clone [https://github.com/kkotdari/.hammerspoon.git](https://github.com/kkotdari/.hammerspoon.git) ~/.hammerspoon
    ```

3.  Hammerspoon 앱을 실행하거나, 이미 실행 중이라면 메뉴 바의 아이콘을 클릭하여 **"Reload Config"**를 선택하면 설정이 바로 적용됩니다.

> ⚠️ **주의**: 이 스크립트는 지극히 개인적인 용도로 작성되었습니다. 그대로 사용하기보다는 참고용으로 활용하시는 것을 권장합니다.

## 🔗 관련 프로젝트

-   [**GlassToaster**](https://github.com/kkotdari/GlassToaster): 이 설정에서 사용하는 macOS용 커스텀 토스트 알림 유틸리티입니다.
