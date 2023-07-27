#!/bin/bash

compare_result() {
    local label=$1
    local expect=$2
    local result=$3

    if [ "$expect" = "$result" ]; then
        echo "$label: OK"
        return 0
    else
        echo "$label: ERR"
        diff <(echo $expect) <(echo $result)
        return 1
    fi
}

TEST_STATUS=0
TEST_DEVICE_ALIAS_01='TEST_DEVICE_ALIAS_01'
TEST_DEVICE_ALIAS_02='TEST_DEVICE_ALIAS_02'
TEST_PUBLIC_KEY_01='TEST_PUBLIC_KEY_01'
TEST_PUBLIC_KEY_02='TEST_PUBLIC_KEY_02'

# ===== 準備 =====
dfx stop
rm -rf .dfx
dfx start --clean --background

# テストで使用するユーザーを作成する
dfx identity new test-user --storage-mode=plaintext || true
dfx identity use test-user

# キャニスターのデプロイ
dfx deploy encrypted_notes_backend

# ===== テスト =====
FUNCTION='registerDevice'
echo "===== $FUNCTION ====="
EXPECT='(variant { Ok })'
RESULT=`dfx canister call encrypted_notes_backend $FUNCTION '('\"$TEST_DEVICE_ALIAS_01\"', '\"$TEST_PUBLIC_KEY_01\"')'`
compare_result "Return Ok" "$EXPECT" "$RESULT" || TEST_STATUS=1

EXPECT='(variant { Err = "Device alias is already registered" })'
RESULT=`dfx canister call encrypted_notes_backend $FUNCTION '('\"$TEST_DEVICE_ALIAS_01\"', '\"$TEST_PUBLIC_KEY_01\"')'`
compare_result "Error duplicate device alias" "$EXPECT" "$RESULT" || TEST_STATUS=1


FUNCTION='getDeviceAliases'
echo "===== $FUNCTION ====="
EXPECT='(vec { '\"$TEST_DEVICE_ALIAS_01\"' })'
RESULT=`dfx canister call encrypted_notes_backend $FUNCTION`
compare_result "Return device list" "$EXPECT" "$RESULT" || TEST_STATUS=1


FUNCTION='deleteDevice'
# 別のデバイスを登録する
UNUSED_RESULR=`dfx canister call encrypted_notes_backend registerDevice '('\"$TEST_DEVICE_ALIAS_02\"', '\"$TEST_PUBLIC_KEY_02\"')'`
echo "===== $FUNCTION ====="
EXPECT='()'
RESULT=`dfx canister call encrypted_notes_backend $FUNCTION '('\"$TEST_DEVICE_ALIAS_01\"')'`
compare_result "Return none" "$EXPECT" "$RESULT" || TEST_STATUS=1
# 確認
FUNCTION='getDeviceAliases'
EXPECT='(vec { '\"$TEST_DEVICE_ALIAS_02\"' })'
RESULT=`dfx canister call encrypted_notes_backend $FUNCTION`
compare_result "Check with $FUNCTION" "$EXPECT" "$RESULT" || TEST_STATUS=1

FUNCTION='addNote'
echo "===== $FUNCTION ====="
EXPECT='()'
RESULT=`dfx canister call encrypted_notes_backend $FUNCTION '("First text!")'`
compare_result "Return none" "$EXPECT" "$RESULT" || TEST_STATUS=1

FUNCTION='getNotes'
echo "===== $FUNCTION ====="
EXPECT='(vec { record { id = 0 : nat; encrypted_text = "First text!" } })'
RESULT=`dfx canister call encrypted_notes_backend $FUNCTION`
compare_result "Return note list" "$EXPECT" "$RESULT" || TEST_STATUS=1

FUNCTION='updateNote'
echo "===== $FUNCTION ====="
EXPECT='()'
RESULT=`dfx canister call encrypted_notes_backend $FUNCTION '(
  record {
    id = 0;
    encrypted_text = "Updated first text!"
  }
)'`
compare_result "Return none" "$EXPECT" "$RESULT" || TEST_STATUS=1
# 確認
FUNCTION='getNotes'
EXPECT='(vec { record { id = 0 : nat; encrypted_text = "Updated first text!" } })'
RESULT=`dfx canister call encrypted_notes_backend $FUNCTION`
compare_result "Check with $FUNCTION" "$EXPECT" "$RESULT" || TEST_STATUS=1

FUNCTION='deleteNote'
echo "===== $FUNCTION ====="
EXPECT='()'
RESULT=`dfx canister call encrypted_notes_backend $FUNCTION '(0)'`
compare_result "Return none" "$EXPECT" "$RESULT" || TEST_STATUS=1
# 確認
FUNCTION='getNotes'
EXPECT='(vec {})'
RESULT=`dfx canister call encrypted_notes_backend $FUNCTION`
compare_result "Check with $FUNCTION" "$EXPECT" "$RESULT" || TEST_STATUS=1

# ===== 後始末 =====
dfx identity use default
dfx identity remove test-user
dfx stop

# ===== テスト結果の確認 =====
echo '===== Result ====='
if [ $TEST_STATUS -eq 0 ]; then
  echo '"PASS"'
  exit 0
else
  echo '"FAIL"'
  exit 1
fi