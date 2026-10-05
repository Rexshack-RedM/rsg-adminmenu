import { locale } from '../../i18n';
import { useEffect, useState } from 'react';
import { fetchNui } from '../../hooks/useNui';
import { ReportDetail } from '../Reports';
import type { Report, ReportStatus } from '../../types';

const statusColors: Record<ReportStatus, string> = {
  open: 'bg-blue-500/20 text-blue-400',
  claimed: 'bg-amber-500/20 text-amber-400',
  resolved: 'bg-green-500/20 text-green-400',
  closed: 'bg-zinc-500/20 text-zinc-400',
};

export function MyReports() {
  const [reports, setReports] = useState<Report[]>([]);
  const [openId, setOpenId] = useState<number | null>(null);

  const load = () => {
    fetchNui<Report[]>('getMyReports', {}, []).then((r) => setReports(r || []));
  };

  useEffect(() => { load(); }, []);

  return (
    <div className="space-y-3">
      <h3 className="text-[var(--rdr-heading)] text-base font-semibold" style={{ fontFamily: 'var(--font-display)' }}>{locale('ui_my_reports')}</h3>
      {reports.length === 0 && <p className="text-[var(--rdr-faint)] text-sm">{locale('ui_you_haven_t_submitted_any_reports_yet')}</p>}
      <div className="space-y-2">
        {reports.map((r) => (
          <button
            key={r.id}
            onClick={() => setOpenId(r.id)}
            className="w-full text-left flex items-center justify-between px-4 py-3 rounded-sm bg-[var(--rdr-surface)] border border-[var(--rdr-border)] hover:border-[var(--rdr-accent)]"
          >
            <div>
              <p className="text-[var(--rdr-text)] text-sm font-medium">#{r.id}: {r.title}</p>
              <p className="text-[var(--rdr-faint)] text-xs mt-0.5">{r.report_type}</p>
            </div>
            <span className={`px-2 py-0.5 rounded-sm text-xs capitalize ${statusColors[r.status]}`}>{r.status}</span>
          </button>
        ))}
      </div>

      {openId != null && <ReportDetail id={openId} isAdmin={false} onClose={() => setOpenId(null)} onChanged={load} />}
    </div>
  );
}
