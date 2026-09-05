import { useEffect, useMemo, useState } from 'react';
import {
  Coins, Landmark, Wifi, Fingerprint, Cpu, MapPin, MessageCircle,
  Package, Plus, Search, ShieldAlert, History as HistoryIcon,
  HeartPulse, Sparkles, Skull, Snowflake, ArrowDownToLine, Eye, LogOut,
  Gavel, KeyRound, Wallet, Briefcase, Tag, UserRound, Cake, FileText,
  TrendingUp, TrendingDown, Ban as BanIcon, Trash2, PawPrint, Flame,
  Zap, ArrowUpToLine, Shuffle, BatteryLow, Link2, Wine, AlertTriangle, Check,
  Ghost, Footprints, Waves, Users,
} from 'lucide-react';
import { copyToClipboard, fetchNui } from '../hooks/useNui';
import { useToast } from './Toast';
import { Modal, ConfirmModal } from './Modal';
import { Dropdown } from './Dropdown';
import { Avatar } from './Avatar';
import { Button, type ButtonTone } from './Button';
import type { HistoryEntry, InventoryItemEntry, ItemCatalogEntry, OnlinePlayer, Permissions, PlayerDetail } from '../types';

interface PlayerManageModalProps {
  player: OnlinePlayer;
  permissions?: Permissions | null;
  onClose: () => void;
}

const mockDetail: PlayerDetail = {
  firstname: 'Test', lastname: 'Player', job: 'Sheriff', grade: 1, jobGradeName: 'Deputy',
  cash: 910, bloodmoney: 0, bank: 1200, valbank: 0, rhobank: 0, blkbank: 0, armbank: 0,
  citizenid: 'DEV1234', serverid: 1, role: 'admin', roleLabel: 'Admin',
  availablePermissions: [
    { value: 'god', label: 'Owner' }, { value: 'headadmin', label: 'Head Admin' }, { value: 'developer', label: 'Developer' },
    { value: 'admin', label: 'Admin' }, { value: 'mod', label: 'Moderator' }, { value: 'helper', label: 'Helper' },
  ],
  ping: 19, steamHex: 'steam:110000172ad57df', ip: '26.204.128.48',
  discordId: '458994322637848596', discordName: 'uiforc', discordAvatarUrl: undefined,
  items: [
    { slot: 1, name: 'onecent', label: '1787 One Cent Token', image: 'onecent.png', amount: 2, weight: 0.25 },
    { slot: 2, name: 'arrow_smallgame', label: 'Arrow Small Game', image: 'arrow_smallgame.png', amount: 2, weight: 0.25 },
    { slot: 3, name: 'weapon_boltactionrifle', label: 'BoltAction Rifle', image: 'weapon_boltactionrifle.png', amount: 1, weight: 4.08 },
  ],
};

const mockHistory: HistoryEntry[] = [
  { id: 31, citizenid: 'DEV1234', action: 'warn', reason: 'Fail RP near the saloon', admin_name: 'uiforc', duration_seconds: null, severity: 'medium', created_at: new Date().toISOString() },
  { id: 30, citizenid: 'DEV1234', action: 'kick', reason: 'testtt', admin_name: 'uiforc', duration_seconds: null, severity: null, created_at: new Date().toISOString() },
];

const mockCatalog: ItemCatalogEntry[] = [
  { name: 'bandage', label: 'Bandage', image: 'bandage.png', type: 'item', weight: 100, category: 'medical' },
  { name: 'weapon_pistol_m1899', label: 'Pistol M1899', image: 'weapon_pistol_m1899.png', type: 'weapon', weight: 1000, category: 'weapon_pistol' },
  { name: 'ammo_box_pistol', label: 'Ammo Box Pistol', image: 'ammo_box_pistol.png', type: 'item', weight: 100, category: 'ammo_pistol' },
  { name: 'fishing_rod', label: 'Fishing Rod', image: 'fishing_rod.png', type: 'item', weight: 500, category: 'fishing' },
];

function fmt(n: number) {
  return `$${Math.round(n).toLocaleString()}`;
}

