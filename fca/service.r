# plumber.R
source("FDS_engine.r")

#* Diagnóstico basado en los síntomas
#* @param patient_data:json Datos del paciente en formato JSON, que incluyen sexo, edad y síntomas.
#* @post /diagnose
function(patient_data){
  get_diagnosis(patient_data)
}
