package room

import "context"

// Repository handles persistent storage of room state.
// It only deals with data persistence, no business logic.
type Repository interface {
	// GetState retrieves the current room state
	GetState(ctx context.Context) (*RoomState, error)

	// SaveState persists the room state
	SaveState(ctx context.Context, state *RoomState) error

	// Clear resets the room state to initial values
	Clear(ctx context.Context) error
}
