#!/bin/bash

# ==========================================
# 1. 환경 설정 및 초기화
# ==========================================
DIARY_DIR="$HOME/.my_diary"

if [ ! -d "$DIARY_DIR" ]; then
    mkdir -p "$DIARY_DIR"
    cd "$DIARY_DIR"
    git init > /dev/null
    echo "📂 초기 설정 완료: $DIARY_DIR"
fi

# ==========================================
# 2. 기능 함수 정의
# ==========================================

# [백업 프로세스 함수]
perform_backup() {
    cd "$DIARY_DIR"
    
    git add .
    if ! git diff-index --quiet HEAD; then
        timestamp=$(date +'%Y-%m-%d %H:%M:%S')
        git commit -m "Manual Backup: $timestamp" > /dev/null
        echo "💾 [로컬 저장소] 변경 사항이 커밋(Commit)되었습니다."
    else
        echo "ℹ️  새로운 변경 사항이 없습니다."
    fi

    echo "☁️  [GitHub] 원격 저장소로 업로드를 시작합니다..."
    git push origin main 2>/dev/null
    
    if [ $? -eq 0 ]; then
        echo "✅ [성공] 업로드가 완료되었습니다!"
    else
        echo "⚠️  [실패] 업로드 실패. 주소나 권한, 인터넷 연결을 확인해주세요."
    fi
}

# [1. 일기 작성]
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

    # 저장 전 가이드 문구 자동 삭제
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
        rm "$temp_file"
    else
        echo "❌ 암호화 실패."
    fi
}

# [2. 일기 조회]
read_diary() {
    echo "📖 --- 일기 목록 ---"
    if ls "$DIARY_DIR"/*.enc 1> /dev/null 2>&1; then
        ls "$DIARY_DIR"/*.enc | xargs -n 1 basename | sed 's/.enc//g'
    else
        echo "📭 저장된 일기가 없습니다."
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
        # 혹시 남아있을 가이드 문구 안전하게 필터링하여 출력
        grep -v "^# \[가이드\]" "$temp_file"
        echo -e "\n============"
    else
        echo "❌ 비밀번호가 틀리거나 파일이 손상되었습니다."
    fi
    
    rm "$temp_file"
}

# [3. 일기 수정] - (✨ 핵심 수정됨)
modify_diary() {
    echo "✏️  --- 일기 수정 ---"
    if ls "$DIARY_DIR"/*.enc 1> /dev/null 2>&1; then
        echo "📋 [수정 가능한 날짜 목록]"
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

    # [✨ 핵심 로직] 복호화된 파일 맨 위에 가이드 문구 강제 삽입
    header_temp=$(mktemp)
    echo "# [가이드] 저장: Ctrl+O -> Enter / 종료: Ctrl+X (이 줄은 지우셔도 됩니다)" > "$header_temp"
    echo "" >> "$header_temp"
    # 가이드 + 기존 내용 합치기
    cat "$temp_file" >> "$header_temp"
    mv "$header_temp" "$temp_file"

    echo "📝 편집기를 엽니다. 수정 후 저장(Ctrl+O, Enter)하고 종료(Ctrl+X)하세요."
    sleep 1
    nano +99 "$temp_file"

    # [✨ 핵심 로직] 저장할 때는 가이드 문구 다시 삭제
    sed -i '/^# \[가이드\]/d' "$temp_file"

    echo "--------------------------------"
    echo -n "🔒 저장할 새로운 암호 설정 (기존 암호 사용 가능): "
    read -s new_password
    echo ""

    openssl enc -aes-256-cbc -salt -pbkdf2 -in "$temp_file" -out "$target_file" -k "$new_password" 2>/dev/null

    if [ $? -eq 0 ]; then
        echo "✅ 수정 내용이 암호화되어 저장되었습니다."
        echo "   (GitHub 업로드는 메인 메뉴의 '5. 백업'을 이용해주세요.)"
    else
        echo "❌ 암호화 저장 실패."
    fi
    rm "$temp_file"
}

# [4. 일기 삭제]
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
        echo "   (GitHub 반영은 메인 메뉴의 '5. 백업'을 이용해주세요.)"
    else
        echo "❌ 비밀번호 불일치."
    fi
}

# [5. 수동 백업 및 연결 설정]
manual_backup() {
    cd "$DIARY_DIR"
    echo "📦 --- 수동 백업 및 연결 설정 ---"

    current_url=$(git remote get-url origin 2>/dev/null)

    if [ -n "$current_url" ]; then
        echo "🔗 현재 연결된 주소: $current_url"
        echo -n "이 주소로 업로드 하시겠습니까? (y/n): "
        read answer

        if [ "$answer" == "y" ] || [ "$answer" == "Y" ]; then
            perform_backup
        else
            echo "------------------------------"
            echo "1. 백업 취소 (메인으로 돌아가기)"
            echo "2. 새로운 주소 입력하기"
            echo -n "선택 >> "
            read sub_choice

            if [ "$sub_choice" == "2" ]; then
                echo -n "새로운 GitHub 주소를 입력하세요: "
                read new_url
                git remote remove origin 2>/dev/null
                git remote add origin "$new_url"
                git branch -M main
                echo "✅ 주소가 변경되었습니다."
                manual_backup 
            else
                echo "백업을 취소하고 메인 메뉴로 돌아갑니다."
                return
            fi
        fi
    else
        echo "⚠️  현재 연결된 원격 저장소가 없습니다."
        echo -n "연결할 GitHub 주소를 입력하세요: "
        read new_url

        if [ -n "$new_url" ]; then
            git remote add origin "$new_url"
            git branch -M main
            echo "✅ 연결되었습니다."
            manual_backup
        else
            echo "주소가 입력되지 않아 취소합니다."
        fi
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
    echo "1. 작성 (Write)"
    echo "2. 조회 (Read)"
    echo "3. 수정 (Modify)"
    echo "4. 삭제 (Delete)"
    echo "5. 백업 및 업로드 (Backup)"
    echo "6. 종료 (Exit)"
    echo -n "선택 >> "
    read choice

    case $choice in
        1) write_diary ;;
        2) read_diary ;;
        3) modify_diary ;;
        4) delete_diary ;;
        5) manual_backup ;;
        6) echo "프로그램을 종료합니다."; break ;;
        *) echo "잘못된 입력입니다." ;;
    esac
done