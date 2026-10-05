import { locale } from '../i18n';
import { useEffect, useMemo, useState } from 'react';
import {
  Search, UserCog, ShieldCheck, Crown, MessageCircle, Cpu, Fingerprint, Calendar, Wifi,
  Eye, MapPin, LogOut, Trash2, KeyRound, UserPlus, CheckCircle2, Award,
} from 'lucide-react';
import { copyToClipboard, fetchNui, useNuiData } from '../hooks/useNui';
import { useToast } from '../components/Toast';
import { Modal } from '../components/Modal';
import { Dropdown } from '../components/Dropdown';
import { Button } from '../components/Button';
import { Avatar } from '../components/Avatar';
import { Logs } from './Logs';
import type { AdminEntry, AdminRoleConfig, Permissions } from '../types';

const mockRoleConfig: AdminRoleConfig[] = [
  { role: 'god', level: 6, label: 'Owner' },
  { role: 'headadmin', level: 5, label: 'Head Admin' },
  { role: 'developer', level: 4, label: 'Developer' },
  { role: 'admin', level: 3, label: 'Admin' },
  { role: 'mod', level: 2, label: 'Moderator' },
  { role: 'helper', level: 1, label: 'Helper' },
];

const mockAdmins: AdminEntry[] = [
  {
    citizenid: 'DEV1234', name: 'Dev Admin', role: 'admin', roleLabel: 'Admin', grantedBy: 'Console', createdAt: new Date().toISOString(),
    serverId: 1, online: true, steamHex: 'steam:110000172ad57df', lastSeen: new Date().toISOString(),
    discordId: '458994322637848596', discordName: 'uiforc', discordAvatarUrl: undefined, reportsResolved: 12,
  },
  {
    citizenid: 'DEV5678', name: 'Old Moderator', role: 'mod', roleLabel: 'Moderator', grantedBy: 'Dev Admin', createdAt: new Date(Date.now() - 86400000 * 30).toISOString(),
    serverId: null, online: false, steamHex: undefined, lastSeen: new Date(Date.now() - 86400000 * 2).toISOString(),
    discordId: undefined, discordName: undefined, discordAvatarUrl: undefined, reportsResolved: 4,
  },
];

function formatDate(value: string | null) {
  if (!value) return locale('ui_never');
  return new Date(value).toLocaleDateString();
}

// palette walks highest -> lowest rank regardless of how many tiers are configured
const RANK_PALETTE = ['#e07a6b', '#e8b25a', '#a58fc4', '#6fa8dc', '#7fc47c', '#b5b5b5'];

function roleColor(rankIndex: number) {
  return RANK_PALETTE[Math.min(rankIndex, RANK_PALETTE.length - 1)];
}

