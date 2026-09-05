import type { ButtonHTMLAttributes } from 'react';
import { Spinner } from './Spinner';

// Kept for call-site compatibility (some callers still pass these), but every
// button renders identically now — one consistent look everywhere, matching
// the "View All Players" reference exactly, rather than a different tint per
// page/action.
export type ButtonVariant = 'outline' | 'solid' | 'ghost';
export type ButtonTone = 'default' | 'accent' | 'green' | 'red' | 'amber';

interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: ButtonVariant;
  tone?: ButtonTone;
  fullWidth?: boolean;
  isLoading?: boolean;
  loadingText?: string;
}

const sizeCls = 'px-3 py-2 text-sm';

export function Button({
  variant: _variant, tone: _tone, fullWidth, isLoading, loadingText, className = '', children, disabled, type = 'button', onClick, ...props
}: ButtonProps) {
  const base = `inline-flex items-center justify-center gap-2 rounded-sm font-medium transition-colors disabled:opacity-40 disabled:pointer-events-none [&_svg]:size-4 [&_svg]:shrink-0 ${sizeCls}`;
  const look = 'border border-[var(--rdr-border)] text-[var(--rdr-text)] bg-transparent hover:bg-white/5 hover:border-[var(--rdr-muted)]';

  return (
    <button
      {...props}
      type={type}
      className={`${base} ${look} ${fullWidth ? 'w-full' : ''} ${className}`}
      disabled={disabled || isLoading}
      onClick={(e) => {
        e.preventDefault();
        onClick?.(e);
      }}
    >
      {isLoading ? (
        <>
          <Spinner />
          {loadingText ?? children}
        </>
      ) : (
        children
      )}
    </button>
  );
}
