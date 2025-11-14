package ai

import (
	"context"

	"shell-ai-go/pkg/storage"
)

// StorageAdapter adapts between AI types and storage types
type StorageAdapter struct {
	storage storage.Storage
}

// NewStorageAdapter creates a new storage adapter
func NewStorageAdapter(s storage.Storage) *StorageAdapter {
	return &StorageAdapter{storage: s}
}

// SaveConversation saves a conversation to storage
func (a *StorageAdapter) SaveConversation(ctx context.Context, conversation *Conversation) error {
	storageConv := a.convertToStorageConversation(conversation)
	return a.storage.SaveConversation(ctx, storageConv)
}

// LoadConversation loads a conversation from storage
func (a *StorageAdapter) LoadConversation(ctx context.Context, id string) (*Conversation, error) {
	storageConv, err := a.storage.LoadConversation(ctx, id)
	if err != nil {
		return nil, err
	}
	return a.convertFromStorageConversation(storageConv), nil
}

// GetOrCreateConversation gets or creates a conversation in storage
func (a *StorageAdapter) GetOrCreateConversation(ctx context.Context, id string) (*Conversation, error) {
	storageConv, err := a.storage.GetOrCreateConversation(ctx, id)
	if err != nil {
		return nil, err
	}
	return a.convertFromStorageConversation(storageConv), nil
}

// AddMessage adds a message to a conversation in storage
func (a *StorageAdapter) AddMessage(ctx context.Context, conversationID string, message *Message) error {
	storageMsg := a.convertToStorageMessage(message)
	return a.storage.AddMessage(ctx, conversationID, storageMsg)
}

// ListConversations lists conversations from storage
func (a *StorageAdapter) ListConversations(ctx context.Context, limit int, offset int) ([]*storage.ConversationSummary, error) {
	return a.storage.ListConversations(ctx, limit, offset)
}

// DeleteConversation deletes a conversation from storage
func (a *StorageAdapter) DeleteConversation(ctx context.Context, id string) error {
	return a.storage.DeleteConversation(ctx, id)
}

// convertToStorageConversation converts AI conversation to storage conversation
func (a *StorageAdapter) convertToStorageConversation(conv *Conversation) *storage.Conversation {
	storageConv := &storage.Conversation{
		ID:       conv.ID,
		Messages: make([]storage.Message, len(conv.Messages)),
		Created:  conv.Created,
		Updated:  conv.Updated,
	}

	for i, msg := range conv.Messages {
		storageConv.Messages[i] = storage.Message{
			Role:      storage.MessageRole(msg.Role),
			Content:   msg.Content,
			Timestamp: msg.Timestamp,
		}
	}

	return storageConv
}

// convertFromStorageConversation converts storage conversation to AI conversation
func (a *StorageAdapter) convertFromStorageConversation(conv *storage.Conversation) *Conversation {
	aiConv := &Conversation{
		ID:       conv.ID,
		Messages: make([]Message, len(conv.Messages)),
		Created:  conv.Created,
		Updated:  conv.Updated,
	}

	for i, msg := range conv.Messages {
		aiConv.Messages[i] = Message{
			Role:      MessageRole(msg.Role),
			Content:   msg.Content,
			Timestamp: msg.Timestamp,
		}
	}

	return aiConv
}

// convertToStorageMessage converts AI message to storage message
func (a *StorageAdapter) convertToStorageMessage(msg *Message) *storage.Message {
	return &storage.Message{
		Role:      storage.MessageRole(msg.Role),
		Content:   msg.Content,
		Timestamp: msg.Timestamp,
	}
}
