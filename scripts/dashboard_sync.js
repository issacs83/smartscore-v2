#!/usr/bin/env node
/**
 * SmartScore v2 — Dashboard Auto-Sync
 *
 * Project Director가 호출하여 대시보드에 에이전트/태스크 상태를 자동 등록.
 * Usage: node dashboard_sync.js [dashboard_url]
 */

const WebSocket = require('ws');
const DASHBOARD_URL = process.argv[2] || 'ws://localhost:7700';

const PROJECT = {
  name: 'SmartScore v2',
  description: '카메라 악보 → 피아노 반주 악보 → 자동 페이지 전환',
};

const PHASES = [
  { id: 0, name: 'OMR + Rendering', status: 'completed' },
  { id: 1, name: 'OMR Accuracy', status: 'completed' },
  { id: 2, name: 'Audio Recognition', status: 'in_progress' },
  { id: 3, name: 'Auto Page Turn', status: 'pending' },
  { id: 4, name: 'Cross-Platform', status: 'pending' },
];

const AGENTS = [
  // Phase 1-2 (완료)
  { agent: 'architect', phase: 0, status: 'completed', task: 'System architecture + Phase 3-5 design' },
  { agent: 'web-developer', phase: 0, status: 'completed', task: 'FastAPI server + Flutter modules G/H' },
  { agent: 'algorithm-researcher', phase: 1, status: 'completed', task: 'OMR engines comparison + CENS/OTW research' },
  { agent: 'ai-trainer', phase: 1, status: 'completed', task: 'Zeus fine-tuning (SER 108→67%)' },
  { agent: 'code-reviewer', phase: 0, status: 'completed', task: 'Architecture + code quality review' },
  { agent: 'security-reviewer', phase: 0, status: 'completed', task: 'CORS, upload limits, SSRF audit' },
  { agent: 'doc-manager', phase: 0, status: 'completed', task: 'Development report (VOC+SRS+SDS)' },
  { agent: 'product-strategist', phase: 0, status: 'completed', task: 'Piano accompaniment auto-turn concept' },

  // Phase 3 (진행중)
  { agent: 'web-developer', phase: 2, status: 'running', task: 'Audio capture + Score following integration' },

  // Phase 4-5 (대기)
  { agent: 'ux-designer', phase: 3, status: 'idle', task: 'Performance Screen UX polish' },
  { agent: 'cuda-engineer', phase: 4, status: 'idle', task: 'onnxruntime-gpu + TensorRT optimization' },
  { agent: 'e2e-tester', phase: 2, status: 'idle', task: 'Audio following E2E tests' },
  { agent: 'inference-optimizer', phase: 4, status: 'idle', task: 'OMR pipeline TensorRT acceleration' },
];

const TASKS = [
  // Phase 3 tasks
  { title: 'Timing Map Generator', phase: 2, status: 'done', agent: 'web-developer' },
  { title: 'Reference Feature Generator', phase: 2, status: 'done', agent: 'web-developer' },
  { title: 'JS Audio Bridge', phase: 2, status: 'done', agent: 'web-developer' },
  { title: 'Dart Audio Capture', phase: 2, status: 'done', agent: 'web-developer' },
  { title: 'CENS Chroma Extractor', phase: 2, status: 'done', agent: 'algorithm-researcher' },
  { title: 'OTW Score Follower', phase: 2, status: 'done', agent: 'algorithm-researcher' },
  { title: 'Follow Controller', phase: 2, status: 'done', agent: 'web-developer' },
  { title: 'Visual Cursor + Highlight', phase: 2, status: 'done', agent: 'web-developer' },
  { title: 'Performance Screen UI', phase: 2, status: 'done', agent: 'web-developer' },
  // Phase 4 tasks
  { title: 'Page Turn Engine', phase: 3, status: 'todo', agent: 'web-developer' },
  { title: 'Page Turn Animation', phase: 3, status: 'todo', agent: 'web-developer' },
  { title: 'BLE Pedal Integration', phase: 3, status: 'todo', agent: 'web-developer' },
  { title: 'Repeat Mark Handling', phase: 3, status: 'todo', agent: 'algorithm-researcher' },
  // Phase 5 tasks
  { title: 'Remove dart:html', phase: 4, status: 'todo', agent: 'web-developer' },
  { title: 'Native Audio Capture', phase: 4, status: 'todo', agent: 'web-developer' },
  { title: 'Production Security', phase: 4, status: 'todo', agent: 'security-reviewer' },
];

async function sync() {
  const ws = new WebSocket(DASHBOARD_URL);

  ws.on('open', () => {
    console.log(`[Dashboard Sync] Connected to ${DASHBOARD_URL}`);

    // Send phases
    PHASES.forEach(p => {
      ws.send(JSON.stringify({
        type: p.status === 'completed' ? 'phase_complete' :
              p.status === 'in_progress' ? 'phase_start' : 'noop',
        phase: p.id,
        name: p.name,
      }));
    });

    // Send agents
    AGENTS.forEach(a => {
      const eventType = a.status === 'completed' ? 'agent_complete' :
                        a.status === 'running' ? 'agent_start' : 'noop';
      if (eventType !== 'noop') {
        ws.send(JSON.stringify({
          type: eventType,
          agent: a.agent,
          phase: a.phase,
          task: a.task,
        }));
      }
    });

    // Send tasks
    TASKS.forEach(t => {
      ws.send(JSON.stringify({
        type: 'task_create',
        title: t.title,
        phase: t.phase,
        agent: t.agent,
      }));
      if (t.status === 'done') {
        ws.send(JSON.stringify({
          type: 'task_done',
          title: t.title,
        }));
      }
    });

    console.log(`[Dashboard Sync] Sent: ${PHASES.length} phases, ${AGENTS.length} agents, ${TASKS.length} tasks`);
    setTimeout(() => { ws.close(); process.exit(0); }, 1000);
  });

  ws.on('error', (err) => {
    console.error(`[Dashboard Sync] Error: ${err.message}`);
    process.exit(1);
  });
}

sync();
