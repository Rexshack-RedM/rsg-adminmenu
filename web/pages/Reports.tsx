import { useMemo, useState } from 'react';
import { Search, FileText, Hourglass, CheckCircle2, BarChart2, Fingerprint, MessageCircle, Cpu, Check } from 'lucide-react';
import { fetchNui, useNuiData } from '../hooks/useNui';
import { useToast } from '../components/Toast';
import { Modal, ConfirmModal } from '../components/Modal';
import { PlayerManageModal } from '../components/PlayerManageModal';
import { Dropdown } from '../components/Dropdown';
import { Button } from '../components/Button';
import { Avatar } from '../components/Avatar';
import type { Permissions, Report, ReportMessage, ReportNearbyPlayer, ReportSeverity, ReportStatus, ReportType } from '../types';

const typeFilterOptions = [
  { value: 'all' as const, label: 'All Types' },
  { value: 'bug' as const, label: 'Bug' },
  { value: 'player' as const, label: 'Player' },
  { value: 'question' as const, label: 'Question' },
];

const statusFilterOptions = [
  { value: 'all' as const, label: 'All Status' },
  { value: 'open' as const, label: 'Open' },
  { value: 'claimed' as const, label: 'Claimed' },
  { value: 'resolved' as const, label: 'Resolved' },
];

const statusColors: Record<ReportStatus, string> = {
  open: 'bg-blue-500/20 text-blue-400',
  claimed: 'bg-amber-500/20 text-amber-400',
  resolved: 'bg-green-500/20 text-green-400',
  closed: 'bg-zinc-500/20 text-zinc-400',
};

const typeLabels: Record<string, string> = { bug: 'Bug', player: 'Player Report', question: 'General Question' };

const severityLabels: Record<ReportSeverity, string> = { low: 'Low', medium: 'Medium', high: 'High' };
const severityColors: Record<ReportSeverity, string> = {
  low: 'bg-blue-500/20 text-blue-400',
  medium: 'bg-amber-500/20 text-amber-400',
  high: 'bg-[var(--rdr-red-20)] text-[var(--rdr-red-bright)]',
};

const mockReports: Report[] = [
  {
    id: 1, report_type: 'bug', severity: 'high', reporter_id: 2, reporter_name: 'John Marston', reporter_license: 'x',
    reporter_discord: '458994322637848596', reporter_discord_name: 'uiforc', reporter_steam: 'steam:110000172ad57df',
    reporter_coords: '0,0,0', title: 'Item duplication near Valentine', description: 'Found a dupe glitch at the general store.',
    status: 'open', created_at: new Date().toISOString(), updated_at: new Date().toISOString(),
  },
];

