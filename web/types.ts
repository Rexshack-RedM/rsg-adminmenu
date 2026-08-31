export type Mode = 'admin' | 'player';

export interface SelfInfo {
  name: string;
  citizenid: string;
  job?: { label?: string };
  avatarUrl?: string;
}

export interface Permissions {
  isAdmin: boolean;
  enablePlayerBlips: boolean;
  canManageHistory: boolean;
  canManageAdmins: boolean;
  atLeastMod: boolean;
  atLeastAdmin: boolean;
  fullAccess: boolean;
}

export interface TimeSettings {
  day: string | null;
  hour: number;
  minute: number;
  second: number;
  transition: number;
  freeze: boolean;
}

export interface WeatherSettings {
  type: string;
  transition: number;
  freeze: boolean;
  snow: boolean;
}

export interface WindSettings {
  direction: number;
  speed: number;
  freeze: boolean;
}

export interface WorldSettings {
  time: TimeSettings;
  weather: WeatherSettings;
  timescale: number;
  wind: WindSettings;
}

export type ResourceState = 'started' | 'starting' | 'stopped' | 'stopping' | 'uninitialized' | 'missing';

export interface ServerResource {
  name: string;
  state: ResourceState;
  version?: string;
  author?: string;
  description?: string;
  dependencies: string[];
}

export interface WebhookSettings {
  adminLogs: string;
  playerManagement: string;
  worldSettings: string;
  reports: string;
}

export interface CustomItem {
  name: string;
  label: string;
  description?: string;
  weight: number;
  type: string;
  image: string;
  created_by?: string | null;
  created_at?: string;
}

export interface OpenPayload {
  mode: Mode;
  self: SelfInfo;
  permissions: Permissions;
}

export interface OnlinePlayer {
  id: number;
  name: string;
  citizenid: string;
  coords?: { x: number; y: number; z: number };
}

export interface PlayerInfo {
  firstname: string;
  lastname: string;
  job: string;
  grade: number;
  cash: number;
  bloodmoney: number;
  bank: number;
  valbank: number;
  rhobank: number;
  blkbank: number;
  armbank: number;
  citizenid: string;
  serverid: number;
}

export interface InventoryItemEntry {
  slot: number;
  name: string;
  label: string;
  image?: string;
  amount: number;
  weight: number;
}

export interface ItemCatalogEntry {
  name: string;
  label: string;
  image?: string;
  type: string;
  weight: number;
  category?: string;
}

export interface HistoryEntry {
  id: number;
  citizenid: string;
  action: 'ban' | 'kick' | 'warn';
  reason: string | null;
  admin_name: string | null;
  duration_seconds: number | null;
  severity: string | null;
  created_at: string;
}

export interface PlayerDetail extends PlayerInfo {
  jobGradeName: string;
  role: string;
  roleLabel: string;
  availablePermissions: { value: string; label: string }[];
  ping: number;
  steamHex?: string;
  ip?: string;
  discordId?: string;
  discordName?: string;
  discordAvatarUrl?: string;
  items: InventoryItemEntry[];
}

export interface FinanceData {
  bank: number;
  valbank: number;
  rhobank: number;
  blkbank: number;
  armbank: number;
  cash: number;
  bloodmoney: number;
}

export type MoneyType = keyof FinanceData;

export interface LeaderboardEntry {
  rank: number;
  citizenid: string;
  name: string;
  accountName: string;
  job: string;
  online: boolean;
  playtimeMinutes: number;
  money: number;
  discordId?: string;
  discordName?: string;
  discordAvatarUrl?: string;
}

export interface DashboardStats {
  onlineCount: number;
  totalMoney: number;
  serverUptimeSeconds: number;
  topPlayer: LeaderboardEntry | null;
  leaderboard: LeaderboardEntry[];
}

export type ReportType = 'bug' | 'player' | 'question';
export type ReportStatus = 'open' | 'claimed' | 'resolved' | 'closed';
export type ReportSeverity = 'low' | 'medium' | 'high';

export interface Report {
  id: number;
  report_type: ReportType;
  severity: ReportSeverity;
  reporter_id: number;
  reporter_name: string;
  reporter_license: string;
  reporter_discord?: string;
  reporter_discord_name?: string;
  reporter_discord_avatar?: string;
  reporter_steam?: string;
  reporter_coords: string;
  reported_player_id?: number;
  reported_player_name?: string;
  title: string;
  description: string;
  image_url?: string;
  status: ReportStatus;
  assigned_admin_id?: number;
  assigned_admin_name?: string;
  created_at: string;
  updated_at: string;
}

