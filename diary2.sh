#!/bin/bash

# ========================================================
# Secret Diary Project (Auto Sync Version)
# Repository: https://github.com/INUJSM/secret_database.git
# ========================================================

# [핵심] 스크립트가 있는 실제 폴더 위치를 변수로 저장
# (어디서 실행하든 에러가 나지 않도록 작업 경로를 고정합니다)
BASE_DIR=$(dirname "$(realpath "$0")")
cd "$BASE_DIR" || exit

DIARY_EXT=".enc"        # 암호화된 일기 파일 확장자
TEMP_FILE=".temp_edit"  # 수정 시 사용할 임시 파일 (숨김 처리)

# --------------------------------------------------------
# 유틸리티 함수
# --------------------------------------------------------

function print_line() {
    echo "------------------------------------------------------"
}

function show_list() {
    echo " [ 저장된 일기 목록 ]"
    ls *${DIARY_EXT} 2>/dev/null
    if [ $? -ne 0 ]; then
        echo " (저장된 일기가 없습니다)"
        return 1
    fi
    return 0
}

# --------------------------------------------------------
# 핵심 기능 함수
# --------------------------------------------------------

# 0. GitHub 레포지토리 및 토큰 설정
function setup_github() {
    print_line
    echo " >> [0] GitHub 연결 설정 (레포지토리 & 토큰)"
    echo " [안내] GitHub 아이디와 토큰(Token)을 입력하면"
    echo "        매번 로그인할 필요 없이 자동 연동됩니다."
    
    echo ""
    echo -n " GitHub 사용자 ID (예: INUJSM): "
    read git_id
    
    echo -n " GitHub Repository 주소 (예: https://github.com/INUJSM/my-diary.git): "
    read git_url
    
    echo -n " Personal Access Token (입력 시 안 보임): "
    read -s git_token
    echo ""
    echo ""

    if [ -z "$git_id" ] || [ -z "$git_url" ] || [ -z "$git_token" ]; then
        echo " [오류] 모든 항목을 입력해야 합니다."
        return
    fi

    # URL 재조립 (https://아이디:토큰@주소)
    clean_url=$(echo "$git_url" | sed 's/https:\/\///')
    auth_url="https://${git_id}:${git_token}@${clean_url}"

    echo " 설정을 변경 중입니다..."
    
    git remote get-url origin &> /dev/null
    if [ $? -eq 0 ]; then
        git remote set-url origin "$auth_url"
    else
        git remote add origin "$auth_url"
    fi

    if [ $? -eq 0 ]; then
        echo " [성공] GitHub 설정이 완료되었습니다!"
        echo " 이제 비밀번호 입력 없이 백업/동기화가 가능합니다."
    else
        echo " [실패] Git 설정 변경에 실패했습니다."
    fi
}

# 1. 일기 쓰기 기능
function write_diary() {
    print_line
    echo " >> [1] 일기 쓰기 모드"
    
    echo -n " 날짜를 입력하세요 (예: 2024-11-26): "
    read input_date
    filename="${input_date}${DIARY_EXT}"

    if [ -f "$filename" ]; then
        echo " [!] 이미 해당 날짜의 일기가 존재합니다. '수정' 기능을 이용해주세요."
        return
    fi

    echo -n " 내용을 입력하세요: "
    read content

    echo ""
    echo -n " [보안] 암호화 비밀번호 설정: "
    read -s password
    echo ""

    echo "$content" | openssl enc -aes-256-cbc -base64 -pbkdf2 -pass pass:"$password" -out "$filename"

    if [ $? -eq 0 ]; then
        echo " [성공] 암호화되어 저장되었습니다: $filename"
    else
        echo " [실패] 저장 중 오류가 발생했습니다."
    fi
}

# 2. 일기 조회 기능
function read_diary() {
    print_line
    echo " >> [2] 일기 조회 모드"
    
    show_list
    if [ $? -ne 0 ]; then return; fi

    echo ""
    echo -n " 조회할 날짜를 입력하세요: "
    read target_date
    filename="${target_date}${DIARY_EXT}"

    if [ ! -f "$filename" ]; then
        echo " [!] 파일을 찾을 수 없습니다."
        return
    fi

    echo -n " [보안] 비밀번호 입력: "
    read -s password
    echo ""
    echo " ---------------- 내용 확인 ----------------"

    openssl enc -d -aes-256-cbc -base64 -pbkdf2 -pass pass:"$password" -in "$filename" 2>/dev/null
    
    if [ $? -ne 0 ]; then
        echo " [접근 거부] 비밀번호가 일치하지 않거나 파일이 손상되었습니다."
    fi
    echo ""
}

