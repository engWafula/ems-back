package httpx

import (
	"errors"
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5/pgconn"
)

// DBError inspects a database error and writes an appropriate HTTP response.
// Constraint violations caused by bad client input are mapped to 4xx with a
// human-friendly message; anything else falls back to 500.
//
// It returns true if it handled the error (a response was written), so callers
// can simply do:
//
//	if err != nil {
//	    if httpx.DBError(c, err) {
//	        return
//	    }
//	}
func DBError(c *gin.Context, err error) bool {
	if err == nil {
		return false
	}

	var pgErr *pgconn.PgError
	if errors.As(err, &pgErr) {
		switch pgErr.Code {
		case "23503": // foreign_key_violation
			Error(c, http.StatusBadRequest,
				"invalid "+fieldFromConstraint(pgErr.ConstraintName)+": referenced record does not exist")
			return true
		case "23505": // unique_violation
			Error(c, http.StatusConflict,
				fieldFromConstraint(pgErr.ConstraintName)+" already exists")
			return true
		case "23502": // not_null_violation
			Error(c, http.StatusBadRequest,
				pgErr.ColumnName+" is required")
			return true
		}
	}

	Error(c, http.StatusInternalServerError, err.Error())
	return true
}

// fieldFromConstraint extracts a readable field name from a Postgres constraint
// name. Conventional names look like "<table>_<column>_fkey" or
// "<table>_<column>_key"; we strip the suffix and leading table prefix so
// "ambulances_district_id_fkey" -> "district_id".
func fieldFromConstraint(name string) string {
	if name == "" {
		return "field"
	}
	trimmed := name
	for _, suffix := range []string{"_fkey", "_key", "_pkey", "_check"} {
		if strings.HasSuffix(trimmed, suffix) {
			trimmed = strings.TrimSuffix(trimmed, suffix)
			break
		}
	}
	// Drop the leading "<table>_" segment if anything remains after it.
	if idx := strings.Index(trimmed, "_"); idx >= 0 && idx < len(trimmed)-1 {
		trimmed = trimmed[idx+1:]
	}
	if trimmed == "" {
		return "field"
	}
	return trimmed
}
