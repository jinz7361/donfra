package room

import (
	"context"
	"fmt"
	"strconv"

	"github.com/redis/go-redis/v9"
)

// RedisRepository implements Repository using Redis for distributed storage.
type RedisRepository struct {
	client *redis.Client
	prefix string // Key prefix for room state keys
}

// NewRedisRepository creates a new Redis-backed repository.
func NewRedisRepository(client *redis.Client) *RedisRepository {
	return &RedisRepository{
		client: client,
		prefix: "room:state:",
	}
}

// GetState retrieves the current room state from Redis.
func (r *RedisRepository) GetState(ctx context.Context) (*RoomState, error) {
	// Use pipeline for atomic multi-key read
	pipe := r.client.Pipeline()
	openCmd := pipe.Get(ctx, r.prefix+"open")
	tokenCmd := pipe.Get(ctx, r.prefix+"token")
	headcountCmd := pipe.Get(ctx, r.prefix+"headcount")
	limitCmd := pipe.Get(ctx, r.prefix+"limit")

	_, err := pipe.Exec(ctx)
	if err != nil && err != redis.Nil {
		return nil, fmt.Errorf("failed to get room state: %w", err)
	}

	state := &RoomState{
		Open:        false,
		InviteToken: "",
		Headcount:   0,
		Limit:       0,
	}

	// Parse open (default: false)
	if openVal, err := openCmd.Result(); err == nil {
		state.Open = (openVal == "true")
	}

	// Parse token (default: "")
	if tokenVal, err := tokenCmd.Result(); err == nil {
		state.InviteToken = tokenVal
	}

	// Parse headcount (default: 0)
	if headcountVal, err := headcountCmd.Result(); err == nil {
		if count, parseErr := strconv.Atoi(headcountVal); parseErr == nil {
			state.Headcount = count
		}
	}

	// Parse limit (default: 0)
	if limitVal, err := limitCmd.Result(); err == nil {
		if limit, parseErr := strconv.Atoi(limitVal); parseErr == nil {
			state.Limit = limit
		}
	}

	return state, nil
}

// SaveState persists the room state to Redis using pipeline for atomicity.
func (r *RedisRepository) SaveState(ctx context.Context, state *RoomState) error {
	pipe := r.client.Pipeline()

	// Convert bool to string
	openStr := "false"
	if state.Open {
		openStr = "true"
	}

	pipe.Set(ctx, r.prefix+"open", openStr, 0)
	pipe.Set(ctx, r.prefix+"token", state.InviteToken, 0)
	pipe.Set(ctx, r.prefix+"headcount", state.Headcount, 0)
	pipe.Set(ctx, r.prefix+"limit", state.Limit, 0)

	_, err := pipe.Exec(ctx)
	if err != nil {
		return fmt.Errorf("failed to save room state: %w", err)
	}

	return nil
}

// Clear resets the room state by deleting all keys.
func (r *RedisRepository) Clear(ctx context.Context) error {
	keys := []string{
		r.prefix + "open",
		r.prefix + "token",
		r.prefix + "headcount",
		r.prefix + "limit",
	}

	if err := r.client.Del(ctx, keys...).Err(); err != nil {
		return fmt.Errorf("failed to clear room state: %w", err)
	}

	return nil
}
