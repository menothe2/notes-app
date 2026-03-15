const PRIORITY_COLORS = {
  HIGH: '#ef4444',
  MEDIUM: '#f59e0b',
  LOW: '#22c55e'
}

export default function NoteCard({ note, onEdit, onDelete }) {
  const color = PRIORITY_COLORS[note.priority] || '#888'
  const date = new Date(note.updatedAt).toLocaleDateString('en-US', {
    month: 'short', day: 'numeric', year: 'numeric'
  })

  return (
    <div className="note-card" style={{ borderTopColor: color }}>
      <div className="note-card-header">
        <span className="priority-badge" style={{ backgroundColor: color }}>
          {note.priority}
        </span>
        <span className="note-date">{date}</span>
      </div>
      <h2 className="note-title">{note.title}</h2>
      <p className="note-content">{note.content}</p>
      <div className="note-actions">
        <button className="btn-edit" onClick={() => onEdit(note)}>Edit</button>
        <button className="btn-delete" onClick={() => onDelete(note.id)}>Delete</button>
      </div>
    </div>
  )
}
