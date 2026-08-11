package domain

import "time"

type Trip struct {
	ID                    string     `json:"id"`
	DispatchAssignmentID  string     `json:"dispatch_assignment_id"`
	IncidentID            string     `json:"incident_id"`
	AmbulanceID           *string    `json:"ambulance_id,omitempty"`
	OriginLat             *float64   `json:"origin_lat,omitempty"`
	OriginLon             *float64   `json:"origin_lon,omitempty"`
	SceneLat              *float64   `json:"scene_lat,omitempty"`
	SceneLon              *float64   `json:"scene_lon,omitempty"`
	DestinationFacilityID *string    `json:"destination_facility_id,omitempty"`
	DestinationLat        *float64   `json:"destination_lat,omitempty"`
	DestinationLon        *float64   `json:"destination_lon,omitempty"`
	OdometerStart         *float64   `json:"odometer_start,omitempty"`
	OdometerEnd           *float64   `json:"odometer_end,omitempty"`
	StartedAt             *time.Time `json:"started_at,omitempty"`
	EndedAt               *time.Time `json:"ended_at,omitempty"`
	Outcome               *string    `json:"outcome,omitempty"`
	Notes                 *string    `json:"notes,omitempty"`
	CreatedAt             time.Time  `json:"created_at"`
	UpdatedAt             time.Time  `json:"updated_at"`

	// Derived display names resolved via joins (omitted when blank).
	IncidentNumber          string `json:"incident_number,omitempty"`
	AmbulanceCode           string `json:"ambulance_code,omitempty"`
	AmbulancePlate          string `json:"ambulance_plate,omitempty"`
	DestinationFacilityName string `json:"destination_facility_name,omitempty"`
}

type TripEvent struct {
	ID          string    `json:"id"`
	TripID      string    `json:"trip_id"`
	EventType   string    `json:"event_type"`
	EventTime   time.Time `json:"event_time"`
	Latitude    *float64  `json:"latitude,omitempty"`
	Longitude   *float64  `json:"longitude,omitempty"`
	ActorUserID *string   `json:"actor_user_id,omitempty"`
	Notes       *string   `json:"notes,omitempty"`

	// Derived display name resolved via join (omitted when blank).
	ActorUserName string `json:"actor_user_name,omitempty"`
}
