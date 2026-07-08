'use client';

import { FormEvent, useEffect, useState } from 'react';
import { buildPaginatedSearchParams, hasNextPage, pageAfterRemovingLastItem, pageCount } from '../lib/search';

type AdminUser = { id: string; fullName: string; phoneNumber: string; role: string; language: string };
type Report = { id: string; reporterId: string; reporterName: string; targetType: string; targetId: string; reason: string; status: string; priority: number; createdAt: string };
type Church = { id: string; name: string; city: string; verificationStatus: string; verified: boolean; createdAt: string; description?: string; churchType?: string };
type DirectoryUser = { id: string; fullName: string; phoneNumber: string; username: string; role: string; language: string; createdAt: string };
type Activity = { id: string; actorName: string; action: string; targetType: string; targetId: string; outcome: string; createdAt: string };
type AuditLog = Activity & { actorId?: string; ipAddress?: string; userAgent?: string; requestId?: string; httpStatus?: number; metadata?: Record<string, unknown> };
type AdminView = 'overview' | 'moderation' | 'churches' | 'users' | 'security' | 'activity';
type Dashboard = {
  stats: { users: number; churches: number; pendingChurches: number; openReports: number; posts: number; events: number; activeAdmins: number };
  reports: Report[];
  pendingChurches: Church[];
  activity: Activity[];
};

const emptyDashboard: Dashboard = {
  stats: { users: 0, churches: 0, pendingChurches: 0, openReports: 0, posts: 0, events: 0, activeAdmins: 0 },
  reports: [],
  pendingChurches: [],
  activity: [],
};

const CHURCH_PAGE_SIZE = 12;
const USER_PAGE_SIZE = 12;
const USER_ROLES = ['member', 'moderator', 'admin', 'platform_admin', 'super_admin', 'suspended'] as const;

