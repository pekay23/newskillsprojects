package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

type WorkOrder struct {
	ID          uuid.UUID      `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	Title       string         `gorm:"not null" json:"title"`
	Description string         `json:"description"`
	Status      string         `gorm:"not null;default:'pending'" json:"status"` // pending, in_progress, completed, cancelled
	Priority    string         `gorm:"not null;default:'medium'" json:"priority"`  // low, medium, high, urgent
	AssignedTo  *uuid.UUID     `gorm:"type:uuid" json:"assignedTo,omitempty"`
	CreatedBy   uuid.UUID      `gorm:"type:uuid;not null" json:"createdBy"`
	PropertyID  uuid.UUID      `gorm:"type:uuid;not null" json:"propertyId"` // FK to cmms.properties conceptually
	CreatedAt   time.Time      `json:"createdAt"`
	UpdatedAt   time.Time      `json:"updatedAt"`
	DeletedAt   gorm.DeletedAt `gorm:"index" json:"-"`
}

// TableName overrides the table name to ensure it sits in the 'workorders' schema
func (WorkOrder) TableName() string {
	return "workorders.work_orders"
}