export function Reports({ permissions }: { permissions: Permissions | null }) {
  const toast = useToast();
  const [data, load] = useNuiData<Report[]>('getAllReports', {}, mockReports);
  const reports = data ?? [];
  const [statusFilter, setStatusFilter] = useState<'all' | ReportStatus>('all');
  const [typeFilter, setTypeFilter] = useState<'all' | ReportType>('all');
  const [query, setQuery] = useState('');
  const [openId, setOpenId] = useState<number | null>(null);
  const [refreshing, setRefreshing] = useState(false);

  const counts = useMemo(() => ({
    open: reports.filter((r) => r.status === 'open').length,
    claimed: reports.filter((r) => r.status === 'claimed').length,
    resolved: reports.filter((r) => r.status === 'resolved').length,
    total: reports.length,
  }), [reports]);

  const filtered = reports.filter((r) => {
    if (statusFilter !== 'all' && r.status !== statusFilter) return false;
    if (typeFilter !== 'all' && r.report_type !== typeFilter) return false;
    if (query && !r.title.toLowerCase().includes(query.toLowerCase()) && !r.reporter_name.toLowerCase().includes(query.toLowerCase())) return false;
    return true;
  });

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-[var(--rdr-heading)] text-2xl font-bold">Report Management</h2>
          <p className="text-[var(--rdr-muted)] mt-1 text-sm">Review and act on player submitted reports</p>
        </div>
        <Button
          variant="outline"
          tone="accent"
          className="text-xs"
          isLoading={refreshing}
          loadingText="Refreshing"
          onClick={async () => { setRefreshing(true); await load(); setRefreshing(false); }}
        >
          Refresh
        </Button>
      </div>

      <div className="grid grid-cols-4 gap-4">
        <ReportStatCard label="Open Reports" value={counts.open} icon={<FileText size={18} />} color="#e07a6b" />
        <ReportStatCard label="Claimed Reports" value={counts.claimed} icon={<Hourglass size={18} />} color="#e8b25a" />
        <ReportStatCard label="Resolved Reports" value={counts.resolved} icon={<CheckCircle2 size={18} />} color="#7fc47c" />
        <ReportStatCard label="Total Reports" value={counts.total} icon={<BarChart2 size={18} />} color="#6fa8dc" />
      </div>

      <div className="flex gap-3">
        <div className="relative flex-1">
          <Search size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-[var(--rdr-faint)]" />
          <input
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Search reports..."
            className="w-full pl-9 pr-3 py-2 bg-[var(--rdr-surface)] border border-[var(--rdr-border)] rounded-sm text-sm text-[var(--rdr-text)]"
          />
        </div>
        <Dropdown className="w-36 shrink-0" value={typeFilter} onChange={setTypeFilter} options={typeFilterOptions} />
        <Dropdown className="w-36 shrink-0" value={statusFilter} onChange={setStatusFilter} options={statusFilterOptions} />
      </div>

      <div className="rounded-sm overflow-hidden" style={{ border: '1px solid var(--rdr-border)' }}>
        <table className="w-full text-sm">
          <thead>
            <tr className="bg-[var(--rdr-surface-2)] text-[var(--rdr-muted)] text-xs uppercase tracking-wider">
              <th className="text-left px-4 py-2 font-medium">#</th>
              <th className="text-left px-4 py-2 font-medium">Type</th>
              <th className="text-left px-4 py-2 font-medium">Title</th>
              <th className="text-left px-4 py-2 font-medium">Reporter</th>
              <th className="text-left px-4 py-2 font-medium">Status</th>
              <th className="text-left px-4 py-2 font-medium">Assigned</th>
            </tr>
          </thead>
          <tbody>
            {filtered.map((r) => (
              <tr key={r.id} onClick={() => setOpenId(r.id)} className="border-t border-[var(--rdr-line)] hover:bg-white/[0.02] cursor-pointer">
                <td className="px-4 py-2.5 text-[var(--rdr-muted)]">#{r.id}</td>
                <td className="px-4 py-2.5 text-[var(--rdr-text)]">{typeLabels[r.report_type]}</td>
                <td className="px-4 py-2.5 text-[var(--rdr-text)] max-w-xs truncate">{r.title}</td>
                <td className="px-4 py-2.5 text-[var(--rdr-muted)]">{r.reporter_name}</td>
                <td className="px-4 py-2.5"><span className={`px-2 py-0.5 rounded-sm text-xs capitalize ${statusColors[r.status]}`}>{r.status}</span></td>
                <td className="px-4 py-2.5 text-[var(--rdr-faint)] text-xs">{r.assigned_admin_name || '-'}</td>
              </tr>
            ))}
            {filtered.length === 0 && (
              <tr><td colSpan={6} className="px-4 py-8 text-center text-[var(--rdr-faint)] text-sm">No reports</td></tr>
            )}
          </tbody>
        </table>
      </div>

      {openId != null && (
        <ReportDetail
          id={openId}
          isAdmin
          permissions={permissions}
          onClose={() => setOpenId(null)}
          onChanged={load}
        />
      )}
    </div>
  );
}