export default function Page() {
  const [user, setUser] = useState<AdminUser | null>(null);
  const [dashboard, setDashboard] = useState<Dashboard>(emptyDashboard);
  const [churches, setChurches] = useState<Church[]>([]);
  const [churchSearch, setChurchSearch] = useState('');
  const [churchPage, setChurchPage] = useState(0);
  const [churchTotal, setChurchTotal] = useState(0);
  const [users, setUsers] = useState<DirectoryUser[]>([]);
  const [userSearch, setUserSearch] = useState('');
  const [userRoleFilter, setUserRoleFilter] = useState('');
  const [userPage, setUserPage] = useState(0);
  const [userTotal, setUserTotal] = useState(0);
  const [auditLogs, setAuditLogs] = useState<AuditLog[]>([]);
  const [loading, setLoading] = useState(false);
  const [busy, setBusy] = useState('');
  const [notice, setNotice] = useState('');
  const [churchAdminUsername, setChurchAdminUsername] = useState('');
  const [resolvedChurchAdmin, setResolvedChurchAdmin] = useState<DirectoryUser | null>(null);
  const [activeView, setActiveView] = useState<AdminView>('overview');

  useEffect(() => {
    let active = true;
    async function restore() {
      try {
        const response = await fetch('/api/session', { cache: 'no-store' });
        if (!response.ok) return;
        const session = await response.json() as AdminUser;
        if (active) setUser(session);
      } catch {}
    }
    void restore();
    return () => { active = false; };
  }, []);

  useEffect(() => {
    if (user) void loadDashboard();
  }, [user]);

  useEffect(() => {
    if (!user) return;
    if (activeView === 'users') void loadUsers(userSearch, userRoleFilter, userPage);
    if (activeView === 'security') void loadAuditLogs();
  }, [activeView]);

  async function loadChurchOptions(query = churchSearch, page = churchPage) {
    const search = buildPaginatedSearchParams({ query, page, pageSize: CHURCH_PAGE_SIZE });
    setLoading(true);
    try {
      const response = await fetch(`/api/admin/churches?${search.params.toString()}`, { cache: 'no-store' });
      if (!response.ok) return;
      const payload = await response.json() as Church[] | { items: Church[]; total: number; limit?: number; offset?: number };
      if (Array.isArray(payload)) {
        setChurches(payload.slice(0, search.pageSize));
        setChurchTotal(payload.length);
      } else {
        setChurches(payload.items);
        setChurchTotal(payload.total);
      }
      setChurchSearch(search.query);
      setChurchPage(search.page);
    } finally {
      setLoading(false);
    }
  }

  function searchChurches() {
    void loadChurchOptions(churchSearch, 0);
  }

  function changeChurchPage(nextPage: number) {
    void loadChurchOptions(churchSearch, nextPage);
  }

  async function loadUsers(query = userSearch, role = userRoleFilter, page = userPage) {
    const search = buildPaginatedSearchParams({ query, page, pageSize: USER_PAGE_SIZE });
    if (role) search.params.set('role', role);
    setLoading(true);
    try {
      const response = await fetch(`/api/admin/users?${search.params.toString()}`, { cache: 'no-store' });
      if (!response.ok) throw new Error(readError(await response.json().catch(() => null)));
      const payload = await response.json() as DirectoryUser[] | { items: DirectoryUser[]; total: number; limit?: number; offset?: number };
      if (Array.isArray(payload)) {
        setUsers(payload.slice(0, USER_PAGE_SIZE));
        setUserTotal(payload.length);
      } else {
        setUsers(payload.items);
        setUserTotal(payload.total);
      }
      setUserSearch(search.query);
      setUserRoleFilter(role);
      setUserPage(search.page);
    } catch (error) {
      setNotice(error instanceof Error ? error.message : 'Users unavailable');
    } finally {
      setLoading(false);
    }
  }

  function searchUsers() {
    void loadUsers(userSearch, userRoleFilter, 0);
  }

  function changeUserPage(nextPage: number) {
    void loadUsers(userSearch, userRoleFilter, nextPage);
  }

  async function loadAuditLogs() {
    setLoading(true);
    try {
      const response = await fetch('/api/admin/audit?limit=100', { cache: 'no-store' });
      if (!response.ok) throw new Error(readError(await response.json().catch(() => null)));
      setAuditLogs(await response.json() as AuditLog[]);
    } catch (error) {
      setNotice(error instanceof Error ? error.message : 'Audit logs unavailable');
    } finally {
      setLoading(false);
    }
  }

  async function loadDashboard(refreshChurches = true) {
    setLoading(true);
    try {
      const response = await fetch('/api/admin/dashboard', { cache: 'no-store' });
      if (response.status === 401) {
        setUser(null);
        return;
      }
      if (!response.ok) throw new Error('Could not load administration data');
      setDashboard(await response.json() as Dashboard);
      if (refreshChurches) await loadChurchOptions('', 0);
    } catch (error) {
      setNotice(error instanceof Error ? error.message : 'Dashboard unavailable');
    } finally {
      setLoading(false);
    }
  }

  async function login(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setBusy('login');
    setNotice('');
    const form = new FormData(event.currentTarget);
    try {
      const response = await fetch('/api/session/login', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({
          phoneNumber: String(form.get('phoneNumber') ?? ''),
          password: String(form.get('password') ?? ''),
        }),
      });
      const payload = await response.json();
      if (!response.ok) throw new Error(readError(payload));
      setUser(payload.user as AdminUser);
    } catch (error) {
      setNotice(error instanceof Error ? error.message : 'Authentication failed');
    } finally {
      setBusy('');
    }
  }

  async function logout() {
    setBusy('logout');
    await fetch('/api/session/logout', { method: 'POST' });
    setUser(null);
    setDashboard(emptyDashboard);
    setChurches([]);
    setChurchSearch('');
    setChurchPage(0);
    setChurchTotal(0);
    setUsers([]);
    setUserSearch('');
    setUserRoleFilter('');
    setUserPage(0);
    setUserTotal(0);
    setAuditLogs([]);
    setBusy('');
  }

  async function updateReport(id: string, status: 'resolved' | 'closed') {
    setBusy(`report:${id}`);
    setNotice('');
    const response = await fetch(`/api/admin/reports/${id}`, {
      method: 'PATCH',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ status }),
    });
    if (response.ok) {
      setNotice(status === 'resolved' ? 'Report marked resolved.' : 'Report closed.');
      await loadDashboard(false);
    } else {
      setNotice(readError(await response.json().catch(() => null)));
    }
    setBusy('');
  }

  async function actOnReport(report: Report, action: 'remove_content' | 'suspend_user') {
    const confirmText = action === 'suspend_user'
      ? 'Suspend the reported user? They will be signed out and blocked from signing in.'
      : 'Remove the reported content? It will stop appearing in feeds and threads.';
    if (!window.confirm(confirmText)) return;
    setBusy(`report:${report.id}`);
    setNotice('');
    const response = await fetch(`/api/admin/reports/${report.id}`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ action, status: 'resolved' }),
    });
    if (response.ok) {
      setNotice(action === 'suspend_user' ? 'User suspended and report resolved.' : 'Content removed and report resolved.');
      await loadDashboard(false);
    } else {
      setNotice(readError(await response.json().catch(() => null)));
    }
    setBusy('');
  }

  async function reviewChurch(id: string, action: 'approve' | 'reject') {
    setBusy(`church:${id}`);
    setNotice('');
    const response = await fetch(`/api/admin/churches/${id}`, {
      method: 'PATCH',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ action }),
    });
    if (response.ok) {
      setNotice(action === 'approve' ? 'Church verification approved.' : 'Church verification rejected.');
      await loadDashboard(false);
      await loadChurchOptions(churchSearch, churchPage);
    } else {
      setNotice(readError(await response.json().catch(() => null)));
    }
    setBusy('');
  }


  async function createChurch(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const formElement = event.currentTarget;
    setBusy('church:create');
    setNotice('');
    const form = new FormData(formElement);
    const body = {
      name: String(form.get('name') ?? '').trim(),
      city: String(form.get('city') ?? '').trim(),
      churchType: String(form.get('churchType') ?? 'Gospel').trim(),
      address: String(form.get('address') ?? '').trim(),
      phone: String(form.get('phone') ?? '').trim(),
      email: String(form.get('email') ?? '').trim(),
      website: String(form.get('website') ?? '').trim(),
      description: String(form.get('description') ?? '').trim(),
      doctrineStatement: String(form.get('doctrineStatement') ?? '').trim(),
    };
    const response = await fetch('/api/admin/churches', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify(body),
    });
    if (response.ok) {
      formElement.reset();
      setNotice('Church registered as official and verified. Assign a church admin below.');
      await loadDashboard(false);
      await loadChurchOptions(churchSearch, 0);
    } else {
      setNotice(readError(await response.json().catch(() => null)));
    }
    setBusy('');
  }



  async function resolveChurchAdminUsername(usernameInput = churchAdminUsername) {
    const username = usernameInput.trim().toLowerCase();
    setResolvedChurchAdmin(null);
    if (!username) {
      setNotice('Enter the exact username first.');
      return null;
    }
    setBusy('church:resolve-user');
    setNotice('');
    const response = await fetch(`/api/admin/users?username=${encodeURIComponent(username)}`, { cache: 'no-store' });
    setBusy('');
    if (!response.ok) {
      setNotice(response.status === 404 ? 'No user found with that exact username.' : readError(await response.json().catch(() => null)));
      return null;
    }
    const targetUser = await response.json() as DirectoryUser;
    setResolvedChurchAdmin(targetUser);
    setNotice(`Selected ${targetUser.fullName} (@${targetUser.username}).`);
    return targetUser;
  }


  async function editChurch(church: Church) {
    const name = window.prompt('Church name', church.name)?.trim();
    if (!name) return;
    const city = window.prompt('City', church.city || '')?.trim();
    if (city == null) return;
    const churchType = window.prompt('Church type', church.churchType || 'Gospel')?.trim();
    if (churchType == null) return;
    const description = window.prompt('Description', church.description || '')?.trim();
    if (description == null) return;
    setBusy(`church:edit:${church.id}`);
    setNotice('');
    const response = await fetch(`/api/admin/churches/${encodeURIComponent(church.id)}`, {
      method: 'PATCH',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ name, city, churchType, description }),
    });
    if (response.ok) {
      setNotice(`${name} updated.`);
      await loadDashboard(false);
      await loadChurchOptions(churchSearch, churchPage);
    } else {
      setNotice(readError(await response.json().catch(() => null)));
    }
    setBusy('');
  }

  async function deleteChurch(church: Church) {
    if (!window.confirm(`Suspend ${church.name}? It will disappear from public church search.`)) return;
    setBusy(`church:delete:${church.id}`);
    setNotice('');
    const response = await fetch(`/api/admin/churches/${encodeURIComponent(church.id)}`, { method: 'DELETE' });
    if (response.ok) {
      setNotice(`${church.name} suspended.`);
      await loadDashboard(false);
      await loadChurchOptions(churchSearch, pageAfterRemovingLastItem(churchPage, churches.length));
    } else {
      setNotice(readError(await response.json().catch(() => null)));
    }
    setBusy('');
  }

  async function updateUserRole(targetUser: DirectoryUser, role: string) {
    if (targetUser.id === user?.id) {
      setNotice('You cannot change your own admin role.');
      return;
    }
    setBusy(`user:role:${targetUser.id}`);
    setNotice('');
    const response = await fetch(`/api/admin/users/${encodeURIComponent(targetUser.id)}`, {
      method: 'PATCH',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ role }),
    });
    if (response.ok) {
      setNotice(`${targetUser.fullName} role updated to ${role.replaceAll('_', ' ')}.`);
      await loadUsers(userSearch, userRoleFilter, userPage);
      await loadDashboard(false);
    } else {
      setNotice(readError(await response.json().catch(() => null)));
    }
    setBusy('');
  }

  async function revokeUserSessions(targetUser: DirectoryUser) {
    if (targetUser.id === user?.id) {
      setNotice('You cannot revoke your own active session from here.');
      return;
    }
    if (!window.confirm(`Revoke all sessions for ${targetUser.fullName}?`)) return;
    setBusy(`user:sessions:${targetUser.id}`);
    setNotice('');
    const response = await fetch(`/api/admin/users/${encodeURIComponent(targetUser.id)}/sessions`, { method: 'POST' });
    if (response.ok) {
      setNotice(`${targetUser.fullName} sessions revoked.`);
      await loadAuditLogs();
    } else {
      setNotice(readError(await response.json().catch(() => null)));
    }
    setBusy('');
  }

  async function toggleUserSuspension(targetUser: DirectoryUser) {
    const nextRole = targetUser.role === 'suspended' ? 'member' : 'suspended';
    if (nextRole === 'suspended' && !window.confirm(`Suspend ${targetUser.fullName}? They will not be able to sign in.`)) return;
    await updateUserRole(targetUser, nextRole);
  }

  async function assignChurchAdmin(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const formElement = event.currentTarget;
    setBusy('church:assign');
    setNotice('');
    const form = new FormData(formElement);
    const churchId = String(form.get('churchId') ?? '').trim();
    const username = String(form.get('username') ?? '').trim();
    const role = String(form.get('role') ?? 'church_admin').trim();
    const targetUser = resolvedChurchAdmin?.username === username.toLowerCase()
      ? resolvedChurchAdmin
      : await resolveChurchAdminUsername(username);
    if (!targetUser) {
      setBusy('');
      return;
    }
    const response = await fetch(`/api/admin/churches/${encodeURIComponent(churchId)}/managers`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ userId: targetUser.id, role }),
    });
    if (response.ok) {
      formElement.reset();
      setChurchAdminUsername('');
      setResolvedChurchAdmin(null);
      setNotice(role.replaceAll('_', ' ') + ` assigned to ${targetUser.fullName} (@${targetUser.username}).`);
      await loadDashboard(false);
    } else {
      setNotice(readError(await response.json().catch(() => null)));
    }
    setBusy('');
  }

  if (!user) {
    return (
      <main className="login-shell">
        <section className="login-story">
          <div className="brand-lockup"><span className="brand-cross">+</span><span>Sanctuary Command</span></div>
          <div className="story-copy">
            <p className="eyebrow">TRUST OPERATIONS</p>
            <h1>Steward the network.<br />Protect the fellowship.</h1>
            <p className="story-lead">A focused command center for church verification, community safety, and platform accountability.</p>
          </div>
          <div className="story-footer">
            <span>Private administrative system</span>
            <span>JWT secured</span>
            <span>Every action audited</span>
          </div>
        </section>
        <section className="login-panel">
          <form className="login-card" onSubmit={login}>
            <div className="login-heading">
              <span className="number-tag">01</span>
              <div><p className="eyebrow">AUTHORIZED PERSONNEL</p><h2>Enter the command room</h2></div>
            </div>
            <label>
              <span>Administrator phone</span>
              <input name="phoneNumber" inputMode="tel" autoComplete="username" placeholder="+251 9..." required />
            </label>
            <label>
              <span>Password</span>
              <input name="password" type="password" autoComplete="current-password" placeholder="Minimum 12 characters" minLength={10} required />
            </label>
            {notice && <p className="form-error">{notice}</p>}
            <button className="primary-button" disabled={busy === 'login'}>
              <span>{busy === 'login' ? 'Authenticating...' : 'Authenticate'}</span><span aria-hidden="true">-&gt;</span>
            </button>
            <p className="login-note">Administrators cannot register here. The first super administrator must be created through the backend CLI.</p>
          </form>
        </section>
      </main>
    );
  }

  const navigation = [
    { id: 'overview' as const, label: 'Overview', code: 'OV' },
    { id: 'moderation' as const, label: 'Moderation', code: 'MO', count: dashboard.stats.openReports },
    { id: 'churches' as const, label: 'Church review', code: 'CH', count: dashboard.stats.pendingChurches },
    { id: 'users' as const, label: 'Users', code: 'US', count: userTotal || dashboard.stats.users },
    { id: 'security' as const, label: 'Security audit', code: 'SE' },
    { id: 'activity' as const, label: 'Admin activity', code: 'AC' },
  ];

  return (
    <main className="admin-shell">
      <aside className="sidebar">
        <div className="sidebar-brand"><span className="brand-cross">+</span><div><strong>Sanctuary</strong><small>COMMAND</small></div></div>
        <nav>
          {navigation.map((item) => (
            <button key={item.id} className={activeView === item.id ? 'nav-item active' : 'nav-item'} onClick={() => setActiveView(item.id)}>
              <span className="nav-code">{item.code}</span><span>{item.label}</span>
              {'count' in item && item.count ? <b>{item.count}</b> : null}
            </button>
          ))}
        </nav>
        <div className="sidebar-foot">
          <div className="admin-avatar">{initials(user.fullName)}</div>
          <div><strong>{user.fullName}</strong><small>{user.role.replaceAll('_', ' ')}</small></div>
          <button onClick={logout} disabled={busy === 'logout'} title="Sign out">EXIT</button>
        </div>
      </aside>

      <section className="workspace">
        <header className="topbar">
          <div><p className="eyebrow">PLATFORM CONTROL / {activeView.toUpperCase()}</p><h1>{viewTitle(activeView)}</h1></div>
          <div className="topbar-actions">
            <span className="live-status"><i /> Systems live</span>
            <button className="refresh-button" onClick={() => void loadDashboard()} disabled={loading}>{loading ? 'Syncing' : 'Refresh data'}</button>
          </div>
        </header>

        {notice && <div className="notice"><span>{notice}</span><button onClick={() => setNotice('')}>CLOSE</button></div>}

        {(activeView === 'overview' || activeView === 'moderation') && (
          <>
            {activeView === 'overview' && <Stats dashboard={dashboard} />}
            <section className="panel">
              <PanelHeading index="02" title="Safety queue" detail="Reports ordered by urgency and age" action={() => setActiveView('moderation')} />
              <div className="report-list">
                {dashboard.reports.length === 0 ? <Empty text="No reports are waiting for review." /> : dashboard.reports.map((report) => (
                  <article className="report-row" key={report.id}>
                    <div className={`priority p${priorityBand(report.priority)}`}><span>{report.priority || 20}</span><small>RISK</small></div>
                    <div className="report-copy">
                      <div className="row-meta"><span>{report.targetType}</span><time>{formatDate(report.createdAt)}</time></div>
                      <h3>{report.reason}</h3>
                      <p>Reported by {report.reporterName} <span>/</span> Target {report.targetId.slice(0, 8)}</p>
                    </div>
                    <span className={`status-chip ${report.status}`}>{report.status}</span>
                    <div className="row-actions">
                      <button onClick={() => updateReport(report.id, 'resolved')} disabled={busy === `report:${report.id}` || report.status === 'resolved'}>Resolve</button>
                      {['post', 'comment', 'post_comment', 'discussion', 'community_discussion'].includes(report.targetType) && (
                        <button className="danger" onClick={() => actOnReport(report, 'remove_content')} disabled={busy === `report:${report.id}`}>Remove content</button>
                      )}
                      <button className="danger" onClick={() => actOnReport(report, 'suspend_user')} disabled={busy === `report:${report.id}`}>Suspend user</button>
                      <button className="quiet" onClick={() => updateReport(report.id, 'closed')} disabled={busy === `report:${report.id}` || report.status === 'closed'}>Close</button>
                    </div>
                  </article>
                ))}
              </div>
            </section>
          </>
        )}

        {(activeView === 'overview' || activeView === 'churches') && (
          <section className="panel">
            <PanelHeading index="03" title="Church registration" detail="Create official church pages and review trust requests" action={() => setActiveView('churches')} />
            {activeView === 'churches' && (
              <>
              <form className="church-create-form" onSubmit={createChurch}>
                <div className="form-intro"><strong>Register church</strong><span>Created by super admin as official and verified. Assign a church admin below after registration.</span></div>
                <label><span>Church name</span><input name="name" required placeholder="Mulu Wongel Church" /></label>
                <label><span>City</span><input name="city" required placeholder="Addis Ababa" /></label>
                <label><span>Type</span><input name="churchType" defaultValue="Gospel" /></label>
                <label><span>Phone</span><input name="phone" inputMode="tel" /></label>
                <label className="wide"><span>Address</span><input name="address" /></label>
                <label><span>Email</span><input name="email" type="email" /></label>
                <label><span>Website</span><input name="website" placeholder="https://..." /></label>
                <label className="wide"><span>Description</span><textarea name="description" rows={3} /></label>
                <label className="wide"><span>Doctrine statement</span><textarea name="doctrineStatement" rows={3} /></label>
                <button className="primary-button church-submit" disabled={busy === 'church:create'}>{busy === 'church:create' ? 'Registering...' : 'Register church'}</button>
              </form>
              <form className="church-assign-form" onSubmit={assignChurchAdmin}>
                <div className="form-intro"><strong>Assign or change church admin</strong><span>Use the exact username selected during mobile registration. Reassigning a church changes the active manager without waiting for approval.</span></div>
                <label><span>Search church</span><input value={churchSearch} onChange={(event) => setChurchSearch(event.target.value)} onKeyDown={(event) => { if (event.key === 'Enter') { event.preventDefault(); searchChurches(); } }} placeholder="Church name or city" /></label>
                <button type="button" className="quiet-button" disabled={loading} onClick={searchChurches}>{loading ? 'Searching...' : 'Search churches'}</button>
                <label><span>Church</span><select name="churchId" required defaultValue=""><option value="" disabled>{churches.length ? `Select church (${churches.length} of ${churchTotal})` : 'Search church first'}</option>{churches.map((church) => <option key={church.id} value={church.id}>{church.name} / {church.city || 'Location not supplied'}</option>)}</select></label>
                <label><span>Exact username</span><input name="username" required placeholder="selam_abebe" autoComplete="off" value={churchAdminUsername} onChange={(event) => { setChurchAdminUsername(event.target.value); setResolvedChurchAdmin(null); }} onBlur={() => { if (churchAdminUsername.trim()) void resolveChurchAdminUsername(); }} /></label>
                <label><span>Selected user</span><div className="resolved-user">{resolvedChurchAdmin ? <><strong>{resolvedChurchAdmin.fullName}</strong><small>@{resolvedChurchAdmin.username} / {resolvedChurchAdmin.phoneNumber}</small></> : <small>Enter username to select user</small>}</div></label>
                <label><span>Role</span><select name="role" defaultValue="church_admin"><option value="church_admin">Church admin</option><option value="pastor">Pastor</option><option value="elder">Elder</option></select></label>
                <button type="button" className="quiet-button" disabled={busy === 'church:resolve-user'} onClick={() => void resolveChurchAdminUsername()}>{busy === 'church:resolve-user' ? 'Checking...' : 'Find user'}</button>
                <button className="primary-button church-submit" disabled={busy === 'church:assign'}>{busy === 'church:assign' ? 'Assigning...' : 'Assign / change manager'}</button>
              </form>
              <div className="church-directory-head"><div><strong>Registered churches</strong><span>{churchTotal} searchable churches / page {churchPage + 1} of {pageCount(churchTotal, CHURCH_PAGE_SIZE)}</span></div><div className="pagination-controls"><button type="button" className="quiet-button" disabled={loading || churchPage <= 0} onClick={() => changeChurchPage(churchPage - 1)}>Previous</button><button type="button" className="quiet-button" disabled={loading || !hasNextPage(churchPage, churchTotal, CHURCH_PAGE_SIZE)} onClick={() => changeChurchPage(churchPage + 1)}>Next</button></div></div>
              <div className="church-grid manage-grid">
                {churches.length === 0 ? <Empty text="Search churches to manage records." /> : churches.map((church) => (
                  <article className="church-card" key={church.id}>
                    <div className="church-monogram">{initials(church.name)}</div>
                    <div className="church-info"><span>{church.verified ? 'VERIFIED' : church.verificationStatus.toUpperCase()} {formatDate(church.createdAt)}</span><h3>{church.name}</h3><p>{church.city || 'Location not supplied'} / {church.churchType || 'Church'}</p></div>
                    <div className="church-actions">
                      <button type="button" onClick={() => void editChurch(church)} disabled={busy === `church:edit:${church.id}`}>Edit</button>
                      <button type="button" className="quiet" onClick={() => void deleteChurch(church)} disabled={busy === `church:delete:${church.id}`}>Suspend</button>
                    </div>
                  </article>
                ))}
              </div>
              </>
            )}
            <div className="church-directory-head"><strong>Pending verification</strong><span>{dashboard.pendingChurches.length} requests</span></div>
            <div className="church-grid">
              {dashboard.pendingChurches.length === 0 ? <Empty text="No church verification requests are pending." /> : dashboard.pendingChurches.map((church) => (
                <article className="church-card" key={church.id}>
                  <div className="church-monogram">{initials(church.name)}</div>
                  <div className="church-info"><span>REQUESTED {formatDate(church.createdAt)}</span><h3>{church.name}</h3><p>{church.city || 'Location not supplied'}</p></div>
                  <div className="church-actions">
                    <button onClick={() => reviewChurch(church.id, 'approve')} disabled={busy === `church:${church.id}`}>Approve</button>
                    <button className="quiet" onClick={() => reviewChurch(church.id, 'reject')} disabled={busy === `church:${church.id}`}>Reject</button>
                  </div>
                </article>
              ))}
            </div>
          </section>
        )}

        {activeView === 'users' && (
          <section className="panel">
            <PanelHeading index="04" title="User administration" detail="Search accounts, manage platform roles, suspend access, and revoke sessions" action={() => setActiveView('users')} />
            <div className="admin-tools">
              <label><span>Search users</span><input value={userSearch} onChange={(event) => setUserSearch(event.target.value)} onKeyDown={(event) => { if (event.key === 'Enter') { event.preventDefault(); searchUsers(); } }} placeholder="Full name, username, or phone" /></label>
              <label><span>Role</span><select value={userRoleFilter} onChange={(event) => { setUserRoleFilter(event.target.value); void loadUsers(userSearch, event.target.value, 0); }}><option value="">All roles</option>{USER_ROLES.map((role) => <option key={role} value={role}>{humanize(role)}</option>)}</select></label>
              <button type="button" className="quiet-button" disabled={loading} onClick={searchUsers}>{loading ? 'Searching...' : 'Search users'}</button>
            </div>
            <div className="church-directory-head"><div><strong>Accounts</strong><span>{userTotal} users / page {userPage + 1} of {pageCount(userTotal, USER_PAGE_SIZE)}</span></div><div className="pagination-controls"><button type="button" className="quiet-button" disabled={loading || userPage <= 0} onClick={() => changeUserPage(userPage - 1)}>Previous</button><button type="button" className="quiet-button" disabled={loading || !hasNextPage(userPage, userTotal, USER_PAGE_SIZE)} onClick={() => changeUserPage(userPage + 1)}>Next</button></div></div>
            <div className="admin-table">
              {users.length === 0 ? <Empty text="No users match this search." /> : users.map((targetUser) => (
                <article className="admin-row" key={targetUser.id}>
                  <div className="admin-avatar compact">{initials(targetUser.fullName)}</div>
                  <div className="admin-row-copy"><strong>{targetUser.fullName}</strong><p>@{targetUser.username || 'no_username'} / {targetUser.phoneNumber}</p><small>Joined {formatDate(targetUser.createdAt)}</small></div>
                  <span className={`status-chip ${targetUser.role === 'suspended' ? 'closed' : targetUser.role}`}>{humanize(targetUser.role)}</span>
                  <select className="role-select" value={targetUser.role} disabled={busy === `user:role:${targetUser.id}` || targetUser.id === user.id} onChange={(event) => void updateUserRole(targetUser, event.target.value)}>{USER_ROLES.map((role) => <option key={role} value={role}>{humanize(role)}</option>)}</select>
                  <div className="row-actions"><button type="button" className="quiet" disabled={busy === `user:sessions:${targetUser.id}` || targetUser.id === user.id} onClick={() => void revokeUserSessions(targetUser)}>Revoke sessions</button><button type="button" disabled={busy === `user:role:${targetUser.id}` || targetUser.id === user.id} onClick={() => void toggleUserSuspension(targetUser)}>{targetUser.role === 'suspended' ? 'Restore' : 'Suspend'}</button></div>
                </article>
              ))}
            </div>
          </section>
        )}

        {activeView === 'security' && (
          <section className="panel activity-panel">
            <PanelHeading index="05" title="Security audit" detail="Recent platform audit events and administrative actions" action={() => setActiveView('security')} />
            <div className="activity-list audit-list">
              {auditLogs.length === 0 ? <Empty text="No audit events found." /> : auditLogs.map((activity) => (
                <article key={activity.id}>
                  <span className={activity.outcome === 'success' ? 'activity-dot success' : 'activity-dot failed'} />
                  <div><strong>{humanize(activity.action)}</strong><p>{activity.targetType} {activity.targetId?.slice(0, 12) || 'unknown'} {activity.httpStatus ? `/ HTTP ${activity.httpStatus}` : ''}</p></div>
                  <time>{formatDateTime(activity.createdAt)}</time>
                </article>
              ))}
            </div>
          </section>
        )}

        {(activeView === 'overview' || activeView === 'activity') && (
          <section className="panel activity-panel">
            <PanelHeading index="04" title="Administrative activity" detail="Immutable actions across trust operations" action={() => setActiveView('activity')} />
            <div className="activity-list">
              {dashboard.activity.length === 0 ? <Empty text="No administrative activity has been recorded." /> : dashboard.activity.map((activity) => (
                <article key={activity.id}>
                  <span className={activity.outcome === 'success' ? 'activity-dot success' : 'activity-dot failed'} />
                  <div><strong>{humanize(activity.action)}</strong><p>{activity.actorName} on {activity.targetType} {activity.targetId.slice(0, 12)}</p></div>
                  <time>{formatDateTime(activity.createdAt)}</time>
                </article>
              ))}
            </div>
          </section>
        )}
      </section>
    </main>
  );
}

