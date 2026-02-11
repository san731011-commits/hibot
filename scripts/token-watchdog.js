#!/usr/bin/env node
/**
 * Token Rate Limit Watchdog
 * 모니터링 및 TPM 900K 임계점에서 자동 차단
 */

const fs = require('fs');
const path = require('path');

const CONFIG = {
  // TPM 한도 설정 (Gemini 3 Flash: 1M, 안전마진 10% 적용)
  TPM_LIMIT: 1000000,
  TPM_THRESHOLD: 900000,  // 90%에서 경고, 쿨다운 시작
  
  // 쿨다운 설정
  COOLDOWN_SECONDS: 30,
  
  // 상태 파일
  STATE_FILE: path.join(process.env.HOME || '/tmp', '.openclaw', 'token-watchdog.json'),
  
  // 로그 파일
  LOG_FILE: path.join(process.env.HOME || '/tmp', '.openclaw', 'logs', 'watchdog.log')
};

class TokenWatchdog {
  constructor() {
    this.state = this.loadState();
    this.ensureLogDir();
  }

  ensureLogDir() {
    const logDir = path.dirname(CONFIG.LOG_FILE);
    if (!fs.existsSync(logDir)) {
      fs.mkdirSync(logDir, { recursive: true });
    }
  }

  loadState() {
    try {
      if (fs.existsSync(CONFIG.STATE_FILE)) {
        return JSON.parse(fs.readFileSync(CONFIG.STATE_FILE, 'utf8'));
      }
    } catch (e) {
      this.log('State load error:', e.message);
    }
    return {
      lastCheck: 0,
      currentTPM: 0,
      cooldownUntil: 0,
      totalBlocked: 0,
      history: []
    };
  }

  saveState() {
    try {
      const stateDir = path.dirname(CONFIG.STATE_FILE);
      if (!fs.existsSync(stateDir)) {
        fs.mkdirSync(stateDir, { recursive: true });
      }
      fs.writeFileSync(CONFIG.STATE_FILE, JSON.stringify(this.state, null, 2));
    } catch (e) {
      this.log('State save error:', e.message);
    }
  }

  log(...args) {
    const timestamp = new Date().toISOString();
    const line = `[${timestamp}] ${args.join(' ')}\n`;
    console.log(line.trim());
    try {
      fs.appendFileSync(CONFIG.LOG_FILE, line);
    } catch (e) {
      // Silent fail for logging
    }
  }

  // session_status 결과 파싱 (JSON 형식)
  async checkTokenUsage() {
    // OpenClaw 세션 상태 확인 (CLI 호출)
    const { execSync } = require('child_process');
    
    try {
      // session_status API 호출 대신 gateway config에서 모델 정보 확인
      const output = execSync('openclaw gateway config.get 2>/dev/null || echo "{}"', { 
        encoding: 'utf8',
        timeout: 5000 
      });
      
      // 현재는 토큰 사용량을 외부에서 직접 측정하기 어려우므로,
      // 간접적으로 세션 활동을 모니터링
      return this.estimateTokenUsage();
    } catch (e) {
      this.log('Token check error:', e.message);
      return { current: 0, allowed: true };
    }
  }

  // 세션 활동 기반 토큰 사용량 추정
  estimateTokenUsage() {
    const now = Date.now();
    const oneMinuteAgo = now - 60000;
    
    // 최근 1분 이내 요청 카운트 기반 추정
    const recentRequests = (this.state.history || []).filter(h => h.time > oneMinuteAgo);
    
    // 요청당 평균 4K 토큰 가정 (입력+출력)
    const estimatedTPM = recentRequests.reduce((sum, h) => sum + (h.tokens || 4000), 0);
    
    return {
      current: estimatedTPM,
      allowed: estimatedTPM < CONFIG.TPM_THRESHOLD && now > this.state.cooldownUntil
    };
  }

