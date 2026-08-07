package sla

import (
	"context"
	"log"
	"time"

	"github.com/redis/go-redis/v9"
	"gorm.io/gorm"
	"rg-workorder-service/internal/models"
)

type Engine struct {
	DB    *gorm.DB
	Redis *redis.Client
}

func NewEngine(db *gorm.DB, redisClient *redis.Client) *Engine {
	return &Engine{DB: db, Redis: redisClient}
}

// Start spins up a background goroutine that polls for SLA breaches
func (e *Engine) Start(ctx context.Context) {
	log.Println("Starting SLA Monitoring Engine...")
	ticker := time.NewTicker(1 * time.Minute)

	go func() {
		for {
			select {
			case <-ctx.Done():
				log.Println("SLA Monitoring Engine shutting down")
				return
			case <-ticker.C:
				e.checkSLAs()
			}
		}
	}()
}

func (e *Engine) checkSLAs() {
	// Find pending/in_progress WOs that are older than 24h (demo SLA)
	var overdue []models.WorkOrder
	threshold := time.Now().Add(-24 * time.Hour)

	// We query where it isn't already escalated to urgent
	e.DB.Where("status IN ? AND priority != ? AND created_at < ?", []string{"pending", "in_progress"}, "urgent", threshold).Find(&overdue)

	for _, wo := range overdue {
		log.Printf("SLA Breach detected for WO: %s. Escalating priority.", wo.ID)
		
		e.DB.Model(&wo).Update("priority", "urgent")

		// Publish event to Redis for other services (e.g., Helpdesk notifications) to consume
		err := e.Redis.Publish(context.Background(), "wo.sla.breach", wo.ID.String()).Err()
		if err != nil {
			log.Printf("Failed to publish SLA breach event to Redis: %v", err)
		}
	}
}
