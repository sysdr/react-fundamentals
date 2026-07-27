import type React from 'react';
import type { Metrics } from '../lib/metricsStore';

interface MetricsDashboardProps {
  metrics: Metrics;
}

const cardStyle: React.CSSProperties = {
  background: 'rgba(255,255,255,0.92)',
  borderRadius: 10,
  padding: '14px 18px',
  minWidth: 140,
  boxShadow: '0 1px 4px rgba(0,0,0,0.08)',
};

const valueStyle: React.CSSProperties = {
  fontSize: 28,
  fontWeight: 700,
  marginTop: 4,
  color: '#1a1a2e',
};

const MetricsDashboard: React.FC<MetricsDashboardProps> = ({ metrics }) => {
  const items: Array<{ label: string; value: string | number; testId: string }> = [
    { label: 'Total Votes', value: metrics.totalVotes, testId: 'metric-total-votes' },
    { label: 'Click Events', value: metrics.clickEvents, testId: 'metric-click-events' },
    { label: 'Main Thread Blocks', value: metrics.mainThreadBlocks, testId: 'metric-blocks' },
    {
      label: 'Last Block (ms)',
      value: metrics.lastBlockDurationMs,
      testId: 'metric-last-block-ms',
    },
    {
      label: 'UI Freeze Detected',
      value: metrics.uiFreezeDetected ? 'YES' : 'NO',
      testId: 'metric-freeze',
    },
    {
      label: 'Responsiveness',
      value: `${metrics.responsivenessScore}%`,
      testId: 'metric-responsiveness',
    },
    { label: 'Demo Runs', value: metrics.demoRuns, testId: 'metric-demo-runs' },
  ];

  return (
    <section data-testid="metrics-dashboard" aria-label="Live metrics dashboard">
      <h2 style={{ marginBottom: 12, color: '#1a1a2e' }}>Live Metrics Dashboard</h2>
      <div
        style={{
          display: 'flex',
          flexWrap: 'wrap',
          gap: 12,
          justifyContent: 'center',
          maxWidth: 900,
        }}
      >
        {items.map((item) => (
          <div key={item.testId} style={cardStyle}>
            <div style={{ fontSize: 12, color: '#666', textTransform: 'uppercase' }}>
              {item.label}
            </div>
            <div data-testid={item.testId} style={valueStyle}>
              {item.value}
            </div>
          </div>
        ))}
      </div>
      {metrics.lastEventAt && (
        <p style={{ marginTop: 12, color: '#555', fontSize: 13 }}>
          Last event: {metrics.lastEventAt}
        </p>
      )}
    </section>
  );
};

export default MetricsDashboard;