  // 요청 전 체크 (호출될 때마다)
  checkBeforeRequest() {
    const now = Date.now();
    
    // 쿨다운 중이면 차단
    if (now < this.state.cooldownUntil) {
      const remaining = Math.ceil((this.state.cooldownUntil - now) / 1000);
      return { 
        allowed: false, 
        reason: `COOLDOWN_ACTIVE`,
        remainingSeconds: remaining,
        message: `⏳ 토큰 사용량 한도에 도달했습니다. ${remaining}초 후에 다시 시도해주세요.`
      };
    }

    // 토큰 사용량 체크
    const usage = this.estimateTokenUsage();
    
    if (usage.current >= CONFIG.TPM_THRESHOLD) {
      // 쿨다운 시작
      this.state.cooldownUntil = now + (CONFIG.COOLDOWN_SECONDS * 1000);
      this.state.totalBlocked++;
      this.saveState();
      
      this.log(`⚠️ TPM THRESHOLD REACHED: ${usage.current}/${CONFIG.TPM_THRESHOLD}. Cooldown started.`);
      
      return {
        allowed: false,
        reason: `THRESHOLD_EXCEEDED`,
        currentTPM: usage.current,
        cooldownSeconds: CONFIG.COOLDOWN_SECONDS,
        message: `⚠️ 토큰 사용량이 ${CONFIG.TPM_THRESHOLD.toLocaleString()}에 근접했습니다 (${usage.current.toLocaleString()}). ${CONFIG.COOLDOWN_SECONDS}초 쿨다운을 시작합니다.`
      };
    }

    return { allowed: true, currentTPM: usage.current };
  }

  // 요청 후 기록
  recordRequest(tokens = 4000) {
    const now = Date.now();
    this.state.history = (this.state.history || []).filter(h => h.time > now - 60000);
    this.state.history.push({ time: now, tokens });
    this.state.lastCheck = now;
    this.saveState();
  }

  // 상태 보고
  getStatus() {
    const usage = this.estimateTokenUsage();
    const now = Date.now();
    const inCooldown = now < this.state.cooldownUntil;
    
    return {
      currentTPM: usage.current,
      threshold: CONFIG.TPM_THRESHOLD,
      limit: CONFIG.TPM_LIMIT,
      utilization: (usage.current / CONFIG.TPM_LIMIT * 100).toFixed(1) + '%',
      inCooldown,
      cooldownRemaining: inCooldown ? Math.ceil((this.state.cooldownUntil - now) / 1000) : 0,
      totalBlocked: this.state.totalBlocked || 0,
      recentRequests: this.state.history?.length || 0
    };
  }
}

// CLI 모드
if (require.main === module) {
  const watchdog = new TokenWatchdog();
  const command = process.argv[2];

  switch (command) {
    case 'check':
      const result = watchdog.checkBeforeRequest();
      console.log(JSON.stringify(result, null, 2));
      process.exit(result.allowed ? 0 : 1);
      break;
    
    case 'record':
      const tokens = parseInt(process.argv[3]) || 4000;
      watchdog.recordRequest(tokens);
      console.log(JSON.stringify({ recorded: true, tokens }, null, 2));
      break;
    
    case 'status':
      console.log(JSON.stringify(watchdog.getStatus(), null, 2));
      break;
    
    default:
      console.log(`
Token Rate Limit Watchdog

Usage:
  node token-watchdog.js check     # 요청 전 체크 (exit code 1 if blocked)
  node token-watchdog.js record    # 요청 기록 (기본 4000 토큰)
  node token-watchdog.js status    # 현재 상태 확인

Config:
  TPM Threshold: ${CONFIG.TPM_THRESHOLD.toLocaleString()}
  TPM Limit: ${CONFIG.TPM_LIMIT.toLocaleString()}
  Cooldown: ${CONFIG.COOLDOWN_SECONDS}s
      `);
  }
}

module.exports = { TokenWatchdog, CONFIG };
