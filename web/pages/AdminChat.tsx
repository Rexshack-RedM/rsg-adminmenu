import { locale } from '../i18n';
import { useEffect, useMemo, useRef, useState } from 'react';
import { Send, MessagesSquare, Users, Zap, ScrollText, UserCog, Wallet } from 'lucide-react';
import { fetchNui, useNuiData, useNuiEvent } from '../hooks/useNui';
import { Avatar } from '../components/Avatar';
import { Button } from '../components/Button';
import type { AdminChatMessage, AdminEntry, SelfInfo } from '../types';
import type { AdminPage } from '../components/Sidebar';

const mockMessages: AdminChatMessage[] = [
  { id: 1, sender_citizenid: 'DEV5678', sender_name: 'Old Moderator', sender_role: 'mod', sender_role_label: 'Moderator', sender_discord_name: 'oldmod', sender_discord_avatar_url: null, message: 'Anyone seen the report queue?', created_at: new Date(Date.now() - 120000).toISOString() },
  { id: 2, sender_citizenid: 'DEV1234', sender_name: 'Dev Admin', sender_role: 'admin', sender_role_label: 'Admin', sender_discord_name: 'uiforc', sender_discord_avatar_url: null, message: "On it, claiming #4 now.", created_at: new Date(Date.now() - 60000).toISOString() },
];

const mockAdmins: AdminEntry[] = [
  { citizenid: 'DEV1234', name: 'Dev Admin', role: 'admin', roleLabel: 'Admin', grantedBy: null, createdAt: new Date().toISOString(), serverId: 1, online: true, reportsResolved: 12, lastSeen: new Date().toISOString() },
  { citizenid: 'DEV5678', name: 'Old Moderator', role: 'mod', roleLabel: 'Moderator', grantedBy: null, createdAt: new Date().toISOString(), serverId: null, online: false, reportsResolved: 4, lastSeen: new Date().toISOString() },
];

interface AdminChatProps {
  self: SelfInfo | null;
  onNavigate: (page: AdminPage) => void;
}

