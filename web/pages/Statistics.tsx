import { locale } from '../i18n';
import { useState } from 'react';
import {
  ResponsiveContainer, BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, Legend,
  PieChart, Pie, Cell, LineChart, Line,
} from 'recharts';
import { useNuiData } from '../hooks/useNui';
import type { StatisticsData, MoneyType, JobDistributionEntry } from '../types';

type Tab = 'players' | 'economy' | 'performance';

const PIE_COLORS = ['#c8892b', '#3b6ea5', '#5e8f4f', '#a5463b', '#7a5ea8', '#3b8a8a', '#b5b5b5'];

const moneyLabels: Record<MoneyType, string> = {
  cash: locale('ui_cash'), bank: locale('ui_bank'), bloodmoney: locale('ui_blood_money'),
  valbank: locale('ui_val_bank'), rhobank: locale('ui_rho_bank'), blkbank: locale('ui_blk_bank'), armbank: locale('ui_arm_bank'),
};

const mockStats: StatisticsData = {
  players: {
    activity: [
      { date: '2026-08-24', averagePlayers: 1, peakPlayers: 2 },
      { date: '2026-08-25', averagePlayers: 2, peakPlayers: 3 },
      { date: '2026-08-26', averagePlayers: 1, peakPlayers: 1 },
      { date: '2026-08-27', averagePlayers: 3, peakPlayers: 4 },
    ],
    jobDistribution: [
      { job: 'Unemployed', count: 9 },
      { job: 'Deputy Sheriff', count: 1 },
    ],
  },
  economy: {
    dailyMoney: [
      { date: '2026-08-24', averageMoney: 4200 }, { date: '2026-08-25', averageMoney: 4600 },
      { date: '2026-08-26', averageMoney: 4400 }, { date: '2026-08-27', averageMoney: 5050 },
    ],
    moneyByType: [
      { type: 'cash', total: 1200 }, { type: 'bank', total: 3000 }, { type: 'bloodmoney', total: 50 },
      { type: 'valbank', total: 0 }, { type: 'rhobank', total: 0 }, { type: 'blkbank', total: 0 }, { type: 'armbank', total: 0 },
    ],
  },
  performance: {
    onlineCount: 1, resourceCount: 142, serverUptimeSeconds: 34560, averagePing: 24,
    hourlyActivity: [
      { hour: '2026-08-27 10:00:00', averagePlayers: 1, peakPlayers: 1 },
      { hour: '2026-08-27 11:00:00', averagePlayers: 2, peakPlayers: 3 },
      { hour: '2026-08-27 12:00:00', averagePlayers: 1, peakPlayers: 2 },
    ],
  },
};

// Parses either a normal date string or (defensively) a raw epoch-ms value that
// slipped through as a string, so a backend serialization hiccup never shows a
// giant number to the user again.
function parseFlexibleDate(input: string): Date {
  const trimmed = input.trim();
  if (trimmed !== '' && !isNaN(Number(trimmed))) {
    return new Date(Number(trimmed));
  }
  return new Date(trimmed.includes(' ') ? trimmed.replace(' ', 'T') : trimmed);
}

function formatDate(d: string) {
  const date = parseFlexibleDate(d);
  if (isNaN(date.getTime())) return d;
  return date.toLocaleDateString(undefined, { month: 'short', day: 'numeric' });
}

function formatHour(h: string) {
  const date = parseFlexibleDate(h);
  if (isNaN(date.getTime())) return h;
  return `${String(date.getHours()).padStart(2, '0')}:00`;
}

