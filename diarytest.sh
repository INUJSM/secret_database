#!/bin/bash

# ==========================================
# 1. 환경 설정 및 초기화
# ==========================================
DIARY_DIR="$HOME/.my_diary"

# 디렉터리가 없으면 생성하고 Git을 초기화합니다.
if [ ! -d "$DIARY_DIR" ]; then
    mkdir -p "$DIARY_DIR"
    cd "$DIARY_DIR"
    git init > /dev/null
    echo "📂 초기 설정 완료: $DIARY_DIR"
fi

# ==========================================
# 2. 기능 함수 정의
# ==========================================

# [기능: GitHub 설정] - 토큰 및 주소 등록
setup_github() {
    echo "⚙️  --- GitHub 환경 설정 ---"
    echo "GitHub 연동을 위해 'Personal Access Token'과 '저장소 주소'가 필요합니다."
    echo ""

    # 1. 토큰 입력
    echo -n "🔑 GitHub Personal Access Token 입력: "
    read -s token
    echo ""
    
    if [ -z "$token" ]; then
        echo "❌ 토큰이 입력되지 않았습니다. 설정을 취소합니다."
        return
    fi

    # 2. 주소 입력
    echo -n "🌐 GitHub 저장소 주소 입력 (https://github.com/...): "
    read repo_url

    if [ -z "$repo_url" ]; then
        echo "❌ 주소가 입력되지 않았습니다. 설정을 취소합니다."
        return
    fi

    # 3. 인증 URL 생성
    auth_url="${repo_url/https:\/\//https:\/\/$token@}"

    cd "$DIARY_DIR"

    # 기존 연결 재설정
    if git remote | grep "origin" > /dev/null; then
        git remote remove origin
    fi

    git remote add origin "$auth_url"
    git branch -M main > /dev/null 2>&1

    echo ""
    echo "✅ 설정이 완료되었습니다."
}

# [기능: 백업 및 업로드 (Push)]
perform_backup() {
    cd "$DIARY_DIR"
    echo "📤 --- 백업 및 업로드 (Push) ---"

    if ! git remote | grep "origin" > /dev/null; then
        echo "⚠️  GitHub 연결이 설정되지 않았습니다."
        echo "   메뉴의 '0. GitHub 설정'을 먼저 진행해주세요."
        return
    fi
    
    # 로컬 커밋
    git add .
    if ! git diff-index --quiet HEAD; then
        timestamp=$(date +'%Y-%m-%d %H:%M:%S')
        git commit -m "Backup: $timestamp" > /dev/null
        echo "💾 [로컬] 변경 사항이 커밋되었습니다."
    else
        echo "ℹ️  새로운 변경 사항이 없습니다. (기존 데이터 업로드 시도)"
    fi

    # 원격 푸시
    echo "☁️  [GitHub] 원격 저장소로 업로드를 시작합니다..."
    git push origin main 2>/dev/null
    
    if [ $? -eq 0 ]; then
        echo "✅ [성공] 업로드가 완료되었습니다!"
    else
        echo "⚠️  [실패] 업로드에 실패했습니다. (토큰 만료 또는 동기화 필요)"
    fi
}

# [기능: 동기화 (Pull)]
synchronize_diary() {
    cd "$DIARY_DIR"
    echo "📥 --- 동기화 (Pull) ---"

    if ! git remote | grep "origin" > /dev/null; then
        echo "⚠️  GitHub 연결이 설정되지 않았습니다."
        echo "   메뉴의 '0. GitHub 설정'을 먼저 진행해주세요."
        return
    fi

    echo "☁️  [GitHub] 원격 저장소의 변경 사항을 가져옵니다..."
    git pull origin main 2>/dev/null

    if [ $? -eq 0 ]; then
        echo "✅ [성공] 동기화가 완료되었습니다."
    else
        echo "⚠️  [실패] 동기화 실패. (충돌 발생 또는 연결 문제)"
    fi
}

# [기능: 일기 작성]
write_diary() {
    echo "📝 --- 일기 작성 ---"
    today=$(date +%Y-%m-%d)
    filename="$DIARY_DIR/${today}.enc"

    if [ -f "$filename" ]; then
        echo "⚠️  오늘 이미 작성한 일기가 있습니다. '수정' 메뉴를 이용해주세요."
        return
    fi

    temp_file=$(mktemp)
    
    # 가이드 문구 추가
    echo "# [가이드] 저장: Ctrl+O -> Enter / 종료: Ctrl+X (이 줄은 지우셔도 됩니다)" > "$temp_file"
    echo "" >> "$temp_file"

    echo "편집기(nano)가 실행됩니다."
    echo -n "엔터를 누르면 시작합니다..."
    read dummy
    
    nano +99 "$temp_file"

    # 가이드 삭제 후 저장
    sed -i '/^# \[가이드\]/d' "$temp_file"

    if [ ! -s "$temp_file" ]; then
        echo "⚠️  내용이 없어 취소되었습니다."
        rm "$temp_file"
        return
    fi

    echo "" 
    echo "--------------------------------" 

    echo -n "🔑 암호 설정: "
    read -s password
    echo ""

    openssl enc -aes-256-cbc -salt -pbkdf2 -in "$temp_file" -out "$filename" -k "$password" 2>/dev/null

    if [ $? -eq 0 ]; then
        echo "🔒 암호화되어 파일로 저장되었습니다."
        echo "   (GitHub 업로드는 메인 메뉴의 '5. 백업'을 이용해주세요.)"
    else
        echo "❌ 암호화 실패."
    fi
    rm "$temp_file"
}