export function PlayerManageModal({ player, permissions, onClose }: PlayerManageModalProps) {
  const toast = useToast();
  const [detail, setDetail] = useState<PlayerDetail | null>(null);
  const [tab, setTab] = useState<'overview' | 'actions' | 'inventory' | 'history'>('overview');

  const load = () => fetchNui<PlayerDetail>('getPlayerInfo', { id: player.id }, mockDetail).then(setDetail);
  useEffect(() => { load(); }, [player.id]);

  const act = async (event: string, extra: Record<string, unknown> = {}, successMsg?: string) => {
    await fetchNui(event, { id: player.id, ...extra }, { success: true });
    if (successMsg) toast.push({ type: 'success', title: successMsg });
  };

  const totalBank = detail ? detail.bank + detail.valbank + detail.rhobank + detail.blkbank + detail.armbank : 0;

  return (
    <div
      className="fixed inset-0 z-[100] flex items-center justify-center bg-black/60"
      onMouseDown={(e) => { if (e.target === e.currentTarget) onClose(); }}
    >
      <div
        className="w-full max-w-2xl mx-4 rounded-sm shadow-2xl overflow-hidden h-[640px] max-h-[85vh] flex flex-col"
        style={{ background: 'var(--rdr-panel)', border: '1px solid var(--rdr-border)' }}
      >
        <div className="flex items-center justify-between px-5 py-4 shrink-0" style={{ borderBottom: '1px solid var(--rdr-line)', background: 'var(--rdr-surface-2)' }}>
          <div className="flex items-center gap-3">
            <Avatar name={player.name} size={44} imageUrl={detail?.discordAvatarUrl} />
            <div>
              <h2 className="text-[var(--rdr-heading)] text-lg font-bold leading-tight" style={{ fontFamily: 'var(--font-display)' }}>{player.name}</h2>
              <p className="text-[var(--rdr-muted)] text-xs mt-0.5">{detail?.discordName ? `@${detail.discordName}` : `Server ID: ${player.id}`}</p>
              <div className="flex items-center gap-1.5 mt-1.5">
                {detail && (
                  <span className="px-1.5 py-0.5 rounded-sm text-[10px] font-semibold uppercase bg-[var(--rdr-accent-20)] text-[var(--rdr-accent-bright)]">{detail.roleLabel}</span>
                )}
                <span className="px-1.5 py-0.5 rounded-sm text-[10px] font-semibold bg-green-500/20 text-green-400">Online</span>
              </div>
            </div>
          </div>
          <button onClick={onClose} className="text-[var(--rdr-muted)] hover:text-[var(--rdr-heading)] text-sm px-2 py-1 rounded hover:bg-white/5 transition-colors">✕</button>
        </div>

        <div className="px-5 pt-3 shrink-0">
          <div className="flex gap-1 p-1 rounded-sm" style={{ background: 'var(--rdr-surface-2)' }}>
            {(['overview', 'actions', 'inventory', 'history'] as const).map((t) => (
              <button
                key={t}
                onClick={() => setTab(t)}
                className={`flex-1 px-3 py-1.5 rounded-sm text-xs font-medium capitalize transition-colors ${
                  tab === t ? 'bg-white/10 text-[var(--rdr-heading)]' : 'text-[var(--rdr-muted)] hover:text-[var(--rdr-heading)]'
                }`}
              >
                {t}
              </button>
            ))}
          </div>
        </div>

        <div className="p-5 overflow-y-auto flex-1 min-h-0">
          {!detail ? (
            <p className="text-[var(--rdr-faint)] text-sm text-center py-8">Loading...</p>
          ) : tab === 'overview' ? (
            <OverviewTab detail={detail} totalBank={totalBank} toast={toast} />
          ) : tab === 'actions' ? (
            <ActionsTab player={player} detail={detail} permissions={permissions} act={act} reload={load} onClose={onClose} toast={toast} />
          ) : tab === 'inventory' ? (
            <InventoryTab player={player} detail={detail} reload={load} toast={toast} />
          ) : (
            <HistoryTab citizenid={detail.citizenid} canManageHistory={permissions?.canManageHistory ?? false} />
          )}
        </div>
      </div>
    </div>
  );
}

function StatCard({ label, value, icon, color }: { label: string; value: string; icon: React.ReactNode; color: string }) {
  return (
    <div className="rounded-lg p-3 flex items-center justify-between" style={{ background: 'var(--rdr-surface)', border: '1px solid var(--rdr-border)' }}>
      <div>
        <p className="text-2xl font-bold text-[var(--rdr-heading)]">{value}</p>
        <p className="text-[var(--rdr-muted)] text-xs mt-1">{label}</p>
      </div>
      <div className="w-8 h-8 rounded-lg flex items-center justify-center shrink-0" style={{ background: `${color}33`, color }}>
        {icon}
      </div>
    </div>
  );
}

function CopyRow({ icon, label, value }: { icon: React.ReactNode; label: string; value: string }) {
  const [copied, setCopied] = useState(false);
  return (
    <button
      onClick={() => {
        copyToClipboard(value);
        setCopied(true);
        setTimeout(() => setCopied(false), 1200);
      }}
      className="w-full flex items-center gap-3 px-3 py-2.5 rounded-sm text-left transition-colors hover:bg-white/5"
      style={{ background: 'var(--rdr-surface-2)' }}
    >
      <span className="w-8 h-8 rounded-sm flex items-center justify-center shrink-0 text-[var(--rdr-muted)]" style={{ background: 'var(--rdr-surface)' }}>{icon}</span>
      <span className="flex-1 min-w-0">
        <span className="block text-[var(--rdr-muted)] text-xs">{label}</span>
        <span className="block text-[var(--rdr-text)] text-sm font-medium truncate">{value}</span>
      </span>
      <span className="text-xs text-[var(--rdr-faint)] shrink-0">{copied ? 'Copied' : 'Copy'}</span>
    </button>
  );
}

function OverviewTab({ detail, totalBank, toast }: { detail: PlayerDetail; totalBank: number; toast: ReturnType<typeof useToast> }) {
  void toast;
  return (
    <div className="space-y-4">
      <div className="grid grid-cols-3 gap-3">
        <StatCard label="Cash" value={fmt(detail.cash)} icon={<Coins size={16} />} color="#7fc47c" />
        <StatCard label="Total Bank" value={fmt(totalBank)} icon={<Landmark size={16} />} color="#e8b25a" />
        <StatCard label="Ping" value={`${detail.ping}ms`} icon={<Wifi size={16} />} color="#6fa8dc" />
      </div>

      <div>
        <p className="text-[var(--rdr-muted)] text-xs uppercase tracking-wider font-medium mb-2">Job Details</p>
        <div className="grid grid-cols-2 gap-2">
          <div className="rounded-sm p-2.5" style={{ background: 'var(--rdr-surface-2)' }}>
            <p className="text-[var(--rdr-muted)] text-xs">Job</p>
            <p className="text-[var(--rdr-text)] text-sm font-medium capitalize">{detail.job}</p>
          </div>
          <div className="rounded-sm p-2.5" style={{ background: 'var(--rdr-surface-2)' }}>
            <p className="text-[var(--rdr-muted)] text-xs">Job Grade</p>
            <p className="text-[var(--rdr-text)] text-sm font-medium">{detail.jobGradeName}</p>
          </div>
        </div>
      </div>

      <div>
        <p className="text-[var(--rdr-muted)] text-xs uppercase tracking-wider font-medium mb-2">Player Details</p>
        <div className="space-y-1.5">
          <CopyRow icon={<Fingerprint size={14} />} label="Citizen ID" value={detail.citizenid} />
          <CopyRow icon={<Cpu size={14} />} label="Steam Hex" value={detail.steamHex || 'Unavailable'} />
          <CopyRow icon={<MapPin size={14} />} label="IP Address" value={detail.ip || 'Unavailable'} />
          <CopyRow icon={<MessageCircle size={14} />} label="Discord ID" value={detail.discordId ? `${detail.discordId}${detail.discordName ? ` (${detail.discordName})` : ''}` : 'Unavailable'} />
        </div>
      </div>
    </div>
  );
}

