import { useState } from 'react';
import { Search, Boxes, Plus, Play, Square, RotateCw } from 'lucide-react';
import { fetchNui, useNuiData } from '../hooks/useNui';
import { useToast } from '../components/Toast';
import { Modal } from '../components/Modal';
import { Dropdown, type DropdownOption } from '../components/Dropdown';
import { Button } from '../components/Button';
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

const stateBadge: Record<ResourceState, { label: string; className: string }> = {
  started: { label: 'Started', className: 'bg-green-500/20 text-green-400' },
  starting: { label: 'Starting', className: 'bg-[var(--rdr-accent-20)] text-[var(--rdr-accent-bright)]' },
  stopped: { label: 'Stopped', className: 'bg-red-500/20 text-red-400' },
  stopping: { label: 'Stopping', className: 'bg-red-500/20 text-red-400' },
  uninitialized: { label: 'Uninitialized', className: 'bg-zinc-500/20 text-zinc-400' },
  missing: { label: 'Missing', className: 'bg-zinc-500/20 text-zinc-400' },
};

export function ResourceLookup() {
  const toast = useToast();
  const [data, refresh] = useNuiData<ServerResource[]>('getResources', {}, mockResources);
  const resources = data ?? [];
  const [query, setQuery] = useState('');
  const [status, setStatus] = useState<'all' | ResourceState>('all');
  const [showInstall, setShowInstall] = useState(false);
  const [busy, setBusy] = useState<string | null>(null);

  const filtered = resources.filter((r) => {
    if (status !== 'all' && r.state !== status) return false;
    if (query && !r.name.toLowerCase().includes(query.toLowerCase())) return false;
    return true;
  });

  const act = async (name: string, action: 'start' | 'stop' | 'restart') => {
    setBusy(name + action);
    const event = action === 'start' ? 'startResource' : action === 'stop' ? 'stopResource' : 'restartResource';
    // the server actually waits and re-checks the resource's real state before
    // replying now, instead of firing the command and immediately claiming
    // success — so this can take up to ~1.5s for start/restart, that's expected
    const res = await fetchNui<{ success: boolean; state?: ResourceState; reason?: string }>(event, { name }, { success: true });
    setBusy(null);
    if (res.success) {
      toast.push({ type: 'success', title: `${name} ${action === 'start' ? 'started' : action === 'stop' ? 'stopped' : 'restarted'}` });
    } else if (res.reason === 'not_found') {
      toast.push({ type: 'error', title: `${name} not found` });
    } else {
      toast.push({ type: 'error', title: `Failed to ${action} ${name}`, description: 'It may need more time, or refuses that command. Check the server console.' });
    }
    refresh();
  };

  return (
    <div className="space-y-4 pb-6">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-[var(--rdr-heading)] text-2xl font-bold flex items-center gap-2"><Boxes size={22} /> Resource Lookup</h2>
          <p className="text-[var(--rdr-muted)] mt-1 text-sm">View and manage every resource running on this server</p>
        </div>
        <Button variant="outline" tone="green" onClick={() => setShowInstall(true)}><Plus size={13} /> Install Resource</Button>
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
          const isStarted = r.state === 'started' || r.state === 'starting';
          return (
            <div key={r.name} className="rounded-lg p-4" style={{ background: 'var(--rdr-surface)', border: '1px solid var(--rdr-border)' }}>
              <div className="flex items-start justify-between gap-3">
                <div className="min-w-0">
                  <div className="flex items-center gap-2 flex-wrap">
                    <p className="text-[var(--rdr-heading)] text-sm font-semibold truncate">{r.name}</p>
                    <span className={`px-1.5 py-0.5 rounded-sm text-[10px] font-semibold uppercase ${badge.className}`}>{badge.label}</span>
                  </div>
                  <p className="text-[var(--rdr-faint)] text-[11px] mt-0.5">v{r.version || 'unknown'} &middot; by {r.author || 'unknown'}</p>
                  {r.description && <p className="text-[var(--rdr-muted)] text-xs mt-1.5">{r.description}</p>}
                  <div className="grid grid-cols-2 gap-4 mt-2.5 text-xs">
                    <div>
                      <p className="text-[var(--rdr-faint)] uppercase tracking-wide text-[10px]">Dependencies</p>
                      <p className="text-[var(--rdr-muted)] mt-0.5">{r.dependencies.length ? r.dependencies.join(', ') : 'No dependencies'}</p>
                    </div>
                  </div>
                </div>
                <div className="flex flex-col gap-1.5 shrink-0 w-28">
                  {isStarted ? (
                    <Button variant="outline" tone="red" className="text-xs" isLoading={busy === r.name + 'stop'} onClick={() => act(r.name, 'stop')}>
                      <Square size={12} /> Stop
                    </Button>
                  ) : (
                    <Button variant="outline" tone="green" className="text-xs" isLoading={busy === r.name + 'start'} onClick={() => act(r.name, 'start')}>
                      <Play size={12} /> Start
                    </Button>
                  )}
                  <Button variant="outline" className="text-xs" isLoading={busy === r.name + 'restart'} onClick={() => act(r.name, 'restart')}>
                    <RotateCw size={12} /> Restart
                  </Button>
                </div>
              </div>
            </div>
          );
        })}
        {filtered.length === 0 && <p className="text-center text-[var(--rdr-faint)] text-sm py-8">No resources found</p>}
      </div>

      {showInstall && <InstallResourceModal onClose={() => setShowInstall(false)} />}
    </div>
  );
}

function InstallResourceModal({ onClose }: { onClose: () => void }) {
  const [name, setName] = useState('');
  const [url, setUrl] = useState('');

  return (
    <Modal title="Install New Resource" subtitle="Install a new resource from GitHub or local file" onClose={onClose} width="max-w-md">
      <div className="space-y-3">
        <div>
          <label className="text-xs text-[var(--rdr-muted)]">Resource Name</label>
          <input value={name} onChange={(e) => setName(e.target.value)} placeholder="e.g., esx_newjob" className="w-full mt-1 bg-[var(--rdr-surface-2)] border border-[var(--rdr-border)] rounded-sm px-3 py-2 text-sm text-[var(--rdr-text)]" />
        </div>
        <div>
          <label className="text-xs text-[var(--rdr-muted)]">Resource URL or Path</label>
          <input value={url} onChange={(e) => setUrl(e.target.value)} placeholder="https://github.com/user/resource" className="w-full mt-1 bg-[var(--rdr-surface-2)] border border-[var(--rdr-border)] rounded-sm px-3 py-2 text-sm text-[var(--rdr-text)]" />
        </div>
        <p className="text-[var(--rdr-faint)] text-[11px] leading-relaxed">
          Downloading and installing a resource requires filesystem access this Lua resource doesn't have on its own
          (FXServer resources can only read/write inside their own folder). This needs to go through your server's
          process manager or txAdmin instead, and isn't wired up yet.
        </p>
        <div className="flex justify-end gap-2">
          <Button variant="ghost" onClick={onClose}>Cancel</Button>
          <Button variant="solid" tone="green" disabled className="opacity-50">Install Resource</Button>
        </div>
      </div>
    </Modal>
  );
}
