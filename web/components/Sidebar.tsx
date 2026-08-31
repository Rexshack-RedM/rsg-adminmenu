import { useEffect, useRef, useState } from 'react';
import {
  LayoutDashboard, BarChart3, Users, ShieldCheck, Ticket, Wallet,
  LogOut, PanelLeftClose, PanelLeftOpen, UserCog, ScrollText, MessagesSquare,
  Navigation, MapPinned, Bookmark, Sparkles, SlidersHorizontal, Boxes, ShieldAlert,
} from 'lucide-react';
import { fetchNui } from '../hooks/useNui';
import { Avatar } from './Avatar';
import type { BotLogo, Permissions, SelfInfo } from '../types';

export type AdminPage =
  | 'dashboard' | 'statistics'
  | 'players' | 'whitelist' | 'reports' | 'finances'
  | 'admins' | 'logs' | 'adminchat'
  | 'teleports' | 'coords' | 'blips' | 'spawner'
  | 'serversettings' | 'resourcelookup' | 'masteractions';

interface SidebarProps {
  self: SelfInfo | null;
  permissions: Permissions | null;
  currentPage: AdminPage;
  onPageChange: (page: AdminPage) => void;
  onClose: () => void;
}

interface NavItem {
  id: AdminPage;
  label: string;
  icon: typeof LayoutDashboard;
  minRole?: 'mod' | 'admin' | 'headadmin';
}

const navGroups: { label: string; items: NavItem[] }[] = [
  {
    label: 'Overview',
    items: [
      { id: 'dashboard', label: 'Dashboard', icon: LayoutDashboard },
      { id: 'statistics', label: 'Statistics', icon: BarChart3 },
    ],
  },
  {
    label: 'Players',
    items: [
      { id: 'players', label: 'Players', icon: Users },
      { id: 'whitelist', label: 'Whitelist', icon: ShieldCheck, minRole: 'mod' },
      { id: 'reports', label: 'Reports', icon: Ticket },
      { id: 'finances', label: 'Finances', icon: Wallet, minRole: 'admin' },
    ],
  },
  {
    label: 'Team',
    items: [
      { id: 'admins', label: 'Admins', icon: UserCog },
      { id: 'logs', label: 'Logs', icon: ScrollText },
      { id: 'adminchat', label: 'Admin Chat', icon: MessagesSquare },
    ],
  },
  {
    label: 'World',
    items: [
      { id: 'teleports', label: 'Teleports', icon: Navigation, minRole: 'mod' },
      { id: 'coords', label: 'Coords', icon: MapPinned, minRole: 'mod' },
      { id: 'blips', label: 'Blips', icon: Bookmark, minRole: 'mod' },
      { id: 'spawner', label: 'Spawner', icon: Sparkles, minRole: 'mod' },
    ],
  },
  {
    label: 'Developer',
    items: [
      { id: 'serversettings', label: 'Server Settings', icon: SlidersHorizontal, minRole: 'headadmin' },
      { id: 'resourcelookup', label: 'Resource Lookup', icon: Boxes, minRole: 'headadmin' },
      { id: 'masteractions', label: 'Master Actions', icon: ShieldAlert, minRole: 'headadmin' },
    ],
  },
];

function canSeeNavItem(item: NavItem, permissions: Permissions | null): boolean {
  if (!item.minRole) return true;
  if (!permissions) return false;
  if (item.minRole === 'headadmin') return permissions.fullAccess;
  if (item.minRole === 'admin') return permissions.atLeastAdmin;
  return permissions.atLeastMod;
}