function ActionButton({ label, icon, onClick, tone = 'default' }: { label: string; icon?: React.ReactNode; onClick: () => void; tone?: ButtonTone }) {
  return (
    <Button variant="outline" tone={tone} onClick={onClick} className="justify-start">
      {icon}{label}
    </Button>
  );
}

function ActionSection({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div>
      <p className="text-[var(--rdr-muted)] text-xs uppercase tracking-wider font-medium mb-2">{title}</p>
      <div className="grid grid-cols-3 gap-2">{children}</div>
    </div>
  );
}

type ActFn = (event: string, extra?: Record<string, unknown>, successMsg?: string) => Promise<void>;

function ActionsTab({
  player, detail, permissions, act, reload, onClose, toast,
}: {
  player: OnlinePlayer; detail: PlayerDetail; permissions?: Permissions | null; act: ActFn; reload: () => void; onClose: () => void; toast: ReturnType<typeof useToast>;
}) {
  const [form, setForm] = useState<null | 'kick' | 'ban' | 'warn' | 'economy' | 'permission' | 'job' | 'charfield' | 'xp'>(null);
  const [charField, setCharField] = useState<{ field: string; label: string } | null>(null);
  const [xpDirection, setXpDirection] = useState<'add' | 'remove'>('add');

  const atLeastMod = permissions?.atLeastMod ?? false;
  const atLeastAdmin = permissions?.atLeastAdmin ?? false;
  const canManageAdmins = permissions?.canManageAdmins ?? false;
  const fullAccess = permissions?.fullAccess ?? false;

  return (
    <div className="space-y-4">
      <ActionSection title="Player Actions">
        <ActionButton tone="green" icon={<HeartPulse />} label="Revive" onClick={() => act('revivePlayer', {}, 'Player revived')} />
        <ActionButton tone="green" icon={<Sparkles />} label="Heal" onClick={() => act('healPlayer', {}, 'Player healed')} />
        <ActionButton tone="red" icon={<Skull />} label="Kill" onClick={() => act('killPlayer', {}, 'Player killed')} />
        <ActionButton icon={<Snowflake />} label="Toggle Freeze" onClick={() => act('toggleFreeze', {}, 'Freeze toggled')} />
        <ActionButton icon={<MapPin />} label="GoTo Player" onClick={() => act('goToPlayer')} />
        <ActionButton icon={<ArrowDownToLine />} label="Bring Player" onClick={() => act('bringPlayer')} />
        <ActionButton icon={<Eye />} label="Toggle Spectate" onClick={() => act('toggleSpectate')} />
        <ActionButton icon={<Package />} label="Open Inventory" onClick={() => act('openInventory')} />
      </ActionSection>

      {atLeastMod && (
        <ActionSection title="Moderation">
          <ActionButton tone="amber" icon={<AlertTriangle />} label="Warn" onClick={() => setForm('warn')} />
          <ActionButton tone="red" icon={<LogOut />} label="Kick" onClick={() => setForm('kick')} />
          {atLeastAdmin && <ActionButton tone="red" icon={<Gavel />} label="Ban" onClick={() => setForm('ban')} />}
          {canManageAdmins && <ActionButton tone="amber" icon={<KeyRound />} label="Set Permission" onClick={() => setForm('permission')} />}
        </ActionSection>
      )}

      {fullAccess && (
        <ActionSection title="Economy">
          <ActionButton tone="green" icon={<Wallet />} label="Give / Remove Money" onClick={() => setForm('economy')} />
        </ActionSection>
      )}

      <ActionSection title="Character">
        <ActionButton icon={<Briefcase />} label="Set Job" onClick={() => setForm('job')} />
        <ActionButton icon={<Tag />} label="Set Nickname" onClick={() => { setCharField({ field: 'nickname', label: 'Nickname' }); setForm('charfield'); }} />
        <ActionButton icon={<UserRound />} label="Set Firstname" onClick={() => { setCharField({ field: 'firstname', label: 'Firstname' }); setForm('charfield'); }} />
        <ActionButton icon={<UserRound />} label="Set Lastname" onClick={() => { setCharField({ field: 'lastname', label: 'Lastname' }); setForm('charfield'); }} />
        <ActionButton icon={<Cake />} label="Set Age" onClick={() => { setCharField({ field: 'age', label: 'Age' }); setForm('charfield'); }} />
        <ActionButton icon={<FileText />} label="Set Description" onClick={() => { setCharField({ field: 'description', label: 'Description' }); setForm('charfield'); }} />
        <ActionButton tone="green" icon={<TrendingUp />} label="Add XP" onClick={() => { setXpDirection('add'); setForm('xp'); }} />
        <ActionButton tone="red" icon={<TrendingDown />} label="Remove XP" onClick={() => { setXpDirection('remove'); setForm('xp'); }} />
      </ActionSection>

      {atLeastAdmin && (
        <ActionSection title="Clear Actions">
          <ActionButton tone="red" icon={<BanIcon />} label="Clear Weapons" onClick={() => act('clearWeapons', {}, 'Weapons cleared')} />
          <ActionButton tone="red" icon={<Trash2 />} label="Clear Items" onClick={() => act('clearItems', {}, 'Inventory cleared')} />
        </ActionSection>
      )}

      {atLeastMod && (
        <ActionSection title="Troll Actions">
          <ActionButton tone="amber" icon={<PawPrint />} label="Wild Attack" onClick={() => act('wildAttack')} />
          <ActionButton tone="amber" icon={<Flame />} label="Set on Fire" onClick={() => act('setOnFire')} />
          <ActionButton tone="amber" icon={<Zap />} label="Lightning" onClick={() => act('lightningPlayer')} />
          <ActionButton tone="amber" icon={<ArrowUpToLine />} label="To Heaven" onClick={() => act('toHeavenPlayer')} />
          <ActionButton tone="amber" icon={<Shuffle />} label="Ragdoll" onClick={() => act('ragdollPlayer')} />
          <ActionButton tone="amber" icon={<BatteryLow />} label="Drain Stamina" onClick={() => act('drainStaminaPlayer')} />
          <ActionButton tone="amber" icon={<Link2 />} label="Handcuff" onClick={() => act('handcuffPlayer')} />
          <ActionButton tone="amber" icon={<Wine />} label="Drunk" onClick={() => act('drunkPlayer')} />
          <ActionButton tone="amber" icon={<Ghost />} label="Jump Scare" onClick={() => act('jumpScarePlayer')} />
          <ActionButton tone="amber" icon={<Footprints />} label="Horse Buck" onClick={() => act('horseBuckPlayer')} />
          <ActionButton tone="amber" icon={<Waves />} label="Haunted" onClick={() => act('hauntedPlayer')} />
          <ActionButton tone="amber" icon={<Users />} label="Make Everyone Attack" onClick={() => act('everyoneAttackPlayer')} />
        </ActionSection>
      )}

      {form === 'warn' && (
        <WarnForm onCancel={() => setForm(null)} onSubmit={async (reason, severity) => {
          await act('warnPlayer', { reason, severity });
          toast.push({ type: 'success', title: 'Player warned' });
          setForm(null);
          reload();
        }} />
      )}
      {form === 'kick' && (
        <KickForm onCancel={() => setForm(null)} onSubmit={async (reason) => {
          await act('kickPlayer', { reason });
          toast.push({ type: 'success', title: 'Player kicked' });
          setForm(null);
          onClose();
        }} />
      )}
      {form === 'ban' && (
        <BanForm onCancel={() => setForm(null)} onSubmit={async (type, duration, reason) => {
          await act('banPlayer', { type, duration, reason });
          toast.push({ type: 'success', title: 'Player banned' });
          setForm(null);
          onClose();
        }} />
      )}
      {form === 'permission' && (
        <PermissionForm
          levels={detail.availablePermissions}
          current={detail.role}
          onCancel={() => setForm(null)}
          onSubmit={async (level) => {
            await act('setPermission', { level });
            toast.push({ type: 'success', title: 'Permission updated' });
            setForm(null);
            reload();
          }}
        />
      )}
      {form === 'economy' && (
        <EconomyForm
          onCancel={() => setForm(null)}
          onSubmit={async (action, type, amount) => {
            await act(action === 'give' ? 'giveMoney' : 'removeMoney', { type, amount });
            toast.push({ type: 'success', title: action === 'give' ? 'Money given' : 'Money removed' });
            setForm(null);
            reload();
          }}
        />
      )}
      {form === 'job' && (
        <JobForm onCancel={() => setForm(null)} onSubmit={async (job, grade) => {
          await act('setJob', { job, grade });
          toast.push({ type: 'success', title: 'Job updated' });
          setForm(null);
          reload();
        }} />
      )}
      {form === 'charfield' && charField && (
        <TextFieldForm
          label={charField.label}
          onCancel={() => setForm(null)}
          onSubmit={async (value) => {
            await act('setCharField', { field: charField.field, value });
            toast.push({ type: 'success', title: `${charField.label} updated` });
            setForm(null);
            reload();
          }}
        />
      )}
      {form === 'xp' && (
        <XpForm
          direction={xpDirection}
          onCancel={() => setForm(null)}
          onSubmit={async (amount) => {
            await act('adjustXp', { direction: xpDirection, amount });
            toast.push({ type: 'success', title: xpDirection === 'add' ? 'XP added' : 'XP removed' });
            setForm(null);
          }}
        />
      )}
      <p className="text-[var(--rdr-faint)] text-[11px]">Server ID: {player.id}</p>
    </div>
  );
}

