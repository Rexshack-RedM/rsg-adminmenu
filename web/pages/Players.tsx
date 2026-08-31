import { useMemo, useState } from 'react';
import { Search, Users, UserCheck, UserX, MessageCircle, ShieldBan } from 'lucide-react';
import { useNuiData, fetchNui } from '../hooks/useNui';
import { PlayerManageModal } from '../components/PlayerManageModal';
import { Avatar } from '../components/Avatar';
import { Modal } from '../components/Modal';
import { Dropdown } from '../components/Dropdown';
import { Button } from '../components/Button';
import { useToast } from '../components/Toast';
import type { ManagedPlayer, OnlinePlayer, Permissions } from '../types';

const statusFilterOptions = [
  { value: 'all' as const, label: 'All Players' },
  { value: 'online' as const, label: 'Online Only' },
  { value: 'offline' as const, label: 'Offline Only' },
  { value: 'banned' as const, label: 'Banned' },
];

const mockPlayers: ManagedPlayer[] = [
  { citizenid: 'DEV1234', serverId: 1, name: 'Dev Player', accountName: 'Steam Dev', job: 'Sheriff', money: 1450, playtimeMinutes: 320, lastSeen: new Date().toISOString(), online: true, discordName: 'uiforc', discordAvatarUrl: undefined, banned: false },
  { citizenid: 'DEV5678', serverId: null, name: 'Old Timer', accountName: 'oldtimer', job: 'Unemployed', money: 200, playtimeMinutes: 40, lastSeen: null, online: false, banned: true, banId: 1, banReason: 'RDM', banPermanent: false, banExpire: Math.floor(Date.now() / 1000) + 86400, bannedBy: 'uiforc' },
];

function formatPlaytime(minutes: number) {
  const h = Math.floor(minutes / 60);
  const m = minutes % 60;
  return `${h}h ${m}m`;
}

