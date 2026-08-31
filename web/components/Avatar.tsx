import { useState } from 'react';

const PALETTE = ['#c8892b', '#5e8f4f', '#3b6ea5', '#a5463b', '#7a5ea8', '#3b8a8a'];

function hashString(str: string) {
  let hash = 0;
  for (let i = 0; i < str.length; i++) {
    hash = (hash << 5) - hash + str.charCodeAt(i);
    hash |= 0;
  }
  return Math.abs(hash);
}

function initials(name: string) {
  const parts = name.trim().split(/\s+/).filter(Boolean);
  if (parts.length === 0) return '?';
  if (parts.length === 1) return parts[0].slice(0, 2).toUpperCase();
  return (parts[0][0] + parts[1][0]).toUpperCase();
}

interface AvatarProps {
  name: string;
  size?: number;
  imageUrl?: string;
}

export function Avatar({ name, size = 36, imageUrl }: AvatarProps) {
  const [imgFailed, setImgFailed] = useState(false);
  const color = PALETTE[hashString(name) % PALETTE.length];

  if (imageUrl && !imgFailed) {
    return (
      <img
        src={imageUrl}
        alt={name}
        onError={() => setImgFailed(true)}
        className="rounded-full object-cover shrink-0"
        style={{ width: size, height: size, border: `1px solid ${color}55` }}
      />
    );
  }

  return (
    <div
      className="rounded-full flex items-center justify-center font-semibold shrink-0"
      style={{
        width: size,
        height: size,
        background: `${color}33`,
        color,
        fontSize: size * 0.38,
        border: `1px solid ${color}55`,
      }}
    >
      {initials(name)}
    </div>
  );
}