export function Admins({ permissions }: { permissions: Permissions | null }) {
  const toast = useToast();
  const canManageAdmins = permissions?.canManageAdmins ?? false;
  const [roleData] = useNuiData<AdminRoleConfig[]>('getRoleConfig', {}, mockRoleConfig);
  const roles = useMemo(() => [...(roleData ?? [])].sort((a, b) => b.level - a.level), [roleData]);
  const roleOptions = useMemo(() => [{ value: 'all', label: locale('ui_all_roles') }, ...roles.map((r) => ({ value: r.role, label: r.label }))], [roles]);

  const [data, refresh] = useNuiData<AdminEntry[]>('getAdmins', {}, mockAdmins);
  const admins = data ?? [];
  const [query, setQuery] = useState('');
  const [roleFilter, setRoleFilter] = useState('all');
  const [selected, setSelected] = useState<AdminEntry | null>(null);
  const [showAdd, setShowAdd] = useState(false);
  const [refreshing, setRefreshing] = useState(false);

  const filtered = admins.filter((a) => {
    if (roleFilter !== 'all' && a.role !== roleFilter) return false;
    if (query) {
      const q = query.toLowerCase();
      if (!a.name.toLowerCase().includes(q) && !(a.discordName ?? '').toLowerCase().includes(q)) return false;
    }
    return true;
  });

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-[var(--rdr-heading)] text-2xl font-bold">{locale('ui_admins')}</h2>
          <p className="text-[var(--rdr-muted)] mt-1 text-sm">{locale('ui_manage_staff_access_and_role_assignments')}</p>
        </div>
        <div className="flex gap-2">
          <Button
            variant="outline"
            className="text-xs"
            isLoading={refreshing}
            loadingText={locale('ui_refreshing')}
            onClick={async () => { setRefreshing(true); try { await refresh(); } finally { setRefreshing(false); } }}
          >
            {locale('ui_refresh')}
          </Button>
          {canManageAdmins && (
            <Button variant="outline" tone="accent" className="text-xs" onClick={() => setShowAdd(true)}>
              <UserPlus /> {locale('ui_add_admin')}
            </Button>
          )}
        </div>
      </div>

      <div className="rounded-lg p-4" style={{ background: 'var(--rdr-surface)', border: '1px solid var(--rdr-border)' }}>
        <p className="text-[var(--rdr-muted)] text-xs uppercase tracking-wider font-medium mb-3 flex items-center gap-1.5"><Crown size={13} /> {locale('ui_role_hierarchy')}</p>
        <div className="flex flex-wrap gap-2">
          {roles.map((r, i) => {
            const color = roleColor(i);
            return (
              <div key={r.role} className="flex items-center gap-2 px-3 py-1.5 rounded-sm" style={{ background: `${color}1a`, border: `1px solid ${color}40` }}>
                <ShieldCheck size={14} style={{ color }} />
                <span className="text-sm font-medium" style={{ color }}>{r.label}</span>
                <span className="text-[10px] text-[var(--rdr-faint)]">{locale('ui_level')} {r.level}</span>
              </div>
            );
          })}
          {roles.length === 0 && <p className="text-[var(--rdr-faint)] text-xs">{locale('ui_no_roles_configured')}</p>}
        </div>
      </div>

      <div className="flex gap-3">
        <div className="relative flex-1">
          <Search size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-[var(--rdr-faint)]" />
          <input
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder={locale('ui_search_admins')}
            className="w-full pl-9 pr-3 py-2 bg-[var(--rdr-surface)] border border-[var(--rdr-border)] rounded-sm text-sm text-[var(--rdr-text)]"
          />
        </div>
        <Dropdown className="w-40 shrink-0" value={roleFilter} onChange={setRoleFilter} options={roleOptions} />
      </div>

      <div className="rounded-sm overflow-hidden" style={{ border: '1px solid var(--rdr-border)' }}>
        <table className="w-full text-sm">
          <thead>
            <tr className="bg-[var(--rdr-surface-2)] text-[var(--rdr-muted)] text-xs uppercase tracking-wider">
              <th className="text-left px-4 py-2 font-medium">{locale('ui_admin')}</th>
              <th className="text-left px-4 py-2 font-medium">{locale('ui_role')}</th>
              <th className="text-left px-4 py-2 font-medium">{locale('ui_reports_resolved')}</th>
              <th className="text-left px-4 py-2 font-medium">{locale('ui_last_login')}</th>
              <th className="text-left px-4 py-2 font-medium">{locale('ui_status')}</th>
              <th className="text-right px-4 py-2 font-medium">{locale('ui_actions')}</th>
            </tr>
          </thead>
          <tbody>
            {filtered.map((a) => (
              <tr key={a.citizenid} className="border-t border-[var(--rdr-line)] hover:bg-white/[0.02]">
                <td className="px-4 py-2.5">
                  <div className="flex items-center gap-3">
                    <Avatar name={a.name} size={28} imageUrl={a.discordAvatarUrl} />
                    <div>
                      <p className="text-[var(--rdr-text)] font-medium">{a.name}</p>
                      <p className="text-[var(--rdr-faint)] text-xs flex items-center gap-1">
                        {a.discordName && <MessageCircle size={11} className="text-[#5865F2]" />}
                        {a.discordName ? `@${a.discordName}` : (a.steamHex || locale('ui_no_identifiers'))}
                      </p>
                    </div>
                  </div>
                </td>
                <td className="px-4 py-2.5">
                  <span className="px-2 py-0.5 rounded-sm bg-[var(--rdr-accent-20)] text-[var(--rdr-accent-bright)] text-xs">{a.roleLabel}</span>
                </td>
                <td className="px-4 py-2.5 text-[var(--rdr-text)]">{a.reportsResolved}</td>
                <td className="px-4 py-2.5 text-[var(--rdr-muted)] text-xs">{a.online ? locale('ui_now') : formatDate(a.lastSeen)}</td>
                <td className="px-4 py-2.5">
                  <span className={`px-2 py-0.5 rounded-sm text-xs ${a.online ? 'bg-green-500/20 text-green-400' : 'bg-zinc-500/20 text-zinc-400'}`}>
                    {a.online ? locale('ui_online') : locale('ui_offline')}
                  </span>
                </td>
                <td className="px-4 py-2.5 text-right">
                  <Button variant="outline" tone="accent" className="text-xs px-3 py-1" onClick={() => setSelected(a)}>
                    <Eye size={13} /> {locale('ui_view')}
                  </Button>
                </td>
              </tr>
            ))}
            {data !== undefined && filtered.length === 0 && (
              <tr><td colSpan={6} className="px-4 py-8 text-center text-[var(--rdr-faint)] text-sm">{locale('ui_no_admins_found')}</td></tr>
            )}
          </tbody>
        </table>
      </div>

      {showAdd && (
        <AddAdminModal
          roleOptions={roles.map((r) => ({ value: r.role, label: r.label }))}
          onClose={() => setShowAdd(false)}
          onAdded={() => { setShowAdd(false); refresh(); }}
        />
      )}

      {selected && (
        <AdminProfileModal
          admin={selected}
          roleOptions={roles.map((r) => ({ value: r.role, label: r.label }))}
          canManageAdmins={canManageAdmins}
          onClose={() => setSelected(null)}
          onChanged={() => { refresh(); }}
        />
      )}
    </div>
  );
}

