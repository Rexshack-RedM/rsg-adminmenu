import { createContext, useCallback, useContext, useRef, useState } from 'react';
import type { ToastMessage } from '../types';

interface ToastContextValue {
  push: (toast: Omit<ToastMessage, 'id'>) => void;
}

const ToastContext = createContext<ToastContextValue>({ push: () => {} });

export function useToast() {
  return useContext(ToastContext);
}

const typeStyles: Record<ToastMessage['type'], string> = {
  success: 'border-l-4 border-l-[var(--rdr-green)]',
  error: 'border-l-4 border-l-[var(--rdr-red)]',
  info: 'border-l-4 border-l-[var(--rdr-accent)]',
};

export function ToastProvider({ children }: { children: React.ReactNode }) {
  const [toasts, setToasts] = useState<ToastMessage[]>([]);
  const idRef = useRef(0);

  const push = useCallback((toast: Omit<ToastMessage, 'id'>) => {
    const id = ++idRef.current;
    setToasts((prev) => [...prev, { ...toast, id }]);
    setTimeout(() => {
      setToasts((prev) => prev.filter((t) => t.id !== id));
    }, 4500);
  }, []);

  return (
    <ToastContext.Provider value={{ push }}>
      {children}
      <div className="fixed bottom-4 right-4 z-[200] flex flex-col gap-2 w-80">
        {toasts.map((t) => (
          <div
            key={t.id}
            className={`bg-[var(--rdr-surface-2)] ${typeStyles[t.type]} rounded shadow-xl px-4 py-3`}
          >
            <p className="text-[var(--rdr-heading)] text-sm font-semibold">{t.title}</p>
            {t.description && <p className="text-[var(--rdr-muted)] text-xs mt-1">{t.description}</p>}
          </div>
        ))}
      </div>
    </ToastContext.Provider>
  );
}
