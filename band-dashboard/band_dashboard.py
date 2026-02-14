#!/usr/bin/env python3
"""
회사 밴드 활동 대시보드 - 간단 버전
- 게시글 수집
- 참여자 랭킹 산출
- HTML 리포트 생성
"""

import json
from datetime import datetime, timedelta
from collections import defaultdict

# band-api를 사용한 버전 (실제 구현 시)
# from band_api import BandAPI

class BandDashboard:
    def __init__(self):
        self.posts = []
        self.members = defaultdict(lambda: {
            'posts': 0,
            'comments': 0,
            'likes': 0,
            'score': 0
        })
    
    def fetch_posts(self):
        """밴드에서 게시글 가져오기"""
        # TODO: band-api 연동
        # 실제로는 여기서 API 호출
        pass
    
    def calculate_ranking(self, days=7):
        """주간 랭킹 계산"""
        since = datetime.now() - timedelta(days=days)
        
        for post in self.posts:
            post_date = datetime.fromtimestamp(post.get('created_at', 0))
            if post_date >= since:
                author = post.get('author', 'Unknown')
                self.members[author]['posts'] += 1
                self.members[author]['likes'] += post.get('like_count', 0)
                self.members[author]['comments'] += post.get('comment_count', 0)
        
        # 점수 계산 (게시글 10점, 댓글 3점, 좋아요 1점)
        for member in self.members:
            m = self.members[member]
            m['score'] = m['posts'] * 10 + m['comments'] * 3 + m['likes'] * 1
        
        # 정렬
        ranking = sorted(
            self.members.items(),
            key=lambda x: x[1]['score'],
            reverse=True
        )
        return ranking[:10]  # TOP 10
    
    def generate_report(self):
        """HTML 리포트 생성"""
        ranking = self.calculate_ranking()
        
        html = f"""
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>회사 밴드 활동 대시보드</title>
    <style>
        body {{ font-family: 'Malgun Gothic', sans-serif; margin: 40px; background: #f5f5f5; }}
        .container {{ max-width: 1200px; margin: 0 auto; }}
        .header {{ background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); 
                   color: white; padding: 30px; border-radius: 10px; margin-bottom: 30px; }}
        .header h1 {{ margin: 0; font-size: 2.5em; }}
        .stats {{ display: grid; grid-template-columns: repeat(4, 1fr); gap: 20px; margin-bottom: 30px; }}
        .stat-box {{ background: white; padding: 25px; border-radius: 10px; text-align: center;
                     box-shadow: 0 2px 10px rgba(0,0,0,0.1); }}
        .stat-number {{ font-size: 3em; font-weight: bold; color: #667eea; }}
        .stat-label {{ color: #666; margin-top: 10px; }}
        .ranking {{ background: white; padding: 30px; border-radius: 10px; 
                    box-shadow: 0 2px 10px rgba(0,0,0,0.1); }}
        .ranking h2 {{ margin-top: 0; color: #333; }}
        table {{ width: 100%; border-collapse: collapse; }}
        th, td {{ padding: 15px; text-align: left; border-bottom: 1px solid #eee; }}
        th {{ background: #f8f9fa; font-weight: bold; color: #555; }}
        .rank {{ font-size: 1.5em; font-weight: bold; color: #667eea; }}
        .medal {{ font-size: 1.5em; }}
        .update-time {{ text-align: center; color: #999; margin-top: 30px; }}
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>📊 회사 밴드 활동 대시보드</h1>
            <p>우리 팀의 소통 활력을 확인하세요!</p>
        </div>
        
        <div class="stats">
            <div class="stat-box">
                <div class="stat-number" id="new-posts">0</div>
                <div class="stat-label">이번 주 새 글</div>
            </div>
            <div class="stat-box">
                <div class="stat-number" id="comments">0</div>
                <div class="stat-label">댓글</div>
            </div>
            <div class="stat-box">
                <div class="stat-number" id="likes">0</div>
                <div class="stat-label">좋아요</div>
            </div>
            <div class="stat-box">
                <div class="stat-number" id="active-members">0</div>
                <div class="stat-label">참여 직원</div>
            </div>
        </div>
        
        <div class="ranking">
            <h2>🏆 이번 주 활동왕 TOP 10</h2>
            <table>
                <thead>
                    <tr>
                        <th>순위</th>
                        <th>직원</th>
                        <th>게시글</th>
                        <th>댓글</th>
                        <th>좋아요</th>
                        <th>총점</th>
                    </tr>
                </thead>
                <tbody>
                    {self._generate_ranking_rows(ranking)}
                </tbody>
            </table>
        </div>
        
        <div class="update-time">
            마지막 업데이트: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
        </div>
    </div>
    
    <script>
        // 실시간 업데이트용 (나중에 API 연동)
        function updateStats() {{
            // TODO: API에서 실제 데이터 가져오기
        }}
        setInterval(updateStats, 300000); // 5분마다 갱신
    </script>
</body>
</html>
        """
        return html
    
    def _generate_ranking_rows(self, ranking):
        """랭킹 테이블 HTML 생성"""
        medals = ['🥇', '🥈', '🥉', '4️⃣', '5️⃣', '6️⃣', '7️⃣', '8️⃣', '9️⃣', '🔟']
        rows = []
        
        for i, (name, data) in enumerate(ranking):
            medal = medals[i] if i < 10 else f"{i+1}위"
            rows.append(f"""
                <tr>
                    <td><span class="medal">{medal}</span></td>
                    <td><strong>{name}</strong></td>
                    <td>{data['posts']}</td>
                    <td>{data['comments']}</td>
                    <td>{data['likes']}</td>
                    <td><strong>{data['score']}</strong></td>
                </tr>
            """)
        
        return ''.join(rows) if rows else '<tr><td colspan="6" style="text-align:center;">아직 데이터가 없습니다</td></tr>'

if __name__ == "__main__":
    dashboard = BandDashboard()
    
    # 테스트용 더미 데이터
    dashboard.posts = [
        {'author': '김팀장', 'created_at': datetime.now().timestamp(), 'like_count': 15, 'comment_count': 5},
        {'author': '박대리', 'created_at': datetime.now().timestamp(), 'like_count': 8, 'comment_count': 3},
        {'author': '김팀장', 'created_at': datetime.now().timestamp(), 'like_count': 12, 'comment_count': 4},
        {'author': '이사원', 'created_at': datetime.now().timestamp(), 'like_count': 6, 'comment_count': 2},
    ]
    
    # 리포트 생성
    html_content = dashboard.generate_report()
    
    with open('/tmp/band_dashboard.html', 'w', encoding='utf-8') as f:
        f.write(html_content)
    
    print("✅ 대시보드 생성 완료: /tmp/band_dashboard.html")