function ReportStatCard({ label, value, icon, color }: { label: string; value: number; icon: React.ReactNode; color: string }) {
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

function ReportCopyRow({ icon, label, value }: { icon: React.ReactNode; label: string; value?: string }) {
  const [copied, setCopied] = useState(false);
  return (
    <button
      disabled={!value}
      onClick={() => {
        if (!value) return;
        navigator.clipboard?.writeText(value).catch(() => {});
        setCopied(true);
        setTimeout(() => setCopied(false), 1200);
      }}
      className="w-full flex items-center gap-2.5 px-2.5 py-2 rounded-sm text-left transition-colors hover:bg-white/5 disabled:hover:bg-transparent"
      style={{ background: 'var(--rdr-surface)' }}
    >
      <span className="shrink-0 text-[var(--rdr-muted)]">{icon}</span>
      <span className="flex-1 min-w-0">
        <span className="block text-[var(--rdr-muted)] text-[11px]">{label}</span>
        <span className="block text-[var(--rdr-text)] text-xs font-medium truncate">{value || 'Unavailable'}</span>
      </span>
      {value && <span className="text-[11px] text-[var(--rdr-faint)] shrink-0 flex items-center gap-1">{copied ? (<><Check size={11} /> Copied</>) : 'Copy'}</span>}
    </button>
  );
}

interface ReportDetailProps {
  id: number;
  isAdmin: boolean;
  permissions?: Permissions | null;
  onClose: () => void;
  onChanged?: () => void;
}

export function ReportDetail({ id, isAdmin, permissions, onClose, onChanged }: ReportDetailProps) {
  const toast = useToast();
  const [data, load] = useNuiData<{ report: Report; messages: ReportMessage[]; nearbyPlayers: ReportNearbyPlayer[] }>(
    'getReportDetails',
    { id },
    { report: mockReports[0], messages: [], nearbyPlayers: [] }
  );
  const report = data?.report ?? null;
  const messages = data?.messages ?? [];
  const nearby = data?.nearbyPlayers ?? [];
  const [reply, setReply] = useState('');
  const [deleteReason, setDeleteReason] = useState<string | null>(null);
  const [jumpPlayer, setJumpPlayer] = useState<{ id: number; name: string; citizenid: string } | null>(null);

  const runAction = async (event: string, extra: Record<string, unknown> = {}) => {
    await fetchNui(event, { id, ...extra }, { success: true });
    onChanged?.();
    load();
  };

  if (!report) return null;

  return (
    <Modal title={`#${report.id}: ${report.title}`} onClose={onClose} width="max-w-2xl">
      <div className="space-y-4">
        <div className="flex items-center gap-1.5 -mt-1">
          <span className="px-2 py-0.5 rounded-sm text-xs bg-[var(--rdr-surface-2)] text-[var(--rdr-text)]">{typeLabels[report.report_type]}</span>
          <span className={`px-2 py-0.5 rounded-sm text-xs ${severityColors[report.severity]}`}>{severityLabels[report.severity]} Priority</span>
          <span className={`px-2 py-0.5 rounded-sm text-xs capitalize ${statusColors[report.status]}`}>{report.status}</span>
        </div>

        <p className="text-[var(--rdr-text)] text-sm whitespace-pre-wrap">{report.description}</p>

        {report.image_url && (
          <a href={report.image_url} target="_blank" rel="noreferrer" className="text-[var(--rdr-accent-bright)] text-xs underline">View attached image</a>
        )}

        {report.reported_player_name && (
          <p className="text-xs text-[var(--rdr-muted)]">Reported: <span className="text-[var(--rdr-text)]">{report.reported_player_name}</span></p>
        )}

        {isAdmin ? (
          <div>
            <p className="text-[var(--rdr-muted)] text-xs uppercase mb-1.5">Reporter Information</p>
            <div className="rounded-sm p-3 space-y-2" style={{ background: 'var(--rdr-surface-2)' }}>
              <div className="flex items-center gap-3">
                <Avatar name={report.reporter_name} size={36} imageUrl={report.reporter_discord_avatar} />
                <div>
                  <p className="text-[var(--rdr-text)] text-sm font-medium">{report.reporter_name}</p>
                  <p className="text-[var(--rdr-faint)] text-xs flex items-center gap-1">
                    {report.reporter_discord_name && <MessageCircle size={11} className="text-[#5865F2]" />}
                    {report.reporter_discord_name ? `@${report.reporter_discord_name}` : 'Discord not linked'}
                  </p>
                </div>
              </div>
              <ReportCopyRow icon={<MessageCircle size={13} />} label="Discord ID" value={report.reporter_discord} />
              <ReportCopyRow icon={<Cpu size={13} />} label="Steam ID" value={report.reporter_steam} />
              <ReportCopyRow icon={<Fingerprint size={13} />} label="License" value={report.reporter_license} />
            </div>
          </div>
        ) : (
          <p className="text-xs text-[var(--rdr-muted)]">Reporter: <span className="text-[var(--rdr-text)]">{report.reporter_name}</span></p>
        )}

        {isAdmin && nearby.length > 0 && (
          <div>
            <p className="text-[var(--rdr-muted)] text-xs uppercase mb-1">Nearby Players ({nearby.length})</p>
            <div className="space-y-1">
              {nearby.map((n) => (
                <button
                  key={n.id}
                  onClick={() => setJumpPlayer({ id: n.player_id, name: n.player_name, citizenid: '' })}
                  className="w-full text-left px-2 py-1.5 rounded-sm bg-[var(--rdr-surface-2)] text-xs text-[var(--rdr-text)] hover:bg-white/5 flex justify-between"
                >
                  <span>{n.player_name} (ID: {n.player_id})</span>
                  <span className="text-[var(--rdr-faint)]">{n.distance.toFixed(1)}m</span>
                </button>
              ))}
            </div>
          </div>
        )}

        <div>
          <p className="text-[var(--rdr-muted)] text-xs uppercase mb-1">Messages ({messages.length})</p>
          <div className="space-y-1.5 max-h-40 overflow-y-auto">
            {messages.map((m) => (
              <div key={m.id} className="bg-[var(--rdr-surface-2)] rounded-sm px-3 py-2">
                <div className="flex justify-between text-[11px] text-[var(--rdr-faint)]">
                  <span>{m.sender_name} ({m.sender_type})</span>
                  <span>{m.created_at_text}</span>
                </div>
                <p className="text-[var(--rdr-text)] text-sm mt-0.5">{m.message}</p>
              </div>
            ))}
            {messages.length === 0 && <p className="text-[var(--rdr-faint)] text-xs">No messages yet</p>}
          </div>
        </div>

        {report.status !== 'closed' && (
          <div className="flex gap-2">
            <input
              value={reply}
              onChange={(e) => setReply(e.target.value)}
              placeholder="Write a reply..."
              className="flex-1 bg-[var(--rdr-surface-2)] border border-[var(--rdr-border)] rounded-sm px-3 py-2 text-sm text-[var(--rdr-text)]"
            />
            <Button
              variant="solid"
              tone="accent"
              disabled={reply.trim().length < 5}
              onClick={async () => { await runAction('replyReport', { message: reply.trim() }); setReply(''); toast.push({ type: 'success', title: 'Reply sent' }); }}
            >
              Reply
            </Button>
          </div>
        )}

        {isAdmin && (
          <div className="flex gap-2 flex-wrap pt-2 border-t border-[var(--rdr-line)]">
            {report.status !== 'claimed' && report.status !== 'closed' && (
              <Button variant="outline" className="text-xs" onClick={() => runAction('claimReport')}>Claim</Button>
            )}
            {report.status === 'claimed' && (
              <Button variant="outline" className="text-xs" onClick={() => runAction('releaseReport')}>Release</Button>
            )}
            {report.status !== 'resolved' && report.status !== 'closed' && (
              <Button variant="outline" tone="green" className="text-xs" onClick={() => runAction('resolveReport')}>Mark Resolved</Button>
            )}
            {report.status !== 'closed' && (
              <Button variant="outline" tone="red" className="text-xs" onClick={() => setDeleteReason('')}>Delete</Button>
            )}
          </div>
        )}
      </div>

      {deleteReason !== null && (
        <div className="mt-4 pt-4 border-t border-[var(--rdr-line)]">
          <label className="text-xs text-[var(--rdr-muted)]">Deletion reason</label>
          <input value={deleteReason} onChange={(e) => setDeleteReason(e.target.value)} className="w-full mt-1 mb-3 bg-[var(--rdr-surface-2)] border border-[var(--rdr-border)] rounded-sm px-3 py-2 text-sm text-[var(--rdr-text)]" />
          <div className="flex justify-end gap-2">
            <Button variant="ghost" onClick={() => setDeleteReason(null)}>Cancel</Button>
            <Button
              variant="solid"
              tone="red"
              disabled={deleteReason.trim().length < 5}
              onClick={async () => { await runAction('deleteReport', { reason: deleteReason.trim() }); setDeleteReason(null); onClose(); }}
            >
              Confirm Delete
            </Button>
          </div>
        </div>
      )}

      {jumpPlayer && <PlayerManageModal player={jumpPlayer} permissions={permissions ?? null} onClose={() => setJumpPlayer(null)} />}
    </Modal>
  );
}
