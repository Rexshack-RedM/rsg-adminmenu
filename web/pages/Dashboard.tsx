import { locale } from '../i18n';
import { Users, Coins, Clock, Crown, MessageCircle } from 'lucide-react';
import { useNuiData } from '../hooks/useNui';
import { StatCard } from '../components/StatCard';
import { Button } from '../components/Button';
import { Avatar } from '../components/Avatar';
import type { DashboardStats, SelfInfo } from '../types';

function formatMoney(n: number) {
  return `$${n.toLocaleString(undefined, { maximumFractionDigits: 2 })}`;
}

function formatUptime(seconds: number) {
  const d = Math.floor(seconds / 86400);
  const h = Math.floor((seconds % 86400) / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  return `${d}d, ${h}h, ${m}m`;
}

function formatPlaytime(minutes: number) {
  const h = Math.floor(minutes / 60);
  const m = minutes % 60;
  return `${h}h ${m}m`;
}

function formatToday() {
  return new Date().toLocaleDateString(undefined, { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' });
}

const mockStats: DashboardStats = {
  onlineCount: 1,
  totalMoney: 5466.24,
  serverUptimeSeconds: 34560,
  topPlayer: { rank: 1, citizenid: 'DEV1234', name: 'UIFORC test', accountName: 'uiforc', job: 'deputysheriff', online: true, playtimeMinutes: 17216, money: 911, discordName: 'uiforc' },
  leaderboard: [
    { rank: 1, citizenid: 'DEV1234', name: 'UIFORC test', accountName: 'uiforc', job: 'deputysheriff', online: true, playtimeMinutes: 17216, money: 911, discordName: 'uiforc' },
    { rank: 2, citizenid: 'DEV5678', name: 'Mirliva SCRIPTS', accountName: '.mirliva.', job: 'unemployed', online: false, playtimeMinutes: 295, money: 1375 },
  ],
};

interface DashboardProps {
  self: SelfInfo | null;
  onViewAllPlayers: () => void;
}

export function Dashboard({ self, onViewAllPlayers }: DashboardProps) {
  const [stats] = useNuiData<DashboardStats>('getDashboardStats', {}, mockStats);

  const firstName = self?.name?.split(' ')[0] || locale('ui_admin');

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-[var(--rdr-heading)] text-2xl font-bold">{locale('ui_hey_x', firstName)}</h2>
        <p className="text-[var(--rdr-muted)] mt-1 text-sm">{formatToday()}</p>
      </div>

      <div className="grid grid-cols-4 gap-4">
        <StatCard label={locale('ui_online_users')} value={stats?.onlineCount ?? '-'} icon={<Users size={18} />} iconBg="rgba(59,110,165,0.25)" iconColor="#6fa8dc" />
        <StatCard label={locale('ui_total_money_on_server')} value={stats ? formatMoney(stats.totalMoney) : '-'} icon={<Coins size={18} />} iconBg="rgba(94,143,79,0.25)" iconColor="#7fc47c" />
        <StatCard label={locale('ui_server_uptime')} value={stats ? formatUptime(stats.serverUptimeSeconds) : '-'} icon={<Clock size={18} />} iconBg="rgba(122,94,168,0.25)" iconColor="#b39ddb" />
        <StatCard label={locale('ui_top_player')} value={stats?.topPlayer?.name ?? '-'} icon={<Crown size={18} />} iconBg="rgba(200,137,43,0.25)" iconColor="var(--rdr-accent-bright)" />
      </div>

      <div className="rounded-lg p-5" style={{ background: 'var(--rdr-surface)', border: '1px solid var(--rdr-border)' }}>
        <div className="flex items-center justify-between mb-4">
          <div>
            <h3 className="text-[var(--rdr-heading)] text-base font-semibold flex items-center gap-2">
              <span></span> {locale('ui_top_players_leaderboard')}
            </h3>
            <p className="text-[var(--rdr-muted)] text-xs mt-0.5">{locale('ui_most_active_outlaws_and_lawmen_on_the_fronti')}</p>
          </div>
          <Button variant="outline" onClick={onViewAllPlayers} className="text-xs">{locale('ui_view_all_players')}</Button>
        </div>
        <table className="w-full text-sm">
          <thead>
            <tr className="text-[var(--rdr-muted)] text-xs uppercase tracking-wider border-b border-[var(--rdr-line)]">
              <th className="text-left py-2 font-medium">{locale('ui_rank')}</th>
              <th className="text-left py-2 font-medium">{locale('ui_player')}</th>
              <th className="text-left py-2 font-medium">{locale('ui_job')}</th>
              <th className="text-right py-2 font-medium">{locale('ui_playtime')}</th>
              <th className="text-right py-2 font-medium">{locale('ui_money')}</th>
            </tr>
          </thead>
          <tbody>
            {(stats?.leaderboard ?? []).map((p) => (
              <tr key={p.citizenid} className="border-b border-[var(--rdr-line)] last:border-b-0">
                <td className="py-3">
                  <span className={`w-6 h-6 inline-flex items-center justify-center rounded-full text-xs font-bold ${p.rank === 1 ? 'bg-white/10 text-[var(--rdr-heading)] border border-white/20' : 'bg-[var(--rdr-surface-2)] text-[var(--rdr-muted)]'}`}>
                    {p.rank}
                  </span>
                </td>
                <td className="py-3">
                  <div className="flex items-center gap-3">
                    <Avatar name={p.name} size={32} imageUrl={p.discordAvatarUrl} />
                    <div>
                      <p className="text-[var(--rdr-text)] font-medium">{p.name}</p>
                      <p className="text-[var(--rdr-faint)] text-xs flex items-center gap-1">
                        {p.discordName && <MessageCircle size={11} className="text-[#5865F2]" />}
                        {p.discordName ? `@${p.discordName}` : p.accountName}
                      </p>
                    </div>
                  </div>
                </td>
                <td className="py-3"><span className="px-2 py-0.5 rounded-sm bg-[var(--rdr-surface-2)] text-[var(--rdr-text)] text-xs capitalize">{p.job}</span></td>
                <td className="py-3 text-right text-[var(--rdr-text)]">{formatPlaytime(p.playtimeMinutes)}</td>
                <td className="py-3 text-right text-[#7fc47c] font-medium">${p.money.toLocaleString()}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