export function Players({ permissions }: { permissions: Permissions | null }) {
  const toast = useToast();
  const [data, refresh] = useNuiData<ManagedPlayer[]>('getAllPlayersManaged', {}, mockPlayers);
  const players = data ?? [];
  const [query, setQuery] = useState('');
  const [statusFilter, setStatusFilter] = useState<'all' | 'online' | 'offline' | 'banned'>('all');
  const [selectedOnline, setSelectedOnline] = useState<OnlinePlayer | null>(null);
  const [selectedOffline, setSelectedOffline] = useState<ManagedPlayer | null>(null);
  const [refreshing, setRefreshing] = useState(false);

  const counts = useMemo(() => ({
    online: players.filter((p) => p.online).length,
    offline: players.filter((p) => !p.online).length,
    banned: players.filter((p) => p.banned).length,
    total: players.length,
  }), [players]);

  const filtered = players.filter((p) => {
    if (statusFilter === 'online' && !p.online) return false;
    if (statusFilter === 'offline' && p.online) return false;
    if (statusFilter === 'banned' && !p.banned) return false;
    if (query) {
      const q = query.toLowerCase();
      if (!p.name.toLowerCase().includes(q) && !p.accountName.toLowerCase().includes(q) && !p.citizenid.toLowerCase().includes(q)) return false;
    }
    return true;
  });

  const unban = async (p: ManagedPlayer) => {
    if (p.banId == null) return;
    await fetchNui('unbanPlayer', { banId: p.banId }, { success: true });
    toast.push({ type: 'success', title: `${p.name} unbanned` });
    setSelectedOffline(null);
    refresh();
  };

  return (
    <div className="space-y-4">
      <div>
        <h2 className="text-[var(--rdr-heading)] text-2xl font-bold">Players</h2>
        <p className="text-[var(--rdr-muted)] mt-1 text-sm">Manage and monitor all server players</p>
      </div>

      <div className="grid grid-cols-4 gap-4">
        <StatBox label="Online Players" value={counts.online} icon={<UserCheck size={18} />} color="#7fc47c" />
        <StatBox label="Offline Players" value={counts.offline} icon={<UserX size={18} />} color="#b5b5b5" />
        <StatBox label="Banned Players" value={counts.banned} icon={<ShieldBan size={18} />} color="#e07a6b" />
        <StatBox label="Total Players" value={counts.total} icon={<Users size={18} />} color="#6fa8dc" />
      </div>

      <div className="flex gap-3">
        <div className="relative flex-1">
          <Search size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-[var(--rdr-faint)]" />
          <input
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Search player name..."
            className="w-full pl-9 pr-3 py-2 bg-[var(--rdr-surface)] border border-[var(--rdr-border)] rounded-sm text-sm text-[var(--rdr-text)]"
          />
        </div>
        <Dropdown className="w-44 shrink-0" value={statusFilter} onChange={setStatusFilter} options={statusFilterOptions} />
        <Button
          variant="outline"
          tone="accent"
          className="text-xs"
          isLoading={refreshing}
          loadingText="Refreshing"
          onClick={async () => { setRefreshing(true); await refresh(); setRefreshing(false); }}
        >
          Refresh
        </Button>
      </div>

      <div className="rounded-sm overflow-hidden" style={{ border: '1px solid var(--rdr-border)' }}>
        <table className="w-full text-sm">
          <thead>
            <tr className="bg-[var(--rdr-surface-2)] text-[var(--rdr-muted)] text-xs uppercase tracking-wider">
              <th className="text-left px-4 py-2 font-medium">Player</th>
              <th className="text-left px-4 py-2 font-medium">Job</th>
              <th className="text-left px-4 py-2 font-medium">Money</th>
              <th className="text-left px-4 py-2 font-medium">Playtime</th>
              <th className="text-left px-4 py-2 font-medium">Last Seen</th>
              <th className="text-left px-4 py-2 font-medium">Status</th>
              <th className="text-right px-4 py-2 font-medium">Actions</th>
            </tr>
          </thead>
          <tbody>
            {filtered.map((p) => (
              <tr key={p.citizenid} className="border-t border-[var(--rdr-line)] hover:bg-white/[0.02]">
                <td className="px-4 py-2.5">
                  <div className="flex items-center gap-3">
                    <Avatar name={p.name} size={28} imageUrl={p.discordAvatarUrl} />
                    <div>
                      <p className="text-[var(--rdr-text)] font-medium">{p.name}</p>
                      <p className="text-[var(--rdr-faint)] text-xs flex items-center gap-1">
                        {p.discordName && <MessageCircle size={11} className="text-[#5865F2]" />}
                        {p.discordName ? `@${p.discordName}` : p.accountName}
                      </p>
                    </div>
                  </div>
                </td>
                <td className="px-4 py-2.5"><span className="px-2 py-0.5 rounded-sm bg-[var(--rdr-surface-2)] text-[var(--rdr-text)] text-xs capitalize">{p.job}</span></td>
                <td className="px-4 py-2.5 text-[#7fc47c]">${p.money.toLocaleString()}</td>
                <td className="px-4 py-2.5 text-[var(--rdr-text)]">{formatPlaytime(p.playtimeMinutes)}</td>
                <td className="px-4 py-2.5 text-[var(--rdr-muted)] text-xs">{p.online ? 'Now' : p.lastSeen ? new Date(p.lastSeen).toLocaleDateString() : 'Never'}</td>
                <td className="px-4 py-2.5">
                  <div className="flex items-center gap-1.5">
                    <span className={`px-2 py-0.5 rounded-sm text-xs ${p.online ? 'bg-green-500/20 text-green-400' : 'bg-zinc-500/20 text-zinc-400'}`}>
                      {p.online ? 'Online' : 'Offline'}
                    </span>
                    {p.banned && (
                      <span className="px-2 py-0.5 rounded-sm text-xs bg-[var(--rdr-red-20)] text-[var(--rdr-red-bright)]">Banned</span>
                    )}
                  </div>
                </td>
                <td className="px-4 py-2.5 text-right">
                  <div className="flex justify-end gap-2">
                    <Button
                      variant="outline"
                      tone="accent"
                      className="text-xs px-3 py-1"
                      onClick={() => p.online && p.serverId != null
                        ? setSelectedOnline({ id: p.serverId, name: p.name, citizenid: p.citizenid })
                        : setSelectedOffline(p)}
                    >
                      {p.online ? 'Manage' : 'View'}
                    </Button>
                    {p.banned && (
                      <Button variant="outline" tone="red" className="text-xs px-3 py-1" onClick={() => unban(p)}>Unban</Button>
                    )}
                  </div>
                </td>
              </tr>
            ))}
            {data !== undefined && filtered.length === 0 && (
              <tr><td colSpan={7} className="px-4 py-8 text-center text-[var(--rdr-faint)] text-sm">No players found</td></tr>
            )}
          </tbody>
        </table>
      </div>

      {selectedOnline && <PlayerManageModal player={selectedOnline} permissions={permissions} onClose={() => setSelectedOnline(null)} />}
      {selectedOffline && (
        <Modal title={selectedOffline.name} subtitle={`Citizen ID: ${selectedOffline.citizenid}`} onClose={() => setSelectedOffline(null)} width="max-w-sm">
          <div className="space-y-2 text-sm">
            <Row label="Account" value={selectedOffline.accountName} />
            <Row label="Job" value={selectedOffline.job} />
            <Row label="Money" value={`$${selectedOffline.money.toLocaleString()}`} />
            <Row label="Playtime" value={formatPlaytime(selectedOffline.playtimeMinutes)} />
            <Row label="Last Seen" value={selectedOffline.lastSeen ? new Date(selectedOffline.lastSeen).toLocaleString() : 'Never'} />
          </div>
          {selectedOffline.banned && (
            <div className="mt-3 p-3 rounded-sm space-y-2" style={{ background: 'var(--rdr-red-10)', border: '1px solid var(--rdr-red-20)' }}>
              <div className="flex items-center justify-between">
                <span className="text-[var(--rdr-red-bright)] text-sm font-semibold">Banned</span>
                <span className="px-2 py-0.5 rounded-sm text-xs bg-[var(--rdr-red-20)] text-[var(--rdr-red-bright)]">{selectedOffline.banPermanent ? 'Permanent' : 'Temporary'}</span>
              </div>
              <Row label="Reason" value={selectedOffline.banReason || 'No reason given'} />
              <Row label="Banned By" value={selectedOffline.bannedBy || 'Unknown'} />
              {!selectedOffline.banPermanent && selectedOffline.banExpire && (
                <Row label="Expires" value={new Date(selectedOffline.banExpire * 1000).toLocaleString()} />
              )}
              <Button variant="outline" tone="red" fullWidth onClick={() => unban(selectedOffline)}>Unban Player</Button>
            </div>
          )}
          <p className="text-[var(--rdr-faint)] text-xs mt-4">This player is offline. Most admin actions require them to be connected.</p>
        </Modal>
      )}
    </div>
  );
}

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-center justify-between py-1.5 border-b border-[var(--rdr-line)] last:border-b-0">
      <span className="text-[var(--rdr-muted)] text-xs">{label}</span>
      <span className="text-[var(--rdr-text)] text-sm font-medium">{value}</span>
    </div>
  );
}

function StatBox({ label, value, icon, color }: { label: string; value: number; icon: React.ReactNode; color: string }) {
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
