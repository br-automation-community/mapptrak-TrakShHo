(*********************************************************************************
 * Copyright: B&R Industrial Automation GmbH 
 * Author:    B&R CD - CPE 
 * Created:   January 20, 2021
 *
 * Description:
 * - Actions, which are needed for the function block "TSH_AsmReceiveShuttleAdd"
 *
 * Actions (Right click on the action name -> "Go to Implementation", to jump to the code):
 * - TSH_AsmReceive_CheckInputs
 * - TSH_AsmReceive_ProcessInit
 * - TSH_AsmReceive_CheckConfig
 * - TSH_AsmReceive_ProcessError
 * - TSH_AsmReceive_Process
 * - TSH_AsmReceive_ProcessCallFBs
 * - TSH_AsmReceive_CheckParameter
 * - TSH_AsmReceive_UpdateParameter
 * - TSH_AsmReceive_ResetInDisabled
 * - TSH_AsmReceive_ErrorReaction
 * - TSH_AsmReceive_ErrorReaction_AssemblyError
 * - TSH_AsmReceive_SimulateCommInterface
 * - TSH_AsmReceive_AutoPauseInit
 * - TSH_AsmReceive_AutoPauseMonitoring
 * - TSH_AsmReceive_Recovery
 * - TSH_AsmReceive_AbortCatch
 *********************************************************************************)

(* Check FUB specific inputs *)
ACTION TSH_AsmReceive_CheckInputs:
	(* Check common inputs before *)
	TSH_CheckCommonInputs;
	
	(* Just need to check, if there was no error before *)
	IF NOT(Error) THEN (* Just check if there was no error before *)
		(* Specific inputs of the function block *)
		IF (ADR(HandoverDataSend) = 0) THEN
			Active										:=	FALSE;
			Error										:=	TRUE;
			StatusID									:=	tshERR_NO_BUFFER_REF;
			Internal.LoggerEntry.LoggerMessage			:=	'INPUT - No data send buffer connected to the function block';
		ELSIF (HandoverDataReceiveAddress = 0) THEN
			Active										:=	FALSE;
			Error										:=	TRUE;
			StatusID									:=	tshERR_NO_BUFFER_REF;
			Internal.LoggerEntry.LoggerMessage			:=	'INPUT - No data receive buffer connected to the function block';
		ELSIF (HandoverDataReceiveSize = 0) THEN
			Active										:=	FALSE;
			Error										:=	TRUE;
			StatusID									:=	tshERR_BUFFER_WRONG_SIZE;
			Internal.LoggerEntry.LoggerMessage			:=	'INPUT - The data receive buffer has size 0';
		ELSIF (UserDataSize > HandoverDataReceiveSize) THEN
			Active										:=	FALSE;
			Error										:=	TRUE;
			StatusID									:=	tshERR_BUFFER_WRONG_SIZE;
			Internal.LoggerEntry.LoggerMessage			:=	'INPUT - The user data is bigger than the data send buffer';
		ELSIF (ADR(Parameter) = 0) THEN
			Active										:=	FALSE;
			Error										:=	TRUE;
			StatusID									:=	tshERR_NO_PARAMETER_REF;
			Internal.LoggerEntry.LoggerMessage			:=	'INPUT - No parameter structure connected to the function block';
		ELSE
			(* Copy data from inputs to internal structure and save adresses *)
			Internal.Communication.DataSendAddress		:=	ADR(HandoverDataSend);
			Internal.Communication.DataReceiveAddress	:=	HandoverDataReceiveAddress;
			Internal.Communication.DataReceiveSize		:=	HandoverDataReceiveSize;
			Internal.Communication.UserDataAddress		:=	UserDataAddress;
			Internal.Communication.UserDataSize			:=	UserDataSize;
			
			(* Give a warning to the logger, that no userdata will be transferred *)
			IF Internal.Communication.UserDataSize = 0 THEN
				Internal.LoggerEntry.OldStatusID		:=	StatusID;
				StatusID								:=	tshWRN_USERDATA;
				Internal.LoggerEntry.LoggerMessage		:=	'COMMUNICATION - No shuttle userdata will be communicated, as userdata size = 0';
				TSH_WriteLoggerEntry;
				StatusID								:=	Internal.LoggerEntry.OldStatusID;	(* Warning will not be shown on the output -> Display old StatusID (zero) *)
			END_IF
		END_IF
	END_IF
END_ACTION

