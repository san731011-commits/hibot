#!/usr/bin/env python3
"""
회사 밴드 활동 대시보드 - 다중 기간 지원 버전
- 주간/월간/연간 통계
- 참여 인원 추이
"""

import json
from datetime import datetime, timedelta
from collections import defaultdict
import calendar

class BandDashboardPro:
    def __init__(self):
        self.posts = []
        self.members = {}
        
    def calculate_stats(self, days=30):
        """지정 기간 통계 계산"""
        since = datetime.now() - timedelta(days=days)
        period_posts = [p for p in self.posts if datetime.fromtimestamp(p.get('created_at', 0)) >= since]
        
        # 멤버별 집계
        member_stats = defaultdict(lambda: {'posts': 0, 'comments': 0, 'likes': 0, 'score': 0, 'first_post': None, 'last_post': None})
        
        for post in period_posts:
            author = post.get('author', 'Unknown')
            post_date = datetime.fromtimestamp(post.get('created_at', 0))
            
            member_stats[author]['posts'] += 1
            member_stats[author]['likes'] += post.get('like_count', 0)
            member_stats[author]['comments'] += post.get('comment_count', 0)
            
            # 첫/마지막 활동 기록
            if member_stats[author]['first_post'] is None or post_date < member_stats[author]['first_post']:
                member_stats[author]['first_post'] = post_date
            if member_stats[author]['last_post'] is None or post_date > member_stats[author]['last_post']:
                member_stats[author]['last_post'] = post_date
        
        # 점수 계산 (게시글 10점, 댓글 3점, 좋아요 1점)
        for member in member_stats:
            m = member_stats[member]
            m['score'] = m['posts'] * 10 + m['comments'] * 3 + m['likes'] * 1
        
        # 전체 통계
        total_stats = {
            'posts': len(period_posts),
            'likes': sum(p.get('like_count', 0) for p in period_posts),
            'comments': sum(p.get('comment_count', 0) for p in period_posts),
            'active_members': len(member_stats),
            'avg_posts_per_member': len(period_posts) / len(member_stats) if member_stats else 0
        }
        
        return {
            'period': f'{days}일',
            'total': total_stats,
            'ranking': sorted(member_stats.items(), key=lambda x: x[1]['score'], reverse=True)[:20]
        }
    
    def get_monthly_trend(self, months=12):
        """월별 활동 추이"""
        now = datetime.now()
        monthly_data = []
        
        for i in range(months):
            month_date = now - timedelta(days=30*i)
            month_start = month_date.replace(day=1, hour=0, minute=0, second=0)
            month_end = (month_start + timedelta(days=32)).replace(day=1) - timedelta(seconds=1)
            
            month_posts = [
                p for p in self.posts 
                if month_start <= datetime.fromtimestamp(p.get('created_at', 0)) <= month_end
            ]
            
            unique_authors = set(p.get('author') for p in month_posts)
            
            monthly_data.append({
                'month': month_start.strftime('%Y-%m'),
                'posts': len(month_posts),
                'active_members': len(unique_authors),
                'likes': sum(p.get('like_count', 0) for p in month_posts)
            })
        
        return list(reversed(monthly_data))
    
    def generate_full_report(self):
        """전체 리포트 HTML 생성"""
        
        # 각 기간별 통계
        weekly = self.calculate_stats(7)
        monthly = self.calculate_stats(30)
        yearly = self.calculate_stats(365)
        
        # 월별 추이
        monthly_trend = self.get_monthly_trend(12)
        
        html = f"""
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>회사 밴드 활동 종합 대시보드</title>
    <style>
        body {{ font-family: 'Malgun Gothic', 'Noto Sans KR', sans-serif; margin: 0; background: #f0f2f5; }}
        .container {{ max-width: 1400px; margin: 0 auto; padding: 20px; }}
        
        /* 헤더 */
        .header {{ 
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); 
            color: white; padding: 40px; border-radius: 15px; 
            margin-bottom: 30px; text-align: center;
        }}
        .header h1 {{ margin: 0; font-size: 2.8em; }}
        .header p {{ margin: 10px 0 0 0; opacity: 0.9; font-size: 1.2em; }}
        
        /* 기간별 탭 */
        .tabs {{ display: flex; gap: 10px; margin-bottom: 30px; justify-content: center; }}
        .tab {{ 
            padding: 15px 30px; background: white; border: none; border-radius: 10px;
            cursor: pointer; font-size: 1.1em; font-weight: bold;
            box-shadow: 0 2px 5px rgba(0,0,0,0.1); transition: all 0.3s;
        }}
        .tab:hover {{ transform: translateY(-2px); box-shadow: 0 4px 10px rgba(0,0,0,0.15); }}
        .tab.active {{ background: #667eea; color: white; }}
        
        /* 통계 카드 */
        .stats-grid {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 20px; margin-bottom: 30px; }}
        .stat-card {{ 
            background: white; padding: 30px; border-radius: 15px; 
            box-shadow: 0 4px 15px rgba(0,0,0,0.08); text-align: center;
            transition: transform 0.3s;
        }}
        .stat-card:hover {{ transform: translateY(-5px); }}
        .stat-icon {{ font-size: 3em; margin-bottom: 10px; }}
        .stat-number {{ font-size: 2.5em; font-weight: bold; color: #667eea; margin: 10px 0; }}
        .stat-label {{ color: #666; font-size: 1.1em; }}
        .stat-change {{ 
            display: inline-block; padding: 5px 10px; border-radius: 20px;
            font-size: 0.9em; margin-top: 10px;
        }}
        .positive {{ background: #d4edda; color: #155724; }}
        .negative {{ background: #f8d7da; color: #721c24; }}
        
        /* 섹션 */
        .section {{ 
            background: white; padding: 30px; border-radius: 15px; 
            margin-bottom: 30px; box-shadow: 0 4px 15px rgba(0,0,0,0.08);
        }}
        .section h2 {{ margin-top: 0; color: #333; border-bottom: 3px solid #667eea; padding-bottom: 15px; }}
        
        /* 랭킹 테이블 */
        table {{ width: 100%; border-collapse: collapse; margin-top: 20px; }}
        th, td {{ padding: 15px; text-align: left; border-bottom: 1px solid #eee; }}
        th {{ background: #f8f9fa; font-weight: bold; color: #555; font-size: 0.95em; }}
        tr:hover {{ background: #f8f9fa; }}
        .rank {{ font-size: 1.5em; font-weight: bold; }}
        .medal {{ font-size: 1.5em; }}
        .member-name {{ font-weight: bold; color: #333; }}
        .activity-bar {{ 
            background: #e9ecef; height: 20px; border-radius: 10px; 
            overflow: hidden; display: inline-block; width: 100px;
        }}
        .activity-fill {{ 
            background: linear-gradient(90deg, #667eea, #764ba2); 
            height: 100%; border-radius: 10px;
        }}
        
        /* 그래프 */
        .chart {{ 
            height: 300px; background: #f8f9fa; border-radius: 10px;
            display: flex; align-items: end; justify-content: space-around;
            padding: 20px; gap: 10px;
        }}
        .chart-bar {{ 
            flex: 1; background: linear-gradient(180deg, #667eea, #764ba2);
            border-radius: 5px 5px 0 0; min-height: 10px;
            position: relative; transition: all 0.3s;
        }}
        .chart-bar:hover {{ opacity: 0.8; }}
        .chart-label {{ 
            position: absolute; bottom: -25px; left: 50%; transform: translateX(-50%);
            font-size: 0.8em; white-space: nowrap;
        }}
        .chart-value {{ 
            position: absolute; top: -25px; left: 50%; transform: translateX(-50%);
            font-weight: bold; color: #667eea;
        }}
        
        /* 푸터 */
        .footer {{ text-align: center; color: #999; padding: 30px; }}
        
        /* 탭 컨텐츠 */
        .tab-content {{ display: none; }}
        .tab-content.active {{ display: block; }}
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>📊 회사 밴드 활동 종합 대시보드</h1>
            <p>우리 팀의 소통 활력을 데이터로 확인하세요!</p>
        </div>
        
        <!-- 기간 선택 탭 -->
        <div class="tabs">
            <button class="tab active" onclick="showTab('weekly')">📅 주간 (7일)</button>
            <button class="tab" onclick="showTab('monthly')">📆 월간 (30일)</button>
            <button class="tab" onclick="showTab('yearly')">📊 연간 (365일)</button>
        </div>
        
        <!-- 주간 통계 -->
        <div id="weekly" class="tab-content active">
            {self._generate_period_section(weekly, '주간')}
        </div>
        
        <!-- 월간 통계 -->
        <div id="monthly" class="tab-content">
            {self._generate_period_section(monthly, '월간')}
        </div>
        
        <!-- 연간 통계 -->
        <div id="yearly" class="tab-content">
            {self._generate_period_section(yearly, '연간')}
            
            <!-- 월별 추이 그래프 -->
            <div class="section">
                <h2>📈 월별 활동 추이 (최근 12개월)</h2>
                <div class="chart">
                    {self._generate_monthly_chart(monthly_trend)}
                </div>
                <div style="margin-top: 40px;">
                    <table>
                        <thead>
                            <tr>
                                <th>월</th>
                                <th>게시글</th>
                                <th>활동 멤버</th>
                                <th>좋아요</th>
                                <th>참여율</th>
                            </tr>
                        </thead>
                        <tbody>
                            {self._generate_monthly_table(monthly_trend)}
                        </tbody>
                    </table>
                </div>
            </div>
        </div>
        
        <div class="footer">
            <p>📅 마지막 업데이트: {datetime.now().strftime('%Y년 %m월 %d일 %H:%M')}</p>
            <p>자동 갱신: 매일 09:00 | 데이터 출처: 회사 네이버 밴드</p>
        </div>
    </div>
    
    <script>
        function showTab(tabName) {{
            // 모든 탭 비활성화
            document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
            document.querySelectorAll('.tab-content').forEach(c => c.classList.remove('active'));
            
            // 선택한 탭 활성화
            event.target.classList.add('active');
            document.getElementById(tabName).classList.add('active');
        }}
    </script>
</body>
</html>
        """
        return html
    
    def _generate_period_section(self, stats, period_name):
        """기간별 섹션 HTML 생성"""
        ranking = stats['ranking']
        total = stats['total']
        
        return f"""
        <div class="stats-grid">
            <div class="stat-card">
                <div class="stat-icon">📝</div>
                <div class="stat-number">{total['posts']:,}</div>
                <div class="stat-label">총 게시글</div>
            </div>
            <div class="stat-card">
                <div class="stat-icon">💬</div>
                <div class="stat-number">{total['comments']:,}</div>
                <div class="stat-label">총 댓글</div>
            </div>
            <div class="stat-card">
                <div class="stat-icon">❤️</div>
                <div class="stat-number">{total['likes']:,}</div>
                <div class="stat-label">총 좋아요</div>
            </div>
            <div class="stat-card">
                <div class="stat-icon">👥</div>
                <div class="stat-number">{total['active_members']}</div>
                <div class="stat-label">활동 멤버</div>
                <div class="stat-change positive">평균 {total['avg_posts_per_member']:.1f}개/인</div>
            </div>
        </div>
        
        <div class="section">
            <h2>🏆 {period_name} 활동왕 TOP 20</h2>
            <table>
                <thead>
                    <tr>
                        <th style="width: 80px;">순위</th>
                        <th>직원</th>
                        <th style="width: 120px;">게시글</th>
                        <th style="width: 120px;">댓글</th>
                        <th style="width: 120px;">좋아요</th>
                        <th style="width: 150px;">활동 점수</th>
                        <th style="width: 200px;">활동 그래프</th>
                    </tr>
                </thead>
                <tbody>
                    {self._generate_ranking_rows(ranking, total['posts'])}
                </tbody>
            </table>
        </div>
        """
    
    def _generate_ranking_rows(self, ranking, total_posts):
        """랭킹 테이블 행 생성"""
        medals = ['🥇', '🥈', '🥉'] + [f'{i}위' for i in range(4, 21)]
        max_score = ranking[0][1]['score'] if ranking else 1
        
        rows = []
        for i, (name, data) in enumerate(ranking):
            bar_width = (data['score'] / max_score * 100) if max_score > 0 else 0
            rows.append(f"""
                <tr>
                    <td><span class="medal">{medals[i]}</span></td>
                    <td><span class="member-name">{name}</span></td>
                    <td>{data['posts']}</td>
                    <td>{data['comments']}</td>
                    <td>{data['likes']}</td>
                    <td><strong style="color: #667eea;">{data['score']:,}</strong></td>
                    <td>
                        <div class="activity-bar">
                            <div class="activity-fill" style="width: {bar_width:.0f}%;"></div>
                        </div>
                    </td>
                </tr>
            """)
        
        return ''.join(rows) if rows else '<tr><td colspan="7" style="text-align:center; padding: 50px;">아직 데이터가 없습니다 📝</td></tr>'
    
    def _generate_monthly_chart(self, monthly_data):
        """월별 그래프 HTML 생성"""
        max_posts = max(m['posts'] for m in monthly_data) if monthly_data else 1
        
        bars = []
        for data in monthly_data:
            height = (data['posts'] / max_posts * 100) if max_posts > 0 else 0
            month_short = data['month'].split('-')[1] + '월'
            bars.append(f"""
                <div class="chart-bar" style="height: {max(height, 5):.0f}%;">
                    <span class="chart-value">{data['posts']}</span>
                    <span class="chart-label">{month_short}</span>
                </div>
            """)
        
        return ''.join(bars)
    
    def _generate_monthly_table(self, monthly_data):
        """월별 테이블 HTML 생성"""
        rows = []
        for data in monthly_data:
            participation = (data['active_members'] / 30 * 100) if data['active_members'] else 0  # 가정: 총 30명
            rows.append(f"""
                <tr>
                    <td><strong>{data['month']}</strong></td>
                    <td>{data['posts']}</td>
                    <td>{data['active_members']}명</td>
                    <td>{data['likes']}</td>
                    <td>
                        <div class="activity-bar">
                            <div class="activity-fill" style="width: {participation:.0f}%;"></div>
                        </div>
                        {participation:.0f}%
                    </td>
                </tr>
            """)
        return ''.join(rows)

if __name__ == "__main__":
    dashboard = BandDashboardPro()
    
    # 테스트용 더미 데이터 (1년치)
    import random
    names = ['김팀장', '박대리', '이사원', '최과장', '정팀장', '송대리', '강사원', '윤과장']
    base_time = datetime.now() - timedelta(days=365)
    
    for i in range(500):  # 1년치 500개 게시글
        post_date = base_time + timedelta(days=random.randint(0, 365))
        dashboard.posts.append({
            'author': random.choice(names),
            'created_at': post_date.timestamp(),
            'like_count': random.randint(0, 30),
            'comment_count': random.randint(0, 15)
        })
    
    # 리포트 생성
    html_content = dashboard.generate_full_report()
    
    with open('/tmp/band_dashboard_pro.html', 'w', encoding='utf-8') as f:
        f.write(html_content)
    
    print("✅ 종합 대시보드 생성 완료: /tmp/band_dashboard_pro.html")
    print(f"📊 테스트 데이터: 500개 게시글, {len(names)}명 멤버")