function formatUptime(seconds: number) {
  const d = Math.floor(seconds / 86400);
  const h = Math.floor((seconds % 86400) / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  return `${d}d, ${h}h, ${m}m`;
}

function formatMoney(n: number) {
  return `$${Math.round(n).toLocaleString()}`;
}

function EmptyState({ message }: { message: string }) {
  return <p className="text-[var(--rdr-faint)] text-sm py-16 text-center">{message}</p>;
}

interface ChartTooltipEntry {
  name: string;
  value: number;
  color: string;
}

interface ChartTooltipProps {
  active?: boolean;
  label?: string;
  payload?: ChartTooltipEntry[];
  labelFormatter?: (label: string) => string;
  valueFormatter?: (value: number) => string;
}

function ChartTooltipContent({ active, label, payload, labelFormatter, valueFormatter }: ChartTooltipProps) {
  if (!active || !payload || payload.length === 0) return null;
  return (
    <div
      className="min-w-[140px]"
      style={{ background: '#0a0a0a', border: '1px solid var(--rdr-border)', borderRadius: 6, padding: '8px 12px', fontSize: 12, color: '#fff' }}
    >
      {label && <p className="text-[var(--rdr-muted)] mb-1.5">{labelFormatter ? labelFormatter(label) : label}</p>}
      <div className="space-y-1">
        {payload.map((entry, i) => (
          <div key={i} className="flex items-center justify-between gap-4">
            <span className="flex items-center gap-1.5 text-[var(--rdr-muted)]">
              <span className="w-2 h-2 rounded-full shrink-0" style={{ background: entry.color }} />
              {entry.name}
            </span>
            <span className="font-semibold">{valueFormatter ? valueFormatter(entry.value) : entry.value}</span>
          </div>
        ))}
      </div>
    </div>
  );
}

interface ChartLegendEntry {
  value: string;
  color: string;
}

function ChartLegendContent({ payload }: { payload?: ChartLegendEntry[] }) {
  if (!payload || payload.length === 0) return null;
  return (
    <div className="flex items-center justify-center gap-4 pt-3">
      {payload.map((entry, i) => (
        <span key={i} className="flex items-center gap-1.5 text-xs text-[var(--rdr-text)]">
          <span className="w-2.5 h-2.5 rounded-sm shrink-0" style={{ background: entry.color }} />
          {entry.value}
        </span>
      ))}
    </div>
  );
}

interface PieTooltipProps {
  active?: boolean;
  payload?: { name: string; value: number; payload: { fill: string; count?: number } }[];
}

function PieTooltip({ active, payload }: PieTooltipProps) {
  if (!active || !payload || payload.length === 0) return null;
  const item = payload[0];
  if (!item.name) return null; // background track / filler segment — nothing meaningful to show
  const count = item.payload.count;
  return (
    <div
      className="flex items-center gap-2 whitespace-nowrap"
      style={{ background: '#0a0a0a', border: '1px solid var(--rdr-border)', borderRadius: 4, padding: '6px 10px', fontSize: 12, color: '#fff' }}
    >
      <span className="w-2 h-2 rounded-full shrink-0" style={{ background: item.payload.fill }} />
      <span>
        {item.name}: <strong>{count != null ? `${count} (${item.value}%)` : item.value}</strong>
      </span>
    </div>
  );
}

// Concentric radial gauges — one ring per job, each arc showing that job's share
// of the total registered player base, with a center summary label.
const RING_BANDS = [
  { ir: '82%', or: '95%' },
  { ir: '65%', or: '78%' },
  { ir: '48%', or: '61%' },
  { ir: '31%', or: '44%' },
];

function JobDistributionRings({ jobs }: { jobs: JobDistributionEntry[] }) {
  const total = jobs.reduce((sum, j) => sum + j.count, 0);
  if (total === 0) return null;

  const top = jobs.slice(0, RING_BANDS.length);
  const restCount = jobs.slice(RING_BANDS.length).reduce((sum, j) => sum + j.count, 0);
  const rings = restCount > 0 ? [...top.slice(0, RING_BANDS.length - 1), { job: locale('ui_other'), count: restCount }] : top;

  return (
    <>
      <div className="relative aspect-square w-full max-w-[220px] mx-auto">
        <ResponsiveContainer width="100%" height="100%">
          <PieChart>
            <Tooltip content={<PieTooltip />} wrapperStyle={{ zIndex: 100, outline: 'none' }} />
            {rings.flatMap((ring, i) => {
              const color = PIE_COLORS[i % PIE_COLORS.length];
              const pct = Math.round((ring.count / total) * 100);
              const band = RING_BANDS[i];
              return [
                <Pie
                  key={`${ring.job}-bg`}
                  data={[{ value: 100 }]}
                  dataKey="value"
                  innerRadius={band.ir}
                  outerRadius={band.or}
                  startAngle={90}
                  endAngle={-270}
                  stroke="none"
                  isAnimationActive={false}
                >
                  <Cell fill={color} fillOpacity={0.15} />
                </Pie>,
                <Pie
                  key={`${ring.job}-fg`}
                  data={[{ value: pct, name: ring.job, count: ring.count }, { value: 100 - pct, name: '' }]}
                  dataKey="value"
                  nameKey="name"
                  innerRadius={band.ir}
                  outerRadius={band.or}
                  startAngle={90}
                  endAngle={-270}
                  stroke="none"
                  isAnimationActive={false}
                >
                  <Cell fill={color} />
                  <Cell fillOpacity={0} />
                </Pie>,
              ];
            })}
          </PieChart>
        </ResponsiveContainer>
        <div className="pointer-events-none absolute inset-0 flex flex-col items-center justify-center">
          <span className="text-xs text-[var(--rdr-muted)]">{locale('ui_total_players')}</span>
          <span className="text-xl font-semibold text-[var(--rdr-heading)]">{total}</span>
        </div>
      </div>
      <div className="flex flex-wrap gap-3 justify-center mt-3">
        {rings.map((ring, i) => (
          <div key={ring.job} className="flex items-center gap-1.5 text-xs text-[var(--rdr-text)]">
            <span className="w-2.5 h-2.5 rounded-sm shrink-0" style={{ background: PIE_COLORS[i % PIE_COLORS.length] }} />
            {ring.job} ({ring.count})
          </div>
        ))}
      </div>
    </>
  );
}

export function Statistics() {
  const [tab, setTab] = useState<Tab>('players');
  const [stats] = useNuiData<StatisticsData>('getStatistics', {}, mockStats);

  return (
    <div className="space-y-4">
      <div>
        <h2 className="text-[var(--rdr-heading)] text-2xl font-bold">{locale('ui_statistics')}</h2>
        <p className="text-[var(--rdr-muted)] mt-1 text-sm">{locale('ui_server_performance_metrics_and_player_analyt')}</p>
      </div>

      <div className="flex gap-1 bg-[var(--rdr-surface-2)] w-fit rounded-sm p-1">
        {(['players', 'economy', 'performance'] as Tab[]).map((t) => (
          <button
            key={t}
            onClick={() => setTab(t)}
            className={`px-4 py-1.5 rounded-sm text-sm font-medium capitalize transition-colors ${
              tab === t ? 'bg-white/10 text-[var(--rdr-heading)]' : 'text-[var(--rdr-muted)] hover:text-[var(--rdr-text)]'
            }`}
          >
            {t}
          </button>
        ))}
      </div>

      {!stats ? (
        <p className="text-[var(--rdr-faint)] text-sm">{locale('ui_loading')}</p>
      ) : tab === 'players' ? (
        <PlayersTab stats={stats} />
      ) : tab === 'economy' ? (
        <EconomyTab stats={stats} />
      ) : (
        <PerformanceTab stats={stats} />
      )}
    </div>
  );
}

function PlayersTab({ stats }: { stats: StatisticsData }) {
  const jobs = stats.players.jobDistribution;
  return (
    <div className="grid grid-cols-2 gap-4">
      <div className="rounded-lg p-5" style={{ background: 'var(--rdr-surface)', border: '1px solid var(--rdr-border)' }}>
        <h3 className="text-[var(--rdr-heading)] text-base font-semibold">{locale('ui_player_activity')}</h3>
        <p className="text-[var(--rdr-muted)] text-xs mt-0.5 mb-4">{locale('ui_daily_player_count_and_peak_times')}</p>
        {stats.players.activity.length === 0 ? (
          <EmptyState message={locale('ui_no_activity_data_yet')} />
        ) : (
          <ResponsiveContainer width="100%" height={260}>
            <BarChart data={stats.players.activity} accessibilityLayer>
              <CartesianGrid vertical={false} stroke="var(--rdr-line)" />
              <XAxis dataKey="date" type="category" interval={0} tickFormatter={formatDate} tickLine={false} axisLine={false} tickMargin={10} stroke="var(--rdr-muted)" fontSize={12} />
              <YAxis tickLine={false} axisLine={false} tickMargin={8} stroke="var(--rdr-muted)" fontSize={12} allowDecimals={false} />
              <Tooltip content={<ChartTooltipContent labelFormatter={formatDate} />} cursor={{ fill: 'rgba(255,255,255,0.04)' }} />
              <Legend content={<ChartLegendContent />} />
              <Bar dataKey="peakPlayers" name={locale('ui_peak_players')} fill="#3b6ea5" radius={4} />
              <Bar dataKey="averagePlayers" name={locale('ui_average_players')} fill="#5e8f4f" radius={4} />
            </BarChart>
          </ResponsiveContainer>
        )}
      </div>

      <div className="rounded-lg p-5" style={{ background: 'var(--rdr-surface)', border: '1px solid var(--rdr-border)' }}>
        <h3 className="text-[var(--rdr-heading)] text-base font-semibold">{locale('ui_job_distribution')}</h3>
        <p className="text-[var(--rdr-muted)] text-xs mt-0.5 mb-4">{locale('ui_player_job_breakdown')}</p>
        {jobs.length === 0 ? (
          <EmptyState message={locale('ui_no_registered_players_yet')} />
        ) : (
          <JobDistributionRings jobs={jobs} />
        )}
      </div>
    </div>
  );
}

function EconomyTab({ stats }: { stats: StatisticsData }) {
  const hasAnyMoney = stats.economy.moneyByType.some((m) => m.total > 0);
  return (
    <div className="space-y-4">
      <div className="rounded-lg p-5" style={{ background: 'var(--rdr-surface)', border: '1px solid var(--rdr-border)' }}>
        <h3 className="text-[var(--rdr-heading)] text-base font-semibold">{locale('ui_money_by_account_type')}</h3>
        <p className="text-[var(--rdr-muted)] text-xs mt-0.5 mb-4">{locale('ui_current_totals_across_every_registered_playe')}</p>
        {!hasAnyMoney ? (
          <EmptyState message={locale('ui_no_money_on_the_server_yet')} />
        ) : (
          <ResponsiveContainer width="100%" height={280}>
            <BarChart data={stats.economy.moneyByType} accessibilityLayer>
              <CartesianGrid vertical={false} stroke="var(--rdr-line)" />
              <XAxis dataKey="type" type="category" interval={0} tickFormatter={(t: MoneyType) => moneyLabels[t]} tickLine={false} axisLine={false} tickMargin={10} stroke="var(--rdr-muted)" fontSize={12} />
              <YAxis tickLine={false} axisLine={false} tickMargin={8} stroke="var(--rdr-muted)" fontSize={12} tickFormatter={(v: number) => `$${v >= 1000 ? `${Math.round(v / 1000)}k` : v}`} />
              <Tooltip content={<ChartTooltipContent labelFormatter={(t: string) => moneyLabels[t as MoneyType]} valueFormatter={formatMoney} />} cursor={{ fill: 'rgba(255,255,255,0.04)' }} />
              <Bar
                dataKey="total"
                name={locale('ui_total')}
                fill="var(--rdr-accent)"
                radius={4}
                minPointSize={(value) => (Number(value) > 0 ? 8 : 0)}
              />
            </BarChart>
          </ResponsiveContainer>
        )}
      </div>

      <div className="rounded-lg p-5" style={{ background: 'var(--rdr-surface)', border: '1px solid var(--rdr-border)' }}>
        <h3 className="text-[var(--rdr-heading)] text-base font-semibold">{locale('ui_server_economy')}</h3>
        <p className="text-[var(--rdr-muted)] text-xs mt-0.5 mb-4">{locale('ui_total_money_on_server_by_day')}</p>
        {stats.economy.dailyMoney.length === 0 ? (
          <EmptyState message={locale('ui_no_economy_history_yet_this_fills_in_over_th')} />
        ) : (
          <ResponsiveContainer width="100%" height={260}>
            <BarChart data={stats.economy.dailyMoney} accessibilityLayer>
              <CartesianGrid vertical={false} stroke="var(--rdr-line)" />
              <XAxis dataKey="date" type="category" interval={0} tickFormatter={formatDate} tickLine={false} axisLine={false} tickMargin={10} stroke="var(--rdr-muted)" fontSize={12} />
              <YAxis tickLine={false} axisLine={false} tickMargin={8} stroke="var(--rdr-muted)" fontSize={12} tickFormatter={(v: number) => `$${v >= 1000 ? `${Math.round(v / 1000)}k` : v}`} />
              <Tooltip content={<ChartTooltipContent labelFormatter={formatDate} valueFormatter={formatMoney} />} cursor={{ fill: 'rgba(255,255,255,0.04)' }} />
              <Legend content={<ChartLegendContent />} />
              <Bar dataKey="averageMoney" name={locale('ui_total_money')} fill="#3ba884" radius={4} maxBarSize={64} />
            </BarChart>
          </ResponsiveContainer>
        )}
      </div>
    </div>
  );
}

function PerformanceTab({ stats }: { stats: StatisticsData }) {
  const perf = stats.performance;
  return (
    <div className="space-y-4">
      <div className="grid grid-cols-4 gap-4">
        <PerfCard label={locale('ui_online_players')} value={String(perf.onlineCount)} />
        <PerfCard label={locale('ui_average_ping')} value={`${perf.averagePing}ms`} />
        <PerfCard label={locale('ui_running_resources')} value={String(perf.resourceCount)} />
        <PerfCard label={locale('ui_server_uptime')} value={formatUptime(perf.serverUptimeSeconds)} />
      </div>

      <div className="rounded-lg p-5" style={{ background: 'var(--rdr-surface)', border: '1px solid var(--rdr-border)' }}>
        <h3 className="text-[var(--rdr-heading)] text-base font-semibold">{locale('ui_player_count_over_time')}</h3>
        <p className="text-[var(--rdr-muted)] text-xs mt-0.5 mb-4">{locale('ui_hourly_average_and_peak_player_counts_last_2')}</p>
        {perf.hourlyActivity.length === 0 ? (
          <EmptyState message={locale('ui_no_activity_data_yet')} />
        ) : (
          <ResponsiveContainer width="100%" height={300}>
            <LineChart data={perf.hourlyActivity} accessibilityLayer margin={{ top: 5, right: 24, left: 0, bottom: 0 }}>
              <CartesianGrid vertical={false} stroke="var(--rdr-line)" />
              <XAxis dataKey="hour" type="category" interval={0} tickFormatter={formatHour} tickLine={false} axisLine={false} tickMargin={10} stroke="var(--rdr-muted)" fontSize={12} />
              <YAxis tickLine={false} axisLine={false} tickMargin={8} stroke="var(--rdr-muted)" fontSize={12} allowDecimals={false} />
              <Tooltip content={<ChartTooltipContent labelFormatter={formatHour} />} cursor={{ stroke: 'var(--rdr-border)' }} />
              <Legend content={<ChartLegendContent />} />
              <Line type="monotone" dataKey="averagePlayers" name={locale('ui_avg_players')} stroke="#3b6ea5" strokeWidth={2} dot={{ r: 3 }} />
              <Line type="monotone" dataKey="peakPlayers" name={locale('ui_peak_players')} stroke="#e8a63d" strokeWidth={2} dot={{ r: 3 }} />
            </LineChart>
          </ResponsiveContainer>
        )}
      </div>
    </div>
  );
}

function PerfCard({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-lg p-4" style={{ background: 'var(--rdr-surface)', border: '1px solid var(--rdr-border)' }}>
      <p className="text-[var(--rdr-muted)] text-sm">{label}</p>
      <p className="text-2xl font-bold text-[var(--rdr-heading)] mt-2">{value}</p>
    </div>
  );
}