export function AdminChat({ self, onNavigate }: AdminChatProps) {
  const [data, refresh] = useNuiData<AdminChatMessage[]>('getAdminChatMessages', {}, mockMessages);
  const [messages, setMessages] = useState<AdminChatMessage[]>([]);
  const [draft, setDraft] = useState('');
  const [sending, setSending] = useState(false);
  const scrollRef = useRef<HTMLDivElement>(null);

  useEffect(() => { setMessages(data ?? []); }, [data]);

  useNuiEvent<AdminChatMessage>('adminChatMessage', (msg) => {
    setMessages((prev) => [...prev, msg]);
  });

  useEffect(() => {
    scrollRef.current?.scrollTo({ top: scrollRef.current.scrollHeight, behavior: 'smooth' });
  }, [messages]);

  const [adminData] = useNuiData<AdminEntry[]>('getAdmins', {}, mockAdmins);
  const admins = adminData ?? [];
  const onlineAdmins = admins.filter((a) => a.online);

  const stats = useMemo(() => {
    const today = new Date().toDateString();
    const messagesToday = messages.filter((m) => new Date(m.created_at).toDateString() === today).length;
    const activeSenders = new Set(messages.map((m) => m.sender_citizenid)).size;
    return { total: messages.length, today: messagesToday, activeSenders };
  }, [messages]);

  // debug/mock path never receives the realtime broadcast, so echo locally
  const isMock = typeof (window as any).GetParentResourceName !== 'function';

  const send = async () => {
    const text = draft.trim();
    if (!text) return;
    setSending(true);
    setDraft('');
    await fetchNui('createAdminChatMessage', { message: text }, { success: true });
    if (isMock) {
      setMessages((prev) => [...prev, {
        id: prev.length + 1,
        sender_citizenid: self?.citizenid ?? 'me',
        sender_name: self?.name ?? locale('ui_you'),
        sender_role: null,
        sender_role_label: null,
        sender_discord_name: self?.name ?? null,
        sender_discord_avatar_url: self?.avatarUrl ?? null,
        message: text,
        created_at: new Date().toISOString(),
      }]);
    }
    setSending(false);
    refresh();
  };

  return (
    <div className="space-y-4 h-full flex flex-col min-h-0">
      <div>
        <h2 className="text-[var(--rdr-heading)] text-2xl font-bold">{locale('ui_admin_chat')}</h2>
        <p className="text-[var(--rdr-muted)] mt-1 text-sm">{locale('ui_admin_chat_between_online_staff')}</p>
      </div>

      <div className="flex-1 min-h-0 grid grid-cols-[1fr_260px] gap-4">
        <div className="rounded-sm flex flex-col min-h-0" style={{ background: 'var(--rdr-surface)', border: '1px solid var(--rdr-border)' }}>
          <div ref={scrollRef} className="flex-1 min-h-0 overflow-y-auto p-4 space-y-3">
            {messages.map((m) => {
              const own = self && m.sender_citizenid === self.citizenid;
              const displayName = m.sender_discord_name ? `@${m.sender_discord_name}` : m.sender_name;
              return (
                <div key={m.id} className={`flex gap-2.5 ${own ? 'flex-row-reverse' : ''}`}>
                  <Avatar name={m.sender_name} size={30} imageUrl={m.sender_discord_avatar_url ?? undefined} />
                  <div className={`max-w-[70%] ${own ? 'items-end' : 'items-start'} flex flex-col`}>
                    <div className="flex items-center gap-1.5 mb-0.5">
                      <span className="text-[var(--rdr-muted)] text-xs font-medium">{displayName}</span>
                      {m.sender_role_label && <span className="px-1.5 py-0.5 rounded-sm text-[9px] uppercase bg-[var(--rdr-accent-20)] text-[var(--rdr-accent-bright)]">{m.sender_role_label}</span>}
                    </div>
                    <div
                      className={`rounded-sm px-3 py-2 text-sm text-[var(--rdr-text)] border ${own ? 'bg-white/10 border-white/20' : 'border-[var(--rdr-border)]'}`}
                      style={{ background: own ? undefined : 'var(--rdr-surface-2)' }}
                    >
                      {m.message}
                    </div>
                    <span className="text-[var(--rdr-faint)] text-[10px] mt-0.5">{new Date(m.created_at).toLocaleTimeString()}</span>
                  </div>
                </div>
              );
            })}
            {messages.length === 0 && <p className="text-[var(--rdr-faint)] text-sm text-center py-8">{locale('ui_no_messages_yet_say_hello_to_the_team')}</p>}
          </div>
          <div className="flex gap-2 p-3 shrink-0" style={{ borderTop: '1px solid var(--rdr-line)' }}>
            <input
              value={draft}
              onChange={(e) => setDraft(e.target.value)}
              onKeyDown={(e) => { if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); send(); } }}
              placeholder={locale('ui_message_the_team')}
              maxLength={500}
              className="flex-1 bg-[var(--rdr-surface-2)] border border-[var(--rdr-border)] rounded-sm px-3 py-2 text-sm text-[var(--rdr-text)]"
            />
            <Button variant="outline" tone="accent" disabled={!draft.trim() || sending} isLoading={sending} onClick={send}>
              <Send size={14} /> {locale('ui_send')}
            </Button>
          </div>
        </div>

        <div className="space-y-4 min-h-0 overflow-y-auto">
          <div className="rounded-lg p-3" style={{ background: 'var(--rdr-surface)', border: '1px solid var(--rdr-border)' }}>
            <p className="text-[var(--rdr-muted)] text-xs uppercase tracking-wider font-medium mb-2 flex items-center gap-1.5"><Users size={13} /> {locale('ui_online_admins_x', onlineAdmins.length)}</p>
            <div className="space-y-1.5">
              {onlineAdmins.map((a) => (
                <div key={a.citizenid} className="flex items-center gap-2">
                  <Avatar name={a.name} size={22} imageUrl={a.discordAvatarUrl} />
                  <span className="text-[var(--rdr-text)] text-xs font-medium truncate">{a.discordName ? `@${a.discordName}` : a.name}</span>
                  <span className="px-1.5 py-0.5 rounded-sm text-[9px] uppercase bg-[var(--rdr-accent-20)] text-[var(--rdr-accent-bright)] ml-auto shrink-0">{a.roleLabel}</span>
                </div>
              ))}
              {onlineAdmins.length === 0 && <p className="text-[var(--rdr-faint)] text-xs">{locale('ui_no_admins_online')}</p>}
            </div>
          </div>

          <div className="rounded-lg p-3" style={{ background: 'var(--rdr-surface)', border: '1px solid var(--rdr-border)' }}>
            <p className="text-[var(--rdr-muted)] text-xs uppercase tracking-wider font-medium mb-2 flex items-center gap-1.5"><Zap size={13} /> {locale('ui_quick_actions')}</p>
            <div className="space-y-1.5">
              <Button variant="outline" fullWidth className="justify-start text-xs" onClick={() => onNavigate('admins')}><UserCog size={13} /> {locale('ui_admins')}</Button>
              <Button variant="outline" fullWidth className="justify-start text-xs" onClick={() => onNavigate('logs')}><ScrollText size={13} /> {locale('ui_logs')}</Button>
              <Button variant="outline" fullWidth className="justify-start text-xs" onClick={() => onNavigate('reports')}><MessagesSquare size={13} /> {locale('ui_reports')}</Button>
              <Button variant="outline" fullWidth className="justify-start text-xs" onClick={() => onNavigate('finances')}><Wallet size={13} /> {locale('ui_finances')}</Button>
            </div>
          </div>

          <div className="rounded-lg p-3" style={{ background: 'var(--rdr-surface)', border: '1px solid var(--rdr-border)' }}>
            <p className="text-[var(--rdr-muted)] text-xs uppercase tracking-wider font-medium mb-2">{locale('ui_chat_statistics')}</p>
            <div className="space-y-1.5 text-xs">
              <div className="flex justify-between"><span className="text-[var(--rdr-muted)]">{locale('ui_total_messages')}</span><span className="text-[var(--rdr-text)] font-medium">{stats.total}</span></div>
              <div className="flex justify-between"><span className="text-[var(--rdr-muted)]">{locale('ui_messages_today')}</span><span className="text-[var(--rdr-text)] font-medium">{stats.today}</span></div>
              <div className="flex justify-between"><span className="text-[var(--rdr-muted)]">{locale('ui_active_participants')}</span><span className="text-[var(--rdr-text)] font-medium">{stats.activeSenders}</span></div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
