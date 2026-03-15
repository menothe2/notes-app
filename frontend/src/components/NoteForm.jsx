import { useState } from 'react'

export default function NoteForm({ initial, onSave, onCancel }) {
  const [title, setTitle] = useState(initial?.title || '')
  const [content, setContent] = useState(initial?.content || '')
  const [priority, setPriority] = useState(initial?.priority || 'MEDIUM')

  const handleSubmit = (e) => {
    e.preventDefault()
    if (!title.trim()) return
    onSave({ title: title.trim(), content: content.trim(), priority })
  }

  return (
    <form className="note-form" onSubmit={handleSubmit}>
      <h2>{initial ? 'Edit Note' : 'New Note'}</h2>

      <label>
        Title
        <input
          type="text"
          value={title}
          onChange={e => setTitle(e.target.value)}
          placeholder="Note title..."
          required
          autoFocus
        />
      </label>

      <label>
        Content
        <textarea
          value={content}
          onChange={e => setContent(e.target.value)}
          placeholder="Write your note here..."
          rows={5}
        />
      </label>

      <label>
        Priority
        <select value={priority} onChange={e => setPriority(e.target.value)}>
          <option value="HIGH">High</option>
          <option value="MEDIUM">Medium</option>
          <option value="LOW">Low</option>
        </select>
      </label>

      <div className="form-actions">
        <button type="button" className="btn-secondary" onClick={onCancel}>Cancel</button>
        <button type="submit" className="btn-primary">Save</button>
      </div>
    </form>
  )
}
