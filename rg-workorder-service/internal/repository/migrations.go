package repository

import (
	"log"

	"gorm.io/gorm"
)

// Migrate creates/updates the workorder schema and indexes.
// The SLA engine queries on (status, priority, created_at, deleted_at) every minute,
// so a composite index is essential to avoid slow full-table scans.
func Migrate(db *gorm.DB) error {
	log.Println("Running workorder migrations...")

	// Composite index for the SLA breach query:
	// WHERE status IN ('pending','in_progress') AND priority != 'urgent'
	//   AND created_at < threshold AND deleted_at IS NULL
	if err := db.Exec(`CREATE INDEX IF NOT EXISTS idx_workorders_sla
		ON workorders.work_orders (status, priority, created_at, deleted_at)`).Error; err != nil {
		return err
	}

	// Index on deleted_at alone for soft-delete scans
	if err := db.Exec(`CREATE INDEX IF NOT EXISTS idx_workorders_deleted_at
		ON workorders.work_orders (deleted_at)`).Error; err != nil {
		return err
	}

	log.Println("Workorder indexes created/verified.")
	return nil
}