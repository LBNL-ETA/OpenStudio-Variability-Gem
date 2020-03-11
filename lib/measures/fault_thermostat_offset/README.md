

###### (Automatically generated documentation)

# Fault_thermostat_offset

## Description
Thermostat offset fault. A positive value means the zone air temperature reading is higher than the actual value. A negative value means the reading is lower than the actual value. A “0.0” value means no offset. Default is 2.0. The units are in degrees Celsius.

## Modeler Description
Thermostat offset fault. A positive value means the zone air temperature reading is higher than the actual value. A negative value means the reading is lower than the actual value. A “0.0” value means no offset. Default is 2.0. The units are in degrees Celsius.

## Measure Type
EnergyPlusMeasure

## Taxonomy


## Arguments


### Thermostat Offset Degrees Celsius

**Name:** offset_degree_c,
**Type:** Double,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### Month of the year when this fault happens

**Name:** fault_month_s,
**Type:** Choice,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### Day of the month when this fault happens

**Name:** fault_day_s,
**Type:** Choice,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### Month of the year when this fault ends

**Name:** fault_month_e,
**Type:** Choice,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### Day of the month when this fault ends

**Name:** fault_day_e,
**Type:** Choice,
**Units:** ,
**Required:** true,
**Model Dependent:** false