const inputCls = 'w-full mt-1 bg-[var(--rdr-surface)] border border-[var(--rdr-border)] rounded-sm px-3 py-2 text-sm text-[var(--rdr-text)]';

const severityOptions = [
  { value: 'low', label: 'Low' },
  { value: 'medium', label: 'Medium' },
  { value: 'high', label: 'High' },
];

function WarnForm({ onCancel, onSubmit }: { onCancel: () => void; onSubmit: (reason: string, severity: string) => void }) {
  const [reason, setReason] = useState('');
  const [severity, setSeverity] = useState('medium');
  return (
    <Modal title="Warn Player" onClose={onCancel} width="max-w-sm">
      <div className="space-y-3">
        <div>
          <label className="text-xs text-[var(--rdr-muted)]">Severity</label>
          <div className="mt-1"><Dropdown value={severity} onChange={setSeverity} options={severityOptions} /></div>
        </div>
        <div>
          <label className="text-xs text-[var(--rdr-muted)]">Reason</label>
          <input autoFocus value={reason} onChange={(e) => setReason(e.target.value)} className={inputCls} placeholder="Reason for warning" />
        </div>
        <div className="flex justify-end gap-2">
          <Button variant="ghost" onClick={onCancel}>Cancel</Button>
          <Button variant="solid" tone="amber" disabled={!reason.trim()} onClick={() => onSubmit(reason.trim(), severity)}>Warn Player</Button>
        </div>
      </div>
    </Modal>
  );
}

function KickForm({ onCancel, onSubmit }: { onCancel: () => void; onSubmit: (reason: string) => void }) {
  const [reason, setReason] = useState('');
  return (
    <Modal title="Kick Player" onClose={onCancel} width="max-w-sm">
      <div className="space-y-3">
        <div>
          <label className="text-xs text-[var(--rdr-muted)]">Reason for Kick</label>
          <input autoFocus value={reason} onChange={(e) => setReason(e.target.value)} className={inputCls} placeholder="Reason for kick" />
        </div>
        <div className="flex justify-end gap-2">
          <Button variant="ghost" onClick={onCancel}>Cancel</Button>
          <Button variant="solid" tone="red" disabled={!reason.trim()} onClick={() => onSubmit(reason.trim())}>Kick Player</Button>
        </div>
      </div>
    </Modal>
  );
}

