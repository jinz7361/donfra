package room

import (
	"context"
	"sync"
)

// MemoryRepository implements Repository using in-memory storage with mutex protection.
type MemoryRepository struct {
	mu    sync.RWMutex
	state RoomState
}

// NewMemoryRepository creates a new in-memory repository with default state.
func NewMemoryRepository() *MemoryRepository {
	return &MemoryRepository{
		state: RoomState{
			Open:        false,
			InviteToken: "",
			Headcount:   0,
			Limit:       0,
		},
	}
}

// GetState retrieves the current room state (returns a copy for safety).
func (r *MemoryRepository) GetState(ctx context.Context) (*RoomState, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	// Return a copy to prevent external modifications
	stateCopy := r.state
	return &stateCopy, nil
}

// SaveState persists the room state.
func (r *MemoryRepository) SaveState(ctx context.Context, state *RoomState) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	r.state = *state
	return nil
}

// Clear resets the room state to initial values.
func (r *MemoryRepository) Clear(ctx context.Context) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	r.state = RoomState{
		Open:        false,
		InviteToken: "",
		Headcount:   0,
		Limit:       0,
	}
	return nil
}
