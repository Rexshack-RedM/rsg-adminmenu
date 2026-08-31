import { useEffect, useMemo, useState } from 'react';
import { Plus, Search, UserCheck, UserX, Clock, Users2 } from 'lucide-react';
import { fetchNui, useNuiData } from '../hooks/useNui';
import { useToast } from '../components/Toast';
import { Modal, ConfirmModal } from '../components/Modal';
import { Dropdown } from '../components/Dropdown';
import { Button } from '../components/Button';
import type { OnlinePlayer, WhitelistEntry, WhitelistStatus } from '../types';

const statusFilterOptions = [
  { value: 'all' as const, label: 'All Status' },
  { value: 'active' as const, label: 'Active' },
  { value: 'suspended' as const, label: 'Suspended' },
  { value: 'expired' as const, label: 'Expired' },
];

const statusColors: Record<WhitelistStatus, string> = {
  active: 'bg-green-500/20 text-green-400',
  suspended: 'bg-red-500/20 text-red-400',
  expired: 'bg-zinc-500/20 text-zinc-400',
};

const mockWhitelist: WhitelistEntry[] = [
  {
    id: 1, citizenid: 'DEV1234', player_name: 'Dev Player', account_name: 'uiforc',
    status: 'active', reason: 'TEST', added_by_name: 'uiforc', expires_at: null, created_at: new Date().toISOString(),
  },
];

export function Whitelist() {
  const toast = useToast();
  const [data, load] = useNuiData<WhitelistEntry[]>('getWhitelist', {}, mockWhitelist);
  const entries = data ?? [];
  const [query, setQuery] = useState('');
  const [statusFilter, setStatusFilter] = useState<'all' | WhitelistStatus>('all');
  const [showAdd, setShowAdd] = useState(false);
  const [removeTarget, setRemoveTarget] = useState<WhitelistEntry | null>(null);

  const counts = useMemo(() => ({
    active: entries.filter((e) => e.status === 'active').length,
    suspended: entries.filter((e) => e.status === 'suspended').length,
    expired: entries.filter((e) => e.status === 'expired').length,
    total: entries.length,
  }), [entries]);

  const filtered = entries.filter((e) => {
    if (statusFilter !== 'all' && e.status !== statusFilter) return false;
    if (query && !e.player_name.toLowerCase().includes(query.toLowerCase()) && !e.account_name.toLowerCase().includes(query.toLowerCase())) return false;
    return true;
  });

  const setStatus = async (entry: WhitelistEntry, status: WhitelistStatus) => {
    await fetchNui('setWhitelistStatus', { id: entry.id, status }, { success: true });
    toast.push({ type: 'success', title: `Marked ${status}` });
    load();
  };

  const remove = async (entry: WhitelistEntry) => {
    await fetchNui('removeWhitelist', { id: entry.id }, { success: true });
    toast.push({ type: 'success', title: 'Removed from whitelist' });
    setRemoveTarget(null);
    load();
  };

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-[var(--rdr-heading)] text-2xl font-bold">Whitelist</h2>
          <p className="text-[var(--rdr-muted)] mt-1 text-sm">Manage and track whitelisted players</p>
        </div>
        <Button variant="solid" tone="accent" onClick={() => setShowAdd(true)}>
          <Plus /> Add Player
        </Button>
      </div>

      <div className="grid grid-cols-4 gap-4">
        <WlCard label="Active Players" value={counts.active} icon={<UserCheck size={18} />} color="#7fc47c" />
        <WlCard label="Suspended Players" value={counts.suspended} icon={<UserX size={18} />} color="#e07a6b" />
        <WlCard label="Expired Players" value={counts.expired} icon={<Clock size={18} />} color="#b5b5b5" />
        <WlCard label="Total Whitelisted" value={counts.total} icon={<Users2 size={18} />} color="#6fa8dc" />
      </div>

      <div className="flex gap-3">
        <div className="relative flex-1">
          <Search size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-[var(--rdr-faint)]" />
          <input
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Search whitelist..."
            className="w-full pl-9 pr-3 py-2 bg-[var(--rdr-surface)] border border-[var(--rdr-border)] rounded-sm text-sm text-[var(--rdr-text)]"
          />
        </div>
        <Dropdown className="w-40 shrink-0" value={statusFilter} onChange={setStatusFilter} options={statusFilterOptions} />
      </div>

      <div className="rounded-sm overflow-hidden" style={{ border: '1px solid var(--rdr-border)' }}>
        <table className="w-full text-sm">
          <thead>
            <tr className="bg-[var(--rdr-surface-2)] text-[var(--rdr-muted)] text-xs uppercase tracking-wider">
              <th className="text-left px-4 py-2 font-medium">Player</th>
              <th className="text-left px-4 py-2 font-medium">Status</th>
              <th className="text-left px-4 py-2 font-medium">Added Info</th>
              <th className="text-left px-4 py-2 font-medium">Reason</th>
              <th className="text-right px-4 py-2 font-medium">Actions</th>
            </tr>
          </thead>
          <tbody>
            {filtered.map((e) => (
              <tr key={e.id} className="border-t border-[var(--rdr-line)]">
                <td className="px-4 py-2.5">
                  <p className="text-[var(--rdr-text)] font-medium">{e.player_name}</p>
                  <p className="text-[var(--rdr-faint)] text-xs">{e.account_name}</p>
                </td>
                <td className="px-4 py-2.5"><span className={`px-2 py-0.5 rounded-sm text-xs capitalize ${statusColors[e.status]}`}>{e.status}</span></td>
                <td className="px-4 py-2.5 text-[var(--rdr-muted)] text-xs">By {e.added_by_name || 'unknown'}<br />{new Date(e.created_at).toLocaleDateString()}</td>
                <td className="px-4 py-2.5 text-[var(--rdr-muted)] text-xs max-w-xs truncate">{e.reason || '-'}</td>
                <td className="px-4 py-2.5 text-right space-x-2 whitespace-nowrap">
                  {e.status !== 'active' ? (
                    <Button variant="ghost" tone="green" className="text-xs px-2 py-1" onClick={() => setStatus(e, 'active')}>Reactivate</Button>
                  ) : (
                    <Button variant="ghost" tone="amber" className="text-xs px-2 py-1" onClick={() => setStatus(e, 'suspended')}>Suspend</Button>
                  )}
                  <Button variant="ghost" tone="red" className="text-xs px-2 py-1" onClick={() => setRemoveTarget(e)}>Remove</Button>
                </td>
              </tr>
            ))}
            {filtered.length === 0 && (
              <tr><td colSpan={5} className="px-4 py-8 text-center text-[var(--rdr-faint)] text-sm">No whitelist entries</td></tr>
            )}
          </tbody>
        </table>
      </div>

      {showAdd && <AddWhitelistModal onClose={() => setShowAdd(false)} onAdded={load} />}
      {removeTarget && (
        <ConfirmModal
          title="Remove from Whitelist"
          message={`Remove ${removeTarget.player_name} from the whitelist?`}
          confirmLabel="Remove"
          danger
          onConfirm={() => remove(removeTarget)}
          onCancel={() => setRemoveTarget(null)}
        />
      )}
    </div>
  );
}

