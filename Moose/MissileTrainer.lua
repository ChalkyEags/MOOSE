--- Provides missile training functions.
--
-- @{#MISSILETRAINER} class
-- ========================
-- The @{#MISSILETRAINER} class uses the DCS world messaging system to be alerted of any missiles fired, and when a missile would hit your aircraft,
-- the class will destroy the missile within a certain range, to avoid damage to your aircraft.
-- It suports the following functionality:
--
--  * Track the missiles fired at you and other players, providing bearing and range information of the missiles towards the airplanes.
--  * Provide alerts of missile launches, including detailed information of the units launching, including bearing, range �
--  * Provide alerts when a missile would have killed your aircraft.
--  * Provide alerts when the missile self destructs.
--  * Enable / Disable and Configure the Missile Trainer using the various menu options.
--
-- MISSILETRAINER construction methods:
-- ====================================
-- Create a new MISSILETRAINER object with the @{#MISSILETRAINER.New} method:
--
--   * @{#MISSILETRAINER.New}: Creates a new MISSILETRAINER object taking the maximum distance to your aircraft to evaluate when a missile needs to be destroyed.
--
-- MISSILETRAINER will collect each unit declared in the mission with a skill level "Client" and "Player", and will monitor the missiles shot at those.
--
-- MISSILETRAINER initialization methods:
-- ======================================
-- A MISSILETRAINER object will behave differently based on the usage of initialization methods:
--
--  * @{#MISSILETRAINER.InitMessagesOnOff}: Sets by default the display of any message to be ON or OFF.
--  * @{#MISSILETRAINER.InitTrackingToAll}: Sets by default the missile tracking report for all players or only for those missiles targetted to you.
--  * @{#MISSILETRAINER.InitTrackingOnOff}: Sets by default the display of missile tracking report to be ON or OFF.
--  * @{#MISSILETRAINER.InitAlertsToAll}: Sets by default the display of alerts to be shown to all players or only to you.
--  * @{#MISSILETRAINER.InitAlertsHitsOnOff}: Sets by default the display of hit alerts ON or OFF.
--  * @{#MISSILETRAINER.InitAlertsLaunchesOnOff}: Sets by default the display of launch alerts ON or OFF.
--  * @{#MISSILETRAINER.InitRangeOnOff}: Sets by default the display of range information of missiles ON of OFF.
--  * @{#MISSILETRAINER.InitBearingOnOff}: Sets by default the display of bearing information of missiles ON of OFF.
--
-- @module MissileTrainer
-- @author FlightControl

Include.File( "Client" )
Include.File( "Scheduler" )

--- The MISSILETRAINER class
-- @type MISSILETRAINER
-- @extends Base#BASE
MISSILETRAINER = {
  ClassName = "MISSILETRAINER",
}

--- Creates the main object which is handling missile tracking.
-- When a missile is fired a SCHEDULER is set off that follows the missile. When near a certain a client player, the missile will be destroyed.
-- @param #MISSILETRAINER
-- @param #number Distance The distance in meters when a tracked missile needs to be destroyed when close to a player.
-- @return #MISSILETRAINER
function MISSILETRAINER:New( Distance )
  local self = BASE:Inherit( self, BASE:New() )
  self:F( Distance )

  self.Schedulers = {}
  self.SchedulerID = 0

  self.MessageInterval = 2
  self.MessageLastTime = timer.getTime()

  self.Distance = Distance / 1000

  _EVENTDISPATCHER:OnShot( self._EventShot, self )

  self.DB = DATABASE:New():FilterStart()
  self.DBClients = self.DB.Clients
  self.DBUnits = self.DB.Units

  for ClientID, Client in pairs( self.DBClients ) do

    local function _Alive( Client )

      Client:Message( "Hello trainee, welcome to the Missile Trainer.\nUse the F10->F2 menu options in the radio menu to change the Missile Trainer settings.\nGood luck!", 10, "ID", "Trainer" )

      Client.MainMenu = MENU_CLIENT:New( Client, "Missile Trainer", nil )

      Client.MenuMessages = MENU_CLIENT:New( Client, "Messages", Client.MainMenu )
      Client.MenuOn = MENU_CLIENT_COMMAND:New( Client, "Messages On", Client.MenuMessages, self._MenuMessages, { MenuSelf = self, MessagesOnOff = true } )
      Client.MenuOff = MENU_CLIENT_COMMAND:New( Client, "Messages Off", Client.MenuMessages, self._MenuMessages, { MenuSelf = self, MessagesOnOff = false } )

      Client.MenuTracking = MENU_CLIENT:New( Client, "Tracking", Client.MainMenu )
      Client.MenuTrackingToAll = MENU_CLIENT_COMMAND:New( Client, "To All", Client.MenuTracking, self._MenuMessages, { MenuSelf = self, TrackingToAll = true } )
      Client.MenuTrackingToTarget = MENU_CLIENT_COMMAND:New( Client, "To Target", Client.MenuTracking, self._MenuMessages, { MenuSelf = self, TrackingToAll = false } )
      Client.MenuTrackOn = MENU_CLIENT_COMMAND:New( Client, "Tracking On", Client.MenuTracking, self._MenuMessages, { MenuSelf = self, TrackingOnOff = true } )
      Client.MenuTrackOff = MENU_CLIENT_COMMAND:New( Client, "Tracking Off", Client.MenuTracking, self._MenuMessages, { MenuSelf = self, TrackingOnOff = false } )

      Client.MenuAlerts = MENU_CLIENT:New( Client, "Alerts", Client.MainMenu )
      Client.MenuAlertsToAll = MENU_CLIENT_COMMAND:New( Client, "To All", Client.MenuAlerts, self._MenuMessages, { MenuSelf = self, AlertsToAll = true } )
      Client.MenuAlertsToTarget = MENU_CLIENT_COMMAND:New( Client, "To Target", Client.MenuAlerts, self._MenuMessages, { MenuSelf = self, AlertsToAll = false } )
      Client.MenuHitsOn = MENU_CLIENT_COMMAND:New( Client, "Hits On", Client.MenuAlerts, self._MenuMessages, { MenuSelf = self, AlertsHitsOnOff = true } )
      Client.MenuHitsOff = MENU_CLIENT_COMMAND:New( Client, "Hits Off", Client.MenuAlerts, self._MenuMessages, { MenuSelf = self, AlertsHitsOnOff = false } )
      Client.MenuLaunchesOn = MENU_CLIENT_COMMAND:New( Client, "Launches On", Client.MenuAlerts, self._MenuMessages, { MenuSelf = self, AlertsLaunchesOnOff = true } )
      Client.MenuLaunchesOff = MENU_CLIENT_COMMAND:New( Client, "Launches Off", Client.MenuAlerts, self._MenuMessages, { MenuSelf = self, AlertsLaunchesOnOff = false } )

      Client.MenuDetails = MENU_CLIENT:New( Client, "Details", Client.MainMenu )
      Client.MenuDetailsDistanceOn = MENU_CLIENT_COMMAND:New( Client, "Range On", Client.MenuDetails, self._MenuMessages, { MenuSelf = self, DetailsRangeOnOff = true } )
      Client.MenuDetailsDistanceOff = MENU_CLIENT_COMMAND:New( Client, "Range Off", Client.MenuDetails, self._MenuMessages, { MenuSelf = self, DetailsRangeOnOff = false } )
      Client.MenuDetailsBearingOn = MENU_CLIENT_COMMAND:New( Client, "Bearing On", Client.MenuDetails, self._MenuMessages, { MenuSelf = self, DetailsBearingOnOff = true } )
      Client.MenuDetailsBearingOff = MENU_CLIENT_COMMAND:New( Client, "Bearing Off", Client.MenuDetails, self._MenuMessages, { MenuSelf = self, DetailsBearingOnOff = false } )

      Client.MenuDistance = MENU_CLIENT:New( Client, "Set distance to plane", Client.MainMenu )
      Client.MenuDistance50 = MENU_CLIENT_COMMAND:New( Client, "50 meter", Client.MenuDistance, self._MenuMessages, { MenuSelf = self, Distance = 50 / 1000 } )
      Client.MenuDistance100 = MENU_CLIENT_COMMAND:New( Client, "100 meter", Client.MenuDistance, self._MenuMessages, { MenuSelf = self, Distance = 100 / 1000 } )
      Client.MenuDistance150 = MENU_CLIENT_COMMAND:New( Client, "150 meter", Client.MenuDistance, self._MenuMessages, { MenuSelf = self, Distance = 150 / 1000 } )
      Client.MenuDistance200 = MENU_CLIENT_COMMAND:New( Client, "200 meter", Client.MenuDistance, self._MenuMessages, { MenuSelf = self, Distance = 200 / 1000 } )


      local ClientID = Client:GetID()
      self:T( ClientID )
      if not self.TrackingMissiles[ClientID] then
        self.TrackingMissiles[ClientID] = {}
      end
      self.TrackingMissiles[ClientID].Client = Client
      if not self.TrackingMissiles[ClientID].MissileData then
        self.TrackingMissiles[ClientID].MissileData = {}
      end
    end

    Client:Alive( _Alive )

  end
  
--  	self.DB:ForEachClient(
--  	 --- @param Client#CLIENT Client
--  	 function( Client )
--  
--        ... actions ...
--        
--  	 end
--  	)

  self.MessagesOnOff = true

  self.TrackingToAll = false
  self.TrackingOnOff = true

  self.AlertsToAll = true
  self.AlertsHitsOnOff = true
  self.AlertsLaunchesOnOff = true

  self.DetailsRangeOnOff = true
  self.DetailsBearingOnOff = true

  self.TrackingMissiles = {}

  self.TrackingScheduler = SCHEDULER:New( self, self._TrackMissiles, {}, 0.5, 0.05, 0 )

  return self
end

-- Initialization methods.


--- Sets by default the display of any message to be ON or OFF.
-- @param #MISSILETRAINER self
-- @param #boolean MessagesOnOff true or false
-- @return #MISSILETRAINER self
function MISSILETRAINER:InitMessagesOnOff( MessagesOnOff )
  self:F( MessagesOnOff )

  self.MessagesOnOff = MessagesOnOff
  if self.MessagesOnOff == true then
    MESSAGE:New( "Messages ON", "Menu", 15, "ID" ):ToAll()
  else
    MESSAGE:New( "Messages OFF", "Menu", 15, "ID" ):ToAll()
  end

  return self
end

--- Sets by default the missile tracking report for all players or only for those missiles targetted to you.
-- @param #MISSILETRAINER self
-- @param #boolean TrackingToAll true or false
-- @return #MISSILETRAINER self
function MISSILETRAINER:InitTrackingToAll( TrackingToAll )
  self:F( TrackingToAll )

  self.TrackingToAll = TrackingToAll
  if self.TrackingToAll == true then
    MESSAGE:New( "Missile tracking to all players ON", "Menu", 15, "ID" ):ToAll()
  else
    MESSAGE:New( "Missile tracking to all players OFF", "Menu", 15, "ID" ):ToAll()
  end

  return self
end

--- Sets by default the display of missile tracking report to be ON or OFF.
-- @param #MISSILETRAINER self
-- @param #boolean TrackingOnOff true or false
-- @return #MISSILETRAINER self
function MISSILETRAINER:InitTrackingOnOff( TrackingOnOff )
  self:F( TrackingOnOff )

  self.TrackingOnOff = TrackingOnOff
  if self.TrackingOnOff == true then
    MESSAGE:New( "Missile tracking ON", "Menu", 15, "ID" ):ToAll()
  else
    MESSAGE:New( "Missile tracking OFF", "Menu", 15, "ID" ):ToAll()
  end

  return self
end

--- Sets by default the display of alerts to be shown to all players or only to you.
-- @param #MISSILETRAINER self
-- @param #boolean AlertsToAll true or false
-- @return #MISSILETRAINER self
function MISSILETRAINER:InitAlertsToAll( AlertsToAll )
  self:F( AlertsToAll )

  self.AlertsToAll = AlertsToAll
  if self.AlertsToAll == true then
    MESSAGE:New( "Alerts to all players ON", "Menu", 15, "ID" ):ToAll()
  else
    MESSAGE:New( "Alerts to all players OFF", "Menu", 15, "ID" ):ToAll()
  end

  return self
end

--- Sets by default the display of hit alerts ON or OFF.
-- @param #MISSILETRAINER self
-- @param #boolean AlertsHitsOnOff true or false
-- @return #MISSILETRAINER self
function MISSILETRAINER:InitAlertsHitsOnOff( AlertsHitsOnOff )
  self:F( AlertsHitsOnOff )

  self.AlertsHitsOnOff = AlertsHitsOnOff
  if self.AlertsHitsOnOff == true then
    MESSAGE:New( "Alerts Hits ON", "Menu", 15, "ID" ):ToAll()
  else
    MESSAGE:New( "Alerts Hits OFF", "Menu", 15, "ID" ):ToAll()
  end

  return self
end

--- Sets by default the display of launch alerts ON or OFF.
-- @param #MISSILETRAINER self
-- @param #boolean AlertsLaunchesOnOff true or false
-- @return #MISSILETRAINER self
function MISSILETRAINER:InitAlertsLaunchesOnOff( AlertsLaunchesOnOff )
  self:F( AlertsLaunchesOnOff )

  self.AlertsLaunchesOnOff = AlertsLaunchesOnOff
  if self.AlertsLaunchesOnOff == true then
    MESSAGE:New( "Alerts Launches ON", "Menu", 15, "ID" ):ToAll()
  else
    MESSAGE:New( "Alerts Launches OFF", "Menu", 15, "ID" ):ToAll()
  end

  return self
end

--- Sets by default the display of range information of missiles ON of OFF.
-- @param #MISSILETRAINER self
-- @param #boolean DetailsRangeOnOff true or false
-- @return #MISSILETRAINER self
function MISSILETRAINER:InitRangeOnOff( DetailsRangeOnOff )
  self:F( DetailsRangeOnOff )

  self.DetailsRangeOnOff = DetailsRangeOnOff
  if self.DetailsRangeOnOff == true then
    MESSAGE:New( "Range display ON", "Menu", 15, "ID" ):ToAll()
  else
    MESSAGE:New( "Range display OFF", "Menu", 15, "ID" ):ToAll()
  end

  return self
end

--- Sets by default the display of bearing information of missiles ON of OFF.
-- @param #MISSILETRAINER self
-- @param #boolean DetailsBearingOnOff true or false
-- @return #MISSILETRAINER self
function MISSILETRAINER:InitBearingOnOff( DetailsBearingOnOff )
  self:F( DetailsBearingOnOff )

  self.DetailsBearingOnOff = DetailsBearingOnOff
  if self.DetailsBearingOnOff == true then
    MESSAGE:New( "Bearing display OFF", "Menu", 15, "ID" ):ToAll()
  else
    MESSAGE:New( "Bearing display OFF", "Menu", 15, "ID" ):ToAll()
  end

  return self
end

-- Menu functions

function MISSILETRAINER._MenuMessages( MenuParameters )

  local self = MenuParameters.MenuSelf

  if MenuParameters.MessagesOnOff ~= nil then
    self:InitMessagesOnOff( MenuParameters.MessagesOnOff )
  end

  if MenuParameters.TrackingToAll ~= nil then
    self:InitTrackingToAll( MenuParameters.TrackingToAll )
  end

  if MenuParameters.TrackingOnOff ~= nil then
    self:InitTrackingOnOff( MenuParameters.TrackingOnOff )
  end

  if MenuParameters.AlertsToAll ~= nil then
    self:InitAlertsToAll( MenuParameters.AlertsToAll )
  end

  if MenuParameters.AlertsHitsOnOff ~= nil then
    self:InitAlertsHitsOnOff( MenuParameters.AlertsHitsOnOff )
  end

  if MenuParameters.AlertsLaunchesOnOff ~= nil then
    self:InitAlertsLaunchesOnOff( MenuParameters.AlertsLaunchesOnOff )
  end

  if MenuParameters.DetailsRangeOnOff ~= nil then
    self:InitRangeOnOff( MenuParameters.DetailsRangeOnOff )
  end

  if MenuParameters.DetailsBearingOnOff ~= nil then
    self:InitBearingOnOff( MenuParameters.DetailsBearingOnOff )
  end

  if MenuParameters.Distance ~= nil then
    self.Distance = MenuParameters.Distance
    MESSAGE:New( "Hit detection distance set to " .. self.Distance .. " meters", "Menu", 15, "ID" ):ToAll()
  end

end

--- Detects if an SA site was shot with an anti radiation missile. In this case, take evasive actions based on the skill level set within the ME.
-- @param #MISSILETRAINER self
-- @param Event#EVENTDATA Event
function MISSILETRAINER:_EventShot( Event )
  self:F( { Event } )

  local TrainerSourceDCSUnit = Event.IniDCSUnit
  local TrainerSourceDCSUnitName = Event.IniDCSUnitName
  local TrainerWeapon = Event.Weapon -- Identify the weapon fired
  local TrainerWeaponName = Event.WeaponName	-- return weapon type

  self:T( "Missile Launched = " .. TrainerWeaponName )

  local TrainerTargetDCSUnit = TrainerWeapon:getTarget() -- Identify target
  local TrainerTargetDCSUnitName = Unit.getName( TrainerTargetDCSUnit )
  local TrainerTargetSkill =  _DATABASE.Templates.Units[TrainerTargetDCSUnitName].Template.skill

  self:T(TrainerTargetDCSUnitName )

  local Client = self.DBClients[TrainerTargetDCSUnitName]
  if Client then

    local TrainerSourceUnit = UNIT:New(TrainerSourceDCSUnit)
    local TrainerTargetUnit = UNIT:New(TrainerTargetDCSUnit)

    if self.MessagesOnOff and self.AlertsLaunchesOnOff then

      local Message = MESSAGE:New(
        string.format( "%s launched a %s",
          TrainerSourceUnit:GetTypeName(),
          TrainerWeaponName
        ) .. self:_AddRange( Client, TrainerWeapon ) .. self:_AddBearing( Client, TrainerWeapon ),"Launch Alert", 5, "ID" )

      if self.AlertsToAll then
        Message:ToAll()
      else
        Message:ToClient( Client )
      end
    end

    local ClientID = Client:GetID()
    local MissileData = {}
    MissileData.TrainerSourceUnit = TrainerSourceUnit
    MissileData.TrainerWeapon = TrainerWeapon
    MissileData.TrainerTargetUnit = TrainerTargetUnit
    MissileData.TrainerWeaponTypeName = TrainerWeapon:getTypeName()
    MissileData.TrainerWeaponLaunched = true
    table.insert( self.TrackingMissiles[ClientID].MissileData, MissileData )
    --self:T( self.TrackingMissiles )
  end
end

function MISSILETRAINER:_AddRange( Client, TrainerWeapon )

  local RangeText = ""

  if self.DetailsRangeOnOff then

    local PositionMissile = TrainerWeapon:getPoint()
    local PositionTarget = Client:GetPositionVec3()

    local Range = ( ( PositionMissile.x - PositionTarget.x )^2 +
      ( PositionMissile.y - PositionTarget.y )^2 +
      ( PositionMissile.z - PositionTarget.z )^2
      ) ^ 0.5 / 1000

    RangeText = string.format( ", at %4.2fkm", Range )
  end

  return RangeText
end

function MISSILETRAINER:_AddBearing( Client, TrainerWeapon )

  local BearingText = ""

  if self.DetailsBearingOnOff then

    local PositionMissile = TrainerWeapon:getPoint()
    local PositionTarget = Client:GetPositionVec3()

    self:T2( { PositionTarget, PositionMissile })

    local DirectionVector = { x = PositionMissile.x - PositionTarget.x, y = PositionMissile.y - PositionTarget.y, z = PositionMissile.z - PositionTarget.z }
    local DirectionRadians = math.atan2( DirectionVector.z, DirectionVector.x )
    --DirectionRadians = DirectionRadians + routines.getNorthCorrection( PositionTarget )
    if DirectionRadians < 0 then
      DirectionRadians = DirectionRadians + 2 * math.pi
    end
    local DirectionDegrees = DirectionRadians * 180 / math.pi

    BearingText = string.format( ", %d degrees", DirectionDegrees )
  end

  return BearingText
end


---
-- @param #MISSILETRAINER self
function MISSILETRAINER:_TrackMissiles()
  self:F2()


  local ShowMessages = false
  if self.MessagesOnOff and self.MessageLastTime + 3 <= timer.getTime() then
    self.MessageLastTime = timer.getTime()
    ShowMessages = true
  end

  for ClientDataID, ClientData in pairs( self.TrackingMissiles ) do

    local Client = ClientData.Client
    self:T2( { Client:GetName() } )


    ClientData.MessageToClient = ""
    ClientData.MessageToAll = ""

    for TrackingDataID, TrackingData in pairs( self.TrackingMissiles ) do

      for MissileDataID, MissileData in pairs( TrackingData.MissileData ) do
        self:T3( MissileDataID )

        local TrainerSourceUnit = MissileData.TrainerSourceUnit
        local TrainerWeapon = MissileData.TrainerWeapon
        local TrainerTargetUnit = MissileData.TrainerTargetUnit
        local TrainerWeaponTypeName = MissileData.TrainerWeaponTypeName
        local TrainerWeaponLaunched = MissileData.TrainerWeaponLaunched

        if Client and Client:IsAlive() and TrainerSourceUnit and TrainerSourceUnit:IsAlive() and TrainerWeapon and TrainerWeapon:isExist() and TrainerTargetUnit and TrainerTargetUnit:IsAlive() then
          local PositionMissile = TrainerWeapon:getPosition().p
          local PositionTarget = Client:GetPositionVec3()

          local Distance = ( ( PositionMissile.x - PositionTarget.x )^2 +
            ( PositionMissile.y - PositionTarget.y )^2 +
            ( PositionMissile.z - PositionTarget.z )^2
            ) ^ 0.5 / 1000

          if Distance <= self.Distance then
            -- Hit alert
            TrainerWeapon:destroy()
            if self.MessagesOnOff and self.AlertsHitsOnOff then

              self:T( "killed" )

              local Message = MESSAGE:New(
                string.format( "%s launched by %s killed %s",
                  TrainerWeapon:getTypeName(),
                  TrainerSourceUnit:GetTypeName(),
                  TrainerTargetUnit:GetPlayerName()
                ),"Hit Alert", 15, "ID" )

              if self.AlertsToAll then
                Message:ToAll()
              else
                Message:ToClient( Client )
              end

              MissileData = nil
              table.remove( TrackingData.MissileData, MissileDataID )
              self:T(TrackingData.MissileData)
            end
          else
            if ShowMessages then
              local TrackingTo
              TrackingTo = string.format( "  -> %s",
                TrainerWeaponTypeName
              )

              if ClientDataID == TrackingDataID then
                if ClientData.MessageToClient == "" then
                  ClientData.MessageToClient = "Missiles to You:\n"
                end
                ClientData.MessageToClient = ClientData.MessageToClient .. TrackingTo .. self:_AddRange( ClientData.Client, TrainerWeapon ) .. self:_AddBearing( ClientData.Client, TrainerWeapon ) .. "\n"
              else
                if self.TrackingToAll then
                  if ClientData.MessageToAll == "" then
                    ClientData.MessageToAll = "Missiles to other Players:\n"
                  end
                  ClientData.MessageToAll = ClientData.MessageToAll .. TrackingTo .. self:_AddRange( ClientData.Client, TrainerWeapon ) .. self:_AddBearing( ClientData.Client, TrainerWeapon ) .. " ( " .. TrainerTargetUnit:GetPlayerName()  ..   " )\n"
                end
              end
            end
          end
        else
          if not ( TrainerWeapon and TrainerWeapon:isExist() ) then
            if self.MessagesOnOff and self.AlertsLaunchesOnOff then
              -- Weapon does not exist anymore. Delete from Table
              local Message = MESSAGE:New(
                string.format( "%s launched by %s self destructed!",
                  TrainerWeaponTypeName,
                  TrainerSourceUnit:GetTypeName()
                ),"Tracking", 5, "ID" )

              if self.AlertsToAll then
                Message:ToAll()
              else
                Message:ToClient( Client )
              end
            end
            MissileData = nil
            table.remove( TrackingData.MissileData, MissileDataID )
            self:T(TrackingData.MissileData)
          end
        end
      end
    end

    if self.MessagesOnOff and self.TrackingOnOff and ShowMessages then
      if ClientData.MessageToClient ~= "" or ClientData.MessageToAll ~= "" then
        local Message = MESSAGE:New( ClientData.MessageToClient .. ClientData.MessageToAll, "Tracking", 1, "ID" ):ToClient( Client )
      end
    end

  end

  return true
end