const banDurations = [
  { value: '3600', label: '1 Hour' }, { value: '21600', label: '6 Hours' }, { value: '43200', label: '12 Hours' },
  { value: '86400', label: '1 Day' }, { value: '259200', label: '3 Days' }, { value: '604800', label: '1 Week' },
  { value: '2678400', label: '1 Month' }, { value: '8035200', label: '3 Months' },
  { value: '16070400', label: '6 Months' }, { value: '32140800', label: '1 Year' },
];
const banTypeOptions = [{ value: 'permanent' as const, label: 'Permanent' }, { value: 'temporary' as const, label: 'Temporary' }];

function BanForm({ onCancel, onSubmit }: { onCancel: () => void; onSubmit: (type: string, duration: string, reason: string) => void }) {
  const [type, setType] = useState<'permanent' | 'temporary'>('permanent');
  const [duration, setDuration] = useState(banDurations[0].value);
  const [reason, setReason] = useState('');
  return (
    <Modal title="Ban Player" onClose={onCancel} width="max-w-sm">
      <div className="space-y-3">
        <div>
          <label className="text-xs text-[var(--rdr-muted)]">Ban Type</label>
          <div className="mt-1"><Dropdown value={type} onChange={setType} options={banTypeOptions} /></div>
        </div>
        {type === 'temporary' && (
          <div>
            <label className="text-xs text-[var(--rdr-muted)]">Duration</label>
            <div className="mt-1"><Dropdown value={duration} onChange={setDuration} options={banDurations} /></div>
          </div>
        )}
        <div>
          <label className="text-xs text-[var(--rdr-muted)]">Reason</label>
          <input value={reason} onChange={(e) => setReason(e.target.value)} className={inputCls} placeholder="Reason for ban" />
        </div>
        <div className="flex justify-end gap-2">
          <Button variant="ghost" onClick={onCancel}>Cancel</Button>
          <Button
            variant="solid"
            tone="red"
            disabled={!reason.trim()}
            onClick={() => onSubmit(type, type === 'permanent' ? '99999999999' : duration, reason.trim())}
          >
            Ban Player
          </Button>
        </div>
      </div>
    </Modal>
  );
}

function PermissionForm({ levels, current, onCancel, onSubmit }: { levels: { value: string; label: string }[]; current: string; onCancel: () => void; onSubmit: (level: string) => void }) {
  const options = useMemo(() => [{ value: 'user', label: 'User' }, ...levels], [levels]);
  const [level, setLevel] = useState(current);
  return (
    <Modal title="Set Permission" onClose={onCancel} width="max-w-sm">
      <div className="space-y-3">
        <div>
          <label className="text-xs text-[var(--rdr-muted)]">Permission Level</label>
          <div className="mt-1"><Dropdown value={level} onChange={setLevel} options={options} /></div>
        </div>
        <div className="flex justify-end gap-2">
          <Button variant="ghost" onClick={onCancel}>Cancel</Button>
          <Button variant="solid" tone="accent" onClick={() => onSubmit(level)}>Set Permission</Button>
        </div>
      </div>
    </Modal>
  );
}

const moneyTypeOptions = [
  { value: 'cash', label: 'Cash' }, { value: 'bank', label: 'Std Bank' }, { value: 'valbank', label: 'Val Bank' },
  { value: 'rhobank', label: 'Rho Bank' }, { value: 'blkbank', label: 'Blk Bank' }, { value: 'armbank', label: 'Arm Bank' },
  { value: 'bloodmoney', label: 'Blood Money' },
];

function EconomyForm({ onCancel, onSubmit }: { onCancel: () => void; onSubmit: (action: 'give' | 'remove', type: string, amount: number) => void }) {
  const [type, setType] = useState('cash');
  const [amount, setAmount] = useState<number | ''>('');
  const numericAmount = Number(amount) || 0;
  return (
    <Modal title="Give / Remove Money" onClose={onCancel} width="max-w-sm">
      <div className="space-y-3">
        <div className="grid grid-cols-2 gap-3">
          <div>
            <label className="text-xs text-[var(--rdr-muted)]">Account Type</label>
            <div className="mt-1"><Dropdown value={type} onChange={setType} options={moneyTypeOptions} /></div>
          </div>
          <div>
            <label className="text-xs text-[var(--rdr-muted)]">Amount</label>
            <input type="number" min={0} value={amount} onChange={(e) => setAmount(e.target.value === '' ? '' : Number(e.target.value))} className={inputCls} />
          </div>
        </div>
        <div className="flex justify-end gap-2">
          <Button variant="ghost" onClick={onCancel}>Cancel</Button>
          <Button variant="solid" tone="red" disabled={numericAmount <= 0} onClick={() => onSubmit('remove', type, numericAmount)}>Remove</Button>
          <Button variant="solid" tone="accent" disabled={numericAmount <= 0} onClick={() => onSubmit('give', type, numericAmount)}>Give</Button>
        </div>
      </div>
    </Modal>
  );
}

function JobForm({ onCancel, onSubmit }: { onCancel: () => void; onSubmit: (job: string, grade: string) => void }) {
  const [job, setJob] = useState('');
  const [grade, setGrade] = useState('0');
  return (
    <Modal title="Set Job" onClose={onCancel} width="max-w-sm">
      <div className="space-y-3">
        <div className="grid grid-cols-2 gap-3">
          <div>
            <label className="text-xs text-[var(--rdr-muted)]">Job Name</label>
            <input value={job} onChange={(e) => setJob(e.target.value)} className={inputCls} placeholder="e.g. sheriff" />
          </div>
          <div>
            <label className="text-xs text-[var(--rdr-muted)]">Grade</label>
            <input type="number" min={0} value={grade} onChange={(e) => setGrade(e.target.value)} className={inputCls} />
          </div>
        </div>
        <div className="flex justify-end gap-2">
          <Button variant="ghost" onClick={onCancel}>Cancel</Button>
          <Button variant="solid" tone="accent" disabled={!job.trim()} onClick={() => onSubmit(job.trim().toLowerCase(), grade)}>Set Job</Button>
        </div>
      </div>
    </Modal>
  );
}

