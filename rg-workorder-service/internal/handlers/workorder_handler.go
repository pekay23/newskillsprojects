package handlers

import (
	"encoding/json"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"rg-workorder-service/internal/models"
	"rg-workorder-service/internal/repository"
)

type WorkOrderHandler struct {
	Repo *repository.WorkOrderRepo
}

func (h *WorkOrderHandler) List(w http.ResponseWriter, r *http.Request) {
	var wos []models.WorkOrder
	result := h.Repo.DB.Find(&wos)
	if result.Error != nil {
		http.Error(w, result.Error.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(wos)
}

func (h *WorkOrderHandler) Get(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	var wo models.WorkOrder
	result := h.Repo.DB.First(&wo, "id = ?", id)
	if result.Error != nil {
		http.Error(w, "Work order not found", http.StatusNotFound)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(wo)
}

func (h *WorkOrderHandler) Create(w http.ResponseWriter, r *http.Request) {
	var wo models.WorkOrder
	if err := json.NewDecoder(r.Body).Decode(&wo); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	// Identify user from API Gateway injected headers
	userIDStr := r.Header.Get("X-User-Id")
	if userIDStr != "" {
		if id, err := uuid.Parse(userIDStr); err == nil {
			wo.CreatedBy = id
		}
	}

	// For demo: auto-generate missing essential UUIDs if blank
	if wo.PropertyID == uuid.Nil {
		wo.PropertyID = uuid.New() // Placeholder
	}
	if wo.CreatedBy == uuid.Nil {
		wo.CreatedBy = uuid.New() // Placeholder
	}

	result := h.Repo.DB.Create(&wo)
	if result.Error != nil {
		http.Error(w, result.Error.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(wo)
}
