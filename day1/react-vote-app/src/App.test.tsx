import { describe, it, expect } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import VoteButton from './components/VoteButton';
import MetricsDashboard from './components/MetricsDashboard';
import { emptyMetrics, scoreFromBlock } from './lib/metricsStore';

describe('VoteButton', () => {
  it('fires onVote without blocking by default', () => {
    let called = false;
    render(
      <VoteButton
        onVote={(d) => {
          called = true;
          expect(d.blocked).toBe(false);
        }}
      />,
    );
    fireEvent.click(screen.getByTestId('vote-button'));
    expect(called).toBe(true);
  });
});

describe('MetricsDashboard', () => {
  it('renders metric values from props', () => {
    const m = {
      ...emptyMetrics(),
      totalVotes: 3,
      clickEvents: 4,
      mainThreadBlocks: 1,
      lastBlockDurationMs: 5000,
      uiFreezeDetected: true,
      responsivenessScore: 40,
      demoRuns: 2,
    };
    render(<MetricsDashboard metrics={m} />);
    expect(screen.getByTestId('metric-total-votes').textContent).toBe('3');
    expect(screen.getByTestId('metric-click-events').textContent).toBe('4');
    expect(screen.getByTestId('metric-blocks').textContent).toBe('1');
    expect(screen.getByTestId('metric-last-block-ms').textContent).toBe('5000');
    expect(screen.getByTestId('metric-freeze').textContent).toBe('YES');
    expect(screen.getByTestId('metric-responsiveness').textContent).toBe('40%');
    expect(screen.getByTestId('metric-demo-runs').textContent).toBe('2');
  });
});

describe('scoreFromBlock', () => {
  it('reduces responsiveness after a long block', () => {
    expect(scoreFromBlock(5000, 1)).toBeLessThan(100);
    expect(scoreFromBlock(0, 0)).toBe(100);
  });
});
