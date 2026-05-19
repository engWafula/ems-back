package domain

import "time"

type DashboardFilters struct {
	DateFrom   *time.Time `json:"date_from,omitempty"`
	DateTo     *time.Time `json:"date_to,omitempty"`
	DistrictID *string    `json:"district_id,omitempty"`
	FacilityID *string    `json:"facility_id,omitempty"`
}

type KPIStat struct {
	Key   string      `json:"key"`
	Label string      `json:"label"`
	Value interface{} `json:"value"`
}

type AmbulanceStatusRow struct {
	District            string `json:"district"`
	AmbulanceStation    string `json:"ambulance_station"`
	PlateNumber         string `json:"plate_number"`
	Category            string `json:"category"`
	MechanicalStatus    string `json:"mechanical_status"`
	DispatchReadiness   string `json:"dispatch_readiness"`
	FuelStatus          string `json:"fuel_status"`
	OxygenStatus        string `json:"oxygen_status"`
	CommunicationStatus string `json:"communication_status"`
}

type TrendPoint struct {
	Bucket string `json:"bucket"`
	Value  int64  `json:"value"`
}

type DonutStat struct {
	Yes int64 `json:"yes"`
	No  int64 `json:"no"`
}

type DashboardResponse struct {
	Filters map[string]interface{} `json:"filters"`
	KPIs    struct {
		ConstituenciesCount           int64   `json:"constituencies_count"`
		BLSAmbulancesCount            int64   `json:"bls_ambulances_count"`
		BLSAmbulancesProportion       float64 `json:"bls_ambulances_proportion"`
		ALSAmbulancesCount            int64   `json:"als_ambulances_count"`
		ALSAmbulancesProportion       float64 `json:"als_ambulances_proportion"`
		HCWsTrainedBEC                int64   `json:"hcws_trained_bec"`
		HCWsTrainedBLS                int64   `json:"hcws_trained_bls"`
		HCWsTrainedALS                int64   `json:"hcws_trained_als"`
		HCWsTrainedCCN                int64   `json:"hcws_trained_ccn"`
		EMTsTrained                   int64   `json:"emts_trained"`
		TrainedAmbulanceDrivers       int64   `json:"trained_ambulance_drivers"`
		TransfersCount                int64   `json:"transfers_count"`
		RedTriagePatientsCount        int64   `json:"red_triage_patients_count"`
		HighlyInfectiousPatientsCount int64   `json:"highly_infectious_patients_count"`
		MarineAmbulanceProportion     float64 `json:"marine_ambulance_proportion"`
		MNMCI                         int64   `json:"mnmci"`
		RTA                           int64   `json:"rta"`
	} `json:"kpis"`
	AmbulanceStatusTable  []AmbulanceStatusRow `json:"ambulance_status_table"`
	TransfersTrend        []TrendPoint         `json:"transfers_trend"`
	FacilityCaseTrend     []TrendPoint         `json:"facility_case_trend"`
	AmbulanceCommittees   DonutStat            `json:"ambulance_committees"`
	AmbulanceLLUFinancing DonutStat            `json:"ambulance_llu_financing"`
	LastUpdatedAt         *time.Time           `json:"last_updated_at,omitempty"`
}