export interface ReportMessage {
  id: number;
  report_id: number;
  sender_type: 'player' | 'admin';
  sender_id: number;
  sender_name: string;
  message: string;
  created_at_text: string;
}

export interface ReportNearbyPlayer {
  id: number;
  report_id: number;
  player_id: number;
  player_name: string;
  player_license: string;
  distance: number;
}

export interface ItemOption {
  value: string;
  label: string;
}

export interface ToastMessage {
  id: number;
  type: 'success' | 'error' | 'info';
  title: string;
  description?: string;
}

export interface BotLogo {
  logoUrl?: string;
  name?: string;
}

export interface ManagedPlayer {
  citizenid: string;
  serverId: number | null;
  name: string;
  accountName: string;
  job: string;
  money: number;
  playtimeMinutes: number;
  lastSeen: string | null;
  online: boolean;
  discordId?: string;
  discordName?: string;
  discordAvatarUrl?: string;
  banned: boolean;
  banId?: number;
  banReason?: string;
  banExpire?: number;
  banPermanent?: boolean;
  bannedBy?: string;
}

export type WhitelistStatus = 'active' | 'suspended' | 'expired';

export interface WhitelistEntry {
  id: number;
  citizenid: string;
  player_name: string;
  account_name: string;
  status: WhitelistStatus;
  reason: string | null;
  added_by_name: string | null;
  expires_at: string | null;
  created_at: string;
}

export interface ActivityPoint {
  date: string;
  averagePlayers: number;
  peakPlayers: number;
}

export interface JobDistributionEntry {
  job: string;
  count: number;
}

export interface MoneyTypeTotal {
  type: MoneyType;
  total: number;
}

export interface DailyMoneyPoint {
  date: string;
  averageMoney: number;
}

export interface HourlyActivityPoint {
  hour: string;
  averagePlayers: number;
  peakPlayers: number;
}

export interface AdminRoleConfig {
  role: string;
  level: number;
  label: string;
}

export interface AdminEntry {
  citizenid: string;
  name: string;
  role: string;
  roleLabel: string;
  grantedBy: string | null;
  createdAt: string;
  serverId: number | null;
  online: boolean;
  steamHex?: string;
  lastSeen: string | null;
  discordId?: string;
  discordName?: string;
  discordAvatarUrl?: string;
  reportsResolved: number;
}

export type LogCategory = 'admin_action' | 'economy' | 'player_action' | 'security' | 'server_event' | 'system';
export type LogSeverity = 'low' | 'medium' | 'high';

export interface LogEntry {
  id: number;
  category: LogCategory;
  severity: LogSeverity;
  admin_citizenid: string | null;
  admin_name: string | null;
  action: string;
  details: string | null;
  target_name: string | null;
  ip: string | null;
  created_at: string;
}

export interface LogsResult {
  logs: LogEntry[];
  total: number;
  page: number;
  perPage: number;
  counts: Record<string, number>;
}

export interface AdminChatMessage {
  id: number;
  sender_citizenid: string;
  sender_name: string;
  sender_role: string | null;
  sender_role_label: string | null;
  sender_discord_name: string | null;
  sender_discord_avatar_url: string | null;
  message: string;
  created_at: string;
}

export type TeleportCategory = 'towns' | 'gangcamps' | 'nature' | 'shops' | 'special';

export interface TeleportLocation {
  id: number | string;
  name: string;
  category: TeleportCategory;
  description?: string;
  x: number;
  y: number;
  z: number;
  heading: number;
  popular?: boolean;
  custom?: boolean;
}

export interface MapBlip {
  id: number;
  name: string;
  sprite: string;
  x: number;
  y: number;
  z: number;
  scale: number;
  created_by?: string | null;
  created_at?: string;
}

export interface CurrentCoords {
  x: number;
  y: number;
  z: number;
  heading: number;
}

export interface StatisticsData {
  players: {
    activity: ActivityPoint[];
    jobDistribution: JobDistributionEntry[];
  };
  economy: {
    dailyMoney: DailyMoneyPoint[];
    moneyByType: MoneyTypeTotal[];
  };
  performance: {
    onlineCount: number;
    resourceCount: number;
    serverUptimeSeconds: number;
    averagePing: number;
    hourlyActivity: HourlyActivityPoint[];
  };
}
