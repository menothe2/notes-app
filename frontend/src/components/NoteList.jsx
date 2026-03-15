import NoteCard from './NoteCard'

export default function NoteList({ notes, onEdit, onDelete }) {
  return (
    <div className="note-grid">
      {notes.map(note => (
        <NoteCard key={note.id} note={note} onEdit={onEdit} onDelete={onDelete} />
      ))}
    </div>
  )
}
