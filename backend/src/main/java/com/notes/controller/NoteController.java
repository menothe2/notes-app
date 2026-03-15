package com.notes.controller;

import com.notes.model.Note;
import com.notes.model.User;
import com.notes.repository.NoteRepository;
import com.notes.repository.UserRepository;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.security.Principal;
import java.util.List;

@RestController
@RequestMapping("/api/notes")
public class NoteController {

    private final NoteRepository noteRepository;
    private final UserRepository userRepository;

    public NoteController(NoteRepository noteRepository, UserRepository userRepository) {
        this.noteRepository = noteRepository;
        this.userRepository = userRepository;
    }

    private User currentUser(Principal principal) {
        return userRepository.findByEmail(principal.getName())
                .orElseThrow(() -> new RuntimeException("User not found"));
    }

    @GetMapping
    public List<Note> getAllNotes(@RequestParam(required = false) String sort, Principal principal) {
        User user = currentUser(principal);
        if ("priority".equals(sort)) {
            return noteRepository.findByUserOrderByPriorityDesc(user);
        }
        return noteRepository.findByUser(user);
    }

    @GetMapping("/{id}")
    public ResponseEntity<Note> getNoteById(@PathVariable Long id, Principal principal) {
        return noteRepository.findByIdAndUser(id, currentUser(principal))
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    @PostMapping
    public Note createNote(@RequestBody Note note, Principal principal) {
        note.setUser(currentUser(principal));
        return noteRepository.save(note);
    }

    @PutMapping("/{id}")
    public ResponseEntity<Note> updateNote(@PathVariable Long id, @RequestBody Note updated, Principal principal) {
        return noteRepository.findByIdAndUser(id, currentUser(principal)).map(note -> {
            note.setTitle(updated.getTitle());
            note.setContent(updated.getContent());
            note.setPriority(updated.getPriority());
            return ResponseEntity.ok(noteRepository.save(note));
        }).orElse(ResponseEntity.notFound().build());
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteNote(@PathVariable Long id, Principal principal) {
        return noteRepository.findByIdAndUser(id, currentUser(principal)).map(note -> {
            noteRepository.delete(note);
            return ResponseEntity.noContent().<Void>build();
        }).orElse(ResponseEntity.notFound().build());
    }
}
