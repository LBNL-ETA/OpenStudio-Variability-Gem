# see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

# start the measure
require "#{File.dirname(__FILE__)}/os_lib_schedules"
class AddIceStorage < OpenStudio::Ruleset::ModelUserScript

  # human readable name
  def name
    return "DR Ice Storage (Large Office)"
  end

  # human readable description
  def description
    return "This measure allows you to apply a chiller from a built in library."
  end

  # human readable description of modeling approach
  def modeler_description
    return "This measure contains a built in idf file library of chillers.  Arguments to the measure allow you to choose a specific chiller by name and apply it to a specified chilled water plant."
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new


    primary_chiller_name = OpenStudio::Measure::OSArgument.makeStringArgument("primary_chiller_name", true)
    primary_chiller_name.setDisplayName("Name of Existing Chiller")
    primary_chiller_name.setDefaultValue("90.1-2004 WaterCooled  Centrifugal Chiller 0")
    args << primary_chiller_name

    condenser_loop_name = OpenStudio::Ruleset::makeChoiceArgumentOfWorkspaceObjects("condenser_loop_name","OS_PlantLoop".to_IddObjectType,model,true)
    condenser_loop_name.setDescription("The condenser loop to connect the new charging chiller to")
    condenser_loop_name.setDisplayName("Condenser Loop Name")
    condenser_loop_name.setDefaultValue("Condenser Water Loop")
    args << condenser_loop_name

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

    condenser_loop = runner.getOptionalWorkspaceObjectChoiceValue("condenser_loop_name", user_arguments,model).get.to_PlantLoop.get
    primary_chiller_name = runner.getStringArgumentValue('primary_chiller_name', user_arguments)
    auto_date = runner.getBoolArgumentValue('auto_date', user_arguments)

 ######### GET CLIMATE ZONES ################
    if auto_date
      ashraeClimateZone = ''
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
        starttime_charging = 12
        endtime_charging = 16
        starttime_gta = 16
        endtime_gta = 20
      elsif ashraeClimateZone == '2B'
        starttime_charging = 3
        endtime_charging = 7
        starttime_gta = 15
        endtime_gta = 19
      elsif ashraeClimateZone == '3A'
        starttime_charging = 3
        endtime_charging = 7
        starttime_gta = 17
        endtime_gta = 21
      elsif ashraeClimateZone == '3B'
        starttime_charging = 3
        endtime_charging = 7
        starttime_gta = 17
        endtime_gta = 21
      elsif ashraeClimateZone == '3C'
        starttime_charging = 11
        endtime_charging = 15
        starttime_gta = 16
        endtime_gta = 20
      elsif ashraeClimateZone == '4A'
        starttime_charging = 3
        endtime_charging = 7
        starttime_gta = 15
        endtime_gta = 19
      elsif ashraeClimateZone == '4B'
        starttime_charging = 3
        endtime_charging = 7
        starttime_gta = 15
        endtime_gta = 19
      elsif ashraeClimateZone == '4C'
        starttime_charging = 1
        endtime_charging = 5
        starttime_gta = 15
        endtime_gta = 19
      elsif ashraeClimateZone == '5A'
        starttime_charging = 3
        endtime_charging = 7
        starttime_gta = 15
        endtime_gta = 19
      elsif ashraeClimateZone == '5B'
        starttime_charging = 2
        endtime_charging = 6
        starttime_gta = 15
        endtime_gta = 19
      elsif ashraeClimateZone == '5C'
        starttime_charging = 1
        endtime_charging = 5
        starttime_gta = 15
        endtime_gta = 19
      elsif ashraeClimateZone == '6A'
        starttime_charging = 3
        endtime_charging = 7
        starttime_gta = 15
        endtime_gta = 19
      elsif ashraeClimateZone == '6B'
        starttime_charging = 1
        endtime_charging = 5
        starttime_gta = 15
        endtime_gta = 19
      elsif ashraeClimateZone == '7A'
        starttime_charging = 3
        endtime_charging = 7
        starttime_gta = 15
        endtime_gta = 19
      end
    end





    primaryChiller = nil
    chilled_water_plant = nil
    # loop through plant loops and swap objects
    model.getPlantLoops.each do |plant_loop|
      plant_loop.supplyComponents.each do |component|
        if component.name.to_s == primary_chiller_name
          new_object = component.clone(model)    ## to prevent an optional result, which will be empty if conversion failed. Openstudio measure writing standard
          if not new_object.to_ChillerElectricEIR.empty?
            primaryChiller = new_object.to_ChillerElectricEIR.get
          end
          chilled_water_plant = plant_loop
          component.remove
        end
      end
    end

    myCWPconcentration = 40             # glycol concentration
    myCWPminTemp = -6.67                # chilled water plant loop minimum temperature
    myCWPsp = 6.7                       # chilled water plant loop setpoint manager
    myPrimaryChillersp = 6.67          # primary chiller setpoint
    myPrimaryChillersplimit = 6.67      # primary chiller setpoint manager limit
    myChargingChillersp = -6.67         # charging chiller setpoint manager
    myChargingChillersplimit = -6.67    # charging chiller setpoint manager limit
    myIceStoragesp = 6.67               # ice storage setpoint manager
    myIceStoragefp = 0                  # ice storage freezing setpoint
    mygtasp = 12.78

    if ashraeClimateZone == '4A' || ashraeClimateZone == '5A'
      mygtasp = 6.67
    end

    chilled_water_plant.setFluidType('Water')
    chilled_water_plant.setGlycolConcentration(myCWPconcentration)
    chilled_water_plant.setMaximumLoopTemperature(40)
    chilled_water_plant.setMinimumLoopTemperature(myCWPminTemp)
    #chilled_water_plant.setLoadDistributionScheme('Optimal')
    chilled_water_plant.setCommonPipeSimulation('CommonPipe')

    loop_sizing = chilled_water_plant.sizingPlant
    loop_sizing.setLoopType('Cooling')
    loop_sizing.setDesignLoopExitTemperature(6.7)
    loop_sizing.setLoopDesignTemperatureDifference(6.7)


    chw_rules = []
    chilled_water_ruleset = { 'name' => 'Chilled-Water-Loop-Sepoint-44F-Schedule',
                             #'winter_design_day' => [[24, 0]],
                             #'summer_design_day' => [[24,6.67]],
                             'default_day' => ['All Days', [24, myCWPsp]]
                             #'rules' => chw_rules
                            }
    chilled_water_spmanager_sch = OsLib_Schedules.createComplexSchedule(model, chilled_water_ruleset)


    primaryChiller_rules = []
    primaryChiller_rules << ['Winter All Days', '1/1-5/31', 'Mon/Tue/Wed/Thu/Fri/Sat/Sun', [24, 99]]
    primaryChiller_rules << ['Winter All Days', '9/1-12/31', 'Mon/Tue/Wed/Thu/Fri/Sat/Sun', [24, 99]]
    primaryChiller_rules << ['Summer Weekend', '6/1-8/31', 'Sat/Sun', [8, 99]]
    primaryChiller_rules << ['Summer Weekday', '6/1-8/31', 'Mon/Tue/Wed/Thu/Fri', [starttime_gta, myPrimaryChillersp],[endtime_gta, mygtasp], [24, myPrimaryChillersp]]
    #primaryChiller_rules << ['Summer Weekday', '6/1-8/31', 'Mon/Tue/Wed/Thu/Fri', [starttime_charging, myPrimaryChillersp], [endtime_charging, 99], [24, myPrimaryChillersp]]
    primaryChiller_ruleset = {'name' => 'Chiller Primary-Setpoint-55F-Schedule', 
                              'winter_design_day' => [[24, 99]],
                              'summer_design_day' => [[24, myPrimaryChillersp]],
                              'default_day' => ['All Days', [starttime_gta, myPrimaryChillersp],[endtime_gta, 99], [24, myPrimaryChillersp]],
                              'rules' => primaryChiller_rules }
    primaryChiller_spmanager_sch = OsLib_Schedules.createComplexSchedule(model, primaryChiller_ruleset)
    

    chargingChiller_rules = []
    chargingChiller_rules << ['Winter All Days', '1/1-5/31', 'Mon/Tue/Wed/Thu/Fri/Sat/Sun', [24, 99]]
    chargingChiller_rules << ['Winter All Days', '9/1-12/31', 'Mon/Tue/Wed/Thu/Fri/Sat/Sun', [24, 99]]
    chargingChiller_rules << ['Summer Weekend', '6/1-8/31', 'Sat/Sun', [8, myChargingChillersp], [24, 99]]
    chargingChiller_rules << ['Summer Weekday', '6/1-8/31', 'Mon/Tue/Wed/Thu/Fri', [starttime_charging, 99], [endtime_charging,myChargingChillersp], [24, 99]]
    chargingChiller_ruleset = {'name' => 'Chiller Charging-Setpoint-20F-Schedule',
                              'winter_design_day' => [[24, 99]],
                              'summer_design_day' => [[24, myChargingChillersp]],
                              'default_day' => ['All Days', [starttime_charging, 99], [endtime_charging,myChargingChillersp], [24, 99]],
                              'rules' => chargingChiller_rules }
    chargingChiller_spmanager_sch = OsLib_Schedules.createComplexSchedule(model, chargingChiller_ruleset)
    
    iceStorage_rules = []
    iceStorage_rules << ['Winter All Days', '1/1-5/31', 'Mon/Tue/Wed/Thu/Fri/Sat/Sun', [24, 99]]
    iceStorage_rules << ['Winter All Days', '9/1-12/31', 'Mon/Tue/Wed/Thu/Fri/Sat/Sun', [24, 99]]
    iceStorage_rules << ['Summer Weekend', '6/1-8/31', 'Sat/Sun', [8, 99]]
    iceStorage_rules << ['Summer Weekday', '6/1-8/31', 'Mon/Tue/Wed/Thu/Fri', [24, myIceStoragesp]]
    #iceStorage_rules << ['Summer Weekday', '6/1-8/31', 'Mon/Tue/Wed/Thu/Fri', [24, myIceStoragesp]]
    iceStorage_ruleset = {'name' => 'IceStorage-Setpoint-44F-Schedule',
                              'winter_design_day' => [[24, 99]],
                              'summer_design_day' => [[24, myIceStoragesp]],
                              'default_day' => ['All Days', [24, myIceStoragesp]],
                              'rules' => iceStorage_rules }
    #iceStorage_spmanager_sch = OsLib_Schedules.createComplexSchedule(model, 'name' => 'IceStorage-Setpoint-44F-Schedule','default_day' => ['All Days', [24, myIceStoragesp]])
    iceStorage_spmanager_sch = OsLib_Schedules.createComplexSchedule(model, iceStorage_ruleset)

    iceStorage_availability_rules = []
    iceStorage_availability_rules << ['Winter All Days', '1/1-5/31', 'Mon/Tue/Wed/Thu/Fri/Sat/Sun', [24, 0]]
    iceStorage_availability_rules << ['Winter All Days', '9/1-12/31', 'Mon/Tue/Wed/Thu/Fri/Sat/Sun', [24, 0]]
    iceStorage_availability_rules << ['Summer Weekend', '6/1-8/31', 'Sat/Sun', [24, 0]]
    iceStorage_availability_rules << ['Summer Weekday', '6/1-8/31', 'Mon/Tue/Wed/Thu/Fri', [starttime_gta, 0],[endtime_gta, 1], [24, 0]]
    iceStorage_availability_ruleset = { 'name' => 'IceStorage-Availability-Schedule', 
                                       'winter_design_day' => [[24, 0]],
                                       'summer_design_day' => [[24, 1]],
                                       'default_day' => ['All Days', [starttime_gta, 0],[endtime_gta, 1], [24, 0]],
                                       'rules' => iceStorage_availability_rules }
    iceStorage_availability_sch = OsLib_Schedules.createComplexSchedule(model, iceStorage_availability_ruleset)
    
    # create a scheduled setpoint manager
    chilledwater_manager_scheduled = OpenStudio::Model::SetpointManagerScheduled.new(model, chilled_water_spmanager_sch)
    primarychiller_manager_scheduled = OpenStudio::Model::SetpointManagerScheduled.new(model, primaryChiller_spmanager_sch)
    chargingchiller_manager_scheduled = OpenStudio::Model::SetpointManagerScheduled.new(model, chargingChiller_spmanager_sch)
    icestorage_manager_scheduled = OpenStudio::Model::SetpointManagerScheduled.new(model, iceStorage_spmanager_sch)

    primaryChiller.setReferenceLeavingChilledWaterTemperature(myPrimaryChillersp)
    primaryChiller.setLeavingChilledWaterLowerTemperatureLimit(myPrimaryChillersplimit)
    primaryChiller.setChillerFlowMode('ConstantFlow')


    chargingChiller = addChiller(model, runner, "charging chiller")
    chargingChiller.setReferenceLeavingChilledWaterTemperature(myChargingChillersp)
    chargingChiller.setLeavingChilledWaterLowerTemperatureLimit(myChargingChillersplimit)
    chargingChiller.setChillerFlowMode('NotModulated')

    iceStorage = addIceStorage(model, runner, "ice storage")
    iceStorage.setFreezingTemperatureofStorageMedium(myIceStoragefp)
    iceStorage.setAvailabilitySchedule(iceStorage_availability_sch)

    runner.registerInfo("PRIMARY CHILLER = '#{primaryChiller.name}' CHARGING CHILLER= '#{chargingChiller.name}' ICE STORAGE= '#{iceStorage.name}'")

    chilled_water_plant.addSupplyBranchForComponent(chargingChiller)
    iceStorage.addToNode(chargingChiller.supplyOutletModelObject.get.to_Node.get)
    chilled_water_plant.addSupplyBranchForComponent(primaryChiller)

    ### remove the existing chilledwater sp manager
    model.getPlantLoops.each do |plant_loop|
      plant_loop.supplyComponents.each do |component|
        if component.name.to_s == "Chilled Water Loop Setpoint Manager"
          component.remove
        end
      end
    end

    primarychiller_manager_scheduled.addToNode(primaryChiller.supplyOutletModelObject.get.to_Node.get)
    chargingchiller_manager_scheduled.addToNode(chargingChiller.supplyOutletModelObject.get.to_Node.get)
    icestorage_manager_scheduled.addToNode(iceStorage.outletModelObject.get.to_Node.get)
    chilledwater_manager_scheduled.addToNode(chilled_water_plant.supplyOutletNode)



    #### connect the new Charging chiller to the condenser loop  #####
    model.getChillerElectricEIRs.each do |chiller|
      #if chiller.condenserType == 'WaterCooled' # works only if chillers not already connected to condenser loop(s)
        condenser_loop.addDemandBranchForComponent(chiller)
        chiller.setCondenserType("WaterCooled")
        runner.registerInfo("In createCondenserLoop - Condenser type = '#{chiller.condenserType}'")
        
      #end
    end

    variable_names = []
    variable_names << 'Chiller Electric Power'
    variable_names << 'Ice Thermal Storage End Fraction'
    variable_names << 'Ice Thermal Storage Cooling Discharge Rate'
    variable_names << 'Ice Thermal Storage Mass Flow Rate'
    variable_names << 'Ice Thermal Storage Tank Outlet Temperature'

    variable_names.each do |variable_name|
      outputVariable = OpenStudio::Model::OutputVariable.new(variable_name, model)
      outputVariable.setReportingFrequency('hourly')
      #runner.registerFinalCondition("The model finished with #{outputVariable.size} output variable objects.")
    end

    return true
  end


  def addChiller(model, runner, namestr)
    # create clgCapFuncTempCurve
    clgCapFuncTempCurve = OpenStudio::Model::CurveBiquadratic.new(model)
    clgCapFuncTempCurve.setCoefficient1Constant(1.0215158E+00)
    clgCapFuncTempCurve.setCoefficient2x(3.7035864E-02)
    clgCapFuncTempCurve.setCoefficient3xPOW2(2.332476E-04)
    clgCapFuncTempCurve.setCoefficient4y(-3.894048E-03)
    clgCapFuncTempCurve.setCoefficient5yPOW2(-6.52536E-05)
    clgCapFuncTempCurve.setCoefficient6xTIMESY(-2.680452E-04)
    clgCapFuncTempCurve.setMinimumValueofx(5)
    clgCapFuncTempCurve.setMaximumValueofx(10)
    clgCapFuncTempCurve.setMinimumValueofy(24)
    clgCapFuncTempCurve.setMaximumValueofy(35)
    # create eirFuncTempCurve
    eirFuncTempCurve = OpenStudio::Model::CurveBiquadratic.new(model)
    eirFuncTempCurve.setCoefficient1Constant(7.0176857E-01)
    eirFuncTempCurve.setCoefficient2x(-4.52016E-03)
    eirFuncTempCurve.setCoefficient3xPOW2(5.331096E-04)
    eirFuncTempCurve.setCoefficient4y(5.498208E-03)
    eirFuncTempCurve.setCoefficient5yPOW2(5.445792E-04)
    eirFuncTempCurve.setCoefficient6xTIMESY(-7.290324E-04)
    eirFuncTempCurve.setMinimumValueofx(5)
    eirFuncTempCurve.setMaximumValueofx(10)
    eirFuncTempCurve.setMinimumValueofy(24)
    eirFuncTempCurve.setMaximumValueofy(35)
    # create eirFuncPlrCurve
    eirFuncPlrCurve = OpenStudio::Model::CurveQuadratic.new(model)
    eirFuncPlrCurve.setCoefficient1Constant(6.369119E-02)
    eirFuncPlrCurve.setCoefficient2x(5.8488E-01)
    eirFuncPlrCurve.setCoefficient3xPOW2(3.5280274E-01)
    eirFuncPlrCurve.setMinimumValueofx(0)
    eirFuncPlrCurve.setMaximumValueofx(1)
    # construct chiller
    chiller = OpenStudio::Model::ChillerElectricEIR.new(model, clgCapFuncTempCurve, eirFuncTempCurve, eirFuncPlrCurve)
    # plant.addSupplyBranchForComponent(chiller)
    chiller.setName(namestr)
    chiller.autosizeReferenceCapacity
    chiller.setReferenceCOP(5.5)
    #chiller.setReferenceLeavingChilledWaterTemperature(6.67)
    #chiller.setReferenceEnteringCondenserFluidTemperature(29.4)
    chiller.autosizeReferenceChilledWaterFlowRate
    chiller.autosizeReferenceCondenserFluidFlowRate
    chiller.setMinimumPartLoadRatio(0.15)
    chiller.setMaximumPartLoadRatio(1)
    chiller.setOptimumPartLoadRatio(1)
    chiller.setMinimumUnloadingRatio(0.25)
    chiller.setCondenserType('WaterCooled')
    
    chiller.setSizingFactor(1)
    chiller.setBasinHeaterCapacity(0)
    chiller.setBasinHeaterSetpointTemperature(10)

    #runner.registerInfo("Chiller '#{chiller}'")
    #runner.registerFinalCondition("ChillerElectricEIR was created with success.\nClick on 'Advanced Output' to see the resulting ChillerElectricEIR")

    return chiller
  end

  def addIceStorage(model, runner, namestr)

    #### Create a new Quadratic Linear Discharge Curve  #####
    ts_discharge_curve = OpenStudio::Model::CurveQuadraticLinear.new(model)
    ts_discharge_curve.setName("Ice Storage Discharge Curve")
    ts_discharge_curve.setCoefficient1Constant(0.0)
    ts_discharge_curve.setCoefficient2x(0.09)
    ts_discharge_curve.setCoefficient3xPOW2(-0.15)
    ts_discharge_curve.setCoefficient4y(0.612)
    ts_discharge_curve.setCoefficient5xTIMESY(-0.324)
    ts_discharge_curve.setCoefficient6xPOW2TIMESY(-0.216)
    ts_discharge_curve.setMinimumValueofx(0)
    ts_discharge_curve.setMaximumValueofx(1)
    ts_discharge_curve.setMinimumValueofy(0)
    ts_discharge_curve.setMaximumValueofy(9.9)

    #### Create a new Quadratic Linear Charge Curve  #####
    ts_charge_curve = OpenStudio::Model::CurveQuadraticLinear.new(model)
    ts_charge_curve.setName("Ice Storage Charge Curve")
    ts_charge_curve.setCoefficient1Constant(0.0)
    ts_charge_curve.setCoefficient2x(0.09)
    ts_charge_curve.setCoefficient3xPOW2(-0.15)
    ts_charge_curve.setCoefficient4y(0.612)
    ts_charge_curve.setCoefficient5xTIMESY(-0.324)
    ts_charge_curve.setCoefficient6xPOW2TIMESY(-0.216)
    ts_charge_curve.setMinimumValueofx(0)
    ts_charge_curve.setMaximumValueofx(1)
    ts_charge_curve.setMinimumValueofy(0)
    ts_charge_curve.setMaximumValueofy(9.9)

    #runner.registerInfo("ICE STORAGE QUADRATIC LINEAR CURVES = '#{ts_charge_curve.name}' AND '#{ts_discharge_curve.name}' ")

    ts = OpenStudio::Model::ThermalStorageIceDetailed.new(model)
    # plant.addSupplyBranchForComponent(ts)
    
    ts.setName(namestr)
    #ts.setAvailabilitySchedule(ts_schRuleSet)
    ts.setCapacity(40)
    ts.setDischargingCurve(ts_discharge_curve)
    ts.setChargingCurve(ts_charge_curve)
    ts.setTimestepoftheCurveData(1)
    ts.setParasiticElectricLoadDuringDischarging(0.0001)
    ts.setParasiticElectricLoadDuringCharging(0.0002)
    ts.setTankLossCoefficient(0.0003)
    #ts.setFreezingTemperatureofStorageMedium(0)
    ts.setThawProcessIndicator("OutsideMelt")

    #runner.registerInfo("Ice Storage '#{ts}'")
    #runner.registerFinalCondition("'#{ts}' was created with success.\nClick on 'Advanced Output' to see the resulting ThermalStorageIceDetailed")

    return ts
  end

end

# register the measure to be used by the application
AddIceStorage.new.registerWithApplication
