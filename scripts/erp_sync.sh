#!/bin/bash
# ERP 데이터 자동 추출 및 홈페이지 업데이트

cd /home/san/.openclaw/workspace/erp-sync

# Python 스크립트 실행
python3 erp_scraper.py >> /tmp/erp-sync.log 2>&1

# 결과 확인
if [ $? -eq 0 ]; then
    echo "[$(date)] ✅ ERP 동기화 성공" >> /tmp/erp-sync.log
else
    echo "[$(date)] ❌ ERP 동기화 실패" >> /tmp/erp-sync.log
fi
