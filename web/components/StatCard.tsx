import type { ReactNode } from 'react';

interface StatCardProps {
  label: string;
  value: ReactNode;
  icon?: ReactNode;
  iconBg?: string;
  iconColor?: string;
}

export function StatCard({ label, value, icon, iconBg = 'rgba(255,255,255,0.08)', iconColor = '#ffffff' }: StatCardProps) {
  return (
    <div
      className="rounded-lg p-4 flex items-center justify-between"
      style={{ background: 'var(--rdr-surface)', border: '1px solid var(--rdr-border)' }}
    >
      <div>
        <p className="text-[var(--rdr-muted)] text-sm">{label}</p>
        <p className="text-2xl font-bold mt-2 text-[var(--rdr-heading)]">{value}</p>
      </div>
      {icon && (
        <div
          className="w-9 h-9 rounded-lg flex items-center justify-center shrink-0"
          style={{ background: iconBg, color: iconColor }}
        >
          {icon}
        </div>
      )}
    </div>
  );
}