function Stats({ dashboard }: { dashboard: Dashboard }) {
  const stats = [
    ['Believers', dashboard.stats.users, 'Total accounts'],
    ['Churches', dashboard.stats.churches, `${dashboard.stats.pendingChurches} pending`],
    ['Open reports', dashboard.stats.openReports, 'Needs attention'],
    ['Published posts', dashboard.stats.posts, `${dashboard.stats.events} events`],
  ];
  return <section className="stat-grid">{stats.map(([label, value, detail], index) => (
    <article key={String(label)}><span>0{index + 1}</span><p>{label}</p><strong>{Number(value).toLocaleString()}</strong><small>{detail}</small></article>
  ))}</section>;
}

function PanelHeading({ index, title, detail, action }: { index: string; title: string; detail: string; action: () => void }) {
  return <header className="panel-heading"><span>{index}</span><div><h2>{title}</h2><p>{detail}</p></div><button onClick={action}>View all -&gt;</button></header>;
}

function Empty({ text }: { text: string }) {
  return <div className="empty-state"><span>+</span><p>{text}</p></div>;
}

function initials(value: string) {
  return value.split(/\s+/).filter(Boolean).slice(0, 2).map((part) => part[0]?.toUpperCase()).join('');
}

function formatDate(value?: string | null) {
  const date = value ? new Date(value) : null;
  if (!date || Number.isNaN(date.getTime())) return 'Date unavailable';
  return new Intl.DateTimeFormat('en-GB', { day: '2-digit', month: 'short' }).format(date);
}

function formatDateTime(value?: string | null) {
  const date = value ? new Date(value) : null;
  if (!date || Number.isNaN(date.getTime())) return 'Date unavailable';
  return new Intl.DateTimeFormat('en-GB', { day: '2-digit', month: 'short', hour: '2-digit', minute: '2-digit' }).format(date);
}

function priorityBand(value: number) {
  if (value >= 70) return 'high';
  if (value >= 40) return 'medium';
  return 'low';
}

function humanize(value: string) {
  return value.replaceAll('_', ' ').replace(/\b\w/g, (letter) => letter.toUpperCase());
}

function readError(value: unknown) {
  if (value && typeof value === 'object') {
    const candidate = value as { message?: string; code?: string };
    return (candidate.message || candidate.code || 'Request failed').replaceAll('_', ' ');
  }
  return 'Request failed';
}

function viewTitle(view: string) {
  if (view === 'moderation') return 'Community safety';
  if (view === 'churches') return 'Church trust review';
  if (view === 'users') return 'User administration';
  if (view === 'security') return 'Security audit';
  if (view === 'activity') return 'Administrator activity';
  return 'Today at a glance';
}
