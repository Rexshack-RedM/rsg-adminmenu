import { useEffect, useLayoutEffect, useRef, useState } from 'react';
import { createPortal } from 'react-dom';
import { Check, ChevronDown } from 'lucide-react';

export interface DropdownOption<T extends string = string> {
  value: T;
  label: string;
  description?: string;
  icon?: React.ReactNode;
  danger?: boolean;
}

interface DropdownProps<T extends string = string> {
  value: T;
  onChange: (value: T) => void;
  options: DropdownOption<T>[];
  className?: string;
  placeholder?: string;
}

const PANEL_MAX_HEIGHT = 256;

export function Dropdown<T extends string = string>({ value, onChange, options, className = '', placeholder }: DropdownProps<T>) {
  const [open, setOpen] = useState(false);
  const [rect, setRect] = useState<{ top: number; left: number; width: number; openUpward: boolean } | null>(null);
  const wrapperRef = useRef<HTMLDivElement>(null);
  const panelRef = useRef<HTMLDivElement>(null);

  // Rendered through a portal into <body> and positioned with `fixed` off the
  // trigger's own bounding rect — a modal's `overflow-y-auto` content wrapper
  // otherwise clips the panel the moment it extends past the modal's (often
  // short) height, cutting off whichever options happen to overflow.
  useLayoutEffect(() => {
    if (!open || !wrapperRef.current) return;
    const trigger = wrapperRef.current.getBoundingClientRect();
    const spaceBelow = window.innerHeight - trigger.bottom;
    const spaceAbove = trigger.top;
    const openUpward = spaceBelow < PANEL_MAX_HEIGHT && spaceAbove > spaceBelow;
    setRect({
      top: openUpward ? trigger.top : trigger.bottom,
      left: trigger.left,
      width: trigger.width,
      openUpward,
    });
  }, [open]);

  useEffect(() => {
    if (!open) return;
    const onClick = (e: MouseEvent) => {
      const target = e.target as Node;
      if (wrapperRef.current?.contains(target)) return;
      if (panelRef.current?.contains(target)) return;
      setOpen(false);
    };
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') setOpen(false);
    };
    document.addEventListener('mousedown', onClick);
    document.addEventListener('keydown', onKey);
    return () => {
      document.removeEventListener('mousedown', onClick);
      document.removeEventListener('keydown', onKey);
    };
  }, [open]);

  const selected = options.find((o) => o.value === value);

  return (
    <div ref={wrapperRef} className={`relative ${className}`}>
      <button
        type="button"
        onClick={() => setOpen((o) => !o)}
        className="w-full flex items-center justify-between gap-2 bg-[var(--rdr-surface)] border border-[var(--rdr-border)] rounded-sm px-3 py-2 text-sm text-[var(--rdr-text)] hover:border-[var(--rdr-heading)] transition-colors"
      >
        <span className={`truncate ${selected ? '' : 'text-[var(--rdr-faint)]'}`}>{selected?.label ?? placeholder ?? 'Select...'}</span>
        <ChevronDown size={14} className={`text-[var(--rdr-muted)] shrink-0 transition-transform duration-150 ${open ? 'rotate-180' : ''}`} />
      </button>
      {open && rect && createPortal(
        <div
          ref={panelRef}
          className="fixed z-[200] min-w-max overflow-y-auto rounded-md py-1 shadow-xl"
          style={{
            top: rect.openUpward ? undefined : rect.top + 4,
            bottom: rect.openUpward ? window.innerHeight - rect.top + 4 : undefined,
            left: rect.left,
            width: rect.width,
            maxHeight: PANEL_MAX_HEIGHT,
            background: 'var(--rdr-bg-elev)',
            border: '1px solid var(--rdr-border)',
          }}
        >
          {options.map((opt) => (
            <button
              key={opt.value}
              type="button"
              onClick={() => {
                onChange(opt.value);
                setOpen(false);
              }}
              className={`w-full flex items-start gap-2.5 px-3 py-2 text-left text-sm transition-colors hover:bg-white/5 ${opt.danger ? 'text-red-400' : 'text-[var(--rdr-text)]'}`}
            >
              {opt.icon && <span className="shrink-0 mt-0.5 text-[var(--rdr-muted)]">{opt.icon}</span>}
              <span className="flex-1 min-w-0">
                <span className="block truncate">{opt.label}</span>
                {opt.description && <span className="block text-xs text-[var(--rdr-faint)] mt-0.5">{opt.description}</span>}
              </span>
              {opt.value === value && <Check size={14} className="shrink-0 mt-0.5 text-[var(--rdr-accent)]" />}
            </button>
          ))}
        </div>,
        document.body,
      )}
    </div>
  );
}
