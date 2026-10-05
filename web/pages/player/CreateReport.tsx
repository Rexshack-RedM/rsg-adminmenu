import { locale } from '../../i18n';
import { useState } from 'react';
import { fetchNui } from '../../hooks/useNui';
import { useToast } from '../../components/Toast';
import { Button } from '../../components/Button';
import { Dropdown } from '../../components/Dropdown';
import type { ReportSeverity, ReportType } from '../../types';

const types: { value: ReportType; label: string; desc: string }[] = [
  { value: 'bug', label: locale('ui_bug_report'), desc: locale('ui_something_in_the_game_is_broken') },
  { value: 'player', label: locale('ui_player_report'), desc: locale('ui_report_another_player') },
  { value: 'question', label: locale('ui_general_question'), desc: locale('ui_ask_staff_a_question') },
];

const severityOptions: { value: ReportSeverity; label: string }[] = [
  { value: 'low', label: locale('ui_low') },
  { value: 'medium', label: locale('ui_medium') },
  { value: 'high', label: locale('ui_high') },
];

export function CreateReport({ onCreated }: { onCreated: () => void }) {
  const toast = useToast();
  const [type, setType] = useState<ReportType | null>(null);
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [reportedPlayerId, setReportedPlayerId] = useState('');
  const [imageUrl, setImageUrl] = useState('');
  const [severity, setSeverity] = useState<ReportSeverity>('medium');
  const [submitting, setSubmitting] = useState(false);

  const valid = title.trim().length >= 5 && title.trim().length <= 100 && description.trim().length >= 10 && description.trim().length <= 500;

  const submit = async () => {
    if (!type || !valid) return;
    setSubmitting(true);
    const res = await fetchNui<{ success: boolean; message?: string }>('createReport', {
      reportType: type,
      title: title.trim(),
      description: description.trim(),
      reportedPlayerId: type === 'player' && reportedPlayerId ? Number(reportedPlayerId) : undefined,
      imageUrl: imageUrl.trim() || undefined,
      severity,
    }, { success: true });
    setSubmitting(false);
    if (res.success) {
      toast.push({ type: 'success', title: locale('ui_report_submitted') });
      setType(null); setTitle(''); setDescription(''); setReportedPlayerId(''); setImageUrl(''); setSeverity('medium');
      onCreated();
    } else {
      toast.push({ type: 'error', title: locale('ui_failed_to_submit'), description: res.message });
    }
  };

  if (!type) {
    return (
      <div className="space-y-3">
        <h3 className="text-[var(--rdr-heading)] text-base font-semibold" style={{ fontFamily: 'var(--font-display)' }}>{locale('ui_select_report_type')}</h3>
        <div className="grid gap-2">
          {types.map((t) => (
            <button
              key={t.value}
              onClick={() => setType(t.value)}
              className="text-left px-4 py-3 rounded-sm bg-[var(--rdr-surface)] border border-[var(--rdr-border)] hover:border-[var(--rdr-accent)]"
            >
              <p className="text-[var(--rdr-text)] text-sm font-medium">{t.label}</p>
              <p className="text-[var(--rdr-muted)] text-xs mt-0.5">{t.desc}</p>
            </button>
          ))}
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-3 max-w-md">
      <Button variant="ghost" tone="accent" className="text-xs px-2 py-1" onClick={() => setType(null)}>{locale('ui_back')}</Button>
      <h3 className="text-[var(--rdr-heading)] text-base font-semibold" style={{ fontFamily: 'var(--font-display)' }}>
        {types.find((t) => t.value === type)?.label}
      </h3>

      <div>
        <label className="text-xs text-[var(--rdr-muted)]">{locale('ui_report_title')}</label>
        <input value={title} onChange={(e) => setTitle(e.target.value)} maxLength={100} className="w-full mt-1 bg-[var(--rdr-surface)] border border-[var(--rdr-border)] rounded-sm px-3 py-2 text-sm text-[var(--rdr-text)]" />
      </div>
      <div>
        <label className="text-xs text-[var(--rdr-muted)]">{locale('ui_description')}</label>
        <textarea value={description} onChange={(e) => setDescription(e.target.value)} maxLength={500} rows={4} className="w-full mt-1 bg-[var(--rdr-surface)] border border-[var(--rdr-border)] rounded-sm px-3 py-2 text-sm text-[var(--rdr-text)]" />
      </div>
      <div>
        <label className="text-xs text-[var(--rdr-muted)]">{locale('ui_severity')}</label>
        <div className="mt-1"><Dropdown value={severity} onChange={setSeverity} options={severityOptions} /></div>
      </div>
      {type === 'player' && (
        <div>
          <label className="text-xs text-[var(--rdr-muted)]">{locale('ui_player_server_id_optional')}</label>
          <input value={reportedPlayerId} onChange={(e) => setReportedPlayerId(e.target.value.replace(/\D/g, ''))} className="w-full mt-1 bg-[var(--rdr-surface)] border border-[var(--rdr-border)] rounded-sm px-3 py-2 text-sm text-[var(--rdr-text)]" />
        </div>
      )}
      {type !== 'question' && (
        <div>
          <label className="text-xs text-[var(--rdr-muted)]">{locale('ui_image_url_optional')}</label>
          <input value={imageUrl} onChange={(e) => setImageUrl(e.target.value)} placeholder={locale('ui_imgur_discord_cdn_gyazo_link')} className="w-full mt-1 bg-[var(--rdr-surface)] border border-[var(--rdr-border)] rounded-sm px-3 py-2 text-sm text-[var(--rdr-text)]" />
        </div>
      )}
      <Button variant="solid" tone="accent" fullWidth disabled={!valid || submitting} onClick={submit}>
        {locale('ui_submit_report')}
      </Button>
    </div>
  );
}