# [기능: 일기 조회]
read_diary() {
    echo "📖 --- 일기 목록 ---"
    if ls "$DIARY_DIR"/*.enc 1> /dev/null 2>&1; then
        ls "$DIARY_DIR"/*.enc | xargs -n 1 basename | sed 's/.enc//g'
    else
        echo "❌ 저장된 일기가 없습니다."
        return
    fi
    
    echo "--------------------------------"
    echo -n "조회할 날짜(YYYY-MM-DD): "
    read target_date
    target_file="$DIARY_DIR/${target_date}.enc"

    if [ ! -f "$target_file" ]; then
        echo "❌ 해당 날짜의 일기가 없습니다."
        return
    fi

    echo -n "🔑 비밀번호: "
    read -s password
    echo ""

    temp_file=$(mktemp)
    openssl enc -d -aes-256-cbc -pbkdf2 -in "$target_file" -out "$temp_file" -k "$password" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        echo "=== 내용 ==="
        grep -v "^# \[가이드\]" "$temp_file"
        echo -e "\n============"
    else
        echo "❌ 비밀번호가 틀리거나 파일이 손상되었습니다."
    fi
    rm "$temp_file"
}

# [기능: 일기 수정]
modify_diary() {
    echo "✏️  --- 일기 수정 ---"
    if ls "$DIARY_DIR"/*.enc 1> /dev/null 2>&1; then
        echo "[수정 가능한 날짜 목록]"
        ls "$DIARY_DIR"/*.enc | xargs -n 1 basename | sed 's/.enc//g'
        echo "--------------------------------"
    else
        echo "❌ 수정할 일기가 없습니다."
        return
    fi

    echo -n "수정할 날짜(YYYY-MM-DD): "
    read target_date
    target_file="$DIARY_DIR/${target_date}.enc"

    if [ ! -f "$target_file" ]; then
        echo "❌ 파일이 없습니다."
        return
    fi

    echo -n "기존 비밀번호 입력: "
    read -s password
    echo ""

    temp_file=$(mktemp)
    openssl enc -d -aes-256-cbc -pbkdf2 -in "$target_file" -out "$temp_file" -k "$password" 2>/dev/null

    if [ $? -ne 0 ]; then
        echo "❌ 비밀번호가 틀립니다."
        rm "$temp_file"
        return
    fi

    # 가이드 문구 삽입
    header_temp=$(mktemp)
    echo "# [가이드] 저장: Ctrl+O -> Enter / 종료: Ctrl+X (이 줄은 지우셔도 됩니다)" > "$header_temp"
    echo "" >> "$header_temp"
    cat "$temp_file" >> "$header_temp"
    mv "$header_temp" "$temp_file"

    echo "📝 편집기를 엽니다."
    sleep 1
    nano +99 "$temp_file"

    # 가이드 삭제
    sed -i '/^# \[가이드\]/d' "$temp_file"

    echo "--------------------------------"
    echo -n "🔒 저장할 새로운 암호 설정 (기존 암호 사용 가능): "
    read -s new_password
    echo ""

    openssl enc -aes-256-cbc -salt -pbkdf2 -in "$temp_file" -out "$target_file" -k "$new_password" 2>/dev/null

    if [ $? -eq 0 ]; then
        echo "✅ 수정 완료."
        echo "   (GitHub 업로드는 메인 메뉴의 '5. 백업'을 이용해주세요.)"
    else
        echo "❌ 암호화 저장 실패."
    fi
    rm "$temp_file"
}

# [기능: 일기 삭제]
delete_diary() {
    echo "🗑️  --- 일기 삭제 ---"
    if ls "$DIARY_DIR"/*.enc 1> /dev/null 2>&1; then
        echo "📋 [삭제 가능한 날짜 목록]"
        ls "$DIARY_DIR"/*.enc | xargs -n 1 basename | sed 's/.enc//g'
        echo "--------------------------------"
    else
        echo "❌ 삭제할 일기가 없습니다."
        return
    fi

    echo -n "삭제할 날짜(YYYY-MM-DD): "
    read target_date
    target_file="$DIARY_DIR/${target_date}.enc"

    if [ ! -f "$target_file" ]; then
        echo "❌ 파일이 없습니다."
        return
    fi
    
    echo -n "비밀번호 확인: "
    read -s password
    echo ""

    openssl enc -d -aes-256-cbc -pbkdf2 -in "$target_file" -k "$password" > /dev/null 2>&1

    if [ $? -eq 0 ]; then
        rm "$target_file"
        echo "🗑️  파일이 삭제되었습니다."
    else
        echo "❌ 비밀번호 불일치."
    fi
}

# ==========================================
# 3. 메인 실행 루프
# ==========================================
while true; do
    echo ""
    echo "=============================="
    echo "   🐧 BASH SECRET DIARY"
    echo "=============================="
    echo "0. ⚙️  GitHub 설정"
    echo "1. 작성 (Write)"
    echo "2. 조회 (Read)"
    echo "3. 수정 (Modify)"
    echo "4. 삭제 (Delete)"
    echo "5. 백업 (Push)"
    echo "6. 동기화 (Pull)"
    echo "8. 종료 (Exit)"
    echo -n "선택 >> "
    read choice

    case $choice in
        0) setup_github ;;
        1) write_diary ;;
        2) read_diary ;;
        3) modify_diary ;;
        4) delete_diary ;;
        5) perform_backup ;;
        6) synchronize_diary ;;
        8) echo "프로그램을 종료합니다."; break ;;
        *) echo "잘못된 입력입니다." ;;
    esac
done