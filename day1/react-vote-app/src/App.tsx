import { useCallback, useEffect, useState } from 'react';
import VoteButton from './components/VoteButton';
import MetricsDashboard from './components/MetricsDashboard';
import { emptyMetrics, scoreFromBlock, type Metrics } from './lib/metricsStore';
import './App.css';

function App() {
  const [metrics, setMetrics] = useState<Metrics>(emptyMetrics());
  const [blockDemo, setBlockDemo] = useState(false);
  const [status, setStatus] = useState('Ready');

  const refreshFromServer = useCallback(async () => {
    try {
      const res = await fetch('/api/metrics');
      if (!res.ok) return;
      const data = (await res.json()) as Metrics;
      setMetrics(data);
    } catch {
      // server may be starting
    }
  }, []);

  useEffect(() => {
    refreshFromServer();
    const id = setInterval(refreshFromServer, 1500);
    return () => clearInterval(id);
  }, [refreshFromServer]);

  const persist = async (next: Metrics) => {
    setMetrics(next);
    try {
      await fetch('/api/metrics', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(next),
      });
    } catch {
      // offline / server down — local state still updates
    }
  };

  const handleVote = async (detail: { blocked: boolean; durationMs: number }) => {
    setStatus(detail.blocked ? `Blocked UI for ${detail.durationMs}ms` : 'Vote recorded');
    const next: Metrics = {
      ...metrics,
      totalVotes: metrics.totalVotes + 1,
      clickEvents: metrics.clickEvents + 1,
      mainThreadBlocks: metrics.mainThreadBlocks + (detail.blocked ? 1 : 0),
      lastBlockDurationMs: detail.blocked
        ? detail.durationMs
        : metrics.lastBlockDurationMs,
      uiFreezeDetected: metrics.uiFreezeDetected || detail.blocked,
      responsivenessScore: detail.blocked
        ? scoreFromBlock(
            detail.durationMs,
            metrics.mainThreadBlocks + 1,
          )
        : metrics.responsivenessScore,
      lastEventAt: new Date().toISOString(),
    };
    await persist(next);
  };

  const runClientDemo = async () => {
    setStatus('Running blocking demo…');
    setBlockDemo(true);
    // Trigger a synthetic blocked vote via API so dashboard updates without 5s freeze in automation
    try {
      const res = await fetch('/api/demo', { method: 'POST' });
      const data = (await res.json()) as { metrics: Metrics };
      setMetrics(data.metrics);
      setStatus('Demo completed — metrics updated');
    } catch {
      setStatus('Demo API unavailable');
    }
  };

  return (
    <div className="app-shell">
      <header>
        <h1>Resilient UI: First Interactive Element</h1>
        <p className="subtitle">
          Day 1 — Vote button, main-thread blocking demo, and live metrics.
        </p>
      </header>

      <MetricsDashboard metrics={metrics} />

      <div className="controls">
        <label className="toggle">
          <input
            type="checkbox"
            checked={blockDemo}
            onChange={(e) => setBlockDemo(e.target.checked)}
            data-testid="block-demo-toggle"
          />
          Enable blocking demo (5s main-thread freeze)
        </label>
        <div>
          <VoteButton blockDemo={blockDemo} onVote={handleVote} />
          <button
            type="button"
            data-testid="run-demo"
            className="demo-btn"
            onClick={runClientDemo}
          >
            Run Demo
          </button>
        </div>
        <p data-testid="status-line" className="status">
          {status}
        </p>
      </div>
    </div>
  );
}

export default App;
