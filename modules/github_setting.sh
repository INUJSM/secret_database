#!/bin/bash

# 0. GitHub 레포지토리 및 토큰 설정
function setup_github() {
    print_line
    echo " >> [0] GitHub 연결 설정 (레포지토리 & 토큰)"
    
    # 1. Git 초기화 확인
    if [ ! -d ".git" ]; then
        echo " [알림] 현재 폴더가 Git 저장소가 아닙니다."
        echo "        자동으로 Git 저장소로 초기화합니다..."
        git init
        git branch -M main
        echo " [완료] Git 초기화 성공 (현재 브랜치: main)"
        echo ""
    fi
    
    # 2. 기존 연결 확인
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

    # 3. 사용자 입력 받기
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

    # 4. 주소 조합 (Token 포함)
    clean_url=$(echo "$git_url" | sed 's/https:\/\///')
    auth_url="https://${git_id}:${git_token}@${clean_url}"

    echo " 설정을 변경 중입니다..."
    
    # 5. Remote URL 설정
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

# ... (아래에 기존 backup_diary, sync_diary 함수는 그대로 두세요) ...