(*################################################################################################################################################*)

(* Check FUB specific configuration parameter *)
ACTION TSH_AsmReceive_CheckConfig:
	(* Check common inputs before *)
	TSH_CheckCommonConfig;
	
	(* Check Movement configuration - only required for Receive *)
	IF NOT(Error) THEN
		IF (Internal.Configuration.Movement.Velocity <= 0.0) THEN	(* Velocity must be a positive value > 0 *)
			Active										:=	FALSE;
			Error										:=	TRUE;
			StatusID									:=	tshERR_CONFIG_VALUE;
			Internal.LoggerEntry.LoggerMessage			:=	'CONFIG - Velocity for handover and recovery movements is lower or equal to 0.0 m/s';				
		END_IF
		IF (Internal.Configuration.Movement.Velocity > tshVELOCITY_LIMIT) THEN	(* Velocity must be smaller than the system limit *)
			Active										:=	FALSE;
			Error										:=	TRUE;
			StatusID									:=	tshERR_CONFIG_VALUE;
			Internal.LoggerEntry.LoggerMessage			:=	'CONFIG - Velocity for handover and recovery movements is higher than allowed maximum of ';
			brsftoa(tshVELOCITY_LIMIT,ADR(Internal.LoggerEntry.ValueString));
			brsstrcat(ADR(Internal.LoggerEntry.LoggerMessage),ADR(Internal.LoggerEntry.ValueString));
			brsstrcat(ADR(Internal.LoggerEntry.LoggerMessage),ADR(' m/s'));				
		END_IF
		IF (Internal.Configuration.Movement.Acceleration <= 0.0) THEN	(* Acceleration must be a positive value > 0 *)
			Active										:=	FALSE;
			Error										:=	TRUE;
			StatusID									:=	tshERR_CONFIG_VALUE;
			Internal.LoggerEntry.LoggerMessage			:=	'CONFIG - Acceleration for handover and recovery movements is lower or equal to 0.0 m/s^2';				
		END_IF
		IF (Internal.Configuration.Movement.Acceleration > tshACCELERATION_LIMIT) THEN	(* Acceleration must be smaller than the system limit *)
			Active										:=	FALSE;
			Error										:=	TRUE;
			StatusID									:=	tshERR_CONFIG_VALUE;
			Internal.LoggerEntry.LoggerMessage			:=	'CONFIG - Acceleration for handover and recovery movements is higher than allowed maximum of ';
			brsftoa(tshACCELERATION_LIMIT,ADR(Internal.LoggerEntry.ValueString));
			brsstrcat(ADR(Internal.LoggerEntry.LoggerMessage),ADR(Internal.LoggerEntry.ValueString));
			brsstrcat(ADR(Internal.LoggerEntry.LoggerMessage),ADR(' m/s^2'));				
		END_IF
		IF (Internal.Configuration.Movement.Deceleration <= 0.0) THEN	(* Deceleration must be a positive value > 0 *)
			Active										:=	FALSE;
			Error										:=	TRUE;
			StatusID									:=	tshERR_CONFIG_VALUE;
			Internal.LoggerEntry.LoggerMessage			:=	'CONFIG - Deceleration for handover and recovery movements is lower or equal to 0.0 m/s^2';				
		END_IF
		IF (Internal.Configuration.Movement.Deceleration > tshDECELERATION_LIMIT) THEN	(* Deceleration must be smaller than the system limit *)
			Active										:=	FALSE;
			Error										:=	TRUE;
			StatusID									:=	tshERR_CONFIG_VALUE;
			Internal.LoggerEntry.LoggerMessage			:=	'CONFIG - Deceleration for handover and recovery movements is higher than allowed maximum of ';
			brsftoa(tshDECELERATION_LIMIT,ADR(Internal.LoggerEntry.ValueString));
			brsstrcat(ADR(Internal.LoggerEntry.LoggerMessage),ADR(Internal.LoggerEntry.ValueString));
			brsstrcat(ADR(Internal.LoggerEntry.LoggerMessage),ADR(' m/s^2'));
		END_IF
	END_IF
END_ACTION

(*################################################################################################################################################*)

(* Initialize the process (internal function blocks, etc. ) *)
ACTION TSH_AsmReceive_ProcessInit:
	Internal.Process.fbAsmReadStatus.Assembly									:=	ADR(Assembly);	
	
	Internal.Process.fbShReadInfo.Axis											:=	ADR(Internal.Process.ShuttleRef);
	
	Internal.Process.fbShCopyUserData.Axis										:=	ADR(Internal.Process.ShuttleRef);
	Internal.Process.fbShCopyUserData.DataAddress								:=	Internal.Communication.DataReceiveAddress + tshTO_RECEIVER_BUFFER_SIZE + 1;
	Internal.Process.fbShCopyUserData.DataSize									:=	Internal.Communication.UserDataSize;
	Internal.Process.fbShCopyUserData.Mode										:=	mcACPTRAK_USERDATA_SET;
	
	Internal.Process.fbSecGetShuttle.Sector										:=	ADR(Sector);
	Internal.Process.fbSecGetShuttle.Mode										:=	mcACPTRAK_SEARCH_BACKWARD;
	Internal.Process.fbSecGetShuttle.AdvancedParameters.StartPosition			:=	tshDISTANCE_SEG_END;
	Internal.Process.fbSecGetShuttle.AdvancedParameters.EndPosition				:=	Internal.ConfigCheck.SafetyZoneLength; 
	Internal.Process.fbSecGetShuttle.AdvancedParameters.SelectionMode			:=	mcACPTRAK_GET_SH_ALL;
	
	Internal.Process.fbSecReadInfo.Sector										:=	ADR(Sector);
	
	Internal.Process.fbShResize.Axis											:=	ADR(Internal.Process.ShuttleRef);
	Internal.Process.fbShResize.Command											:=	mcACPTRAK_RESIZE_DIMENSIONS;
	Internal.Process.fbShResize.ResizeParameter.Mode							:=	mcACPTRAK_RESIZE_AVOID_ERRORSTOP;
	
	(* Configure shuttle add with catch mode - shuttle is caught at specified position *)
	Internal.Process.fbSecAddShuttle.Sector										:=	ADR(Sector);
	Internal.Process.fbSecAddShuttle.Orientation								:=	mcDIR_POSITIVE;
	Internal.Process.fbSecAddShuttle.Position									:=	Internal.Parameter.CatchPosition;
	Internal.Process.fbSecAddShuttle.AdvancedParameters.MoveCmd					:=	mcACPTRAK_MOV_CMD_ELASTICMOVEVEL;
	Internal.Process.fbSecAddShuttle.AdvancedParameters.Mode					:=	mcACPTRAK_ADD_CATCH;
	
	Internal.Process.fbRoutedMoveAbs.Axis										:= ADR(Internal.Process.ShuttleRef);
	Internal.Process.fbRoutedMoveAbs.Sector										:= ADR(Internal.Parameter.Target.Sector);
	Internal.Process.fbRoutedMoveAbs.Position									:= Internal.Parameter.Target.Position;
	Internal.Process.fbRoutedMoveAbs.Velocity									:= Internal.Parameter.Target.Velocity;
	Internal.Process.fbRoutedMoveAbs.Acceleration								:= Internal.Parameter.Target.Acceleration;
	Internal.Process.fbRoutedMoveAbs.Deceleration								:= Internal.Parameter.Target.Deceleration;
	Internal.Process.fbRoutedMoveAbs.AdvancedParameters.StartDirection			:= Internal.Parameter.Target.StartDirection;
	Internal.Process.fbRoutedMoveAbs.AdvancedParameters.EndDirection			:= Internal.Parameter.Target.EndDirection;
	Internal.Process.fbRoutedMoveAbs.AdvancedParameters.ShuttleOrientation		:= Internal.Parameter.Target.ShuttleOrientation;
	
	(* Initialize the recovery function blocks here as well *)
	Internal.Recovery.fbReset.Axis												:=	ADR(Internal.Process.ShuttleRef);
	
	Internal.Recovery.fbReadStatus.Axis											:=	ADR(Internal.Process.ShuttleRef);
	
	Internal.Recovery.fbSecGetShuttle.Sector									:=	ADR(Sector);
	
	Internal.Recovery.fbRoutedMoveAbs.Axis										:=	ADR(Internal.Process.ShuttleRef);
	Internal.Recovery.fbRoutedMoveAbs.Acceleration								:=	Internal.Configuration.Movement.Acceleration;
	Internal.Recovery.fbRoutedMoveAbs.Deceleration								:=	Internal.Configuration.Movement.Deceleration;
	Internal.Recovery.fbRoutedMoveAbs.Velocity									:=	Internal.Configuration.Movement.Velocity;
	Internal.Recovery.fbRoutedMoveAbs.Sector									:=	ADR(Sector);
	(* Send it to the middle of Zone "Receive" to be sure it's far enough away from Zone "Handover" and the parallel area *)
	Internal.Recovery.fbRoutedMoveAbs.Position									:=	Internal.ConfigCheck.SafetyZoneLength + tshRECOVERY_DISTANCE_TOLERANCE; 
	Internal.Recovery.fbRoutedMoveAbs.BufferMode								:=	mcABORTING;
	Internal.Recovery.fbRoutedMoveAbs.AdvancedParameters.StartDirection			:=	mcDIR_UNDEFINED;
	Internal.Recovery.fbRoutedMoveAbs.AdvancedParameters.EndDirection			:=	mcDIR_UNDEFINED;
	Internal.Recovery.fbRoutedMoveAbs.AdvancedParameters.ShuttleOrientation		:=	mcDIR_UNDEFINED;
	
	Internal.Recovery.fbAsmDeleteShuttle.Assembly								:=	ADR(Assembly);
	Internal.Recovery.fbAsmDeleteShuttle.Axis									:=	ADR(Internal.Process.ShuttleRef);
	Internal.Recovery.fbAsmDeleteShuttle.Command								:=	mcACPTRAK_SH_DELETE_SPECIFIC;
	
	Internal.Recovery.fbTimer.PT												:=	tshRECOVERY_CHECK_TIME;
	Internal.Recovery.fbErrorCheckTimer.PT										:=	tshERROR_CHECK_TIME;
END_ACTION

(*################################################################################################################################################*)

(* Resets all execute and enable inputs of process relevant function blocks, which are called cyclically (except barrier) *)
ACTION TSH_AsmReceive_ProcessError:	
	Internal.Process.fbShReadInfo.Enable			:=	FALSE;
	Internal.Process.fbSecAddShuttle.Execute		:=	FALSE;
	Internal.Process.fbShResize.Execute				:=	FALSE;
		
	(* Reset the counter from response check *)				
	Internal.ResponseTimeoutCheck.WaitedCycles		:=	0;
	
	(* Reset the initialization function blocks here as well *)
	Internal.LoggerEntry.fbCreateUsrLogBook.Execute	:=	FALSE;
	
	(* Reset the recovery function blocks here as well *)
	Internal.Recovery.fbReset.Execute				:=	FALSE;
	Internal.Recovery.fbReadStatus.Enable			:=	FALSE;
	Internal.Recovery.fbSecGetShuttle.Enable		:=	FALSE;
	Internal.Recovery.fbSecGetShuttle.Next			:=	FALSE;
	Internal.Recovery.fbRoutedMoveAbs.Execute		:=	FALSE;
	Internal.Recovery.fbAsmDeleteShuttle.Execute	:=	FALSE;
	Internal.Recovery.fbTimer.IN					:=	FALSE;
	Internal.Recovery.fbErrorCheckTimer.IN			:=	FALSE;
END_ACTION

(*################################################################################################################################################*)

(* Handles the core process functionality of the shuttle handover *)
ACTION TSH_AsmReceive_Process:
	
	(* Catch mode runs permanently outside ArSim *)
	Internal.Process.fbSecAddShuttle.AdvancedParameters.Acceleration			:=	Internal.Parameter.Target.Acceleration;
	Internal.Process.fbSecAddShuttle.AdvancedParameters.Deceleration			:=	Internal.Parameter.Target.Deceleration;
	Internal.Process.fbSecAddShuttle.AdvancedParameters.Velocity				:=	Internal.Parameter.Target.Velocity;
	Internal.Process.fbSecAddShuttle.Execute									:=	NOT(Internal.Simulation.ArSim) OR Internal.Communication.DataReceive.ProcessCommands.0;
	
	CASE Internal.Process.Step OF
		tshAR_WAIT_FOR_CATCH:
			(* Wait for a shuttle to be caught at the CatchPosition *)
			IF (Internal.Process.fbSecAddShuttle.Active) THEN
				Internal.Process.ShuttleRef										:= Internal.Process.fbSecAddShuttle.Axis;
				Internal.Process.fbSecAddShuttle.Execute						:= FALSE;
				(* A shuttle was caught successfully *)
				Internal.Communication.DataSend.ProcessStatus.8					:=	TRUE;				
				(* Increase handover count by one *)
				Internal.Info.HandoverCount										:=	Internal.Info.HandoverCount + 1;
				(* Get the shuttle reference and ID for further internal use *)
				Internal.Process.ShuttleRef										:=	Internal.Process.fbSecAddShuttle.Axis;
				Internal.Process.ShuttleID										:=	Internal.Process.fbSecAddShuttle.ID;
				(* Set info output, which shuttle was added *)
				Internal.Info.Shuttle.Valid										:=	TRUE;
				Internal.Info.Shuttle.ShuttleRef								:=	Internal.Process.ShuttleRef;
				Internal.Info.Shuttle.ShuttleID									:=	Internal.Process.ShuttleID;
				Internal.Info.Shuttle.Action									:=	tshSHUTTLE_ACTION_ADDED;
				(* Copy userdata to the shuttle *)
				TSH_ShuttleCopyUserData;
				(* Change the step *)					
				Internal.Process.Step											:=	tshAR_MOVE_SHUTTLE;
			ELSIF (Internal.Process.fbSecAddShuttle.Error) THEN
				(* Display an error *)
				Active															:=	FALSE;
				Error															:=	TRUE;
				StatusID														:=	tshERR_INTERNAL;
				Internal.LoggerEntry.LoggerMessage								:=	'HANDOVER - Catching a shuttle was not successful';		
				TSH_WriteLoggerEntry;	
				
				(* Set diagnostic info output *)
				Internal.Info.Diagnosis.Valid									:=	TRUE;
				Internal.Info.Diagnosis.Functionblock							:=	'MC_BR_SecAddShuttle_AcpTrak';
				Internal.Info.Diagnosis.StatusID       							:=	Internal.Process.fbSecAddShuttle.ErrorID;
			END_IF
		
		(* Move the shuttle to the given end position *)
		tshAR_MOVE_SHUTTLE:
			Internal.Process.fbRoutedMoveAbs.Execute							:= TRUE;
			IF Internal.Process.fbRoutedMoveAbs.Active AND NOT(Internal.Process.RoutedMoveAbsActiveOld) THEN
				Internal.Process.fbRoutedMoveAbs.Execute						:= FALSE;			
				(* Change the step *)					
				Internal.Process.Step											:=	tshAR_WAIT_CONFIRMATION;
			ELSIF (Internal.Process.fbRoutedMoveAbs.Error) THEN
				(* Display an error *)
				Active															:=	FALSE;
				Error															:=	TRUE;
				StatusID														:=	tshERR_INTERNAL;
				Internal.LoggerEntry.LoggerMessage								:=	'HANDOVER - Routing a shuttle was not successful';		
				TSH_WriteLoggerEntry;	
				
				(* Set diagnostic info output *)
				Internal.Info.Diagnosis.Valid									:=	TRUE;
				Internal.Info.Diagnosis.Functionblock							:=	'MC_BR_RoutedMoveAbs_AcpTrak';
				Internal.Info.Diagnosis.StatusID       							:=	Internal.Process.fbRoutedMoveAbs.ErrorID;
			END_IF;
			
			
		tshAR_WAIT_CONFIRMATION:			
			Internal.ResponseTimeoutCheck.Response								:=	Internal.Communication.DataReceive.ProcessStatus.8; 	(* Shuttle was deleted successfully *)
			TSH_CheckResponseTimeout;
			
			IF (Internal.ResponseTimeoutCheck.Responded) THEN	(* Response came in time *)
				(* Reset status *)
				Internal.Communication.DataSend.ProcessStatus.8					:=	FALSE;
				(* Movement already started by SecAddShuttleWithMovement - check if resize is needed *)
				IF (Internal.Parameter.ShuttleSize.EnableResize = tshSHUTTLE_RESIZE_ENABLE) THEN
					(* Resize the shuttle to the needed size *)
					Internal.Process.fbShResize.ResizeParameter.ExtentToFront	:=	Internal.Parameter.ShuttleSize.ExtendToFront;
					Internal.Process.fbShResize.ResizeParameter.ExtentToBack	:=	Internal.Parameter.ShuttleSize.ExtendToBack;					
					Internal.Process.fbShResize.ResizeParameter.Width			:=	Internal.Parameter.ShuttleSize.Width;	
					Internal.Process.fbShResize.Execute							:=	TRUE;	
					(* Change step *)
					Internal.Process.Step										:=	tshAR_RESIZE_SHUTTLE;
				ELSE
					(* Handover procedure done successfully *)
					Internal.Process.Step										:=	tshAR_WAIT_FOR_CATCH;
				END_IF
			ELSIF (Error) THEN
				(* In case of an error reset the process step*)
				Internal.Process.Step											:=	tshAR_WAIT_FOR_CATCH;
			END_IF		
				
		tshAR_RESIZE_SHUTTLE:
			IF (Internal.Process.fbShResize.Done) THEN					
				(* Reset the function block *)
				Internal.Process.fbShResize.Execute								:=	FALSE;
				(* Handover procedure done successfully - Movement mode *)
				Internal.Process.Step											:=	tshAR_WAIT_FOR_CATCH;
			ELSIF (Internal.Process.fbShResize.Error) THEN
				(* Display an error *)
				Active															:=	FALSE;
				Error															:=	TRUE;
				StatusID														:=	tshERR_INTERNAL;
				Internal.LoggerEntry.LoggerMessage								:=	'HANDOVER - Resizing the shuttle is not possible (Details see motion logger)';		
				TSH_WriteLoggerEntry;
				
				(* Set diagnostic info output *)
				Internal.Info.Diagnosis.Valid									:=	TRUE;
				Internal.Info.Diagnosis.Functionblock							:=	'MC_BR_ShResize_AcpTrak';
				Internal.Info.Diagnosis.StatusID       							:=	Internal.Process.fbShResize.ErrorID;
			
				(* Reset the function block *)
				Internal.Process.fbShResize.Execute								:=	FALSE;
				(* Change step *)
				Internal.Process.Step											:=	tshAR_WAIT_FOR_CATCH;
			END_IF			
			
	END_CASE	
END_ACTION

(*################################################################################################################################################*)

(* Call all function blocks, which need to be called cyclically *)
ACTION TSH_AsmReceive_ProcessCallFBs:
	Internal.Process.fbAsmReadStatus();
	Internal.Process.fbShReadInfo();
	Internal.Process.fbSecAddShuttle();
	Internal.Process.fbSecReadInfo();
	Internal.Process.fbSecGetShuttle();
	Internal.Process.fbShResize();
	
	Internal.Process.RoutedMoveAbsActiveOld	:= Internal.Process.fbRoutedMoveAbs.Active;
	Internal.Process.fbRoutedMoveAbs();
	
	(* Call initialization function blocks here as well *)
	Internal.LoggerEntry.fbCreateUsrLogBook();
	
	(* Call the recovery function blocks here as well *)
	Internal.Recovery.fbReset();
	Internal.Recovery.fbReadStatus();
	Internal.Recovery.fbSecGetShuttle();
	Internal.Recovery.fbRoutedMoveAbs();
	Internal.Recovery.fbAsmDeleteShuttle();
	Internal.Recovery.fbTimer();
	Internal.Recovery.fbErrorCheckTimer();
END_ACTION

(*################################################################################################################################################*)					

(* Check FUB specific parameter *)
ACTION TSH_AsmReceive_CheckParameter:
(* Just need to check, if there was no error before *)
	IF NOT(Error) AND (ADR(Parameter) <> 0) THEN
		(* Check Parameter values before copying them to the internal structure *)	
		IF (Parameter.AutoPause.EnableHandoverAutoPause < tshHANDOVER_AUTO_PAUSE_DISABLE) OR (Parameter.AutoPause.EnableHandoverAutoPause > tshHANDOVER_AUTO_PAUSE_ENABLE) THEN
			Active										:=	FALSE;
			Error										:=	TRUE;
			StatusID									:=	tshERR_PARAMETER_VALUE;
			Internal.LoggerEntry.LoggerMessage			:=	'PARAMETER - EnableHandoverAutoPause has an unknown value';
		END_IF	
		IF (Parameter.ShuttleSize.EnableResize < tshSHUTTLE_RESIZE_DISABLE OR Parameter.ShuttleSize.EnableResize > tshSHUTTLE_RESIZE_ENABLE) THEN
			Active										:=	FALSE;
			Error										:=	TRUE;
			StatusID									:=	tshERR_PARAMETER_VALUE;
			Internal.LoggerEntry.LoggerMessage			:=	'PARAMETER - EnableResize has an unknown value';
		END_IF
		IF (Parameter.ShuttleSize.ExtendToBack <= 0.0) THEN
			Active										:=	FALSE;
			Error										:=	TRUE;
			StatusID									:=	tshERR_PARAMETER_VALUE;
			Internal.LoggerEntry.LoggerMessage			:=	'PARAMETER - ExtendToBack is smaller than 0.0 m';
		END_IF
		IF (Parameter.ShuttleSize.ExtendToFront <= 0.0) THEN
			Active										:=	FALSE;
			Error										:=	TRUE;
			StatusID									:=	tshERR_PARAMETER_VALUE;
			Internal.LoggerEntry.LoggerMessage			:=	'PARAMETER - ExtendToFront is smaller than 0.0 m';
		END_IF
		IF (Parameter.ShuttleSize.Width <= 0.0) THEN
			Active										:=	FALSE;
			Error										:=	TRUE;
			StatusID									:=	tshERR_PARAMETER_VALUE;
			Internal.LoggerEntry.LoggerMessage			:=	'PARAMETER - Shuttle width is smaller than 0.0 m';
		END_IF
		IF (Parameter.Target.Sector.controlif = 0) THEN
			Active										:=	FALSE;
			Error										:=	TRUE;
			StatusID									:=	tshERR_PARAMETER_VALUE;
			Internal.LoggerEntry.LoggerMessage			:=	'PARAMETER - No target sector set';
		END_IF
		IF (Parameter.Target.Acceleration <= 0.0) THEN
			Active										:=	FALSE;
			Error										:=	TRUE;
			StatusID									:=	tshERR_PARAMETER_VALUE;
			Internal.LoggerEntry.LoggerMessage			:=	'PARAMETER - Acceleration is smaller than 0.0 m/s�';
		END_IF
		IF (Parameter.Target.Deceleration <= 0.0) THEN
			Active										:=	FALSE;
			Error										:=	TRUE;
			StatusID									:=	tshERR_PARAMETER_VALUE;
			Internal.LoggerEntry.LoggerMessage			:=	'PARAMETER - Deceleration is smaller than 0.0 m/s�';
		END_IF
		IF (Parameter.Target.Velocity <= 0.0) THEN
			Active										:=	FALSE;
			Error										:=	TRUE;
			StatusID									:=	tshERR_PARAMETER_VALUE;
			Internal.LoggerEntry.LoggerMessage			:=	'PARAMETER - Velocity is smaller than 0.0 m/s';
		END_IF
		IF (Parameter.Target.Position < 0.0) THEN
			Active										:=	FALSE;
			Error										:=	TRUE;
			StatusID									:=	tshERR_PARAMETER_VALUE;
			Internal.LoggerEntry.LoggerMessage			:=	'PARAMETER - Target position is smaller than 0.0 m';
		END_IF
		
		(* Calculate dynamic SafetyZoneLength: braking distance * safety factor + shuttle length *)
		(* Braking distance = v� / (2 * a) *)
		Internal.ConfigCheck.SafetyZoneLength := (Parameter.Target.Velocity * Parameter.Target.Velocity) / (2.0 * Parameter.Target.Deceleration) * tshHANDOVER_ZONE_SAFETY_FACTOR + Parameter.ShuttleSize.ExtendToFront + Parameter.ShuttleSize.ExtendToBack;
		
		IF (Internal.ConfigCheck.SectorLength < Internal.ConfigCheck.SafetyZoneLength) THEN
			Active										:=	FALSE;
			Error										:=	TRUE;
			StatusID									:=	tshERR_PARAMETER_VALUE;
			Internal.LoggerEntry.LoggerMessage			:=	'PARAMETER - Sector "';
			IF (Internal.ConfigCheck.SectorName <> '') THEN
				brsstrcat(ADR(Internal.LoggerEntry.LoggerMessage),ADR(Internal.ConfigCheck.SectorName));
			ELSE
				brsstrcat(ADR(Internal.LoggerEntry.LoggerMessage),ADR('Receive'));
			END_IF
			brsstrcat(ADR(Internal.LoggerEntry.LoggerMessage),ADR('" is too short for safe braking distance. Reduce velocity or increase deceleration'));
		END_IF
		IF NOT(Error) THEN
			(* Copy parameter to internal structure *)
			brsmemcpy(ADR(Internal.Parameter),ADR(Parameter),SIZEOF(Internal.Parameter));
			(* Calculate the right number of shuttles for auto pause based on the parameter *)
			TSH_AsmReceive_AutoPauseInit;
		END_IF
	END_IF
END_ACTION

(*################################################################################################################################################*)

(* Action to update the internal parameter structure *)
ACTION TSH_AsmReceive_UpdateParameter:
	(* Save the old outputs, to reset them to the right value *)
	Internal.ParCheck.OldActive						:=	Active;
	Internal.ParCheck.OldError						:=	Error;
	(* Save all status IDs except the one, which is set inside the action *)
	IF (StatusID <> tshERR_PARAMETER_VALUE) THEN		
		Internal.ParCheck.OldStatusID				:=	StatusID;
	END_IF
	
	(* When input "Update" is set and the action wasn't performed yet *)
	IF (Update) AND NOT(Internal.ParCheck.ParCheckDone) AND (Internal.State <> tshSTATE_INIT) THEN		
		(* For the check, error must be false *)
		Error										:=	FALSE;
		(* Check the parameter *)
		TSH_AsmReceive_CheckParameter;
		
		(* Parameter check is done *)
		Internal.ParCheck.ParCheckDone				:=	TRUE;
			
		IF NOT(Error) THEN	
			(* Update done successful *)
			UpdateDone	:=	TRUE;
			
			(* Give information, that the update was successful *)
			IF (Internal.Configuration.LoggingMode >= tshLOGGING_ADVANCED) THEN
				Internal.LoggerEntry.OldStatusID	:=	StatusID;
				StatusID							:=	tshINFO_INTERNAL;
				(* Enter the compensated position *)
				Internal.LoggerEntry.LoggerMessage	:=	'PARAMETER - The parameter have been updated successfully';
				TSH_WriteLoggerEntry;		
				StatusID							:=	Internal.LoggerEntry.OldStatusID;	(* Info will not be shown on the output -> Display old StatusID (zero) *)
			END_IF
		END_IF
		
		(* Update values here if needed *)
		(* Recalculate SafetyZoneLength with updated parameters *)
		Internal.ConfigCheck.SafetyZoneLength := (Internal.Parameter.Target.Velocity * Internal.Parameter.Target.Velocity) / (2.0 * Internal.Parameter.Target.Deceleration) * tshHANDOVER_ZONE_SAFETY_FACTOR + Internal.Parameter.ShuttleSize.ExtendToFront + Internal.Parameter.ShuttleSize.ExtendToBack;
		Internal.Recovery.fbRoutedMoveAbs.Position	:=	Internal.ConfigCheck.SafetyZoneLength + tshRECOVERY_DISTANCE_TOLERANCE;
		Internal.Process.fbSecGetShuttle.AdvancedParameters.EndPosition	:=	Internal.ConfigCheck.SafetyZoneLength; 
		
		(* Leave the error and active output in their old state*)
		Error										:=	Internal.ParCheck.OldError;
		Active										:=	Internal.ParCheck.OldActive;
		
		(* "ELSIF" is entered once after disabling the input *)
	ELSIF NOT(Update) AND (Internal.ParCheck.ParCheckDone) THEN
		(* Reset the internal flag *)
		Internal.ParCheck.ParCheckDone				:=	FALSE;
		
		(* Reset the output and set the old status ID (Active and Error haven't been changed) *)
		UpdateDone									:=	FALSE;
		StatusID									:=	Internal.ParCheck.OldStatusID;
	END_IF
END_ACTION

(*################################################################################################################################################*)

(* This action resets all function blocks, which do need more than 1 cycle *)
ACTION TSH_AsmReceive_ResetInDisabled:
	(* Disable all function blocks *)	
	Internal.Process.fbAsmReadStatus.Enable			:=	FALSE;
	Internal.Process.fbShReadInfo.Enable			:=	FALSE;
	Internal.Process.fbSecAddShuttle.Execute		:=	FALSE;
	Internal.Process.fbSecReadInfo.Enable			:=	FALSE;
	Internal.Process.fbSecGetShuttle.Enable			:=	FALSE;	
	Internal.Process.fbShResize.Execute				:=	FALSE;
	Internal.Process.fbRoutedMoveAbs.Execute		:=  FALSE;
	
	(* Reset the recovery function blocks here as well *)
	Internal.Recovery.fbReset.Execute				:=	FALSE;
	Internal.Recovery.fbReadStatus.Enable			:=	FALSE;
	Internal.Recovery.fbSecGetShuttle.Enable		:=	FALSE;
	Internal.Recovery.fbSecGetShuttle.Next			:=	FALSE;
	Internal.Recovery.fbRoutedMoveAbs.Execute		:=	FALSE;
	Internal.Recovery.fbAsmDeleteShuttle.Execute	:=	FALSE;
	Internal.Recovery.fbSecStop.Execute				:=	FALSE;
	Internal.Recovery.fbTimer.IN					:=	FALSE;
	Internal.Recovery.fbErrorCheckTimer.IN			:=	FALSE;
	
	(* Call the function blocks *)
	TSH_AsmReceive_ProcessCallFBs;
END_ACTION

(*################################################################################################################################################*)

(* Chech for errors in the handover and react on them *)
ACTION TSH_AsmReceive_ErrorReaction:
	(* Reset the error detected flag. If an error is still present, it will be set to true again. Is used for the timer *)	
	Internal.ErrorCheck.ErrorDetected							:=	FALSE;
	
	(* Check always (as soon as communication is valid), if the Assembly Send is not ready *)
	IF NOT(Internal.Communication.DataReceive.AssemblyStatus.1) AND (Internal.State > tshSTATE_WAIT_COMMUNICATION) THEN		
		(* Log information about the error, which was detected *)
		IF (Internal.Configuration.LoggingMode = tshLOGGING_DEBUGGING) AND NOT(Internal.ErrorCheck.ErrorDetectedOld) THEN
			Internal.LoggerEntry.OldStatusID					:=	StatusID;
			StatusID											:=	tshWRN_INTERNAL;
			Internal.LoggerEntry.LoggerMessage					:=	'ERROR DETECTION - "Assembly Send" is not ready';
			TSH_WriteLoggerEntry;		
			StatusID											:=	Internal.LoggerEntry.OldStatusID;	(* the "old" error ID should be displayed *)
		END_IF
		(*Reset the string and then set the core logger message for this error *)
		brsmemset(ADR(Internal.LoggerEntry.LoggerMessage),0,SIZEOF(Internal.LoggerEntry.LoggerMessage));
		Internal.LoggerEntry.LoggerMessage						:=	'HANDOVER - The handover is stopped as the "Assembly Send" is not ready';
		(* Use the common assembly error reaction *)
		TSH_AsmReceive_ErrorReaction_AssemblyError;
	END_IF
	
	(* Check always (as soon as communication is valid), if the Assembly Receive is not ready *)
	IF NOT(Internal.Process.fbAsmReadStatus.AssemblyReady) AND (Internal.State > tshSTATE_WAIT_COMMUNICATION) THEN		
		(* Log information about the error, which was detected *)
		IF (Internal.Configuration.LoggingMode = tshLOGGING_DEBUGGING) AND NOT(Internal.ErrorCheck.ErrorDetectedOld) THEN
			Internal.LoggerEntry.OldStatusID					:=	StatusID;
			StatusID											:=	tshWRN_INTERNAL;
			Internal.LoggerEntry.LoggerMessage					:=	'ERROR DETECTION - "Assembly Receive" is not ready';
			TSH_WriteLoggerEntry;		
			StatusID											:=	Internal.LoggerEntry.OldStatusID;	(* the "old" error ID should be displayed *)
		END_IF
		(*Reset the string and then set the core logger message for this error *)
		brsmemset(ADR(Internal.LoggerEntry.LoggerMessage),0,SIZEOF(Internal.LoggerEntry.LoggerMessage));
		Internal.LoggerEntry.LoggerMessage						:=	'HANDOVER - The handover is stopped as the "Assembly Receive" is not ready';
		(* Use the common assembly error reaction *)
		TSH_AsmReceive_ErrorReaction_AssemblyError;
	END_IF
	
	(* Check if the Function block Send is on hold, if the Function block Receive is in run, on hold or in error *)
	IF (Internal.Communication.DataReceive.ProcessStatus.6) AND (Internal.State > tshSTATE_RECOVERY) THEN
		(* If auto restart is active, suppress this error reaction *)
		IF NOT(Internal.Recovery.AutoRestartActive) THEN
			(* Log information about the error, which was detected *)
			IF (Internal.Configuration.LoggingMode = tshLOGGING_DEBUGGING) AND NOT(Internal.ErrorCheck.ErrorDetectedOld) THEN
				Internal.LoggerEntry.OldStatusID				:=	StatusID;
				StatusID										:=	tshWRN_INTERNAL;
				Internal.LoggerEntry.LoggerMessage				:=	'ERROR DETECTION - "Function block Send" is in on hold';
				TSH_WriteLoggerEntry;		
				StatusID										:=	Internal.LoggerEntry.OldStatusID;	(* the "old" error ID should be displayed *)
			END_IF
			(*Reset the string and then set the core logger message for this error *)
			brsmemset(ADR(Internal.LoggerEntry.LoggerMessage),0,SIZEOF(Internal.LoggerEntry.LoggerMessage));
			Internal.LoggerEntry.LoggerMessage					:=	'HANDOVER - The handover is stopped as the "Function block Send" is on hold';
			(* Use the common assembly error reaction *)
			TSH_AsmReceive_ErrorReaction_AssemblyError;
		END_IF
		(* Reset the timer *)
		Internal.ErrorCheck.fbTimerAutoRestart.IN				:=	FALSE;
		Internal.ErrorCheck.fbTimerAutoRestart();
	ELSE
		(* Start the timer *)
		Internal.ErrorCheck.fbTimerAutoRestart.IN				:=	(Internal.State = tshSTATE_RUNNING);
		Internal.ErrorCheck.fbTimerAutoRestart.PT				:=	tshERROR_CHECK_TIME;
		Internal.ErrorCheck.fbTimerAutoRestart();
		(* If this error isn't present anymore, stop the auto restart *)
		IF (Internal.ErrorCheck.fbTimerAutoRestart.Q) THEN
			Internal.Recovery.AutoRestartActive					:=	FALSE;
		END_IF
	END_IF
	
	(* Check if the Function block Send is in error, if the Function block Receive is in run, on hold or in error *)
	IF (Internal.Communication.DataReceive.ProcessStatus.7) AND (Internal.State > tshSTATE_RECOVERY) THEN		
		(* Log information about the error, which was detected *)
		IF (Internal.Configuration.LoggingMode = tshLOGGING_DEBUGGING) AND NOT(Internal.ErrorCheck.ErrorDetectedOld) THEN
			Internal.LoggerEntry.OldStatusID					:=	StatusID;
			StatusID											:=	tshWRN_INTERNAL;
			Internal.LoggerEntry.LoggerMessage					:=	'ERROR DETECTION - "Function block Send" is in error';
			TSH_WriteLoggerEntry;		
			StatusID											:=	Internal.LoggerEntry.OldStatusID;	(* the "old" error ID should be displayed *)
		END_IF
		(*Reset the string and then set the core logger message for this error *)
		brsmemset(ADR(Internal.LoggerEntry.LoggerMessage),0,SIZEOF(Internal.LoggerEntry.LoggerMessage));
		Internal.LoggerEntry.LoggerMessage						:=	'HANDOVER - The handover is stopped as the "Function block Send" is in error';
		(* Use the common assembly error reaction *)
		TSH_AsmReceive_ErrorReaction_AssemblyError;
	END_IF	
	
	(* Reset the timer every cycle, so when the error is gone, the input is false *)
	Internal.Recovery.fbErrorCheckTimer.IN						:=	FALSE;
	(* Check if the Function block Receive is in error, if the Function block send recovery *)
	IF (Internal.Communication.DataReceive.ProcessStatus.7) AND (Internal.State = tshSTATE_RECOVERY) THEN
		Internal.Recovery.fbErrorCheckTimer.IN					:=	Internal.Info.Recovery.RecoveryActive OR RecoveryDone;	(* When the recovery is active, it was started on both sides *)
		(* Log information about the error, which was detected *)
		IF (Internal.Configuration.LoggingMode = tshLOGGING_DEBUGGING) AND (Internal.Recovery.fbErrorCheckTimer.Q) AND NOT(Internal.ErrorCheck.ErrorDetectedOld) THEN
			Internal.LoggerEntry.OldStatusID					:=	StatusID;
			StatusID											:=	tshWRN_INTERNAL;
			Internal.LoggerEntry.LoggerMessage					:=	'ERROR DETECTION - "Function block Send" is in error during Recovery';
			TSH_WriteLoggerEntry;		
			StatusID											:=	Internal.LoggerEntry.OldStatusID;	(* the "old" error ID should be displayed *)
		END_IF
		(* React on the detected error *)
		IF (Internal.Recovery.fbErrorCheckTimer.Q) THEN
			(* Set the error detected flag *)
			Internal.ErrorCheck.ErrorDetected					:=	TRUE;
			(* Reset the handover ready flag *)		
			HandoverReady										:=	FALSE;
			(* Set the recovery needed flag *)
			Internal.Recovery.RecoveryNeeded					:=	TRUE;
			(* Reset the timer input *)
			Internal.Recovery.fbErrorCheckTimer.IN				:=	FALSE;
		END_IF
	END_IF
	
	(* Check always (as soon as communication is valid), if the Function block Send is disabled *)
	IF NOT(Internal.Communication.DataReceive.ProcessStatus.0) AND (Internal.State > tshSTATE_WAIT_COMMUNICATION) THEN		
		(* Log information about the error, which was detected *)
		IF (Internal.Configuration.LoggingMode = tshLOGGING_DEBUGGING) AND NOT(Internal.ErrorCheck.ErrorDetectedOld) THEN
			Internal.LoggerEntry.OldStatusID					:=	StatusID;
			StatusID											:=	tshWRN_INTERNAL;
			Internal.LoggerEntry.LoggerMessage					:=	'ERROR DETECTION - "Function block Send" is disabled"';
			TSH_WriteLoggerEntry;		
			StatusID											:=	Internal.LoggerEntry.OldStatusID;	(* the "old" error ID should be displayed *)
		END_IF
		(*Reset the string and then set the core logger message for this error *)
		brsmemset(ADR(Internal.LoggerEntry.LoggerMessage),0,SIZEOF(Internal.LoggerEntry.LoggerMessage));
		Internal.LoggerEntry.LoggerMessage						:=	'HANDOVER - The handover is stopped as the "Function block Send" is disabled';
		(* Use the common assembly error reaction *)
		TSH_AsmReceive_ErrorReaction_AssemblyError;
	END_IF
	
	(* Check for shuttle errors on Assembly Send, when handover is running *)
	IF (Internal.State = tshSTATE_RUNNING) THEN
		(* If there is an errorstop in- or outside the handover zone *)
		IF (Internal.Communication.DataReceive.ProcessStatus.12) THEN
			(* Set the error detected flag *)
			Internal.ErrorCheck.ErrorDetected					:=	TRUE;
			(* Reset the handover ready flag *)		
			HandoverReady										:=	FALSE;
			(* Log information about the error, which was detected *)
			IF (Internal.Configuration.LoggingMode = tshLOGGING_DEBUGGING) AND NOT(Internal.ErrorCheck.ErrorDetectedOld) THEN
				Internal.LoggerEntry.OldStatusID				:=	StatusID;
				StatusID										:=	tshWRN_INTERNAL;
				Internal.LoggerEntry.LoggerMessage				:=	'ERROR DETECTION - Shuttle error on "Assembly Send"';
				TSH_WriteLoggerEntry;		
				StatusID										:=	Internal.LoggerEntry.OldStatusID;	(* the "old" error ID should be displayed *)
			END_IF
			(* When the timer is true, there was no new shuttle for the specified time and handove was stopped properly *)
			IF (Internal.ErrorCheck.fbTimerError.Q) THEN
				(* Recovery needed before restarting the handover *)
				Internal.Recovery.RecoveryNeeded				:=	TRUE;
				(* In state "Error", the output "RecoveryNeeded" must be set as well, without changing the state *)
				IF (Internal.State < tshSTATE_ON_HOLD) THEN
					Internal.State								:=	tshSTATE_ON_HOLD;
				
					(* Give information about the error reaction in advanced mode *)
					IF (Internal.Configuration.LoggingMode > tshLOGGING_BASIC) THEN
						Internal.LoggerEntry.OldStatusID		:=	StatusID;
						StatusID								:=	tshWRN_INTERNAL;
						Internal.LoggerEntry.LoggerMessage		:=	'HANDOVER - The handover is stopped as there are shuttles in error stop on "Assembly Send"';
						TSH_WriteLoggerEntry;		
						StatusID								:=	Internal.LoggerEntry.OldStatusID;	(* Warning will not be shown on the output -> Display old StatusID (zero) *)
					END_IF
				END_IF
			END_IF			
		END_IF
	END_IF
		
	(* Check for shuttle errors on Assembly Receive, when handover is running *)
	IF (Internal.State = tshSTATE_RUNNING) THEN
		(* Just react, if the current shuttle is not effected *)
		IF (Internal.ErrorCheck.ShuttlesInErrorStop OR Internal.ErrorCheck.ShuttlesDisabled OR Internal.ErrorCheck.ShuttlesStandstill) THEN
			(* Set the error detected flag *)
			Internal.ErrorCheck.ErrorDetected					:=	TRUE;
			(* Reset the handover ready flag *)		
			HandoverReady										:=	FALSE;
			(* Log information about the error, which was detected *)
			IF (Internal.Configuration.LoggingMode = tshLOGGING_DEBUGGING) AND NOT(Internal.ErrorCheck.ErrorDetectedOld) THEN
				IF (Internal.ErrorCheck.ShuttlesInErrorStop) THEN
					Internal.LoggerEntry.OldStatusID			:=	StatusID;
					StatusID									:=	tshWRN_INTERNAL;
					Internal.LoggerEntry.LoggerMessage			:=	'ERROR DETECTION - Shuttle(s) in error on "Assembly Receive"';
					TSH_WriteLoggerEntry;		
					StatusID									:=	Internal.LoggerEntry.OldStatusID;	(* the "old" error ID should be displayed *)
				ELSIF (Internal.ErrorCheck.ShuttlesDisabled) THEN
					Internal.LoggerEntry.OldStatusID			:=	StatusID;
					StatusID									:=	tshWRN_INTERNAL;
					Internal.LoggerEntry.LoggerMessage			:=	'ERROR DETECTION - Disabled shuttle(s) on "Assembly Receive"';
					TSH_WriteLoggerEntry;		
					StatusID									:=	Internal.LoggerEntry.OldStatusID;	(* the "old" error ID should be displayed *)
				ELSIF (Internal.ErrorCheck.ShuttlesStandstill) THEN
					Internal.LoggerEntry.OldStatusID			:=	StatusID;
					StatusID									:=	tshWRN_INTERNAL;
					Internal.LoggerEntry.LoggerMessage			:=	'ERROR DETECTION - Shuttle(s) in standstill on "Assembly Receive"';
					TSH_WriteLoggerEntry;		
					StatusID									:=	Internal.LoggerEntry.OldStatusID;	(* the "old" error ID should be displayed *)
				END_IF
			END_IF	
			(* When the timer is true, there was no new shuttle for the specified time and handove was stopped properly *)
			IF (Internal.ErrorCheck.fbTimerError.Q) THEN
				(* Recovery needed before restarting the handover *)
				Internal.Recovery.RecoveryNeeded				:=	TRUE;
				(* In state "Error", the output "RecoveryNeeded" must be set as well, without changing the state *)
				IF (Internal.State < tshSTATE_ON_HOLD) THEN
					Internal.State								:=	tshSTATE_ON_HOLD;
				
					(* Give information about the error reaction in advanced mode *)
					IF (Internal.Configuration.LoggingMode > tshLOGGING_BASIC) THEN
						Internal.LoggerEntry.OldStatusID		:=	StatusID;
						StatusID								:=	tshWRN_INTERNAL;
						Internal.LoggerEntry.LoggerMessage		:=	'HANDOVER - The handover is stopped as there are shuttles in error stop on "Assembly Receive"';
						TSH_WriteLoggerEntry;		
						StatusID								:=	Internal.LoggerEntry.OldStatusID;	(* Warning will not be shown on the output -> Display old StatusID (zero) *)
					END_IF
				END_IF
			END_IF
		END_IF
	END_IF
	
	(* If an error was detected and recovery is active, the recovery fails *)
	IF (Internal.ErrorCheck.ErrorDetected) AND (Internal.State = tshSTATE_RECOVERY) THEN
		(* Keep the recovery needed flag *)
		(* Set the recovery failed flag for the user *)
		Internal.Info.Recovery.RecoveryIdle						:=	FALSE;
		Internal.Info.Recovery.RecoveryActive					:=	FALSE;
		Internal.Info.Recovery.RecoveryFailed					:=	TRUE;
		(* Reset the sequence step *)
		Internal.RecoverySequence.SequenceStep					:=	0;
		(* Reset the recovery state *)
		Internal.Recovery.State									:=	tshRECOVERY_IDLE;
		(* Write a logger entry *)
		Active													:=	FALSE;
		Error													:=	TRUE;
		StatusID												:=	tshERR_RECOVERY;
		Internal.LoggerEntry.LoggerMessage						:=	'RECOVERY - Recovery failed, as there has been an error detected';		
		TSH_WriteLoggerEntry;
	END_IF
	
	(* Enter a message to the logger, that an handover is stopped because of an error reason (Every logging mode) *)
	IF (Internal.ErrorCheck.ErrorDetected) AND (Internal.ErrorCheck.ErrorDetected <> Internal.ErrorCheck.ErrorDetectedOld) THEN
		Internal.LoggerEntry.OldStatusID						:=	StatusID;
		StatusID												:=	tshWRN_INTERNAL;
		Internal.LoggerEntry.LoggerMessage						:=	'HANDOVER - The handover might be stopped, as an error was detected';
		TSH_WriteLoggerEntry;		
		StatusID												:=	Internal.LoggerEntry.OldStatusID;	(* Warning will not be shown on the output -> Display old StatusID (zero) *)
	END_IF
	Internal.ErrorCheck.ErrorDetectedOld						:=	Internal.ErrorCheck.ErrorDetected;
	
	(* Start the timer for error detection, which is needed to ensure no shuttles are passing the trigger point anymore *)
	Internal.ErrorCheck.fbTimerError.IN							:=	Internal.ErrorCheck.ErrorDetected AND (Internal.Process.Step = tshAR_WAIT_FOR_CATCH);
	Internal.ErrorCheck.fbTimerError.PT							:=	tshERROR_CHECK_TIME;
	(* Call the function block *)
	Internal.ErrorCheck.fbTimerError();	
END_ACTION

(*################################################################################################################################################*)

(* Handles the error reaction for all assembly and functionblock related errors (same procedure for each error) *)
ACTION TSH_AsmReceive_ErrorReaction_AssemblyError:
	(* Set the error detected flag *)
	Internal.ErrorCheck.ErrorDetected					:=	TRUE;
	(* Reset the handover ready flag *)		
	HandoverReady										:=	FALSE;	
		
	(* If there are no shuttles on the system, no recovery is needed and the handover can be put on hold directly *)
	IF (Internal.Process.NoShuttlesOnSector) AND (Internal.Communication.DataReceive.ProcessStatus.15) THEN
		(* No recovery needed *)
		Internal.Recovery.RecoveryNeeded				:=	FALSE;
		(* Just change the state, when it's not changed yet *)
		IF (Internal.State < tshSTATE_ON_HOLD) THEN
			Internal.State								:=	tshSTATE_ON_HOLD;				
			(* Give information about the error reaction in debugging mode *)
			IF (Internal.Configuration.LoggingMode > tshLOGGING_BASIC) THEN
				Internal.LoggerEntry.OldStatusID		:=	StatusID;
				StatusID								:=	tshWRN_INTERNAL;
				(* The core message is set before this action is called, to make it more generic *)
				IF (Internal.Configuration.LoggingMode = tshLOGGING_DEBUGGING) THEN
					(* Add details for debugging *)
					brsstrcat(ADR(Internal.LoggerEntry.LoggerMessage),ADR(' (No shuttles on both handover sectors)'));
				END_IF
				TSH_WriteLoggerEntry;		
				StatusID								:=	Internal.LoggerEntry.OldStatusID;	(* Warning will not be shown on the output -> Display old StatusID (zero) *)
			ELSE				
				(*Reset the string to not interfere with other messages*)
				brsmemset(ADR(Internal.LoggerEntry.LoggerMessage),0,SIZEOF(Internal.LoggerEntry.LoggerMessage));
			END_IF
		END_IF
		
		(* If there are just shuttles on Assembly Receive, do nothing, as they will move from the sector. Otherwise another error reaction will be triggered*)
	ELSIF NOT(Internal.Process.NoShuttlesOnSector) AND (Internal.Communication.DataReceive.ProcessStatus.15) THEN
		(* Do nothing and just wait for the shuttles to move from the sector *)
		
		(* If there are shuttles on the assembly send, a recovery is needed, and it must be ensured that no handover was triggered for a certain time *)
	ELSE
		(* When the timer is true, there was no new shuttle for the specified time and handove was stopped properly *)
		IF (Internal.ErrorCheck.fbTimerError.Q) THEN
			(* Recovery needed before restarting the handover *)
			Internal.Recovery.RecoveryNeeded			:=	TRUE;
			(* In state "Error", the output "RecoveryNeeded" must be set as well, without changing the state *)
			IF (Internal.State < tshSTATE_ON_HOLD) THEN
				Internal.State							:=	tshSTATE_ON_HOLD;
				
				(* Give information about the error reaction in debugging mode *)
				IF (Internal.Configuration.LoggingMode > tshLOGGING_BASIC) THEN
					Internal.LoggerEntry.OldStatusID	:=	StatusID;
					StatusID							:=	tshWRN_INTERNAL;
					(* The core message is set before this action is called, to make it more generic *)
					IF (Internal.Configuration.LoggingMode = tshLOGGING_DEBUGGING) THEN
						(* Add details for debugging *)
						brsstrcat(ADR(Internal.LoggerEntry.LoggerMessage),ADR(' (Shuttles on handover sector)'));
					END_IF
					TSH_WriteLoggerEntry;		
					StatusID							:=	Internal.LoggerEntry.OldStatusID;	(* Warning will not be shown on the output -> Display old StatusID (zero) *)
				ELSE				
					(*Reset the string to not interfere with other messages*)
					brsmemset(ADR(Internal.LoggerEntry.LoggerMessage),0,SIZEOF(Internal.LoggerEntry.LoggerMessage));
				END_IF
			END_IF
		END_IF
	END_IF
END_ACTION

(*################################################################################################################################################*)

(* Simulate the data receive interface on AsmReceive for the simulation mode "STANDALONE" *)
ACTION TSH_AsmReceive_SimulateCommInterface:
	(* Simulate the communication interface *)
	Internal.Communication.DataReceive.AssemblyStatus.1						:=	TRUE;	(* Assembly Ready *)
	Internal.Communication.DataReceive.AssemblyStatus.7						:=	TRUE;	(* POWERLINK communication running *)
	
	Internal.Communication.DataReceive.HeartbeatCount						:=	Internal.Communication.DataSend.HeartbeatCount + 1;	(* Communication heartbeat *)
	
	IF (SimAddShuttle AND (SimAddShuttle <> Internal.Simulation.SimAddShuttleOld) AND (Internal.Communication.DataSend.RecoveryInfo.ShuttlesInHandoverArea = 0)) THEN
		Internal.Communication.DataReceive.ProcessCommands.0				:=	TRUE; (* Command to add a shuttle *)
	END_IF
	Internal.Simulation.SimAddShuttleOld									:=	SimAddShuttle;
	IF (Internal.Communication.DataSend.ProcessStatus.8) THEN
		Internal.Communication.DataReceive.ProcessCommands.0				:=	FALSE; (* Command to add a shuttle *)
	END_IF
	
	Internal.Communication.DataReceive.ProcessCommands.4					:=	FALSE;	(* TransferArea Monitoring *)
	Internal.Communication.DataReceive.UserDataSize							:=	Internal.Communication.DataSend.UserDataSize; (* Userdata Size *)
	
	Internal.Communication.DataReceive.ProcessStatus.0						:=	TRUE;	(* Function block enabled *)
	Internal.Communication.DataReceive.ProcessStatus.1						:=	TRUE;	(* Function block initialized *)
	Internal.Communication.DataReceive.ProcessStatus.2						:=	TRUE;	(* Handover zone empty *)
	Internal.Communication.DataReceive.ProcessStatus.3						:=	Internal.Communication.DataSend.ProcessStatus.3;	(* Recovering *)
	Internal.Communication.DataReceive.ProcessStatus.4						:=	Internal.Communication.DataSend.ProcessStatus.4;	(* Recovery Done *)
	Internal.Communication.DataReceive.ProcessStatus.5						:=	Internal.Communication.DataSend.ProcessStatus.5;	(* Running *)
	Internal.Communication.DataReceive.ProcessStatus.6						:=	(Internal.State = tshSTATE_ON_HOLD) OR (Internal.State = tshSTATE_ERROR);	(* On hold *)
	Internal.Communication.DataReceive.ProcessStatus.7						:=	FALSE;	(* Error *)
	Internal.Communication.DataReceive.ProcessStatus.8						:=	Internal.Communication.DataSend.ProcessStatus.8;	(* Shuttle deleted successfully *)
	Internal.Communication.DataReceive.ProcessStatus.9						:=	FALSE;	(* FREE *)
	Internal.Communication.DataReceive.ProcessStatus.10						:=	Internal.Communication.DataSend.ProcessCommands.3;	(* Handover paused *)
	Internal.Communication.DataReceive.ProcessStatus.11						:=	FALSE;	(* Recovery needed *)
	Internal.Communication.DataReceive.ProcessStatus.12						:=	FALSE;	(* Shuttle error on AsmSend *)
	Internal.Communication.DataReceive.ProcessStatus.13						:=	FALSE;	(* FREE *)
	Internal.Communication.DataReceive.ProcessStatus.14						:=	TRUE;	(* Shuttle in handover zone data valid *)
	Internal.Communication.DataReceive.ProcessStatus.15						:=	TRUE;	(* No Shuttles on sector *)
	
	Internal.Communication.DataReceive.RecoveryInfo.ShuttlesInHandoverArea	:=	0;
	Internal.Communication.DataReceive.RecoveryInfo.CurrentZone				:=	Internal.Communication.DataSend.RecoveryInfo.CurrentZone;
	
END_ACTION

(*################################################################################################################################################*)

(*Initialize the auto pause feature by calculating the maximum number of shuttles*)
ACTION TSH_AsmReceive_AutoPauseInit:
	(* Calculate the total shuttle length *)
	Internal.Monitoring.ShuttleLength			:=	Internal.Parameter.ShuttleSize.ExtendToFront + Internal.Parameter.ShuttleSize.ExtendToBack;
	(* Calculate the length of the possible queuing area taking care at least 1 shuttle fits between the barrier and the end of the queueing area *)
	IF ((Internal.ConfigCheck.SafetyZoneLength / 2 - tshDISTANCE_SEG_END) > Internal.Monitoring.ShuttleLength) THEN
		//The free area is at least
		Internal.Monitoring.QueuingAreaLength	:=	Internal.ConfigCheck.SectorLength - (Internal.ConfigCheck.SafetyZoneLength / 2);	
	ELSE
		Internal.Monitoring.QueuingAreaLength	:=	Internal.ConfigCheck.SectorLength - Internal.Monitoring.ShuttleLength - tshDISTANCE_SEG_END;	
	END_IF
	(* Based on the values above calculate the maximum number of shuttles allowed on the sector *)
	Internal.Monitoring.MaxNumberOfShuttles		:=	TRUNC(Internal.Monitoring.QueuingAreaLength / Internal.Monitoring.ShuttleLength);	
	Internal.Monitoring.MaxNumberOfShuttles		:=	MAX(Internal.Monitoring.MaxNumberOfShuttles + tshAUTO_PAUSE_SYSTEM_OFFSET, 1);	//At least 1 Shuttle by system calculations
	(* Take care of the user offset *)
	Internal.Monitoring.MaxNumberOfShuttles		:=	MAX(Internal.Monitoring.MaxNumberOfShuttles + Internal.Parameter.AutoPause.UserOffset, 0);	//Only positive numbers
END_ACTION

(*################################################################################################################################################*)

(*Monitor the receive sector and set the auto pause flag if needed*)
ACTION TSH_AsmReceive_AutoPauseMonitoring:
	IF (Internal.Parameter.AutoPause.EnableHandoverAutoPause = tshHANDOVER_AUTO_PAUSE_ENABLE) AND Internal.Process.fbSecReadInfo.Valid THEN
		(* In case the number of shuttles on the sector exceeds the maximum number, the pause command is set *)
		Internal.Monitoring.AutoPauseActive	:=	(Internal.Process.fbSecReadInfo.SectorInfo.ShuttleCount.Count >= INT_TO_UINT(Internal.Monitoring.MaxNumberOfShuttles));
	ELSE
		Internal.Monitoring.AutoPauseActive	:=	FALSE;
	END_IF
END_ACTION

(*################################################################################################################################################*)

(* Recovery of AsmReceive *)
ACTION TSH_AsmReceive_Recovery:	
	(* Simplified recovery: Check for shuttle, reset and continue *)
	CASE Internal.Recovery.State OF
		tshRECOVERY_IDLE:
			(* Send the actual zone number *)
			Internal.Communication.DataSend.RecoveryInfo.CurrentZone.0		:=	TRUE;
			(* Reset recovery flags *)
			Internal.Recovery.ShuttleResetDone								:=	FALSE;
			Internal.RecoverySequence.SequenceStep							:=	0;
			(* When both assemblies are in recovery mode, start the recovery logic *)
			IF (Internal.Communication.DataSend.ProcessStatus.3) AND (Internal.Communication.DataReceive.ProcessStatus.3) AND (Internal.Communication.DataReceive.RecoveryInfo.CurrentZone.0) THEN
				Internal.Recovery.State										:=	tshRECOVERY_ZONE_RECEIVE;
				(* Recovery is now active *)					
				Internal.Info.Recovery.RecoveryIdle							:=	FALSE;
				Internal.Info.Recovery.RecoveryActive						:=	TRUE;
			END_IF
			
		tshRECOVERY_ZONE_RECEIVE:
			(* Send the actual zone number *)
			Internal.Communication.DataSend.RecoveryInfo.CurrentZone.1		:=	TRUE;
			
			CASE Internal.RecoverySequence.SequenceStep OF
				0:	(* Check if we have a shuttle in process *)
					IF Internal.Process.ShuttleRef.controlif <> 0 THEN
						(* Shuttle found in process - reset it *)
						Internal.RecoverySequence.SequenceStep				:=	10;
					ELSE
						(* No shuttle in process - search for one *)
						Internal.RecoverySequence.SequenceStep				:=	5;
					END_IF
					
				5:	(* SecGetShuttle - search for shuttles on sector *)
					(* Configure search parameters *)
					Internal.Recovery.fbSecGetShuttle.Sector				:=	ADR(Sector);
					Internal.Recovery.fbSecGetShuttle.Mode					:=	mcACPTRAK_SEARCH_FORWARD;
					Internal.Recovery.fbSecGetShuttle.AdvancedParameters.SelectionMode	:=	mcACPTRAK_GET_SH_ALL;
					Internal.Recovery.fbSecGetShuttle.AdvancedParameters.StartPosition	:=	0.0;
					(* Use RecoverySearchLength if configured, otherwise entire sector *)
					IF Internal.Parameter.RecoverySearchLength > 0.0 THEN
						Internal.Recovery.fbSecGetShuttle.AdvancedParameters.EndPosition	:=	Internal.Parameter.RecoverySearchLength;
					ELSE
						Internal.Recovery.fbSecGetShuttle.AdvancedParameters.EndPosition	:=	0.0;
					END_IF
					Internal.Recovery.fbSecGetShuttle.Enable				:=	TRUE;
					Internal.Recovery.fbSecGetShuttle();
					
					IF Internal.Recovery.fbSecGetShuttle.Valid AND Internal.Recovery.fbSecGetShuttle.TotalCount <> 0 THEN
						(* Shuttle found - use it *)
						Internal.Process.ShuttleRef							:=	Internal.Recovery.fbSecGetShuttle.Axis;
						Internal.RecoverySequence.SequenceStep				:=	10;
					ELSIF Internal.Recovery.fbSecGetShuttle.Valid THEN
						(* No shuttle found - wait for Send *)
						Internal.Recovery.fbSecGetShuttle.Enable			:=	FALSE;
						Internal.RecoverySequence.SequenceStep				:=	50;
					ELSIF Internal.Recovery.fbSecGetShuttle.Error THEN
						(* Real error - go back to idle *)
						Internal.Recovery.fbSecGetShuttle.Enable			:=	FALSE;
						Internal.Recovery.State								:=	tshRECOVERY_IDLE;
					END_IF
					
				10:	(* MC_Reset - reset shuttle error if any *)
					IF NOT(Internal.Recovery.ShuttleResetDone) THEN
						Internal.Recovery.fbReset.Axis						:=	ADR(Internal.Process.ShuttleRef);
						Internal.Recovery.fbReset.Execute					:=	TRUE;
						Internal.Recovery.fbReset();
						
						IF Internal.Recovery.fbReset.Done THEN
							Internal.Recovery.fbReset.Execute				:=	FALSE;
							Internal.Recovery.ShuttleResetDone				:=	TRUE;
						ELSIF Internal.Recovery.fbReset.Error THEN
							Internal.Recovery.fbReset.Execute				:=	FALSE;
							Internal.Recovery.ShuttleResetDone				:=	TRUE;
						END_IF
					ELSE
						(* Reset done - start movement *)
						Internal.RecoverySequence.SequenceStep				:=	20;
					END_IF
					
				20:	(* MC_BR_RoutedMoveAbs - start movement to target, don't wait for completion *)
					Internal.Recovery.fbRoutedMoveAbs.Axis					:=	ADR(Internal.Process.ShuttleRef);
					Internal.Recovery.fbRoutedMoveAbs.Sector				:=	ADR(Internal.Parameter.Target.Sector);
					Internal.Recovery.fbRoutedMoveAbs.Position				:=	Internal.Parameter.Target.Position;
					Internal.Recovery.fbRoutedMoveAbs.Velocity				:=	Internal.Parameter.Target.Velocity;
					Internal.Recovery.fbRoutedMoveAbs.Acceleration			:=	Internal.Parameter.Target.Acceleration;
					Internal.Recovery.fbRoutedMoveAbs.Deceleration			:=	Internal.Parameter.Target.Deceleration;
					Internal.Recovery.fbRoutedMoveAbs.Execute				:=	TRUE;
					Internal.Recovery.fbRoutedMoveAbs();
					
					IF Internal.Recovery.fbRoutedMoveAbs.Active THEN
						(* Movement started - proceed to next shuttle immediately *)
						Internal.Recovery.fbRoutedMoveAbs.Execute			:=	FALSE;
						Internal.Recovery.ShuttleResetDone					:=	FALSE;
						Internal.RecoverySequence.SequenceStep				:=	30;
					ELSIF Internal.Recovery.fbRoutedMoveAbs.Error THEN
						(* Error - skip this shuttle and try next *)
						Internal.Recovery.fbRoutedMoveAbs.Execute			:=	FALSE;
						Internal.Recovery.ShuttleResetDone					:=	FALSE;
						Internal.RecoverySequence.SequenceStep				:=	30;
					END_IF
					
				30:	(* Check for next shuttle using fbSecGetShuttle.Next *)
					IF Internal.Recovery.fbSecGetShuttle.Valid THEN
						(* Still enabled, get next *)
						Internal.Recovery.fbSecGetShuttle.Next				:=	TRUE;
						Internal.Recovery.fbSecGetShuttle();
						
						IF Internal.Recovery.fbSecGetShuttle.Valid AND NOT Internal.Recovery.fbSecGetShuttle.RemainingCount = 0 THEN
							(* More shuttles - process them *)
							Internal.Process.ShuttleRef						:=	Internal.Recovery.fbSecGetShuttle.Axis;
							Internal.Recovery.fbSecGetShuttle.Next			:=	FALSE;
							Internal.RecoverySequence.SequenceStep			:=	10;
						ELSE
							(* No more shuttles *)
							Internal.Recovery.fbSecGetShuttle.Enable		:=	FALSE;
							Internal.Recovery.fbSecGetShuttle.Next			:=	FALSE;
							Internal.RecoverySequence.SequenceStep			:=	50;
						END_IF
					ELSE
						(* Not valid anymore - move to wait for Send *)
						Internal.Recovery.fbSecGetShuttle.Enable			:=	FALSE;
						Internal.RecoverySequence.SequenceStep				:=	50;
					END_IF
					
				50:	(* All shuttles processed - go to catching state to receive shuttles from Send *)
					Internal.Recovery.State									:=	tshRECOVERY_CATCHING;
			END_CASE
			
		tshRECOVERY_CATCHING:
			(* Signal to Send that Receive is ready to catch shuttles *)
			Internal.Communication.DataSend.RecoveryInfo.CurrentZone.5		:=	TRUE;
			
			(* Wait for Send to finish recovery (CurrentZone.4 = Done) *)
			IF (Internal.Communication.DataReceive.RecoveryInfo.CurrentZone.4 OR Internal.Communication.DataReceive.ProcessStatus.4) THEN
				(* Send has finished - proceed to done *)
				Internal.Communication.DataSend.RecoveryInfo.CurrentZone.5	:=	FALSE;
				Internal.Recovery.State										:=	tshRECOVERY_DONE;
			END_IF
			
		tshRECOVERY_DONE:			
			(* Send the actual zone number *)
			Internal.Communication.DataSend.RecoveryInfo.CurrentZone.4		:=	TRUE;
			Internal.Communication.DataSend.ProcessStatus.4					:=	TRUE;
			(* Wait for both sides to be finished *)
			IF (Internal.Communication.DataReceive.RecoveryInfo.CurrentZone.4 OR Internal.Communication.DataReceive.ProcessStatus.4) THEN
				(* The recovery finished successfully *)
				RecoveryBusy												:=	FALSE;					
				Internal.Info.Recovery.RecoveryActive						:=	FALSE;
				RecoveryDone												:=	TRUE;
				(* Reset the Info output for the shuttles before checking for the zone *)
				brsmemset(ADR(Internal.Info.Shuttle),0,SIZEOF(Internal.Info.Shuttle));
			END_IF
		
	END_CASE
END_ACTION

(*################################################################################################################################################*)

(* Abort catch mode before disabling the FUB - requires multiple cycles *)
ACTION TSH_AsmReceive_AbortCatch:
	CASE Internal.Process.AbortCatchStep OF
		0: (* Check if abort needed *)
			Internal.Process.AbortCatchDone									:=	FALSE;
			IF Internal.Process.fbSecAddShuttle.Busy THEN
				Internal.Process.fbSecAddShuttle.AdvancedParameters.Mode	:=	mcACPTRAK_ABORT_CATCH;
				Internal.Process.fbSecAddShuttle.Execute					:=	FALSE;
				Internal.Process.fbSecAddShuttle();
				Internal.Process.AbortCatchStep								:=	1;
			ELSE
				Internal.Process.AbortCatchDone								:=	TRUE;
			END_IF
			
		1: (* Wait for abort complete *)
			Internal.Process.fbSecAddShuttle.Execute						:=	TRUE;
			Internal.Process.fbSecAddShuttle();
			IF Internal.Process.fbSecAddShuttle.Done THEN
				Internal.Process.fbSecAddShuttle.Execute					:=	FALSE;
				Internal.Process.fbSecAddShuttle.AdvancedParameters.Mode	:=	mcACPTRAK_ADD_CATCH;
				Internal.Process.AbortCatchDone								:=	TRUE;
				Internal.Process.AbortCatchStep								:=	0;
			END_IF
	END_CASE
END_ACTION