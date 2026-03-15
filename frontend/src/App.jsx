import { useState, useEffect } from 'react'
import NoteList from './components/NoteList'
import NoteForm from './components/NoteForm'
import LoginPage from './components/LoginPage'

const API = `${import.meta.env.VITE_API_URL || ''}/api/notes`

export default function App() {
  const [token, setToken] = useState(() => localStorage.getItem('token'))
  const [userEmail, setUserEmail] = useState(() => localStorage.getItem('userEmail'))
  const [notes, setNotes] = useState([])
  const [editingNote, setEditingNote] = useState(null)
  const [showForm, setShowForm] = useState(false)
  const [sortByPriority, setSortByPriority] = useState(false)
  const [error, setError] = useState(null)
  const [lightMode, setLightMode] = useState(false)

  useEffect(() => {
    document.body.classList.toggle('light', lightMode)
  }, [lightMode])

  const authHeaders = {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${token}`
  }

  const handleLogin = (newToken, email) => {
    localStorage.setItem('token', newToken)
    localStorage.setItem('userEmail', email)
    setToken(newToken)
    setUserEmail(email)
  }

  const handleSignOut = () => {
    localStorage.removeItem('token')
    localStorage.removeItem('userEmail')
    setToken(null)
    setUserEmail(null)
    setNotes([])
  }

  const fetchNotes = async () => {
    try {
      const url = sortByPriority ? `${API}?sort=priority` : API
      const res = await fetch(url, { headers: authHeaders })
      if (res.status === 401) { handleSignOut(); return }
      if (!res.ok) throw new Error('Failed to fetch notes')
      setNotes(await res.json())
      setError(null)
    } catch (e) {
      setError('Could not connect to backend. Is the Java server running?')
    }
  }

  useEffect(() => { if (token) fetchNotes() }, [sortByPriority, token])

  const handleSave = async (noteData) => {
    try {
      const method = editingNote ? 'PUT' : 'POST'
      const url = editingNote ? `${API}/${editingNote.id}` : API
      const res = await fetch(url, {
        method,
        headers: authHeaders,
        body: JSON.stringify(noteData)
      })
      if (res.status === 401) { handleSignOut(); return }
      if (!res.ok) throw new Error('Failed to save')
      setShowForm(false)
      setEditingNote(null)
      fetchNotes()
    } catch (e) {
      setError('Failed to save note.')
    }
  }

  const handleDelete = async (id) => {
    if (!window.confirm('Delete this note?')) return
    try {
      const res = await fetch(`${API}/${id}`, { method: 'DELETE', headers: authHeaders })
      if (res.status === 401) { handleSignOut(); return }
      fetchNotes()
    } catch (e) {
      setError('Failed to delete note.')
    }
  }

  const handleEdit = (note) => { setEditingNote(note); setShowForm(true) }
  const handleCancel = () => { setShowForm(false); setEditingNote(null) }

  if (!token) {
    return <LoginPage onLogin={handleLogin} />
  }

  return (
    <div className="app">
      <header className="app-header">
        <h1>Notes</h1>
        <div className="header-actions">
          <label className="sort-toggle">
            <input
              type="checkbox"
              checked={sortByPriority}
              onChange={e => setSortByPriority(e.target.checked)}
            />
            Sort by priority
          </label>
          <button className="btn-primary" onClick={() => { setEditingNote(null); setShowForm(true) }}>
            + New Note
          </button>
          <button className="btn-theme" onClick={() => setLightMode(m => !m)} title="Toggle theme">
            {lightMode ? '🌙' : '☀️'}
          </button>
          <div className="user-menu">
            <span className="user-email">{userEmail}</span>
            <button className="btn-signout" onClick={handleSignOut}>Sign out</button>
          </div>
        </div>
      </header>

      {error && <div className="error-banner">{error}</div>}

      {showForm && (
        <div className="modal-overlay" onClick={handleCancel}>
          <div className="modal" onClick={e => e.stopPropagation()}>
            <NoteForm initial={editingNote} onSave={handleSave} onCancel={handleCancel} />
          </div>
        </div>
      )}

      <main>
        {notes.length === 0 && !error ? (
          <div className="empty-state">No notes yet. Create one!</div>
        ) : (
          <NoteList notes={notes} onEdit={handleEdit} onDelete={handleDelete} />
        )}
      </main>
    </div>
  )
}
