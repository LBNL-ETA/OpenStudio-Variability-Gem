# *******************************************************************************
# OpenStudio(Retrofit_equipment_os), Copyright (c) 2008-2018, Alliance for Sustainable Energy, LLC.
# All rights reserved.
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# (1) Redistributions of source code must retain the above copyright notice,
# this list of conditions and the following disclaimer.
#
# (2) Redistributions in binary form must reproduce the above copyright notice,
# this list of conditions and the following disclaimer in the documentation
# and/or other materials provided with the distribution.
#
# (3) Neither the name of the copyright holder nor the names of any contributors
# may be used to endorse or promote products derived from this software without
# specific prior written permission from the respective party.
#
# (4) Other than as required in clauses (1) and (2), distributions in any form
# of modifications or other derivative works may not use the "OpenStudio"
# trademark, "OS", "os", or any other confusingly similar designation without
# specific prior written permission from Alliance for Sustainable Energy, LLC.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDER(S) AND ANY CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
# THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER(S), ANY CONTRIBUTORS, THE
# UNITED STATES GOVERNMENT, OR THE UNITED STATES DEPARTMENT OF ENERGY, NOR ANY OF
# THEIR EMPLOYEES, BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT
# OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
# STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
# *******************************************************************************

# start the measure
class AdjustThermostatSetpointsByDegrees < OpenStudio::Measure::ModelMeasure
  # define the name that a user will see
  def name
    return 'DR GTA'
  end

  # human readable description
  def description
    return 'This measure adjusts heating and cooling setpoints by a user-specified number of degrees and a user-specified time period. This is applied throughout the entire building.'
  end

  # human readable description of modeling approach
  def modeler_description
    return 'This measure will clone all of the schedules that are used as heating and cooling setpoints for thermal zones. The clones are hooked up to the thermostat in place of the original schedules. Then the schedules are adjusted by the specified values during a specified time period. There is a checkbox to determine if the thermostat for design days should be altered.'
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    # make an argument for adjustment to cooling setpoint
    cooling_adjustment = OpenStudio::Measure::OSArgument.makeDoubleArgument('cooling_adjustment', true)
    cooling_adjustment.setDisplayName('Degrees Fahrenheit to Adjust Cooling Setpoint By')
    cooling_adjustment.setDefaultValue(5.0)
    args << cooling_adjustment

    # make an argument for the start time of cooling adjustment
    starttime_cooling = OpenStudio::Measure::OSArgument.makeStringArgument('starttime_cooling', true)
    starttime_cooling.setDisplayName('Start Time for Cooling Adjustment')
    starttime_cooling.setDefaultValue('16:01:00')
    args << starttime_cooling

    # make an argument for the end time of cooling adjustment
    endtime_cooling = OpenStudio::Measure::OSArgument.makeStringArgument('endtime_cooling', true)
    endtime_cooling.setDisplayName('End Time for Cooling Adjustment')
    endtime_cooling.setDefaultValue('20:00:00')
    args << endtime_cooling

    # make an argument for the start time of heating adjustment
    starttime_heating1 = OpenStudio::Measure::OSArgument.makeStringArgument('starttime_heating1', true)
    starttime_heating1.setDisplayName('Start Time for Heating Adjustment')
    starttime_heating1.setDefaultValue('16:01:00')
    args << starttime_heating1

    # make an argument for the end time of heating adjustment
    endtime_heating1 = OpenStudio::Measure::OSArgument.makeStringArgument('endtime_heating1', true)
    endtime_heating1.setDisplayName('End Time for Heating Adjustment')
    endtime_heating1.setDefaultValue('20:00:00')
    args << endtime_heating1

    # make an argument for adjustment to heating setpoint
    heating_adjustment = OpenStudio::Measure::OSArgument.makeDoubleArgument('heating_adjustment', true)
    heating_adjustment.setDisplayName('Degrees Fahrenheit to Adjust heating Setpoint By')
    heating_adjustment.setDefaultValue(-2.0)
    args << heating_adjustment

    # make an argument for the start time of heating adjustment
    starttime_heating2 = OpenStudio::Measure::OSArgument.makeStringArgument('starttime_heating2', true)
    starttime_heating2.setDisplayName('Start Time for Heating Adjustment')
    starttime_heating2.setDefaultValue('16:01:00')
    args << starttime_heating2

    # make an argument for the end time of heating adjustment
    endtime_heating2 = OpenStudio::Measure::OSArgument.makeStringArgument('endtime_heating2', true)
    endtime_heating2.setDisplayName('End Time for Heating Adjustment')
    endtime_heating2.setDefaultValue('20:00:00')
    args << endtime_heating2

    # make an argument if the thermostat for design days should be altered
    alter_design_days = OpenStudio::Measure::OSArgument.makeBoolArgument('alter_design_days', true)
    alter_design_days.setDisplayName('Alter Design Day Thermostats')
    alter_design_days.setDefaultValue(false)
    args << alter_design_days

    auto_date = OpenStudio::Measure::OSArgument.makeBoolArgument('auto_date', true)
    auto_date.setDisplayName('Enable Climate-specific Periods Setting ?')
    auto_date.setDefaultValue(true)
    args << auto_date


    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    # assign the user inputs to variables
    cooling_adjustment = runner.getDoubleArgumentValue('cooling_adjustment', user_arguments)
    heating_adjustment = runner.getDoubleArgumentValue('heating_adjustment', user_arguments)
    starttime_cooling = runner.getStringArgumentValue('starttime_cooling', user_arguments)
    endtime_cooling = runner.getStringArgumentValue('endtime_cooling', user_arguments)
    starttime_heating1 = runner.getStringArgumentValue('starttime_heating1', user_arguments)
    endtime_heating1 = runner.getStringArgumentValue('endtime_heating1', user_arguments)
    starttime_heating2 = runner.getStringArgumentValue('starttime_heating2', user_arguments)
    endtime_heating2 = runner.getStringArgumentValue('endtime_heating2', user_arguments)
    alter_design_days = runner.getBoolArgumentValue('alter_design_days', user_arguments)
    auto_date = runner.getBoolArgumentValue('auto_date', user_arguments)

    winter_start_month1 = 1
    winter_end_month1 = 5
    summer_start_month = 6
    summer_end_month = 8
    winter_start_month2 = 9
    winter_end_month2 = 12


