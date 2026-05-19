package application

import (
	"context"

	"dispatch/internal/modules/fuel/domain"
	platformdb "dispatch/internal/platform/db"
)

type Repository interface {
	List(ctx context.Context, p platformdb.Pagination) ([]domain.FuelLog, int64, error)
	GetByID(ctx context.Context, id string) (domain.FuelLog, error)
	Create(ctx context.Context, in domain.FuelLog) (domain.FuelLog, error)
	Update(ctx context.Context, id string, req UpdateFuelLogRequest) (domain.FuelLog, error)
	Delete(ctx context.Context, id string) error

	GetPublicByToken(ctx context.Context, token string) (domain.FuelLogPublicView, error)
	ConfirmDispense(ctx context.Context, token string, req ConfirmFuelDispenseRequest) (int64, error)
}