function AddAdminModal({ roleOptions, onClose, onAdded }: { roleOptions: { value: string; label: string }[]; onClose: () => void; onAdded: () => void }) {
  const toast = useToast();
  const [steamHex, setSteamHex] = useState('');
  const [role, setRole] = useState(roleOptions[roleOptions.length - 1]?.value ?? '');
  const [submitting, setSubmitting] = useState(false);

  const submit = async () => {
    if (!steamHex.trim() || !role) return;
    setSubmitting(true);
    const res = await fetchNui<{ success: boolean; message?: string }>('addAdmin', { steamHex: steamHex.trim(), role }, { success: true });
    setSubmitting(false);
    if (res.success) {
      toast.push({ type: 'success', title: locale('ui_admin_added') });
      onAdded();
    } else {
      toast.push({ type: 'error', title: locale('ui_failed_to_add_admin'), description: res.message });
    }
  };

  return (
    <Modal title={locale('ui_add_admin')} subtitle={locale('ui_the_target_player_must_be_currently_online')} onClose={onClose} width="max-w-sm">
      <div className="space-y-3">
        <div>
          <label className="text-xs text-[var(--rdr-muted)]">{locale('ui_steam_hex_identifier')}</label>
          <input
            autoFocus
            value={steamHex}
            onChange={(e) => setSteamHex(e.target.value)}
            placeholder="steam:110000172ad57df"
            className="w-full mt-1 bg-[var(--rdr-surface)] border border-[var(--rdr-border)] rounded-sm px-3 py-2 text-sm text-[var(--rdr-text)]"
          />
        </div>
        <div>
          <label className="text-xs text-[var(--rdr-muted)]">{locale('ui_role')}</label>
          <div className="mt-1"><Dropdown value={role} onChange={setRole} options={roleOptions} /></div>
        </div>
        <div className="flex justify-end gap-2">
          <Button variant="ghost" onClick={onClose}>{locale('ui_cancel')}</Button>
          <Button variant="solid" tone="accent" disabled={!steamHex.trim() || submitting} isLoading={submitting} onClick={submit}>{locale('ui_add_admin')}</Button>
        </div>
      </div>
    </Modal>
  );
}