function WlCard({ label, value, icon, color }: { label: string; value: number; icon: React.ReactNode; color: string }) {
  return (
    <div className="rounded-lg p-4 flex items-center justify-between" style={{ background: 'var(--rdr-surface)', border: '1px solid var(--rdr-border)' }}>
      <div>
        <p className="text-[var(--rdr-muted)] text-sm">{label}</p>
        <p className="text-2xl font-bold mt-2" style={{ color }}>{value}</p>
      </div>
      <div className="w-9 h-9 rounded-lg flex items-center justify-center shrink-0" style={{ background: `${color}33`, color }}>
        {icon}
      </div>
    </div>
  );
}

function AddWhitelistModal({ onClose, onAdded }: { onClose: () => void; onAdded: () => void }) {
  const toast = useToast();
  const [players, setPlayers] = useState<OnlinePlayer[]>([]);
  const [selected, setSelected] = useState<OnlinePlayer | null>(null);
  const [reason, setReason] = useState('');
  const [expiresInDays, setExpiresInDays] = useState('');

  useEffect(() => {
    fetchNui<OnlinePlayer[]>('getPlayers', {}, [{ id: 1, name: 'Dev Player | (Steam Dev)', citizenid: 'DEV1234' }]).then(setPlayers);
  }, []);

  const submit = async () => {
    if (!selected) return;
    await fetchNui('addWhitelist', {
      citizenid: selected.citizenid,
      playerName: selected.name,
      accountName: selected.name,
      reason: reason.trim() || null,
      expiresInDays: expiresInDays ? Number(expiresInDays) : null,
    }, { success: true });
    toast.push({ type: 'success', title: 'Player added to whitelist' });
    onAdded();
    onClose();
  };

  return (
    <Modal title="Add to Whitelist" subtitle="Select an online player" onClose={onClose} width="max-w-md">
      <div className="space-y-3">
        <Dropdown
          className="w-full"
          value={selected?.citizenid ?? ''}
          onChange={(v) => setSelected(players.find((p) => p.citizenid === v) ?? null)}
          placeholder="Select a player..."
          options={players.map((p) => ({ value: p.citizenid, label: `ID: ${p.id} | ${p.name}` }))}
        />
        <div>
          <label className="text-xs text-[var(--rdr-muted)]">Reason (optional)</label>
          <input value={reason} onChange={(e) => setReason(e.target.value)} className="w-full mt-1 bg-[var(--rdr-surface-2)] border border-[var(--rdr-border)] rounded-sm px-3 py-2 text-sm text-[var(--rdr-text)]" />
        </div>
        <div>
          <label className="text-xs text-[var(--rdr-muted)]">Expires in days (optional, blank = never)</label>
          <input type="number" min={0} value={expiresInDays} onChange={(e) => setExpiresInDays(e.target.value)} className="w-full mt-1 bg-[var(--rdr-surface-2)] border border-[var(--rdr-border)] rounded-sm px-3 py-2 text-sm text-[var(--rdr-text)]" />
        </div>
        <div className="flex justify-end gap-2 pt-2">
          <Button variant="ghost" onClick={onClose}>Cancel</Button>
          <Button variant="solid" tone="accent" disabled={!selected} onClick={submit}>Add to Whitelist</Button>
        </div>
      </div>
    </Modal>
  );
}