# 3. 일기 수정 기능
function edit_diary() {
    print_line
    echo " >> [3] 일기 수정 모드"
    
    show_list
    if [ $? -ne 0 ]; then return; fi

    echo ""
    echo -n " 수정할 날짜를 입력하세요: "
    read target_date
    filename="${target_date}${DIARY_EXT}"

    if [ ! -f "$filename" ]; then
        echo " [!] 파일을 찾을 수 없습니다."
        return
    fi

    echo -n " [보안] 비밀번호 입력 (본인 확인): "
    read -s password
    echo ""

    openssl enc -d -aes-256-cbc -base64 -pbkdf2 -pass pass:"$password" -in "$filename" -out "$TEMP_FILE" 2>/dev/null

    if [ $? -ne 0 ]; then
        echo " [오류] 비밀번호가 틀렸습니다. 수정 권한이 없습니다."
        rm -f "$TEMP_FILE" 2>/dev/null
        return
    fi

    if command -v nano &> /dev/null; then
        nano "$TEMP_FILE"
    else
        vi "$TEMP_FILE"
    fi

    openssl enc -aes-256-cbc -base64 -pbkdf2 -pass pass:"$password" -in "$TEMP_FILE" -out "$filename"
    rm "$TEMP_FILE"

    echo " [성공] 수정된 내용이 다시 암호화되어 저장되었습니다."
}

# 4. 일기 삭제 기능
function delete_diary() {
    print_line
    echo " >> [4] 일기 삭제 모드"
    
    show_list
    if [ $? -ne 0 ]; then return; fi

    echo ""
    echo -n " 삭제할 날짜를 입력하세요: "
    read target_date
    filename="${target_date}${DIARY_EXT}"

    if [ ! -f "$filename" ]; then
        echo " [!] 파일을 찾을 수 없습니다."
        return
    fi

    echo -n " [보안] 비밀번호 입력 (본인 확인): "
    read -s password
    echo ""

    openssl enc -d -aes-256-cbc -base64 -pbkdf2 -pass pass:"$password" -in "$filename" -out /dev/null 2>/dev/null

    if [ $? -ne 0 ]; then
        echo " [오류] 비밀번호가 일치하지 않아 삭제할 수 없습니다."
        return
    fi

    echo -n " 정말로 삭제하시겠습니까? (y/n): "
    read confirm
    if [ "$confirm" == "y" ]; then
        rm "$filename"
        echo " [성공] 로컬 파일이 영구 삭제되었습니다."
    else
        echo " 삭제가 취소되었습니다."
    fi
}

# 5. 일기 백업 기능 (Push)
function backup_diary() {
    print_line
    echo " >> [5] 일기 백업 모드 (GitHub Push)"
    
    git add *${DIARY_EXT} 2>/dev/null
    git add -u *${DIARY_EXT} 2>/dev/null

    commit_msg="Backup Diary: $(date '+%Y-%m-%d %H:%M:%S')"
    git commit -m "$commit_msg"

    echo " Github으로 데이터 전송 중..."
    current_branch=$(git branch --show-current)
    git push origin "$current_branch"

    if [ $? -eq 0 ]; then
        echo " [성공] 백업이 완료되었습니다."
    else
        echo " [실패] 백업 중 오류가 발생했습니다. (설정 확인 필요)"
    fi
}

# 6. 일기 동기화 기능 (Pull)
function sync_diary() {
    print_line
    echo " >> [6] 일기 동기화 모드 (GitHub Pull)"
    echo " 원격 저장소에서 최신 일기 데이터를 가져옵니다..."
    
    current_branch=$(git branch --show-current)
    git pull origin "$current_branch"

    if [ $? -eq 0 ]; then
        echo " [성공] 최신 데이터와 동기화되었습니다."
    else
        echo " [주의] 동기화 중 충돌(Conflict)이 발생했거나 네트워크 오류입니다."
    fi
}

# 7. 프로그램 설치 (경로 자동 등록)
function install_program() {
    print_line
    echo " >> [7] 설치 모드 (명령어 'mydiary' 등록)"
    
    # 이미 상단에서 계산한 BASE_DIR 사용
    SCRIPT_NAME=$(basename "$0")
    FULL_PATH="$BASE_DIR/$SCRIPT_NAME"
    
    if [ -f "$HOME/.zshrc" ]; then
        CONFIG_FILE="$HOME/.zshrc"
    else
        CONFIG_FILE="$HOME/.bashrc"
    fi

    echo " 등록할 경로: $FULL_PATH"
    
    grep -q "alias mydiary=" "$CONFIG_FILE"
    if [ $? -eq 0 ]; then
        echo " [!] 이미 'mydiary' 명령어가 등록되어 있습니다."
        return
    fi

    chmod +x "$FULL_PATH"
    echo "" >> "$CONFIG_FILE"
    echo "# Secret Diary Alias" >> "$CONFIG_FILE"
    echo "alias mydiary='$FULL_PATH'" >> "$CONFIG_FILE"
    
    echo " [성공] 설치가 완료되었습니다!"
    echo " 터미널을 다시 켜거나 'source $CONFIG_FILE'을 입력하세요."
}

# --------------------------------------------------------
# 메인 루프
# --------------------------------------------------------

while true; do
    print_line
    echo "      Secret Database Diary"
    print_line
    echo " 0. GitHub 설정 (토큰/주소 변경)"
    echo " 1. 일기 쓰기"
    echo " 2. 일기 조회"
    echo " 3. 일기 수정"
    echo " 4. 일기 삭제"
    echo " 5. 일기 백업 (Push)"
    echo " 6. 동기화    (Pull)"
    echo " 7. 설치      (명령어 등록)"
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