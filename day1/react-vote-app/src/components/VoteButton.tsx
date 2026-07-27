import type React from 'react';

export interface VoteButtonProps {
  blockDemo?: boolean;
  onVote?: (detail: { blocked: boolean; durationMs: number }) => void;
  label?: string;
}

const VoteButton: React.FC<VoteButtonProps> = ({
  blockDemo = false,
  onVote,
  label = 'Vote',
}) => {
  const handleVoteClick = () => {
    const start = Date.now();
    let blocked = false;

    if (blockDemo) {
      blocked = true;
      // Simulate 5 seconds of heavy main-thread work (failure demo)
      while (Date.now() - start < 5000) {
        // burn CPU
      }
    }

    const durationMs = Date.now() - start;
    onVote?.({ blocked, durationMs });
  };

  return (
    <button
      type="button"
      data-testid="vote-button"
      onClick={handleVoteClick}
      style={{
        padding: '12px 28px',
        fontSize: '16px',
        cursor: 'pointer',
        margin: '10px',
        backgroundColor: blockDemo ? '#c0392b' : '#27ae60',
        color: 'white',
        border: 'none',
        borderRadius: '6px',
        boxShadow: '0 2px 6px rgba(0,0,0,0.18)',
        fontWeight: 600,
      }}
    >
      {label}
    </button>
  );
};

export default VoteButton;
