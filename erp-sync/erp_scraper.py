#!/usr/bin/env python3
"""
ERP 웹 스크래핑 자동화 예시
- Playwright 사용
- 로그인 세션 저장
- 데이터 추출 → 홈페이지 전송
"""

import os
import json
import asyncio
from playwright.async_api import async_playwright

# 설정
ERP_URL = "https://erp.yourcompany.com"  # ERP 주소
ERP_USERNAME = os.getenv("ERP_USERNAME", "your_username")
ERP_PASSWORD = os.getenv("ERP_PASSWORD", "your_password")
WEBSITE_API = "https://your-website.com/api/erp-data"  # 홈페이지 API

async def scrape_erp():
    """ERP에서 데이터 추출"""
    async with async_playwright() as p:
        # 브라우저 실행 (headless=True는 백그라운드)
        browser = await p.chromium.launch(headless=True)
        
        # 세션 저장 경로 (재사용)
        context = await browser.new_context(
            storage_state="erp_auth.json" if os.path.exists("erp_auth.json") else None
        )
        
        page = await context.new_page()
        
        try:
            # 1. 로그인 (세션 없을 때만)
            if not os.path.exists("erp_auth.json"):
                print("🔐 ERP 로그인 중...")
                await page.goto(f"{ERP_URL}/login")
                await page.fill("input[name='username']", ERP_USERNAME)
                await page.fill("input[name='password']", ERP_PASSWORD)
                await page.click("button[type='submit']")
                await page.wait_for_load_state("networkidle")
                
                # 로그인 성공 시 세션 저장
                await context.storage_state(path="erp_auth.json")
                print("✅ 로그인 성공, 세션 저장됨")
            
            # 2. 데이터 페이지로 이동
            print("📊 데이터 추출 중...")
            await page.goto(f"{ERP_URL}/dashboard")
            await page.wait_for_selector(".data-section", timeout=10000)
            
            # 3. 필요한 데이터 추출 (선택자는 실제 ERP에 맞게 수정)
            data = {
                "timestamp": asyncio.get_event_loop().time(),
                "sales_today": await page.inner_text("#today-sales"),
                "orders_pending": await page.inner_text("#pending-orders"),
                "inventory_count": await page.inner_text("#inventory-total"),
                "top_products": await page.eval_on_selector_all(
                    ".top-product-item", 
                    "items => items.map(i => i.innerText)"
                )
            }
            
            print(f"✅ 데이터 추출 완료: {json.dumps(data, indent=2)}")
            
            # 4. 홈페이지 API로 전송
            # import aiohttp
            # async with aiohttp.ClientSession() as session:
            #     async with session.post(WEBSITE_API, json=data) as resp:
            #         print(f"🌐 홈페이지 응답: {resp.status}")
            
            # 임시: 파일로 저장
            with open("/tmp/erp_data.json", "w") as f:
                json.dump(data, f, indent=2)
            print("💾 데이터 저장 완료: /tmp/erp_data.json")
            
            return data
            
        except Exception as e:
            print(f"❌ 오류 발생: {e}")
            # 세션 만료 가능성 → 삭제 후 재시도
            if os.path.exists("erp_auth.json"):
                os.remove("erp_auth.json")
                print("🔄 세션 삭제됨, 다음 실행 시 재로그인")
            raise
            
        finally:
            await browser.close()

if __name__ == "__main__":
    asyncio.run(scrape_erp())
