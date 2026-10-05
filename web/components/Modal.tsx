import { locale } from '../i18n';
import { useEffect, type ReactNode } from 'react';
import { Button } from './Button';

interface ModalProps {
  title: string;
  subtitle?: string;
  onClose: () => void;
  children: ReactNode;
  width?: string;
}

export function Modal({ title, subtitle, onClose, children, width = 'max-w-md' }: ModalProps) {
  // Capture-phase so this fires before the page-level Escape handler that closes
  // the whole NUI, and stopPropagation keeps it from reaching that handler at all.
  useEffect(() => {
    const onKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        e.stopPropagation();
        onClose();
      }
    };
    window.addEventListener('keydown', onKeyDown, true);
    return () => window.removeEventListener('keydown', onKeyDown, true);
  }, [onClose]);

  return (
    <div
      className="fixed inset-0 z-[100] flex items-center justify-center bg-black/60"
      onMouseDown={(e) => { if (e.target === e.currentTarget) onClose(); }}
    >
      <div
        className={`w-full ${width} mx-4 rounded-sm shadow-2xl overflow-hidden`}
        style={{ background: 'var(--rdr-panel)', border: '1px solid var(--rdr-border)' }}
      >
        <div
          className="flex items-center justify-between px-5 py-3"
          style={{ borderBottom: '1px solid var(--rdr-line)', background: 'var(--rdr-surface-2)' }}
        >
          <div>
            <h2 className="text-[var(--rdr-heading)] text-base font-semibold" style={{ fontFamily: 'var(--font-display)' }}>
              {title}
            </h2>
            {subtitle && <p className="text-[var(--rdr-muted)] text-xs mt-0.5">{subtitle}</p>}
          </div>
          <button
            onClick={onClose}
            className="text-[var(--rdr-muted)] hover:text-[var(--rdr-heading)] text-sm px-2 py-1 rounded hover:bg-white/5 transition-colors"
          >
            ✕
          </button>
        </div>
        <div className="p-5 max-h-[70vh] overflow-y-auto">{children}</div>
      </div>
    </div>
  );
}

interface ConfirmModalProps {
  title: string;
  message: string;
  confirmLabel?: string;
  danger?: boolean;
  onConfirm: () => void;
  onCancel: () => void;
}

export function ConfirmModal({ title, message, confirmLabel = locale('ui_confirm'), danger, onConfirm, onCancel }: ConfirmModalProps) {
  return (
    <Modal title={title} onClose={onCancel} width="max-w-sm">
      <p className="text-[var(--rdr-text)] text-sm mb-5">{message}</p>
      <div className="flex justify-end gap-2">
        <Button variant="ghost" onClick={onCancel}>{locale('ui_cancel')}</Button>
        <Button variant="solid" tone={danger ? 'red' : 'accent'} onClick={onConfirm}>{confirmLabel}</Button>
      </div>
    </Modal>
  );
}