function TextFieldForm({ label, onCancel, onSubmit }: { label: string; onCancel: () => void; onSubmit: (value: string) => void }) {
  const [value, setValue] = useState('');
  return (
    <Modal title={`Set ${label}`} onClose={onCancel} width="max-w-sm">
      <div className="space-y-3">
        <div>
          <label className="text-xs text-[var(--rdr-muted)]">{label}</label>
          <input autoFocus value={value} onChange={(e) => setValue(e.target.value)} className={inputCls} placeholder={`New ${label.toLowerCase()}`} />
        </div>
        <div className="flex justify-end gap-2">
          <Button variant="ghost" onClick={onCancel}>Cancel</Button>
          <Button variant="solid" tone="accent" disabled={!value.trim()} onClick={() => onSubmit(value.trim())}>Save</Button>
        </div>
      </div>
    </Modal>
  );
}

function XpForm({ direction, onCancel, onSubmit }: { direction: 'add' | 'remove'; onCancel: () => void; onSubmit: (amount: number) => void }) {
  const [amount, setAmount] = useState<number | ''>('');
  const numericAmount = Number(amount) || 0;
  return (
    <Modal title={direction === 'add' ? 'Add XP' : 'Remove XP'} onClose={onCancel} width="max-w-sm">
      <div className="space-y-3">
        <div>
          <label className="text-xs text-[var(--rdr-muted)]">Amount</label>
          <input type="number" min={0} value={amount} onChange={(e) => setAmount(e.target.value === '' ? '' : Number(e.target.value))} className={inputCls} />
        </div>
        <div className="flex justify-end gap-2">
          <Button variant="ghost" onClick={onCancel}>Cancel</Button>
          <Button variant="solid" tone={direction === 'add' ? 'accent' : 'red'} disabled={numericAmount <= 0} onClick={() => onSubmit(numericAmount)}>
            {direction === 'add' ? 'Add XP' : 'Remove XP'}
          </Button>
        </div>
      </div>
    </Modal>
  );
}

function ItemIcon({ image, label, size = 36 }: { image?: string; label: string; size?: number }) {
  const [failed, setFailed] = useState(false);
  if (!image || failed) {
    return (
      <div className="rounded-sm flex items-center justify-center shrink-0" style={{ width: size, height: size, background: 'var(--rdr-surface)' }}>
        <Package size={size * 0.5} className="text-[var(--rdr-faint)]" />
      </div>
    );
  }
  return (
    <img
      src={`nui://rsg-inventory/html/images/${image}`}
      alt={label}
      onError={() => setFailed(true)}
      className="rounded-sm object-contain shrink-0"
      style={{ width: size, height: size, background: 'var(--rdr-surface)' }}
    />
  );
}

function InventoryTab({ player, detail, reload, toast }: { player: OnlinePlayer; detail: PlayerDetail; reload: () => void; toast: ReturnType<typeof useToast> }) {
  const [removeTarget, setRemoveTarget] = useState<InventoryItemEntry | null>(null);
  const [showAdd, setShowAdd] = useState(false);

  return (
    <div className="space-y-2">
      <Button variant="outline" tone="green" fullWidth onClick={() => setShowAdd(true)}>
        <Plus /> Select Item to Add
      </Button>

      {detail.items.length === 0 ? (
        <p className="text-[var(--rdr-faint)] text-sm text-center py-8">This player's inventory is empty.</p>
      ) : (
        <div className="space-y-1.5">
          {detail.items.map((item) => (
            <button
              key={item.slot}
              onClick={() => setRemoveTarget(item)}
              className="w-full flex items-center gap-3 px-3 py-2 rounded-sm text-left transition-colors hover:bg-white/5"
              style={{ background: 'var(--rdr-surface-2)' }}
            >
              <ItemIcon image={item.image} label={item.label} />
              <div className="flex-1 min-w-0">
                <p className="text-[var(--rdr-text)] text-sm font-medium truncate">{item.label}</p>
                <p className="text-[var(--rdr-faint)] text-xs">x{item.amount} ({item.weight})</p>
              </div>
            </button>
          ))}
        </div>
      )}

      {removeTarget && (
        <RemoveItemModal
          item={removeTarget}
          onClose={() => setRemoveTarget(null)}
          onRemove={async (amount) => {
            await fetchNui('removePlayerItem', { id: player.id, item: removeTarget.name, amount, slot: removeTarget.slot }, { success: true });
            toast.push({ type: 'success', title: 'Item removed' });
            setRemoveTarget(null);
            reload();
          }}
        />
      )}
      {showAdd && (
        <ItemPickerModal
          onClose={() => setShowAdd(false)}
          onAdd={async (items) => {
            for (const { item, quantity } of items) {
              await fetchNui('giveItem', { id: player.id, item, quantity }, { success: true });
            }
            toast.push({ type: 'success', title: `${items.length} item${items.length === 1 ? '' : 's'} given` });
            setShowAdd(false);
            reload();
          }}
        />
      )}
    </div>
  );
}

function RemoveItemModal({ item, onClose, onRemove }: { item: InventoryItemEntry; onClose: () => void; onRemove: (amount: number) => void }) {
  const [amount, setAmount] = useState<number | ''>(1);
  const clampedAmount = Math.min(item.amount, Math.max(1, Number(amount) || 0));
  return (
    <Modal title="Remove Item" subtitle={`Remove ${item.label} from player inventory`} onClose={onClose} width="max-w-sm">
      <div className="flex items-center gap-3 rounded-sm p-3 mb-4" style={{ background: 'var(--rdr-surface-2)' }}>
        <ItemIcon image={item.image} label={item.label} />
        <div>
          <p className="text-[var(--rdr-text)] text-sm font-medium">{item.label}</p>
          <p className="text-[var(--rdr-faint)] text-xs">Available: {item.amount}</p>
        </div>
      </div>
      <label className="text-xs text-[var(--rdr-muted)]">Amount to Remove</label>
      <input
        type="number" min={1} max={item.amount} value={amount}
        onChange={(e) => setAmount(e.target.value === '' ? '' : Number(e.target.value))}
        onBlur={() => setAmount(clampedAmount)}
        className={inputCls}
      />
      <p className="text-[var(--rdr-faint)] text-xs mt-1">Maximum: {item.amount}</p>
      <div className="flex justify-end gap-2 mt-4">
        <Button variant="ghost" onClick={onClose}>Cancel</Button>
        <Button variant="outline" tone="red" onClick={() => onRemove(item.amount)}>Remove All</Button>
        <Button variant="solid" tone="red" disabled={clampedAmount <= 0} onClick={() => onRemove(clampedAmount)}>Remove {clampedAmount}</Button>
      </div>
    </Modal>
  );
}