function StatCard({ label, value, icon }: { label: string; value: string; icon: React.ReactNode }) {
  return (
    <div className="rounded-lg p-3 flex items-center justify-between" style={{ background: 'var(--rdr-surface)', border: '1px solid var(--rdr-border)' }}>
      <div className="min-w-0">
        <p className="text-[var(--rdr-heading)] text-sm font-bold truncate">{value}</p>
        <p className="text-[var(--rdr-muted)] text-xs mt-1">{label}</p>
      </div>
      <div className="w-8 h-8 rounded-lg flex items-center justify-center shrink-0 bg-[var(--rdr-accent-20)] text-[var(--rdr-accent-bright)]">
        {icon}
      </div>
    </div>
  );
}

function AdminProfileModal({
  admin, roleOptions, canManageAdmins, onClose, onChanged,
}: { admin: AdminEntry; roleOptions: { value: string; label: string }[]; canManageAdmins: boolean; onClose: () => void; onChanged: () => void }) {
  const toast = useToast();
  const [changingRole, setChangingRole] = useState(false);
  const [newRole, setNewRole] = useState(admin.role);
  const [kicking, setKicking] = useState(false);
  const [kickReason, setKickReason] = useState('');
  const [removing, setRemoving] = useState(false);

  const act = async (event: string, extra: Record<string, unknown> = {}, successMsg?: string) => {
    if (admin.serverId == null) return;
    await fetchNui(event, { id: admin.serverId, ...extra }, { success: true });
    if (successMsg) toast.push({ type: 'success', title: successMsg });
  };

  const changeRole = async () => {
    const res = await fetchNui<{ success: boolean }>('changeAdminRole', { citizenid: admin.citizenid, name: admin.name, role: newRole }, { success: true });
    if (res.success) {
      toast.push({ type: 'success', title: locale('ui_role_updated') });
      setChangingRole(false);
      onChanged();
    } else {
      toast.push({ type: 'error', title: locale('ui_failed_to_update_role') });
    }
  };

  const removeAdmin = async () => {
    const res = await fetchNui<{ success: boolean }>('removeAdmin', { citizenid: admin.citizenid, name: admin.name }, { success: true });
    if (res.success) {
      toast.push({ type: 'success', title: locale('ui_admin_access_removed') });
      onChanged();
      onClose();
    } else {
      toast.push({ type: 'error', title: locale('ui_failed_to_remove_admin') });
    }
  };

  return (
    <div
      className="fixed inset-0 z-[100] flex items-center justify-center bg-black/60"
      onMouseDown={(e) => { if (e.target === e.currentTarget) onClose(); }}
    >
      <div
        className="w-full max-w-2xl mx-4 rounded-sm shadow-2xl overflow-hidden max-h-[85vh] flex flex-col"
        style={{ background: 'var(--rdr-panel)', border: '1px solid var(--rdr-border)' }}
      >
        <div className="flex items-center justify-between px-5 py-4 shrink-0" style={{ borderBottom: '1px solid var(--rdr-line)', background: 'var(--rdr-surface-2)' }}>
          <div className="flex items-center gap-3">
            <Avatar name={admin.name} size={44} imageUrl={admin.discordAvatarUrl} />
            <div>
              <h2 className="text-[var(--rdr-heading)] text-lg font-bold leading-tight" style={{ fontFamily: 'var(--font-display)' }}>{admin.name}</h2>
              <p className="text-[var(--rdr-muted)] text-xs mt-0.5">{admin.discordName ? `@${admin.discordName}` : admin.citizenid}</p>
              <div className="flex items-center gap-1.5 mt-1.5">
                <span className="px-1.5 py-0.5 rounded-sm text-[10px] font-semibold uppercase bg-[var(--rdr-accent-20)] text-[var(--rdr-accent-bright)]">{admin.roleLabel}</span>
                <span className={`px-1.5 py-0.5 rounded-sm text-[10px] font-semibold ${admin.online ? 'bg-green-500/20 text-green-400' : 'bg-zinc-500/20 text-zinc-400'}`}>{admin.online ? locale('ui_online') : locale('ui_offline')}</span>
              </div>
            </div>
          </div>
          <button onClick={onClose} className="text-[var(--rdr-muted)] hover:text-[var(--rdr-heading)] text-sm px-2 py-1 rounded hover:bg-white/5 transition-colors">✕</button>
        </div>

        <div className="p-5 overflow-y-auto flex-1 min-h-0 space-y-4">
          <div className="grid grid-cols-3 gap-3">
            <StatCard label={locale('ui_reports_resolved')} value={String(admin.reportsResolved)} icon={<CheckCircle2 size={16} />} />
            <StatCard label={locale('ui_admin_since')} value={formatDate(admin.createdAt)} icon={<Calendar size={16} />} />
            <StatCard label={locale('ui_last_login')} value={admin.online ? locale('ui_now') : formatDate(admin.lastSeen)} icon={<Wifi size={16} />} />
          </div>

          <div>
            <p className="text-[var(--rdr-muted)] text-xs uppercase tracking-wider font-medium mb-2">{locale('ui_identifiers')}</p>
            <div className="space-y-1.5">
              <IdRow icon={<Fingerprint size={14} />} label={locale('ui_citizen_id')} value={admin.citizenid} />
              <IdRow icon={<Cpu size={14} />} label={locale('ui_steam_hex')} value={admin.steamHex} />
              <IdRow icon={<MessageCircle size={14} />} label={locale('ui_discord_id')} value={admin.discordId} />
              <IdRow icon={<Award size={14} />} label={locale('ui_granted_by')} value={admin.grantedBy ?? undefined} />
            </div>
          </div>

          <div>
            <p className="text-[var(--rdr-muted)] text-xs uppercase tracking-wider font-medium mb-2">{locale('ui_admin_actions')}</p>
            {!admin.online && <p className="text-[var(--rdr-faint)] text-xs mb-2">{locale('ui_spectate_teleport_and_kick_require_this_admi')}</p>}
            <div className="grid grid-cols-3 gap-2">
              <Button variant="outline" disabled={!admin.online} className="justify-start" onClick={() => act('toggleSpectate')}>
                <Eye /> {locale('ui_spectate')}
              </Button>
              <Button variant="outline" disabled={!admin.online} className="justify-start" onClick={() => act('goToPlayer')}>
                <MapPin /> {locale('ui_teleport')}
              </Button>
              <Button variant="outline" tone="red" disabled={!admin.online} className="justify-start" onClick={() => setKicking(true)}>
                <LogOut /> {locale('ui_kick')}
              </Button>
              {canManageAdmins && (
                <Button variant="outline" tone="amber" className="justify-start" onClick={() => setChangingRole(true)}>
                  <KeyRound /> {locale('ui_change_role')}
                </Button>
              )}
              {canManageAdmins && (
                <Button variant="outline" tone="red" className="justify-start" onClick={() => setRemoving(true)}>
                  <Trash2 /> {locale('ui_remove_admin')}
                </Button>
              )}
            </div>
          </div>

          <div>
            <p className="text-[var(--rdr-muted)] text-xs uppercase tracking-wider font-medium mb-2 flex items-center gap-1.5"><UserCog size={13} /> {locale('ui_admin_activity_log')}</p>
            <div className="max-h-56 overflow-y-auto rounded-sm" style={{ border: '1px solid var(--rdr-border)' }}>
              <Logs embedded adminCitizenid={admin.citizenid} />
            </div>
          </div>
        </div>
      </div>

      {changingRole && (
        <Modal title={locale('ui_change_role')} onClose={() => setChangingRole(false)} width="max-w-sm">
          <div className="space-y-3">
            <div>
              <label className="text-xs text-[var(--rdr-muted)]">{locale('ui_new_role')}</label>
              <div className="mt-1"><Dropdown value={newRole} onChange={setNewRole} options={roleOptions} /></div>
            </div>
            <div className="flex justify-end gap-2">
              <Button variant="ghost" onClick={() => setChangingRole(false)}>{locale('ui_cancel')}</Button>
              <Button variant="solid" tone="accent" onClick={changeRole}>{locale('ui_update_role')}</Button>
            </div>
          </div>
        </Modal>
      )}

      {kicking && (
        <Modal title={locale('ui_kick_admin')} onClose={() => setKicking(false)} width="max-w-sm">
          <div className="space-y-3">
            <div>
              <label className="text-xs text-[var(--rdr-muted)]">{locale('ui_reason_for_kick_2')}</label>
              <input
                autoFocus value={kickReason} onChange={(e) => setKickReason(e.target.value)}
                className="w-full mt-1 bg-[var(--rdr-surface)] border border-[var(--rdr-border)] rounded-sm px-3 py-2 text-sm text-[var(--rdr-text)]"
              />
            </div>
            <div className="flex justify-end gap-2">
              <Button variant="ghost" onClick={() => setKicking(false)}>{locale('ui_cancel')}</Button>
              <Button
                variant="solid" tone="red" disabled={!kickReason.trim()}
                onClick={async () => { await act('kickPlayer', { reason: kickReason.trim() }, locale('ui_admin_kicked')); setKicking(false); onChanged(); }}
              >
                {locale('ui_kick')}
              </Button>
            </div>
          </div>
        </Modal>
      )}

      {removing && (
        <Modal title={locale('ui_remove_admin_access')} onClose={() => setRemoving(false)} width="max-w-sm">
          <p className="text-[var(--rdr-text)] text-sm mb-5">{locale('ui_remove_admin_access_confirm', admin.name)}</p>
          <div className="flex justify-end gap-2">
            <Button variant="ghost" onClick={() => setRemoving(false)}>{locale('ui_cancel')}</Button>
            <Button variant="solid" tone="red" onClick={removeAdmin}>{locale('ui_remove_access')}</Button>
          </div>
        </Modal>
      )}
    </div>
  );
}

function IdRow({ icon, label, value }: { icon: React.ReactNode; label: string; value?: string }) {
  const [copied, setCopied] = useState(false);
  return (
    <button
      disabled={!value}
      onClick={() => {
        if (!value) return;
        copyToClipboard(value);
        setCopied(true);
        setTimeout(() => setCopied(false), 1200);
      }}
      className="w-full flex items-center gap-3 px-3 py-2.5 rounded-sm text-left transition-colors hover:bg-white/5 disabled:hover:bg-transparent"
      style={{ background: 'var(--rdr-surface-2)' }}
    >
      <span className="w-8 h-8 rounded-sm flex items-center justify-center shrink-0 text-[var(--rdr-muted)]" style={{ background: 'var(--rdr-surface)' }}>{icon}</span>
      <span className="flex-1 min-w-0">
        <span className="block text-[var(--rdr-muted)] text-xs">{label}</span>
        <span className="block text-[var(--rdr-text)] text-sm font-medium truncate">{value || locale('ui_unavailable')}</span>
      </span>
      {value && <span className="text-xs text-[var(--rdr-faint)] shrink-0">{copied ? locale('ui_copied') : locale('ui_copy')}</span>}
    </button>
  );
}
