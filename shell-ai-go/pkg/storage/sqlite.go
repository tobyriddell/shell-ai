package storage

import (
	"context"
	"database/sql"
	"fmt"
	"os"
	"path/filepath"
	"time"

	_ "modernc.org/sqlite"
)

// SQLiteStorage implements Storage interface using SQLite with WAL mode
type SQLiteStorage struct {
	db *sql.DB
}

// NewSQLiteStorage creates a new SQLite storage instance
func NewSQLiteStorage() (*SQLiteStorage, error) {
	// Get user's home directory for config
	homeDir, err := os.UserHomeDir()
	if err != nil {
		return nil, fmt.Errorf("failed to get home directory: %w", err)
	}
	
	configDir := filepath.Join(homeDir, ".config", "shell-ai")

	// Ensure config directory exists
	if err := os.MkdirAll(configDir, 0755); err != nil {
		return nil, fmt.Errorf("failed to create config directory: %w", err)
	}

	// Database file path
	dbPath := filepath.Join(configDir, "conversations.db")

	// Open database with WAL mode for concurrent access
	db, err := sql.Open("sqlite", dbPath+"?_journal_mode=WAL&_synchronous=NORMAL&_cache_size=1000&_foreign_keys=ON")
	if err != nil {
		return nil, fmt.Errorf("failed to open database: %w", err)
	}

	// Configure connection pool
	db.SetMaxOpenConns(10)
	db.SetMaxIdleConns(5)
	db.SetConnMaxLifetime(time.Hour)

	storage := &SQLiteStorage{db: db}

	// Initialize database schema
	if err := storage.initSchema(); err != nil {
		db.Close()
		return nil, fmt.Errorf("failed to initialize schema: %w", err)
	}

	return storage, nil
}

// initSchema creates the database tables
func (s *SQLiteStorage) initSchema() error {
	queries := []string{
		`CREATE TABLE IF NOT EXISTS conversations (
			id TEXT PRIMARY KEY,
			title TEXT,
			created_at INTEGER NOT NULL,
			updated_at INTEGER NOT NULL,
			message_count INTEGER DEFAULT 0
		)`,
		`CREATE TABLE IF NOT EXISTS messages (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			conversation_id TEXT NOT NULL,
			role TEXT NOT NULL,
			content TEXT NOT NULL,
			timestamp INTEGER NOT NULL,
			FOREIGN KEY (conversation_id) REFERENCES conversations (id) ON DELETE CASCADE
		)`,
		`CREATE INDEX IF NOT EXISTS idx_messages_conversation_id ON messages (conversation_id)`,
		`CREATE INDEX IF NOT EXISTS idx_messages_timestamp ON messages (timestamp)`,
		`CREATE INDEX IF NOT EXISTS idx_conversations_updated_at ON conversations (updated_at)`,
	}

	for _, query := range queries {
		if _, err := s.db.Exec(query); err != nil {
			return fmt.Errorf("failed to execute schema query: %w", err)
		}
	}

	return nil
}

// SaveConversation saves a conversation to the database
func (s *SQLiteStorage) SaveConversation(ctx context.Context, conversation *Conversation) error {
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback()

	// Upsert conversation
	_, err = tx.ExecContext(ctx, `
		INSERT OR REPLACE INTO conversations (id, title, created_at, updated_at, message_count)
		VALUES (?, ?, ?, ?, ?)
	`, conversation.ID, s.generateTitle(conversation), 
		conversation.Created.Unix(), conversation.Updated.Unix(), len(conversation.Messages))
	if err != nil {
		return fmt.Errorf("failed to save conversation: %w", err)
	}

	// Delete existing messages
	_, err = tx.ExecContext(ctx, "DELETE FROM messages WHERE conversation_id = ?", conversation.ID)
	if err != nil {
		return fmt.Errorf("failed to delete existing messages: %w", err)
	}

	// Insert messages
	stmt, err := tx.PrepareContext(ctx, `
		INSERT INTO messages (conversation_id, role, content, timestamp)
		VALUES (?, ?, ?, ?)
	`)
	if err != nil {
		return fmt.Errorf("failed to prepare message statement: %w", err)
	}
	defer stmt.Close()

	for _, msg := range conversation.Messages {
		_, err = stmt.ExecContext(ctx, conversation.ID, string(msg.Role), msg.Content, msg.Timestamp.Unix())
		if err != nil {
			return fmt.Errorf("failed to insert message: %w", err)
		}
	}

	return tx.Commit()
}

// LoadConversation loads a conversation by ID
func (s *SQLiteStorage) LoadConversation(ctx context.Context, id string) (*Conversation, error) {
	// Load conversation metadata
	var title string
	var createdAt, updatedAt int64
	var messageCount int

	err := s.db.QueryRowContext(ctx, `
		SELECT title, created_at, updated_at, message_count
		FROM conversations WHERE id = ?
	`, id).Scan(&title, &createdAt, &updatedAt, &messageCount)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, fmt.Errorf("conversation not found")
		}
		return nil, fmt.Errorf("failed to load conversation: %w", err)
	}

	// Load messages
	rows, err := s.db.QueryContext(ctx, `
		SELECT role, content, timestamp
		FROM messages WHERE conversation_id = ?
		ORDER BY timestamp ASC
	`, id)
	if err != nil {
		return nil, fmt.Errorf("failed to query messages: %w", err)
	}
	defer rows.Close()

	var messages []Message
	for rows.Next() {
		var role, content string
		var timestamp int64

		if err := rows.Scan(&role, &content, &timestamp); err != nil {
			return nil, fmt.Errorf("failed to scan message: %w", err)
		}

		messages = append(messages, Message{
			Role:      MessageRole(role),
			Content:   content,
			Timestamp: time.Unix(timestamp, 0),
		})
	}

	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("error iterating messages: %w", err)
	}

	return &Conversation{
		ID:       id,
		Messages: messages,
		Created:  time.Unix(createdAt, 0),
		Updated:  time.Unix(updatedAt, 0),
	}, nil
}

