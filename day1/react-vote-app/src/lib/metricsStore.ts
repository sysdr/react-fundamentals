export type Metrics = {
  totalVotes: number;
  clickEvents: number;
  mainThreadBlocks: number;
  lastBlockDurationMs: number;
  uiFreezeDetected: boolean;
  responsivenessScore: number;
  lastEventAt: string | null;
  demoRuns: number;
};

export const emptyMetrics = (): Metrics => ({
  totalVotes: 0,
  clickEvents: 0,
  mainThreadBlocks: 0,
  lastBlockDurationMs: 0,
  uiFreezeDetected: false,
  responsivenessScore: 100,
  lastEventAt: null,
  demoRuns: 0,
});

export function scoreFromBlock(durationMs: number, blocks: number): number {
  const penalty = Math.min(95, Math.round(durationMs / 100) + blocks * 5);
  return Math.max(5, 100 - penalty);
}
