source("FDS_engine.r")

#* Diagnóstico basado en los síntomas
#* @param patient_data:json Datos del paciente en formato JSON, que incluyen sexo, edad y síntomas.
#* @post /diagnose_text
function(patient_data) {
  get_diagnosis(patient_data)
}

#* Diagnóstico basado en los síntomas
#* @post /diagnose_json
function(req) {
  data <- jsonlite::fromJSON(req$postBody)
  get_diagnosis(data)
}

#* Ping endpoint
#* @get /ping
function() {
  return("OK")
}
