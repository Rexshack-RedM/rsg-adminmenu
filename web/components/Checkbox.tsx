import { Check } from 'lucide-react';

interface CheckboxProps {
  checked: boolean;
  onChange: (checked: boolean) => void;
  label?: string;
  className?: string;
}

export function Checkbox({ checked, onChange, label, className = '' }: CheckboxProps) {
  return (
    <label
      onClick={() => onChange(!checked)}
      className={`inline-flex items-center gap-1.5 cursor-pointer select-none ${className}`}
    >
      <span
        className="w-4 h-4 rounded-sm flex items-center justify-center shrink-0 transition-colors"
        style={{
          background: checked ? 'var(--rdr-heading)' : 'transparent',
          border: `1px solid ${checked ? 'var(--rdr-heading)' : 'var(--rdr-border)'}`,
        }}
      >
        {checked && <Check size={11} className="text-black" strokeWidth={3} />}
      </span>
      {label && <span className="text-[var(--rdr-muted)]">{label}</span>}
    </label>
  );
}
