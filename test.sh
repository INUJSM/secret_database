#!/bin/bash

# ========================================================
# Secret Diary Project (Folder Structure Version)
# Repository: https://github.com/INUJSM/secret_database.git
# ========================================================

# [핵심] 스크립트가 있는 실제 폴더 위치를 변수로 저장
BASE_DIR=$(dirname "$(realpath "$0")")
cd "$BASE_DIR" || exit

# [변경] 일기 데이터를 저장할 하위 폴더 지정
DATA_DIR="data"

# 데이터 폴더가 없으면 생성
if [ ! -d "$DATA_DIR" ]; then
    mkdir -p "$DATA_DIR"
fi

# [자동 이사] 혹시 바깥(루트)에 있는 일기 파일이 있다면 data 폴더로 이동
mv *.enc "$DATA_DIR" 2>/dev/null

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
    
    # [수정] data 폴더 안의 파일만 조회
    # 파일이 하나도 없으면 ls가 에러를 뱉으므로 2>/dev/null 처리
    count=$(ls "$DATA_DIR"/*${DIARY_EXT} 2>/dev/null | wc -l)
    
    if [ "$count" -eq 0 ]; then
        echo " (저장된 일기가 없습니다)"
        return 1
    fi

    # 경로(data/)를 빼고 파일명만 예쁘게 출력
    ls "$DATA_DIR"/*${DIARY_EXT} | xargs -n 1 basename
    return 0
}

# --------------------------------------------------------
# 핵심 기능 함수
# --------------------------------------------------------

# 0. GitHub 레포지토리 및 토큰 설정
function setup_github() {
    print_line
    echo " >> [0] GitHub 연결 설정 (레포지토리 & 토큰)"
    
    if [ ! -d ".git" ]; then
        echo " [알림] 현재 폴더가 Git 저장소가 아닙니다."
        echo "        자동으로 Git 저장소로 초기화합니다..."
        git init
        git branch -M main
        echo " [완료] Git 초기화 성공 (현재 브랜치: main)"
        echo ""
    fi
    
    current_url=$(git remote get-url origin 2>/dev/null)
    
    if [ $? -eq 0 ] && [ -n "$current_url" ]; then
        echo " -------------------------------------------------"
        echo " [!] 이미 연결된 저장소 정보가 감지되었습니다."
        echo " 현재 URL: $current_url"
        echo " -------------------------------------------------"
        echo -n " 기존 설정을 덮어쓰고 새로 설정하시겠습니까? (y/n): "
        read confirm
        
        if [ "$confirm" != "y" ]; then
            echo " [안내] 설정 변경을 취소하고 메뉴로 돌아갑니다."
            return
        fi
        echo ""
    else
        echo " [안내] 현재 연결된 원격 저장소가 없습니다. 설정을 시작합니다."
    fi

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
    
    # [수정] 파일 경로에 DATA_DIR 추가
    filename="$DATA_DIR/${input_date}${DIARY_EXT}"

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
    # [수정] 경로 추가
    filename="$DATA_DIR/${target_date}${DIARY_EXT}"

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
    # [수정] 경로 추가
    filename="$DATA_DIR/${target_date}${DIARY_EXT}"

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
    # [수정] 경로 추가
    filename="$DATA_DIR/${target_date}${DIARY_EXT}"

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

# 5. 일기 백업 기능
function backup_diary() {
    print_line
    echo " >> [5] 일기 백업 모드 (GitHub으로 보내기)"
    
    git remote get-url origin &> /dev/null
    if [ $? -ne 0 ]; then
        echo " [오류] GitHub 설정이 필요합니다. 0번 메뉴를 이용하세요."
        return
    fi

    # [중요] 모든 변경사항(data 폴더 이동 포함) 반영
    git add -A

    if git diff-index --quiet HEAD --; then
        echo " [알림] 변경된 내용이 없어 백업을 건너뜁니다."
        return
    fi

    commit_msg="Update Diary: $(date '+%Y-%m-%d %H:%M:%S')"
    git commit -m "$commit_msg" 2>/dev/null

    echo " GitHub으로 동기화 중..."
    current_branch=$(git branch --show-current)
    
    git push origin "$current_branch"

    if [ $? -eq 0 ]; then
        echo " [성공] 백업 완료 (파일 위치 변경도 반영됨)"
    else
        echo " -------------------------------------------------------"
        echo " [실패] 서버와 충돌이 발생했습니다."
        echo "        메뉴 [6]번 -> [2]번(덮어쓰기)을 해보세요."
        echo " -------------------------------------------------------"
    fi
}

# 6. 일기 동기화 기능
function sync_diary() {
    print_line
    echo " >> [6] 일기 동기화 모드 (서버와 합치기)"
    
    git fetch origin &> /dev/null
    if [ $? -ne 0 ]; then
        echo " [오류] 인터넷 연결이나 GitHub 설정을 확인해주세요."
        return
    fi

    current_branch=$(git branch --show-current)

    echo " -------------------------------------------------------"
    echo " [1] 안전하게 합치기 (Smart Merge)"
    echo "    - 서버의 내용을 가져오되, 내용이 다르면 선택합니다."
    echo ""
    echo " [2] 강제 덮어쓰기 (Reset)"
    echo "    - 내 컴퓨터의 모든 작업을 버리고 서버랑 똑같이 만듭니다."
    echo " -------------------------------------------------------"
    echo -n " 선택 (1/2): "
    read sync_mode

    if [ "$sync_mode" == "1" ]; then
        echo " [진행] 서버의 변경 사항을 가져오는 중..."
        
        pull_output=$(git pull origin "$current_branch" 2>&1)
        pull_status=$?

        if [ $pull_status -eq 0 ]; then
            echo " [성공] 충돌 없이 자동으로 합쳐졌습니다."
            
            deleted_files=$(git ls-files --deleted)
            if [ -n "$deleted_files" ]; then
                echo " [알림] 삭제된 파일이 서버에서 복구되었습니다."
                git checkout .
            fi
        else
            if [[ "$pull_output" == *"CONFLICT"* ]] || [[ "$pull_output" == *"overwritten"* ]]; then
                echo " -------------------------------------------------------"
                echo " [!] 내용 불일치 감지! (서버 파일 vs 내 파일)"
                echo " -------------------------------------------------------"
                echo " 1. 내 파일 유지 (Keep My Local)"
                echo " 2. 서버 파일 적용 (Accept Theirs)"
                echo " -------------------------------------------------------"
                echo -n " 해결 방법 선택 (1/2): "
                read conflict_choice

                if [ "$conflict_choice" == "1" ]; then
                    echo " [진행] 내 파일 내용을 유지합니다..."
                    git stash &> /dev/null
                    git pull origin "$current_branch" &> /dev/null
                    git stash pop &> /dev/null
                    git checkout --ours . 2>/dev/null
                    git add -A
                    git commit -m "Merge conflict: Kept local version" 2>/dev/null
                    echo " [완료] 내 내용으로 유지되었습니다."
                    
                elif [ "$conflict_choice" == "2" ]; then
                    echo " [진행] 서버 파일 내용을 적용합니다..."
                    git reset --hard "origin/$current_branch"
                    echo " [완료] 서버 내용으로 변경되었습니다."
                else
                    echo " [취소] 동기화를 중단합니다."
                fi
            else
                echo " [오류] 알 수 없는 이유로 동기화에 실패했습니다."
                echo " 메시지: $pull_output"
            fi
        fi

    elif [ "$sync_mode" == "2" ]; then
        echo " [경고] 내 컴퓨터의 모든 파일이 삭제되고 서버 내용으로 바뀝니다."
        echo -n " 정말 진행하시겠습니까? (y/n): "
        read confirm
        
        if [ "$confirm" == "y" ]; then
            echo " [진행] 서버 데이터로 강제 초기화 중..."
            git reset --hard "origin/$current_branch"
            git clean -fd
            echo " [성공] 서버와 100% 동일한 상태가 되었습니다."
        else
            echo " [취소] 작업을 취소합니다."
        fi
    else
        echo " 잘못된 입력입니다."
    fi
}

# 7. 프로그램 설치
function install_program() {
    print_line
    echo " >> [7] 설치 모드 (명령어 자동 등록)"
    
    CURRENT_DIR=$(pwd)
    SCRIPT_NAME=$(basename "$0")
    FULL_PATH="$CURRENT_DIR/$SCRIPT_NAME"
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        CONFIG_FILE="$HOME/.zshrc"
        OS_TYPE="MacBook (macOS)"
    else
        CONFIG_FILE="$HOME/.bashrc"
        OS_TYPE="Windows/Linux"
    fi

    echo " 감지된 시스템: $OS_TYPE"
    echo " 설정 파일 위치: $CONFIG_FILE"
    
    if [ ! -f "$CONFIG_FILE" ]; then
        touch "$CONFIG_FILE"
    fi

    ALIAS_NAME="test.sh"

    grep -q "alias $ALIAS_NAME=" "$CONFIG_FILE"
    if [ $? -eq 0 ]; then
        echo " ------------------------------------------------------"
        echo " [!] 이미 '$ALIAS_NAME' 명령어가 등록되어 있습니다."
        echo " ------------------------------------------------------"
        return
    fi

    chmod +x "$FULL_PATH"
    echo "" >> "$CONFIG_FILE"
    echo "# Secret Diary Project Alias" >> "$CONFIG_FILE"
    echo "alias $ALIAS_NAME='$FULL_PATH'" >> "$CONFIG_FILE"
    
    echo " ------------------------------------------------------"
    echo " [성공] 설치가 완료되었습니다!"
    echo " ------------------------------------------------------"
    echo " [중요] 적용하려면 다음 명령어를 한 번 입력하세요:"
    echo "        source $CONFIG_FILE"
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