// ListConversations returns a list of conversation summaries
func (s *SQLiteStorage) ListConversations(ctx context.Context, limit int, offset int) ([]*ConversationSummary, error) {
	rows, err := s.db.QueryContext(ctx, `
		SELECT c.id, c.title, c.message_count, c.created_at, c.updated_at,
		       COALESCE(m.content, '') as last_message
		FROM conversations c
		LEFT JOIN messages m ON c.id = m.conversation_id AND m.timestamp = (
			SELECT MAX(timestamp) FROM messages WHERE conversation_id = c.id
		)
		ORDER BY c.updated_at DESC
		LIMIT ? OFFSET ?
	`, limit, offset)
	if err != nil {
		return nil, fmt.Errorf("failed to query conversations: %w", err)
	}
	defer rows.Close()

	var summaries []*ConversationSummary
	for rows.Next() {
		var summary ConversationSummary
		var createdAt, updatedAt int64

		if err := rows.Scan(&summary.ID, &summary.Title, &summary.MessageCount,
			&createdAt, &updatedAt, &summary.LastMessage); err != nil {
			return nil, fmt.Errorf("failed to scan conversation: %w", err)
		}

		summary.Created = time.Unix(createdAt, 0)
		summary.Updated = time.Unix(updatedAt, 0)

		summaries = append(summaries, &summary)
	}

	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("error iterating conversations: %w", err)
	}

	return summaries, nil
}

// DeleteConversation deletes a conversation by ID
func (s *SQLiteStorage) DeleteConversation(ctx context.Context, id string) error {
	result, err := s.db.ExecContext(ctx, "DELETE FROM conversations WHERE id = ?", id)
	if err != nil {
		return fmt.Errorf("failed to delete conversation: %w", err)
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("failed to get rows affected: %w", err)
	}

	if rowsAffected == 0 {
		return fmt.Errorf("conversation not found")
	}

	return nil
}

// AddMessage adds a message to an existing conversation
func (s *SQLiteStorage) AddMessage(ctx context.Context, conversationID string, message *Message) error {
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback()

	// Insert message
	_, err = tx.ExecContext(ctx, `
		INSERT INTO messages (conversation_id, role, content, timestamp)
		VALUES (?, ?, ?, ?)
	`, conversationID, string(message.Role), message.Content, message.Timestamp.Unix())
	if err != nil {
		return fmt.Errorf("failed to insert message: %w", err)
	}

	// Update conversation metadata
	_, err = tx.ExecContext(ctx, `
		UPDATE conversations 
		SET updated_at = ?, message_count = message_count + 1
		WHERE id = ?
	`, message.Timestamp.Unix(), conversationID)
	if err != nil {
		return fmt.Errorf("failed to update conversation: %w", err)
	}

	return tx.Commit()
}

// GetOrCreateConversation gets an existing conversation or creates a new one
func (s *SQLiteStorage) GetOrCreateConversation(ctx context.Context, id string) (*Conversation, error) {
	// Try to load existing conversation
	conversation, err := s.LoadConversation(ctx, id)
	if err == nil {
		return conversation, nil
	}

	// Create new conversation if not found
	now := time.Now()
	conversation = &Conversation{
		ID:       id,
		Messages: make([]Message, 0),
		Created:  now,
		Updated:  now,
	}

	// Save the new conversation
	if err := s.SaveConversation(ctx, conversation); err != nil {
		return nil, fmt.Errorf("failed to create conversation: %w", err)
	}

	return conversation, nil
}

// CleanupOldConversations removes conversations older than the specified duration
func (s *SQLiteStorage) CleanupOldConversations(ctx context.Context, olderThan time.Duration) error {
	cutoff := time.Now().Add(-olderThan).Unix()
	
	result, err := s.db.ExecContext(ctx, "DELETE FROM conversations WHERE updated_at < ?", cutoff)
	if err != nil {
		return fmt.Errorf("failed to cleanup old conversations: %w", err)
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("failed to get rows affected: %w", err)
	}

	fmt.Printf("Cleaned up %d old conversations\n", rowsAffected)
	return nil
}

// Close closes the database connection
func (s *SQLiteStorage) Close() error {
	return s.db.Close()
}

// generateTitle creates a title for a conversation based on its content
func (s *SQLiteStorage) generateTitle(conversation *Conversation) string {
	if len(conversation.Messages) == 0 {
		return "New Conversation"
	}

	// Use the first user message as title (truncated)
	for _, msg := range conversation.Messages {
		if msg.Role == RoleUser {
			title := msg.Content
			if len(title) > 50 {
				title = title[:47] + "..."
			}
			return title
		}
	}

	return "Conversation"
}
