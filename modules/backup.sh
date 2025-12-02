#!/bin/bash

function backup_diary() {
    echo " >> [5] 일기 백업 모드"

    if [ ! -d ".git" ]; then
        echo "[!] Git 초기화가 되어있지 않습니다. (GitHub 설정 필요)"
        return
    fi

    if ! git remote | grep "origin" > /dev/null; then
        echo "[!] GitHub 연결이 설정되지 않았습니다."
        return
    fi
    
    git add "$DATA_DIR"
    
    if ! git diff-index --quiet HEAD; then
        timestamp=$(date +'%Y-%m-%d %H:%M:%S')
        git commit -m "Backup: $timestamp" > /dev/null
        echo "[성공] 일기 데이터가 커밋되었습니다."
    else
        echo "[!] 새로운 일기 데이터가 없습니다."
    fi

    echo "[GitHub] 원격 저장소로 업로드를 시작합니다..."
    
    current_branch=$(git branch --show-current)
    if [ -z "$current_branch" ]; then current_branch="main"; fi
    
    git push origin "$current_branch" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        echo "[성공] 업로드가 완료되었습니다!"
    else
        echo "[실패] 업로드에 실패했습니다."
    fi
}