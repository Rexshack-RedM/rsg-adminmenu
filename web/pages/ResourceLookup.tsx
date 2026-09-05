import { useState } from 'react';
import { Search, Boxes } from 'lucide-react';
import { useNuiData } from '../hooks/useNui';
import { Dropdown, type DropdownOption } from '../components/Dropdown';
import type { ResourceState, ServerResource } from '../types';

const mockResources: ServerResource[] = [
  { name: 'rsg-adminmenu', state: 'started', version: '2.0.11', author: 'RSG', description: 'Admin menu', dependencies: ['rsg-core', 'ox_lib'] },
  { name: 'rsg-core', state: 'started', version: undefined, author: undefined, description: undefined, dependencies: [] },
];

const statusOptions: DropdownOption<'all' | ResourceState>[] = [
  { value: 'all', label: 'All Status' },
  { value: 'started', label: 'Started' },
  { value: 'stopped', label: 'Stopped' },
];

function formatDependencies(value: unknown): string {
  const list = Array.isArray(value)
    ? value.filter((v) => typeof v === 'string' && v.length > 0)
    : typeof value === 'string'
      ? value.split(',').map((s) => s.trim()).filter(Boolean)
      : value && typeof value === 'object'
        ? Object.values(value).filter((v): v is string => typeof v === 'string' && v.length > 0)
        : [];
  return list.length ? list.join(', ') : 'No dependencies';
}

const stateBadge: Record<ResourceState, { label: string; className: string }> = {
  started: { label: 'Started', className: 'bg-green-500/20 text-green-400' },
  starting: { label: 'Starting', className: 'bg-[var(--rdr-accent-20)] text-[var(--rdr-accent-bright)]' },
  stopped: { label: 'Stopped', className: 'bg-red-500/20 text-red-400' },
  stopping: { label: 'Stopping', className: 'bg-red-500/20 text-red-400' },
  uninitialized: { label: 'Uninitialized', className: 'bg-zinc-500/20 text-zinc-400' },
  missing: { label: 'Missing', className: 'bg-zinc-500/20 text-zinc-400' },
};

export function ResourceLookup() {
  const [data] = useNuiData<ServerResource[]>('getResources', {}, mockResources);
  const resources = data ?? [];
  const [query, setQuery] = useState('');
  const [status, setStatus] = useState<'all' | ResourceState>('all');

  const filtered = resources.filter((r) => {
    if (status !== 'all' && r.state !== status) return false;
    if (query && !r.name.toLowerCase().includes(query.toLowerCase())) return false;
    return true;
  });

  return (
    <div className="space-y-4 pb-6">
      <div>
        <h2 className="text-[var(--rdr-heading)] text-2xl font-bold flex items-center gap-2"><Boxes size={22} /> Resource Lookup</h2>
        <p className="text-[var(--rdr-muted)] mt-1 text-sm">Every resource running on this server</p>
      </div>

      <div className="flex gap-3 items-center">
        <div className="relative flex-1">
          <Search size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-[var(--rdr-faint)]" />
          <input
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Search resources..."
            className="w-full pl-9 pr-3 py-2 bg-[var(--rdr-surface)] border border-[var(--rdr-border)] rounded-sm text-sm text-[var(--rdr-text)]"
          />
        </div>
        <Dropdown className="w-40 shrink-0" value={status} onChange={setStatus} options={statusOptions} />
        <span className="text-[var(--rdr-faint)] text-xs whitespace-nowrap px-3 py-2 rounded-sm" style={{ background: 'var(--rdr-surface)', border: '1px solid var(--rdr-border)' }}>
          {filtered.length} resource{filtered.length === 1 ? '' : 's'}
        </span>
      </div>

      <div className="space-y-2">
        {filtered.map((r) => {
          const badge = stateBadge[r.state] ?? stateBadge.uninitialized;
          return (
            <div key={r.name} className="rounded-lg p-4" style={{ background: 'var(--rdr-surface)', border: '1px solid var(--rdr-border)' }}>
              <div className="flex items-center gap-2 flex-wrap">
                <p className="text-[var(--rdr-heading)] text-sm font-semibold truncate">{r.name}</p>
                <span className={`px-1.5 py-0.5 rounded-sm text-[10px] font-semibold uppercase ${badge.className}`}>{badge.label}</span>
              </div>
              <p className="text-[var(--rdr-faint)] text-[11px] mt-0.5">v{r.version || 'unknown'} &middot; by {r.author || 'unknown'}</p>
              {r.description && <p className="text-[var(--rdr-muted)] text-xs mt-1.5">{r.description}</p>}
              <div className="mt-2.5 text-xs">
                <p className="text-[var(--rdr-faint)] uppercase tracking-wide text-[10px]">Dependencies</p>
                <p className="text-[var(--rdr-muted)] mt-0.5">{formatDependencies(r.dependencies)}</p>
              </div>
            </div>
          );
        })}
        {filtered.length === 0 && <p className="text-center text-[var(--rdr-faint)] text-sm py-8">No resources found</p>}
      </div>
    </div>
  );
}