const catalogFilterOptions = [
  { value: 'all', label: 'All Categories' },
  { value: 'ammo', label: 'Ammo' },
  { value: 'consumable', label: 'Consumable' },
  { value: 'financial', label: 'Financial' },
  { value: 'fishing', label: 'Fishing' },
  { value: 'horse', label: 'Horse' },
  { value: 'medical', label: 'Medical' },
  { value: 'resource', label: 'Resource' },
  { value: 'tools', label: 'Tools' },
  { value: 'weapon_kit', label: 'Accessories' },
  { value: 'weapons', label: 'Weapons' },
  { value: 'other', label: 'Other' },
];

// items.lua's `category` field is fine-grained (ammo_pistol, weapon_revolver, ...) —
// collapse it down to the broad buckets the category filter above offers.
function broadCategory(raw?: string): string {
  if (!raw) return 'other';
  if (raw.startsWith('ammo_')) return 'ammo';
  if (raw === 'weapon_kit') return 'weapon_kit';
  if (raw.startsWith('weapon_')) return 'weapons';
  if (['consumable', 'financial', 'fishing', 'horse', 'medical', 'resource', 'tools'].includes(raw)) return raw;
  return 'other';
}

function ItemPickerModal({ onClose, onAdd }: { onClose: () => void; onAdd: (items: { item: string; quantity: number }[]) => void }) {
  const [catalog, setCatalog] = useState<ItemCatalogEntry[]>([]);
  const [query, setQuery] = useState('');
  const [category, setCategory] = useState('all');
  const [count, setCount] = useState<number | ''>(1);
  const clampedCount = Math.max(1, Number(count) || 0);
  const [selected, setSelected] = useState<ItemCatalogEntry[]>([]);
  const [page, setPage] = useState(1);
  const perPage = 16;

  useEffect(() => { fetchNui<ItemCatalogEntry[]>('getAllItems', {}, mockCatalog).then(setCatalog); }, []);

  const filtered = useMemo(() => catalog.filter((i) => {
    if (category !== 'all' && broadCategory(i.category) !== category) return false;
    if (query && !i.label.toLowerCase().includes(query.toLowerCase())) return false;
    return true;
  }), [catalog, category, query]);

  useEffect(() => { setPage(1); }, [query, category]);

  const totalPages = Math.max(1, Math.ceil(filtered.length / perPage));
  const pageItems = filtered.slice((page - 1) * perPage, page * perPage);

  const toggleSelected = (item: ItemCatalogEntry) => {
    setSelected((prev) => (
      prev.some((i) => i.name === item.name)
        ? prev.filter((i) => i.name !== item.name)
        : [...prev, item]
    ));
  };

  return (
    <Modal title="Select Item to Add" subtitle={`Choose one or more items to add to player inventory (${filtered.length} items found)`} onClose={onClose} width="max-w-3xl">
      <div className="flex gap-2 mb-2">
        <div className="relative flex-1">
          <Search size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-[var(--rdr-faint)]" />
          <input value={query} onChange={(e) => setQuery(e.target.value)} placeholder="Search items..." className="w-full pl-9 pr-3 py-2 bg-[var(--rdr-surface)] border border-[var(--rdr-border)] rounded-sm text-sm text-[var(--rdr-text)]" />
        </div>
        <Dropdown className="w-40 shrink-0" value={category} onChange={setCategory} options={catalogFilterOptions} />
        <input
          type="number" min={1} value={count}
          onChange={(e) => setCount(e.target.value === '' ? '' : Number(e.target.value))}
          onBlur={() => setCount(clampedCount)}
          className="w-20 shrink-0 bg-[var(--rdr-surface)] border border-[var(--rdr-border)] rounded-sm px-2 py-2 text-sm text-[var(--rdr-text)]"
          title="Quantity per item"
        />
      </div>

      <div className="flex items-center justify-between mb-2 h-5">
        {selected.length > 0 ? (
          <>
            <span className="text-xs text-[var(--rdr-heading)]">{selected.length} item{selected.length === 1 ? '' : 's'} selected</span>
            <button onClick={() => setSelected([])} className="text-xs text-[var(--rdr-faint)] hover:text-[var(--rdr-muted)]">Clear selection</button>
          </>
        ) : (
          <span className="text-xs text-[var(--rdr-faint)]">Click items to select multiple</span>
        )}
      </div>

      <div className="grid grid-cols-4 gap-2 content-start items-start min-h-[280px]">
        {pageItems.map((item) => {
          const isSelected = selected.some((i) => i.name === item.name);
          return (
            <button
              key={item.name}
              onClick={() => toggleSelected(item)}
              className={`relative flex flex-col items-center gap-2 p-3 rounded-sm border text-center transition-colors ${
                isSelected ? 'border-[var(--rdr-heading)] bg-white/10' : 'border-[var(--rdr-border)] hover:border-[var(--rdr-muted)]'
              }`}
              style={{ background: isSelected ? undefined : 'var(--rdr-surface-2)' }}
            >
              {isSelected && (
                <span className="absolute top-1.5 right-1.5 w-4 h-4 rounded-full flex items-center justify-center bg-[var(--rdr-heading)]">
                  <Check size={11} className="text-black" />
                </span>
              )}
              <ItemIcon image={item.image} label={item.label} size={40} />
              <span className="text-xs font-medium text-[var(--rdr-text)] truncate w-full">{item.label}</span>
              <span className="text-[10px] text-[var(--rdr-faint)] truncate w-full">{item.name.toUpperCase()}</span>
              <span className="px-1.5 py-0.5 rounded-sm text-[10px] bg-[var(--rdr-red-15)] text-[var(--rdr-red-bright)] capitalize">
                {catalogFilterOptions.find((o) => o.value === broadCategory(item.category))?.label ?? 'Other'}
              </span>
            </button>
          );
        })}
        {pageItems.length === 0 && <p className="col-span-4 text-center text-[var(--rdr-faint)] text-sm py-8">No items found</p>}
      </div>

      <div className="flex items-center justify-between mt-4 pt-4 border-t border-[var(--rdr-line)]">
        <Button variant="ghost" onClick={onClose}>Cancel</Button>
        <div className="flex items-center gap-2">
          <span className="text-[var(--rdr-faint)] text-xs">{filtered.length} items total</span>
          <Button variant="outline" disabled={page <= 1} onClick={() => setPage((p) => p - 1)} className="text-xs px-2.5 py-1.5">Previous</Button>
          <span className="text-xs text-[var(--rdr-muted)]">Page {page} / {totalPages}</span>
          <Button variant="outline" disabled={page >= totalPages} onClick={() => setPage((p) => p + 1)} className="text-xs px-2.5 py-1.5">Next</Button>
        </div>
        <Button
          variant="solid"
          tone="accent"
          disabled={selected.length === 0}
          onClick={() => onAdd(selected.map((s) => ({ item: s.name, quantity: clampedCount })))}
        >
          Add {selected.length} Item{selected.length === 1 ? '' : 's'} to Player
        </Button>
      </div>
    </Modal>
  );
}

