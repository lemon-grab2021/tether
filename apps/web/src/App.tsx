import "./App.css";

// Icons as simple SVG components
function TetherLogo() {
  return (
    <svg viewBox="0 0 32 32" fill="none" xmlns="http://www.w3.org/2000/svg">
      <circle cx="10" cy="16" r="8" fill="#4A90E2" />
      <circle cx="22" cy="16" r="8" fill="#7AB8F5" />
      <circle cx="16" cy="16" r="4" fill="#357ABD" />
    </svg>
  );
}

function SearchIcon() {
  return (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <circle cx="11" cy="11" r="8" />
      <path d="m21 21-4.3-4.3" />
    </svg>
  );
}

function BellIcon() {
  return (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M6 8a6 6 0 0 1 12 0c0 7 3 9 3 9H3s3-2 3-9" />
      <path d="M10.3 21a1.94 1.94 0 0 0 3.4 0" />
    </svg>
  );
}

function PlusIcon() {
  return (
    <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M5 12h14" />
      <path d="M12 5v14" />
    </svg>
  );
}

function UsersIcon() {
  return (
    <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2" />
      <circle cx="9" cy="7" r="4" />
      <path d="M22 21v-2a4 4 0 0 0-3-3.87" />
      <path d="M16 3.13a4 4 0 0 1 0 7.75" />
    </svg>
  );
}

function LinkIcon() {
  return (
    <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71" />
      <path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71" />
    </svg>
  );
}

function HomeIcon() {
  return (
    <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="m3 9 9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z" />
      <polyline points="9 22 9 12 15 12 15 22" />
    </svg>
  );
}

function MessageIcon() {
  return (
    <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M7.9 20A9 9 0 1 0 4 16.1L2 22Z" />
    </svg>
  );
}

function CirclesIcon() {
  return (
    <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <circle cx="8" cy="12" r="5" />
      <circle cx="16" cy="12" r="5" />
    </svg>
  );
}

function UserIcon() {
  return (
    <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <circle cx="12" cy="8" r="5" />
      <path d="M20 21a8 8 0 0 0-16 0" />
    </svg>
  );
}

// Sample data
const directMessages = [
  { id: 1, name: "Sarah Chen", initials: "SC", preview: "That sounds great! Let me check my schedule", time: "2m", unread: 2, online: true },
  { id: 2, name: "Alex Rivera", initials: "AR", preview: "Thanks for sharing the document", time: "15m", unread: 0, online: true },
  { id: 3, name: "Jordan Lee", initials: "JL", preview: "See you tomorrow at the meeting!", time: "1h", unread: 0, online: false },
  { id: 4, name: "Taylor Smith", initials: "TS", preview: "Can you send me the link?", time: "3h", unread: 1, online: false },
];

const circles = [
  { id: 1, name: "Design Team", members: 8, unread: 3 },
  { id: 2, name: "Weekend Hikers", members: 12, unread: 0 },
  { id: 3, name: "Book Club", members: 5, unread: 7 },
  { id: 4, name: "Family", members: 6, unread: 0 },
];

export default function App() {
  return (
    <div className="app">
      {/* Header */}
      <header className="header">
        <div className="header-logo">
          <TetherLogo />
          <h1>Tether</h1>
        </div>
        <div className="header-actions">
          <button className="icon-btn" aria-label="Search">
            <SearchIcon />
          </button>
          <button className="icon-btn" aria-label="Notifications">
            <BellIcon />
          </button>
        </div>
      </header>

      {/* Main Content */}
      <main className="main-content">
        {/* Welcome Panel */}
        <section className="welcome-panel" aria-label="Welcome">
          <div className="welcome-content">
            <p className="welcome-greeting">Good morning</p>
            <h2 className="welcome-name">Welcome back, Jamie</h2>
            <div className="welcome-status">
              <span className="status-dot" aria-hidden="true" />
              <span>3 friends online</span>
            </div>
          </div>
        </section>

        {/* Quick Actions */}
        <section className="section" aria-labelledby="quick-actions-title">
          <h2 id="quick-actions-title" className="sr-only">Quick Actions</h2>
          <div className="quick-actions">
            <button className="quick-action-btn">
              <span className="quick-action-icon create" aria-hidden="true">
                <PlusIcon />
              </span>
              <span className="quick-action-label">Create Circle</span>
            </button>
            <button className="quick-action-btn">
              <span className="quick-action-icon join" aria-hidden="true">
                <UsersIcon />
              </span>
              <span className="quick-action-label">Join Circle</span>
            </button>
            <button className="quick-action-btn">
              <span className="quick-action-icon links" aria-hidden="true">
                <LinkIcon />
              </span>
              <span className="quick-action-label">My Links</span>
            </button>
          </div>
        </section>

        {/* Direct Messages */}
        <section className="section" aria-labelledby="dm-title">
          <div className="section-header">
            <h2 id="dm-title" className="section-title">Direct Messages</h2>
            <button className="section-link">See all</button>
          </div>
          <div className="conversation-list">
            {directMessages.map((dm) => (
              <article
                key={dm.id}
                className={`conversation-card ${dm.unread > 0 ? "unread" : ""}`}
                tabIndex={0}
                role="button"
                aria-label={`Chat with ${dm.name}${dm.unread > 0 ? `, ${dm.unread} unread messages` : ""}`}
              >
                <div className="avatar">
                  <div className="avatar-image">{dm.initials}</div>
                  {dm.online && <span className="avatar-online" aria-label="Online" />}
                </div>
                <div className="conversation-content">
                  <div className="conversation-header">
                    <span className="conversation-name">{dm.name}</span>
                    <span className="conversation-time">{dm.time}</span>
                  </div>
                  <p className="conversation-preview">{dm.preview}</p>
                </div>
                {dm.unread > 0 && (
                  <span className="unread-badge" aria-hidden="true">{dm.unread}</span>
                )}
              </article>
            ))}
          </div>
        </section>

        {/* Circles */}
        <section className="section" aria-labelledby="circles-title">
          <div className="section-header">
            <h2 id="circles-title" className="section-title">Your Circles</h2>
            <button className="section-link">See all</button>
          </div>
          <div className="circles-grid">
            {circles.map((circle) => (
              <article
                key={circle.id}
                className="circle-card"
                tabIndex={0}
                role="button"
                aria-label={`${circle.name} circle, ${circle.members} members${circle.unread > 0 ? `, ${circle.unread} unread` : ""}`}
              >
                <div className="circle-icon" aria-hidden="true">
                  <CirclesIcon />
                </div>
                <h3 className="circle-name">{circle.name}</h3>
                <div className="circle-members">
                  <span>{circle.members} members</span>
                  {circle.unread > 0 && (
                    <span className="circle-unread">{circle.unread} new</span>
                  )}
                </div>
              </article>
            ))}
          </div>
        </section>
      </main>

      {/* Bottom Navigation */}
      <nav className="bottom-nav" aria-label="Main navigation">
        <button className="nav-item active" aria-current="page">
          <HomeIcon />
          <span className="nav-label">Home</span>
        </button>
        <button className="nav-item">
          <MessageIcon />
          <span className="nav-label">Messages</span>
        </button>
        <button className="nav-item">
          <CirclesIcon />
          <span className="nav-label">Circles</span>
        </button>
        <button className="nav-item">
          <UserIcon />
          <span className="nav-label">Profile</span>
        </button>
      </nav>
    </div>
  );
}