export function Sidebar({ self, permissions, currentPage, onPageChange, onClose }: SidebarProps) {
  const [collapsed, setCollapsed] = useState(false);
  const [botLogo, setBotLogo] = useState<BotLogo>({});
  const navRef = useRef<HTMLElement>(null);
  const [scroll, setScroll] = useState({ top: false, bottom: false });

  const visibleGroups = navGroups
    .map((group) => ({ ...group, items: group.items.filter((item) => canSeeNavItem(item, permissions)) }))
    .filter((group) => group.items.length > 0);

  useEffect(() => {
    fetchNui<BotLogo>('getBotLogo', {}, {}).then(setBotLogo);
  }, []);

  const updateScrollState = () => {
    const el = navRef.current;
    if (!el) return;
    setScroll({
      top: el.scrollTop > 2,
      bottom: el.scrollTop + el.clientHeight < el.scrollHeight - 2,
    });
  };

  useEffect(() => {
    updateScrollState();
    const el = navRef.current;
    if (!el) return;
    const resizeObserver = new ResizeObserver(updateScrollState);
    resizeObserver.observe(el);
    return () => resizeObserver.disconnect();
  }, [collapsed]);

  // jump the active item into view when it's navigated to programmatically
  // (e.g. a Quick Action button elsewhere in the app) rather than clicked here
  useEffect(() => {
    navRef.current?.querySelector(`[data-nav-id="${currentPage}"]`)?.scrollIntoView({ block: 'nearest' });
  }, [currentPage]);

  return (
    <div
      className="flex flex-col shrink-0 transition-[width] duration-150"
      style={{
        width: collapsed ? 72 : 240,
        background: 'linear-gradient(180deg, rgba(0,0,0,0.9) 0%, rgba(0,0,0,0.75) 100%)',
        borderRight: '1px solid var(--rdr-border)',
      }}
    >
      <div className={`flex items-center gap-2.5 py-4 ${collapsed ? 'justify-center' : 'px-4'}`} style={{ borderBottom: '1px solid var(--rdr-line)' }}>
        {botLogo.logoUrl ? (
          <img src={botLogo.logoUrl} alt="" className="w-7 h-7 rounded-md object-cover shrink-0" />
        ) : (
          <div className="w-7 h-7 rounded-md bg-[var(--rdr-accent-20)] text-[var(--rdr-accent-bright)] flex items-center justify-center shrink-0 font-bold text-sm" style={{ fontFamily: 'var(--font-display)' }}>
            R
          </div>
        )}
        {!collapsed && (
          <div className="min-w-0">
            <h1 className="text-[var(--rdr-heading)] text-base tracking-wide truncate" style={{ fontFamily: 'var(--font-display)' }}>
              RSG Admin
            </h1>
            <p className="text-[var(--rdr-faint)] text-[10px] uppercase tracking-widest">Frontier Control</p>
          </div>
        )}
      </div>

      <div className={`flex py-2 ${collapsed ? 'justify-center' : 'justify-end px-3'}`}>
        <button
          onClick={() => setCollapsed((c) => !c)}
          title={collapsed ? 'Expand sidebar' : 'Collapse sidebar'}
          className="text-[var(--rdr-muted)] hover:text-[var(--rdr-heading)] p-1.5 rounded hover:bg-white/5 transition-colors"
        >
          {collapsed ? <PanelLeftOpen size={16} /> : <PanelLeftClose size={16} />}
        </button>
      </div>

      <div className="relative flex-1 min-h-0">
        <nav ref={navRef} onScroll={updateScrollState} className="h-full overflow-y-auto pb-3">
          {visibleGroups.map((group) => (
            <div key={group.label} className="mb-1.5">
              {!collapsed && (
                <p className="px-5 py-1 text-[10px] font-semibold uppercase tracking-widest text-[var(--rdr-faint)]">{group.label}</p>
              )}
              {group.items.map((item) => {
                const Icon = item.icon;
                const active = currentPage === item.id;
                return (
                  <button
                    key={item.id}
                    data-nav-id={item.id}
                    onClick={() => onPageChange(item.id)}
                    title={collapsed ? item.label : undefined}
                    className={`w-full py-2 flex items-center gap-3 text-left transition-colors ${collapsed ? 'justify-center px-0' : 'px-5'} ${
                      active
                        ? 'text-[var(--rdr-heading)] bg-white/10 border-l-2 border-[var(--rdr-heading)]'
                        : 'text-[var(--rdr-muted)] hover:bg-white/5 hover:text-[var(--rdr-text)] border-l-2 border-transparent'
                    }`}
                  >
                    <Icon size={16} />
                    {!collapsed && <span className="text-sm">{item.label}</span>}
                  </button>
                );
              })}
            </div>
          ))}
        </nav>
        {scroll.top && (
          <div className="absolute top-0 inset-x-0 h-6 pointer-events-none" style={{ background: 'linear-gradient(180deg, rgba(0,0,0,0.85) 0%, transparent 100%)' }} />
        )}
        {scroll.bottom && (
          <div className="absolute bottom-0 inset-x-0 h-6 pointer-events-none flex items-end justify-center pb-0.5" style={{ background: 'linear-gradient(0deg, rgba(0,0,0,0.85) 0%, transparent 100%)' }}>
            <span className="text-[var(--rdr-faint)] text-[10px]">▾</span>
          </div>
        )}
      </div>

      <div className="p-3 space-y-3 shrink-0" style={{ borderTop: '1px solid var(--rdr-line)' }}>
        {self && (
          <div className={`flex items-center gap-2.5 ${collapsed ? 'justify-center' : 'px-2'}`}>
            <Avatar name={self.name} imageUrl={self.avatarUrl} size={30} />
            {!collapsed && (
              <div className="min-w-0">
                <p className="text-[var(--rdr-text)] text-sm font-medium truncate">{self.name}</p>
                <p className="text-[var(--rdr-accent-bright)] text-xs truncate">{self.job?.label || 'Administrator'}</p>
              </div>
            )}
          </div>
        )}

        <button
          onClick={onClose}
          title="Close"
          className={`w-full flex items-center gap-2 py-2 rounded-sm text-sm text-[var(--rdr-muted)] hover:text-[var(--rdr-heading)] hover:bg-white/5 transition-colors ${collapsed ? 'justify-center px-0' : 'justify-center px-3'}`}
        >
          <LogOut size={15} /> {!collapsed && 'Close'}
        </button>
      </div>
    </div>
  );
}
