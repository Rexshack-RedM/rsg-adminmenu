import { useEffect, useRef, useState } from 'react';
import { MapPin, RefreshCw, Play, Square, Check, ClipboardList } from 'lucide-react';
import { fetchNui } from '../../hooks/useNui';
import { Button } from '../../components/Button';
import type { CurrentCoords } from '../../types';

const mockCoords: CurrentCoords = { x: -1792.08, y: -365.75, z: 161.43, heading: 39.42 };

function StatBox({ label, value, color }: { label: string; value: string; color: string }) {
  return (
    <div className="rounded-sm p-3" style={{ background: `${color}1a`, border: `1px solid ${color}40` }}>
      <p className="text-xs" style={{ color }}>{label}</p>
      <p className="text-[var(--rdr-heading)] text-lg font-bold mt-1">{value}</p>
    </div>
  );
}

function FormatRow({ badge, label, value }: { badge: string; label: string; value: string }) {
  const [copied, setCopied] = useState(false);
  return (
    <div className="rounded-sm p-3" style={{ background: 'var(--rdr-surface)', border: '1px solid var(--rdr-border)' }}>
      <div className="flex items-center gap-2 mb-2">
        <span className="px-1.5 py-0.5 rounded-sm text-[10px] font-semibold bg-[var(--rdr-accent-20)] text-[var(--rdr-accent-bright)]">{badge}</span>
        <span className="text-[var(--rdr-muted)] text-xs">{label}</span>
      </div>
      <div className="flex items-center gap-2">
        <code className="flex-1 text-sm text-[var(--rdr-text)] bg-[var(--rdr-surface-2)] rounded-sm px-3 py-2 truncate">{value}</code>
        <Button
          variant="outline"
          className="text-xs px-3 py-2 shrink-0"
          onClick={() => { navigator.clipboard?.writeText(value).catch(() => {}); setCopied(true); setTimeout(() => setCopied(false), 1200); }}
        >
          {copied ? <Check size={13} /> : <ClipboardList size={13} />} {copied ? 'Copied' : 'Copy'}
        </Button>
      </div>
    </div>
  );
}

export function Coords() {
  const [coords, setCoords] = useState<CurrentCoords>(mockCoords);
  const [live, setLive] = useState(false);
  const intervalRef = useRef<number | null>(null);

  const refresh = () => {
    fetchNui<CurrentCoords>('getCurrentCoords', {}, mockCoords).then(setCoords);
  };

  useEffect(() => { refresh(); }, []);

  useEffect(() => {
    if (live) {
      intervalRef.current = window.setInterval(refresh, 1000);
    } else if (intervalRef.current) {
      window.clearInterval(intervalRef.current);
      intervalRef.current = null;
    }
    return () => { if (intervalRef.current) window.clearInterval(intervalRef.current); };
  }, [live]);

  const fmt = (n: number) => n.toFixed(2);

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-[var(--rdr-heading)] text-2xl font-bold flex items-center gap-2"><MapPin size={22} /> Coordinates</h2>
          <p className="text-[var(--rdr-muted)] mt-1 text-sm">Get your current player coordinates in various formats</p>
        </div>
        <span className={`px-2 py-1 rounded-sm text-xs ${live ? 'bg-green-500/20 text-green-400' : 'bg-[var(--rdr-surface-2)] text-[var(--rdr-faint)]'}`}>
          Live Update {live ? 'ON' : 'OFF'}
        </span>
      </div>

      <div className="rounded-lg p-4 flex items-center justify-between" style={{ background: 'var(--rdr-surface)', border: '1px solid var(--rdr-border)' }}>
        <div>
          <p className="text-[var(--rdr-heading)] text-sm font-semibold">Live Coordinate Update</p>
          <p className="text-[var(--rdr-muted)] text-xs mt-0.5">Enable to automatically update coordinates in real-time</p>
        </div>
        <div className="flex gap-2">
          <Button variant="outline" className="text-xs" onClick={refresh}><RefreshCw size={13} /> Refresh</Button>
          <Button variant="outline" tone={live ? 'red' : 'green'} className="text-xs" onClick={() => setLive((l) => !l)}>
            {live ? <><Square size={13} /> Stop Live</> : <><Play size={13} /> Start Live</>}
          </Button>
        </div>
      </div>

      <div>
        <p className="text-[var(--rdr-muted)] text-xs uppercase tracking-wider font-medium mb-2">Current Position</p>
        <div className="grid grid-cols-4 gap-3">
          <StatBox label="X" value={fmt(coords.x)} color="#e07a6b" />
          <StatBox label="Y" value={fmt(coords.y)} color="#7fc47c" />
          <StatBox label="Z" value={fmt(coords.z)} color="#6fa8dc" />
          <StatBox label="Heading" value={`${fmt(coords.heading)}°`} color="#a58fc4" />
        </div>
      </div>

      <div>
        <p className="text-[var(--rdr-muted)] text-xs uppercase tracking-wider font-medium mb-2">Coordinate Formats</p>
        <div className="space-y-2">
          <FormatRow badge="Vector2" label="2D Position (X, Y)" value={`vector2(${fmt(coords.x)}, ${fmt(coords.y)})`} />
          <FormatRow badge="Vector3" label="3D Position (X, Y, Z)" value={`vector3(${fmt(coords.x)}, ${fmt(coords.y)}, ${fmt(coords.z)})`} />
          <FormatRow badge="Vector4" label="3D Position with Heading (X, Y, Z, H)" value={`vector4(${fmt(coords.x)}, ${fmt(coords.y)}, ${fmt(coords.z)}, ${fmt(coords.heading)})`} />
        </div>
      </div>
    </div>
  );
}
