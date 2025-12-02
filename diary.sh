#!/bin/bash

# ========================================================
# Secret Diary Project (Initial Version)
# ========================================================

# [핵심] 스크립트 실행 위치 변수 지정 (모듈들과 공유)
export BASE_DIR=$(dirname "$(realpath "$0")")
cd "$BASE_DIR" || exit

# --------------------------------------------------------
# 모듈 불러오기 (Import)
# --------------------------------------------------------
source "$BASE_DIR/modules/utils.sh"
source "$BASE_DIR/modules/write.sh"
source "$BASE_DIR/modules/read.sh"
source "$BASE_DIR/modules/edit.sh"
source "$BASE_DIR/modules/delete.sh"
source "$BASE_DIR/modules/github_setting.sh"
source "$BASE_DIR/modules/backup.sh"
source "$BASE_DIR/modules/sync.sh"
source "$BASE_DIR/modules/install.sh"

# --------------------------------------------------------
# 메인 루프
# --------------------------------------------------------

while true; do
    print_line
    echo "      Secret Database Diary"
    print_line
    echo " 0. Github 설정"
    echo " 1. 일기 쓰기"
    echo " 2. 일기 조회"
    echo " 3. 일기 수정"
    echo " 4. 일기 삭제"
    echo " 5. 일기 백업 (Push)"
    echo " 6. 동기화    (Pull)"
    echo " 7. 설치 "
    echo " q. 종료"
    print_line
    echo -n " 메뉴 선택: "
    read choice

    case "$choice" in
        0) setup_github ;;
        1) write_diary ;;
        2) read_diary ;;
        3) edit_diary ;;
        4) delete_diary ;;
        5) backup_diary ;;
        6) sync_diary ;;
        7) install_program ;;
        q) echo " 프로그램을 종료합니다."; exit 0 ;;
        *) echo " 잘못된 입력입니다." ;;
    esac
    echo ""
done