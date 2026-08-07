package repository

import (
	"fmt"

	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"rg-workorder-service/internal/models"
)

type WorkOrderRepo struct {
	DB *gorm.DB
}

func NewPostgresDB(dsn string) (*gorm.DB, error) {
	// Connect to Neon PostgreSQL
	db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{})
	if err != nil {
		return nil, fmt.Errorf("failed to connect to database: %w", err)
	}

	// Auto-migrate tables into the workorders schema
	err = db.AutoMigrate(&models.WorkOrder{})
	if err != nil {
		return nil, fmt.Errorf("failed to migrate tables: %w", err)
	}

	return db, nil
}
