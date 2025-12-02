#!/bin/bash

function sync_diary() {
    echo " >> [6] 일기 동기화 모드"

    if [ ! -d ".git" ]; then
        echo "[!] Git 초기화가 되어있지 않습니다."
        echo "   메뉴의 '0. GitHub 설정'을 먼저 진행해주세요."
        return
    fi

    if ! git remote | grep "origin" > /dev/null; then
        echo "[!] GitHub 연결이 설정되지 않았습니다."
        echo "   메뉴의 '0. GitHub 설정'을 먼저 진행해주세요."
        return
    fi

    echo "[GitHub] 원격 저장소의 변경 사항을 가져옵니다..."
    
    current_branch=$(git branch --show-current)
    if [ -z "$current_branch" ]; then current_branch="main"; fi

    git pull origin "$current_branch" 2>/dev/null

    if [ $? -eq 0 ]; then
        echo "[성공] 동기화가 완료되었습니다."
        echo ""
        show_list
    else
        echo "[실패] 동기화 실패. (충돌 발생 또는 연결 문제)"
        echo "   (혹시 로컬에 커밋하지 않은 변경사항이 있는지 확인해보세요.)"
    fi
}