const historyIcon: Record<string, React.ReactNode> = {
  ban: <ShieldAlert size={16} className="text-[var(--rdr-red-bright)]" />,
  kick: <ShieldAlert size={16} className="text-amber-400" />,
  warn: <AlertTriangle size={16} className="text-amber-400" />,
};

const historyLabel: Record<string, string> = { ban: 'Ban', kick: 'Kick', warn: 'Warning' };
const historyBadgeCls: Record<string, string> = {
  ban: 'bg-[var(--rdr-red-20)] text-[var(--rdr-red-bright)]',
  kick: 'bg-amber-500/20 text-amber-400',
  warn: 'bg-amber-500/20 text-amber-400',
};

function HistoryTab({ citizenid, canManageHistory }: { citizenid: string; canManageHistory: boolean }) {
  const toast = useToast();
  const [history, setHistory] = useState<HistoryEntry[] | null>(null);
  const [deleteTarget, setDeleteTarget] = useState<HistoryEntry | null>(null);

  const load = () => fetchNui<HistoryEntry[]>('getPlayerHistory', { citizenid }, mockHistory).then(setHistory);
  useEffect(() => { load(); }, [citizenid]);

  const confirmDelete = async () => {
    if (!deleteTarget) return;
    const res = await fetchNui<{ success: boolean }>('deleteHistoryEntry', { id: deleteTarget.id }, { success: true });
    if (res.success) {
      toast.push({ type: 'success', title: 'History entry deleted' });
      setDeleteTarget(null);
      load();
    } else {
      toast.push({ type: 'error', title: 'Failed to delete entry' });
    }
  };

  if (history === null) return <p className="text-[var(--rdr-faint)] text-sm text-center py-8">Loading...</p>;

  return (
    <div className="space-y-2">
      <div className="flex items-center justify-between mb-1">
        <p className="text-[var(--rdr-heading)] text-sm font-semibold flex items-center gap-2"><HistoryIcon size={15} /> History</p>
        <span className="px-2 py-0.5 rounded-sm text-xs bg-[var(--rdr-red-15)] text-[var(--rdr-red-bright)]">{history.length} entries</span>
      </div>
      {history.length === 0 ? (
        <p className="text-[var(--rdr-faint)] text-sm text-center py-8">No warning, kick, or ban history for this player.</p>
      ) : (
        history.map((h) => (
          <div key={h.id} className="rounded-sm p-3" style={{ background: 'var(--rdr-surface-2)' }}>
            <div className="flex items-center justify-between">
              <p className="text-[var(--rdr-text)] text-sm font-medium flex items-center gap-2">{historyIcon[h.action]} {historyLabel[h.action] ?? h.action} #{h.id}</p>
              <div className="flex items-center gap-1.5">
                {h.severity && <span className="px-2 py-0.5 rounded-sm text-xs capitalize bg-[var(--rdr-surface)] text-[var(--rdr-muted)]">{h.severity}</span>}
                <span className={`px-2 py-0.5 rounded-sm text-xs capitalize ${historyBadgeCls[h.action] ?? 'bg-[var(--rdr-surface)] text-[var(--rdr-muted)]'}`}>{h.action}</span>
                {canManageHistory && (
                  <button
                    onClick={() => setDeleteTarget(h)}
                    title="Delete entry"
                    className="text-[var(--rdr-muted)] hover:text-[var(--rdr-red-bright)] p-1 rounded hover:bg-white/5"
                  >
                    <Trash2 size={13} />
                  </button>
                )}
              </div>
            </div>
            <p className="text-[var(--rdr-muted)] text-sm mt-1">{h.reason || 'No reason given'}</p>
            <p className="text-[var(--rdr-faint)] text-xs mt-1">By: {h.admin_name || 'Unknown'} · {new Date(h.created_at).toLocaleString()}</p>
          </div>
        ))
      )}
      {deleteTarget && (
        <ConfirmModal
          title="Delete History Entry"
          message={`Permanently delete ${historyLabel[deleteTarget.action] ?? deleteTarget.action} #${deleteTarget.id}? This cannot be undone.`}
          confirmLabel="Delete"
          danger
          onConfirm={confirmDelete}
          onCancel={() => setDeleteTarget(null)}
        />
      )}
    </div>
  );
}