######### GET CLIMATE ZONES ################
    if auto_date
      ashraeClimateZone = ''
      #climateZoneNUmber = ''
      climateZones = model.getClimateZones
      climateZones.climateZones.each do |climateZone|
        if climateZone.institution == 'ASHRAE'
          ashraeClimateZone = climateZone.value
          runner.registerInfo("Using ASHRAE Climate zone #{ashraeClimateZone}.")
        end
      end

      if ashraeClimateZone == '' # should this be not applicable or error?
        runner.registerError("Please assign an ASHRAE Climate Zone to your model using the site tab in the OpenStudio application. The measure can't make AEDG recommendations without this information.")
        return false # note - for this to work need to check for false in measure.rb and add return false there as well.
      end

      if ashraeClimateZone == '2A'
        starttime_cooling = '16:01:00'
        endtime_cooling = '19:59:00'
        starttime_heating1 = '5:01:00'
        endtime_heating1 = '8:59:00'
        starttime_heating2 = '16:01:00'
        endtime_heating2 = '19:59:00'
      elsif ashraeClimateZone == '2B'
        starttime_cooling = '14:59:00'
        endtime_cooling = '18:59:00'
        starttime_heating1 = '5:01:00'
        endtime_heating1 = '8:59:00'
        starttime_heating2 = '16:01:00'
        endtime_heating2 = '19:59:00'
      elsif ashraeClimateZone == '3A'
        starttime_cooling = '16:59:00'
        endtime_cooling = '20:59:00'
        starttime_heating1 = '5:01:00'
        endtime_heating1 = '8:59:00'
        starttime_heating2 = '16:01:00'
        endtime_heating2 = '19:59:00'
      elsif ashraeClimateZone == '3B'
        starttime_cooling = '16:59:00'
        endtime_cooling = '20:59:00'
        starttime_heating1 = '5:01:00'
        endtime_heating1 = '8:59:00'
        starttime_heating2 = '17:01:00'
        endtime_heating2 = '20:59:00'
      elsif ashraeClimateZone == '3C'
        starttime_cooling = '16:01:00'
        endtime_cooling = '19:59:00'
        starttime_heating1 = '5:01:00'
        endtime_heating1 = '8:59:00'
        starttime_heating2 = '16:01:00'
        endtime_heating2 = '19:59:00'
      elsif ashraeClimateZone == '4A'
        cooling_adjustment = 0
        starttime_cooling = '2:59:00'
        endtime_cooling = '6:59:00'
        starttime_heating1 = '6:01:00'
        endtime_heating1 = '9:59:00'
        starttime_heating2 = '16:01:00'
        endtime_heating2 = '19:59:00'
      elsif ashraeClimateZone == '4B'
        starttime_cooling = '14:59:00'
        endtime_cooling = '18:59:00'
        starttime_heating1 = '5:01:00'
        endtime_heating1 = '8:59:00'
        starttime_heating2 = '16:01:00'
        endtime_heating2 = '19:59:00'
      elsif ashraeClimateZone == '4C'
        starttime_cooling = '14:59:00'
        endtime_cooling = '18:59:00'
        starttime_heating1 = '6:01:00'
        endtime_heating1 = '9:59:00'
        starttime_heating2 = '16:01:00'
        endtime_heating2 = '19:59:00'
      elsif ashraeClimateZone == '5A'
        cooling_adjustment = 0
        starttime_cooling = '2:59:00'
        endtime_cooling = '6:59:00'
        starttime_heating1 = '6:01:00'
        endtime_heating1 = '9:59:00'
        starttime_heating2 = '16:01:00'
        endtime_heating2 = '19:59:00'
      elsif ashraeClimateZone == '5B'
        starttime_cooling = '14:59:00'
        endtime_cooling = '18:59:00'
        starttime_heating1 = '6:01:00'
        endtime_heating1 = '9:59:00'
        starttime_heating2 = '16:01:00'
        endtime_heating2 = '19:59:00'
      elsif ashraeClimateZone == '5C'
        starttime_cooling = '14:59:00'
        endtime_cooling = '18:59:00'
        starttime_heating1 = '6:01:00'
        endtime_heating1 = '9:59:00'
        starttime_heating2 = '16:59:00'
        endtime_heating2 = '20:59:00'
      elsif ashraeClimateZone == '6A'
        starttime_cooling = '14:59:00'
        endtime_cooling = '18:59:00'
        starttime_heating1 = '17:59:00'
        endtime_heating1 = '21:59:00'
        starttime_heating2 = '17:59:00'
        endtime_heating2 = '21:59:00'
      elsif ashraeClimateZone == '6B'
        starttime_cooling = '14:59:00'
        endtime_cooling = '18:59:00'
        starttime_heating1 = '6:01:00'
        endtime_heating1 = '9:59:00'
        starttime_heating2 = '16:01:00'
        endtime_heating2 = '19:59:00'
      elsif ashraeClimateZone == '7A'
        starttime_cooling = '14:59:00'
        endtime_cooling = '18:59:00'
        starttime_heating1 = '17:59:00'
        endtime_heating1 = '17:59:00'
        starttime_heating2 = '17:59:00'
        endtime_heating2 = '21:59:00'
      end
    end

    if ashraeClimateZone == '6A'
      cooling_adjustment = 2
      heating_adjustment = -1
    end

    if starttime_cooling.to_f > endtime_cooling.to_f
      runner.registerError('For cooling adjustment, the end time should be larger than the start time.')
      return false
    end
    if starttime_heating1.to_f > endtime_heating1.to_f
      runner.registerError('For heating adjustment, the end time should be larger than the start time.')
      return false
    end
    if starttime_heating2.to_f > endtime_heating2.to_f
      runner.registerError('For heating adjustment, the end time should be larger than the start time.')
      return false
    end

    # ruby test to see if first charter of string is uppercase letter
    if cooling_adjustment < 0
      runner.registerWarning('Lowering the cooling setpoint will increase energy use.')
    elsif cooling_adjustment.abs > 500
      runner.registerError("#{cooling_adjustment} is a larger than typical setpoint adjustment")
      return false
    elsif cooling_adjustment.abs > 50
      runner.registerWarning("#{cooling_adjustment} is a larger than typical setpoint adjustment")
    end
    if heating_adjustment > 0
      runner.registerWarning('Raising the heating setpoint will increase energy use.')
    elsif heating_adjustment.abs > 500
      runner.registerError("#{heating_adjustment} is a larger than typical setpoint adjustment")
      return false
    elsif heating_adjustment.abs > 50
      runner.registerWarning("#{heating_adjustment} is a larger than typical setpoint adjustment")
    end

    # setup OpenStudio units that we will need
    temperature_ip_unit = OpenStudio.createUnit('F').get
    temperature_si_unit = OpenStudio.createUnit('C').get

    # define starting units
    cooling_adjustment_ip = OpenStudio::Quantity.new(cooling_adjustment, temperature_ip_unit)
    heating_adjustment_ip = OpenStudio::Quantity.new(heating_adjustment, temperature_ip_unit)

    
    # push schedules to hash to avoid making unnecessary duplicates
    clg_set_schs = {}
    htg_set_schs = {}
    # get spaces
    thermostats = model.getThermostatSetpointDualSetpoints
    thermostats.each do |thermostat|
      # setup new cooling setpoint schedule
      clg_set_sch = thermostat.coolingSetpointTemperatureSchedule
  runner.registerInfo("#{clg_set_sch.get.name.to_s}")
      if !clg_set_sch.empty?
        # clone of not alredy in hash
        if clg_set_schs.key?(clg_set_sch.get.name.to_s)
          new_clg_set_sch = clg_set_schs[clg_set_sch.get.name.to_s]
        else
          new_clg_set_sch = clg_set_sch.get.clone(model)
          new_clg_set_sch = new_clg_set_sch.to_Schedule.get
          new_clg_set_sch_name = new_clg_set_sch.setName("#{new_clg_set_sch.name} adjusted by #{cooling_adjustment_ip}")

          # add to the hash
          clg_set_schs[clg_set_sch.get.name.to_s] = new_clg_set_sch
        end
        # hook up clone to thermostat
        thermostat.setCoolingSetpointTemperatureSchedule(new_clg_set_sch)
  #runner.registerInfo("#{new_clg_set_sch.get.name.to_s}")        
      else
        runner.registerWarning("Thermostat '#{thermostat.name}' doesn't have a cooling setpoint schedule")
      end

      # setup new heating setpoint schedule
      htg_set_sch = thermostat.heatingSetpointTemperatureSchedule
      if !htg_set_sch.empty?
        # clone of not already in hash
        if htg_set_schs.key?(htg_set_sch.get.name.to_s)
          new_htg_set_sch = htg_set_schs[htg_set_sch.get.name.to_s]
        else
          new_htg_set_sch = htg_set_sch.get.clone(model)
          new_htg_set_sch = new_htg_set_sch.to_Schedule.get
          new_htg_set_sch_name = new_htg_set_sch.setName("#{new_htg_set_sch.name} adjusted by #{heating_adjustment_ip}")

          # add to the hash
          htg_set_schs[htg_set_sch.get.name.to_s] = new_htg_set_sch
        end
        # hook up clone to thermostat
        thermostat.setHeatingSetpointTemperatureSchedule(new_htg_set_sch)
      else
        runner.registerWarning("Thermostat '#{thermostat.name}' doesn't have a heating setpoint schedule.")
      end
    end
     # setting up variables to use for initial and final condition
    clg_sch_set_values = [] # may need to flatten this
    htg_sch_set_values = [] # may need to flatten this
    final_clg_sch_set_values = []
    final_htg_sch_set_values = []

    # consider issuing a warning if the model has un-conditioned thermal zones (no ideal air loads or hvac)
    zones = model.getThermalZones
    zones.each do |zone|
      # if you have a thermostat but don't have ideal air loads or zone equipment then issue a warning
      if !zone.thermostatSetpointDualSetpoint.empty? && !zone.useIdealAirLoads && (zone.equipment.size <= 0)
        runner.registerWarning("Thermal zone '#{zone.name}' has a thermostat but does not appear to be conditioned.")
      end
    end
    shift_time1 = OpenStudio::Time.new(starttime_cooling)
    shift_time2 = OpenStudio::Time.new(endtime_cooling)
    shift_time3 = OpenStudio::Time.new(0, 24, 0, 0)
    shift_time4 = OpenStudio::Time.new(starttime_heating1)
    shift_time5 = OpenStudio::Time.new(endtime_heating1)
    shift_time6 = OpenStudio::Time.new(starttime_heating2)
    shift_time7 = OpenStudio::Time.new(endtime_heating2)
    # make cooling schedule adjustments and rename. Put in check to skip and warn if schedule not ruleset
    

    clg_set_schs.each do |k, v| # old name and new object for schedule
      if !v.to_ScheduleRuleset.empty?

        schedule = v.to_ScheduleRuleset.get
        default_rule = schedule.defaultDaySchedule
        rules = schedule.scheduleRules

        days_covered = Array.new(7, false)

        if rules.length > 0
          rules.each do |rule|
            winterStartMonth1 = OpenStudio::MonthOfYear.new(winter_start_month1)
            winterEndMonth1 = OpenStudio::MonthOfYear.new(winter_end_month1)
            winterStartDate1 = OpenStudio::Date.new(winterStartMonth1, 1)
            winterEndDate1 = OpenStudio::Date.new(winterEndMonth1, 30)

            winter_rule1 = rule.clone(model).to_ScheduleRule.get
            winter_rule1.setStartDate(winterStartDate1)
            winter_rule1.setEndDate(winterEndDate1)

            allDaysCovered(winter_rule1, days_covered)

            cloned_day_winter = rule.daySchedule.clone(model)
            cloned_day_winter.setParent(winter_rule1)


            winterStartMonth2 = OpenStudio::MonthOfYear.new(winter_start_month2)
            winterEndMonth2 = OpenStudio::MonthOfYear.new(winter_end_month2)
            winterStartDate2 = OpenStudio::Date.new(winterStartMonth2, 1)
            winterEndDate2 = OpenStudio::Date.new(winterEndMonth2, 30)

            winter_rule2 = winter_rule1.clone(model).to_ScheduleRule.get
            winter_rule2.setStartDate(winterStartDate2)
            winter_rule2.setEndDate(winterEndDate2)

            cloned_day_winter2 = cloned_day_winter.clone(model)
            cloned_day_winter2.setParent(winter_rule2)

            summerStartMonth = OpenStudio::MonthOfYear.new(summer_start_month)
            summerEndMonth = OpenStudio::MonthOfYear.new(summer_end_month)
            summerStartDate = OpenStudio::Date.new(summerStartMonth, 1)
            summerEndDate = OpenStudio::Date.new(summerEndMonth, 30)
            
            summer_rule = rule #rule.clone(model).to_ScheduleRule.get
            summer_rule.setStartDate(summerStartDate)
            summer_rule.setEndDate(summerEndDate)

            cloned_day_summer = rule.daySchedule.clone(model)
            cloned_day_summer.setParent(summer_rule)

            summer_day = summer_rule.daySchedule
            day_time_vector = summer_day.times
            day_value_vector = summer_day.values
            summer_day.clearValues
            
            summer_day = createDaySchedule(summer_day, day_time_vector, day_value_vector, shift_time1, shift_time2, cooling_adjustment_ip)
            final_clg_sch_set_values << summer_day.values
          end
        end
        

        if days_covered.include?(false)
          winterStartMonth1 = OpenStudio::MonthOfYear.new(winter_start_month1)
          winterEndMonth1 = OpenStudio::MonthOfYear.new(winter_end_month1)
          winterStartDate1 = OpenStudio::Date.new(winterStartMonth1, 1)
          winterEndDate1 = OpenStudio::Date.new(winterEndMonth1, 30)

          winter_rule1 = OpenStudio::Model::ScheduleRule.new(schedule)
          winter_rule1.setStartDate(winterStartDate1)
          winter_rule1.setEndDate(winterEndDate1)

          coverSomeDays(winter_rule1, days_covered)
          allDaysCovered(winter_rule1, days_covered)

          cloned_day_winter = default_rule.clone(model)
          cloned_day_winter.setParent(winter_rule1)

          winterStartMonth2 = OpenStudio::MonthOfYear.new(winter_start_month2)
          winterEndMonth2 = OpenStudio::MonthOfYear.new(winter_end_month2)
          winterStartDate2 = OpenStudio::Date.new(winterStartMonth2, 1)
          winterEndDate2 = OpenStudio::Date.new(winterEndMonth2, 30)

          winter_rule2 = winter_rule1.clone(model).to_ScheduleRule.get
          winter_rule2.setStartDate(winterStartDate2)
          winter_rule2.setEndDate(winterEndDate2)

          cloned_day_winter2 = cloned_day_winter.clone(model)
          cloned_day_winter2.setParent(winter_rule2)

          summerStartMonth = OpenStudio::MonthOfYear.new(summer_start_month)
          summerEndMonth = OpenStudio::MonthOfYear.new(summer_end_month)
          summerStartDate = OpenStudio::Date.new(summerStartMonth, 1)
          summerEndDate = OpenStudio::Date.new(summerEndMonth, 30)
          
          summer_rule = winter_rule1.clone(model).to_ScheduleRule.get
          summer_rule.setStartDate(summerStartDate)
          summer_rule.setEndDate(summerEndDate)

          cloned_day_summer = default_rule.clone(model)
          cloned_day_summer.setParent(summer_rule)

          summer_day = summer_rule.daySchedule
          day_time_vector = summer_day.times
          day_value_vector = summer_day.values
          summer_day.clearValues
          
          summer_day = createDaySchedule(summer_day, day_time_vector, day_value_vector, shift_time1, shift_time2, cooling_adjustment_ip)
          final_clg_sch_set_values << summer_day.values
        end

        ######################################################################
      else
        runner.registerWarning("Schedule '#{k}' isn't a ScheduleRuleset object and won't be altered by this measure.")
        v.remove # remove un-used clone
      end
    end
    
    # make heating schedule adjustments and rename. Put in check to skip and warn if schedule not ruleset
    htg_set_schs.each do |k, v| # old name and new object for schedule
      if !v.to_ScheduleRuleset.empty?
        schedule = v.to_ScheduleRuleset.get
        default_rule = schedule.defaultDaySchedule
        rules = schedule.scheduleRules

        days_covered = Array.new(7, false)

        if rules.length > 0
          rules.each do |rule|

            summerStartMonth = OpenStudio::MonthOfYear.new(summer_start_month)
            summerEndMonth = OpenStudio::MonthOfYear.new(summer_end_month)
            summerStartDate = OpenStudio::Date.new(summerStartMonth, 1)
            summerEndDate = OpenStudio::Date.new(summerEndMonth, 30)
            
            summer_rule = rule.clone(model).to_ScheduleRule.get
            summer_rule.setStartDate(summerStartDate)
            summer_rule.setEndDate(summerEndDate)

            allDaysCovered(summer_rule, days_covered)

            cloned_day_summer = rule.daySchedule.clone(model)
            cloned_day_summer.setParent(summer_rule)

            winterStartMonth1 = OpenStudio::MonthOfYear.new(winter_start_month1)
            winterEndMonth1 = OpenStudio::MonthOfYear.new(winter_end_month1)
            winterStartDate1 = OpenStudio::Date.new(winterStartMonth1, 1)
            winterEndDate1 = OpenStudio::Date.new(winterEndMonth1, 30)

            winter_rule1 = rule #rule.clone(model).to_ScheduleRule.get
            winter_rule1.setStartDate(winterStartDate1)
            winter_rule1.setEndDate(winterEndDate1)

            cloned_day_winter = rule.daySchedule.clone(model)
            cloned_day_winter.setParent(winter_rule1)

            winter_day1 = winter_rule1.daySchedule
            day_time_vector = winter_day1.times
            day_value_vector = winter_day1.values
            winter_day1.clearValues
            
            winter_day1 = createDaySchedule(winter_day1, day_time_vector, day_value_vector, shift_time4, shift_time5, heating_adjustment_ip)
            if shift_time4 != shift_time6 
            	winter_day1 = createDaySchedule(winter_day1, day_time_vector, day_value_vector, shift_time6, shift_time7, heating_adjustment_ip)
            end

            final_htg_sch_set_values << winter_day1.values

            winterStartMonth2 = OpenStudio::MonthOfYear.new(winter_start_month2)
            winterEndMonth2 = OpenStudio::MonthOfYear.new(winter_end_month2)
            winterStartDate2 = OpenStudio::Date.new(winterStartMonth2, 1)
            winterEndDate2 = OpenStudio::Date.new(winterEndMonth2, 30)

            winter_rule2 = winter_rule1.clone(model).to_ScheduleRule.get
            winter_rule2.setStartDate(winterStartDate2)
            winter_rule2.setEndDate(winterEndDate2)

            cloned_day_winter2 = winter_day1.clone(model)
            cloned_day_winter2.setParent(winter_rule2)

          end
        end
        
        
        if days_covered.include?(false)
          
            summerStartMonth = OpenStudio::MonthOfYear.new(summer_start_month)
            summerEndMonth = OpenStudio::MonthOfYear.new(summer_end_month)
            summerStartDate = OpenStudio::Date.new(summerStartMonth, 1)
            summerEndDate = OpenStudio::Date.new(summerEndMonth, 30)
            
            summer_rule = OpenStudio::Model::ScheduleRule.new(schedule)
            summer_rule.setStartDate(summerStartDate)
            summer_rule.setEndDate(summerEndDate)

            coverSomeDays(summer_rule, days_covered)
            allDaysCovered(summer_rule, days_covered)

            cloned_day_summer = default_rule.clone(model)
            cloned_day_summer.setParent(summer_rule)

            winterStartMonth1 = OpenStudio::MonthOfYear.new(winter_start_month1)
            winterEndMonth1 = OpenStudio::MonthOfYear.new(winter_end_month1)
            winterStartDate1 = OpenStudio::Date.new(winterStartMonth1, 1)
            winterEndDate1 = OpenStudio::Date.new(winterEndMonth1, 30)

            winter_rule1 = summer_rule.clone(model).to_ScheduleRule.get
            winter_rule1.setStartDate(winterStartDate1)
            winter_rule1.setEndDate(winterEndDate1)

            cloned_day_winter = default_rule.clone(model)
            cloned_day_winter.setParent(winter_rule1)

            winter_day1 = winter_rule1.daySchedule
            day_time_vector = winter_day1.times
            day_value_vector = winter_day1.values
            winter_day1.clearValues
            
            winter_day1 = createDaySchedule(winter_day1, day_time_vector, day_value_vector, shift_time4, shift_time5, heating_adjustment_ip)
            if shift_time4 != shift_time6 
            	winter_day1 = createDaySchedule(winter_day1, day_time_vector, day_value_vector, shift_time6, shift_time7, heating_adjustment_ip)
            end
            
            final_htg_sch_set_values << winter_day1.values

            winterStartMonth2 = OpenStudio::MonthOfYear.new(winter_start_month2)
            winterEndMonth2 = OpenStudio::MonthOfYear.new(winter_end_month2)
            winterStartDate2 = OpenStudio::Date.new(winterStartMonth2, 1)
            winterEndDate2 = OpenStudio::Date.new(winterEndMonth2, 30)

            winter_rule2 = winter_rule1.clone(model).to_ScheduleRule.get
            winter_rule2.setStartDate(winterStartDate2)
            winter_rule2.setEndDate(winterEndDate2)

            cloned_day_winter2 = winter_day1.clone(model)
            cloned_day_winter2.setParent(winter_rule2)

        end

      else
        runner.registerWarning("Schedule '#{k}' isn't a ScheduleRuleset object and won't be altered by this measure.")
        v.remove # remove un-used clone
      end
    end


    # get min and max heating and cooling and convert to IP
    clg_sch_set_values = clg_sch_set_values.flatten
    htg_sch_set_values = htg_sch_set_values.flatten

    # set NA flag if can't get values for schedules (e.g. if all compact)
    applicable_flag = false

    # get min and max if values exist
    if !clg_sch_set_values.empty?
      min_clg_si = OpenStudio::Quantity.new(clg_sch_set_values.min, temperature_si_unit)
      max_clg_si = OpenStudio::Quantity.new(clg_sch_set_values.max, temperature_si_unit)
      min_clg_ip = OpenStudio.convert(min_clg_si, temperature_ip_unit).get
      max_clg_ip = OpenStudio.convert(max_clg_si, temperature_ip_unit).get
      applicable_flag = true
    else
      min_clg_ip = 'NA'
      max_clg_ip = 'NA'
    end

    # get min and max if values exist
    if !htg_sch_set_values.empty?
      min_htg_si = OpenStudio::Quantity.new(htg_sch_set_values.min, temperature_si_unit)
      max_htg_si = OpenStudio::Quantity.new(htg_sch_set_values.max, temperature_si_unit)
      min_htg_ip = OpenStudio.convert(min_htg_si, temperature_ip_unit).get
      max_htg_ip = OpenStudio.convert(max_htg_si, temperature_ip_unit).get
      applicable_flag = true
    else
      min_htg_ip = 'NA'
      max_htg_ip = 'NA'
    end

    # not applicable if no schedules can be altered
    if applicable_flag == false
      runner.registerAsNotApplicable('No thermostat schedules in the models could be altered.')
    end

    # reporting initial condition of model
    starting_spaces = model.getSpaces
    runner.registerInitialCondition("Initial cooling setpoints used in the model range from #{min_clg_ip} to #{max_clg_ip}. Initial heating setpoints used in the model range from #{min_htg_ip} to #{max_htg_ip}.")

    # get min and max heating and cooling and convert to IP for final
    final_clg_sch_set_values = final_clg_sch_set_values.flatten
    final_htg_sch_set_values = final_htg_sch_set_values.flatten

    if !clg_sch_set_values.empty?
      final_min_clg_si = OpenStudio::Quantity.new(final_clg_sch_set_values.min, temperature_si_unit)
      final_max_clg_si = OpenStudio::Quantity.new(final_clg_sch_set_values.max, temperature_si_unit)
      final_min_clg_ip = OpenStudio.convert(final_min_clg_si, temperature_ip_unit).get
      final_max_clg_ip = OpenStudio.convert(final_max_clg_si, temperature_ip_unit).get
    else
      final_min_clg_ip = 'NA'
      final_max_clg_ip = 'NA'
    end

    # get min and max if values exist
    if !htg_sch_set_values.empty?
      final_min_htg_si = OpenStudio::Quantity.new(final_htg_sch_set_values.min, temperature_si_unit)
      final_max_htg_si = OpenStudio::Quantity.new(final_htg_sch_set_values.max, temperature_si_unit)
      final_min_htg_ip = OpenStudio.convert(final_min_htg_si, temperature_ip_unit).get
      final_max_htg_ip = OpenStudio.convert(final_max_htg_si, temperature_ip_unit).get
    else
      final_min_htg_ip = 'NA'
      final_max_htg_ip = 'NA'
    end

    # reporting final condition of model
    finishing_spaces = model.getSpaces
    runner.registerFinalCondition("Final cooling setpoints used in the model range from #{final_min_clg_ip} to #{final_max_clg_ip}. Final heating setpoints used in the model range from #{final_min_htg_ip} to #{final_max_htg_ip}.\n The cooling setpoints are increased by #{cooling_adjustment}F，from #{starttime_cooling} to #{endtime_cooling}. \n The heating setpoints are decreased by #{0-heating_adjustment}F，from #{starttime_heating2} to #{endtime_heating2}.")

    return true
  end


  def allDaysCovered(sch_rule, sch_day_covered)
    if sch_rule.applySunday 
      sch_day_covered[0] = true
    end
    if sch_rule.applyMonday
      sch_day_covered[1] = true
    end
    if sch_rule.applyTuesday
      sch_day_covered[2] = true
    end
    if sch_rule.applyWednesday
      sch_day_covered[3] = true
    end
    if sch_rule.applyThursday
      sch_day_covered[4] = true
    end
    if sch_rule.applyFriday
      sch_day_covered[5] = true
    end
    if sch_rule.applySaturday
      sch_day_covered[6] = true
    end
  end

  def coverSomeDays(sch_rule, sch_day_covered)
    if sch_day_covered[0] == false
      sch_rule.setApplySunday(true)
    end
    if sch_day_covered[1] == false
      sch_rule.setApplyMonday(true)
    end
    if sch_day_covered[2] == false
      sch_rule.setApplyTuesday(true)
    end
    if sch_day_covered[3] == false
      sch_rule.setApplyWednesday(true)
    end
    if sch_day_covered[4] == false
      sch_rule.setApplyThursday(true)
    end
    if sch_day_covered[5] == false
      sch_rule.setApplyFriday(true)
    end
    if sch_day_covered[6] == false
      sch_rule.setApplySaturday(true)
    end

  end

  def updateDaySchedule(sch_day, time_begin, time_mid, time_end1)
    if (time_begin < time_mid)
      new_times = []
      new_values = []
      day_time_vector = sch_day.times
      day_value_vector = sch_day.values

      day_time_vector.each do |time|
        new_times << time
      end

      # push values to array
      day_value_vector.each do |value|
        new_values << value
      end

      sch_day.clearValues

      sch_day.addValue(time_begin,0)       
      for i in 1..(new_values.length - 1)
        sch_day.addValue(new_times[i], new_values[i])
      end
    end
    return sch_day
  end

  def createDaySchedule(sch_day, vec_time, vec_value, time_begin, time_end, adjustment)
    temperature_si_unit = OpenStudio.createUnit('C').get
    temperature_ip_unit = OpenStudio.createUnit('F').get

    count = 0
    for i in 0..(vec_time.size - 1)
      if vec_time[i]>time_begin&&vec_time[i]<time_end && count == 0
      v_si = OpenStudio::Quantity.new(vec_value[i], temperature_si_unit)
      v_ip = OpenStudio.convert(v_si, temperature_ip_unit).get
      target_v_ip = v_ip + adjustment
      target_temp_si = OpenStudio.convert(target_v_ip, temperature_si_unit).get
      sch_day.addValue(time_begin, vec_value[i])
      sch_day.addValue(vec_time[i],target_temp_si.value)
      count=1
      elsif vec_time[i]>time_end && count == 0
      v_si = OpenStudio::Quantity.new(vec_value[i], temperature_si_unit)
      v_ip = OpenStudio.convert(v_si, temperature_ip_unit).get
      target_v_ip = v_ip + adjustment
      target_temp_si = OpenStudio.convert(target_v_ip, temperature_si_unit).get
      sch_day.addValue(time_begin,vec_value[i])
      sch_day.addValue(time_end,target_temp_si.value)
      sch_day.addValue(vec_time[i],vec_value[i])
      count = 2
      elsif vec_time[i]>time_begin && vec_time[i]<=time_end && count==1
      v_si = OpenStudio::Quantity.new(vec_value[i], temperature_si_unit)
      v_ip = OpenStudio.convert(v_si, temperature_ip_unit).get
      target_v_ip = v_ip + adjustment
      target_temp_si = OpenStudio.convert(target_v_ip, temperature_si_unit).get
      sch_day.addValue(vec_time[i], vec_value[i])
      elsif vec_time[i]>time_end && count == 1
      v_si = OpenStudio::Quantity.new(vec_value[i], temperature_si_unit)
      v_ip = OpenStudio.convert(v_si, temperature_ip_unit).get
      target_v_ip = v_ip + adjustment
      target_temp_si = OpenStudio.convert(target_v_ip, temperature_si_unit).get
      sch_day.addValue(time_end, target_temp_si)
      sch_day.addValue(vec_time[i], vec_value[i])
      count=2
      else 
      v_si = OpenStudio::Quantity.new(vec_value[i], temperature_si_unit)
      v_ip = OpenStudio.convert(v_si, temperature_ip_unit).get
      target_v_ip = v_ip
      target_temp_si = OpenStudio.convert(target_v_ip, temperature_si_unit).get
      sch_day.addValue(vec_time[i], target_temp_si.value)
      end
    end
    return sch_day
  end
end



# this allows the measure to be used by the application
AdjustThermostatSetpointsByDegrees.new.registerWithApplication
