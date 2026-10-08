(*********************************************************************************
 * Copyright: B&R Industrial Automation GmbH 
 * Author:    B&R CD - CPE 
 * Created:   January 14, 2021
 *
 * Description:
 * - Actions, which are needed for the function block "TSH_AsmSendShuttleDelete"
 *
 * Actions (Right click on the action name -> "Go to Implementation", to jump to the code):
 * - TSH_AsmSend_CheckInputs
 * - TSH_AsmSend_CheckConfig
 * - TSH_AsmSend_ProcessInit
 * - TSH_AsmSend_ProcessError
 * - TSH_AsmSend_Process
 * - TSH_AsmSend_ProcessCallFBs
 * - TSH_AsmSend_TrgPointGetInfo
 * - TSH_AsmSend_HandoverPauseHandling
 * - TSH_AsmSend_BarrierClose
 * - TSH_AsmSend_BarrierOpen
 * - TSH_AsmSend_BarrierAddTickets
 * - TSH_AsmSend_ResetInDisabled
 * - TSH_AsmSend_CurrentShuttleCheck
 * - TSH_AsmSend_ErrorReaction
 * - TSH_AsmSend_ErrorReaction_StopShuttle
 * - TSH_AsmSend_ErrorReaction_AssemblyError
 * - TSH_AsmSend_SimulateCommInterface
 * - TSH_AsmSend_Recovery
 * - TSH_AsmSend_Recovery_Zone_Handover
 * - TSH_AsmSend_Recovery_Zone_Send
 *********************************************************************************)

(* Check FUB specific inputs *)
ACTION TSH_AsmSend_CheckInputs:
	(* Check common inputs before *)
	TSH_CheckCommonInputs;
	
	(* Just need to check, if there was no error before *)
	IF NOT(Error) THEN
		(* Common Inputs of the function blocks *)
		IF (ADR(ProcessPoint_GetData) = 0) THEN	
			Active										:=	FALSE;
			Error										:=	TRUE;
			StatusID									:=	tshERR_NO_PP_REF;
			Internal.LoggerEntry.LoggerMessage			:=	'INPUT - No get data process point connected to the function block';
		ELSIF (ADR(ProcessPoint_DeleteShuttle) = 0) THEN
			Active										:=	FALSE;
			Error										:=	TRUE;
			StatusID									:=	tshERR_NO_PP_REF;
			Internal.LoggerEntry.LoggerMessage			:=	'INPUT - No delete shuttle process point connected to the function block';
		ELSIF (ADR(HandoverDataReceive) = 0) THEN
			Active										:=	FALSE;
			Error										:=	TRUE;
			StatusID									:=	tshERR_NO_BUFFER_REF;
			Internal.LoggerEntry.LoggerMessage			:=	'INPUT - No data receive buffer connected to the function block';
		ELSIF (HandoverDataSendAddress = 0) THEN
			Active										:=	FALSE;
			Error										:=	TRUE;
			StatusID									:=	tshERR_NO_BUFFER_REF;
			Internal.LoggerEntry.LoggerMessage			:=	'INPUT - No data send buffer connected to the function block';
		ELSIF (HandoverDataSendSize = 0) THEN
			Active										:=	FALSE;
			Error										:=	TRUE;
			StatusID									:=	tshERR_BUFFER_WRONG_SIZE;
			Internal.LoggerEntry.LoggerMessage			:=	'INPUT - The data send buffer has size 0';
		ELSIF (UserDataSize > HandoverDataSendSize) THEN
			Active										:=	FALSE;
			Error										:=	TRUE;
			StatusID									:=	tshERR_BUFFER_WRONG_SIZE;
			Internal.LoggerEntry.LoggerMessage			:=	'INPUT - The user data is bigger than the data send buffer';
		ELSIF (DiagCpuIsSimulated() AND (Internal.Configuration.Simulation.Velocity = 0 OR Internal.Configuration.Simulation.Acceleration = 0 OR Internal.Configuration.Simulation.Deceleration = 0)) THEN
			Active										:=	FALSE;
			Error										:=	TRUE;
			StatusID									:=	tshERR_PARAMETER_VALUE;
			Internal.LoggerEntry.LoggerMessage			:=	'INPUT - Simulation active and no movement parameter set';
		ELSE
			(* Copy data from inputs to internal structure and save adresses *)
			Internal.Communication.DataReceiveAddress	:=	ADR(HandoverDataReceive);
			Internal.Communication.DataSendAddress		:=	HandoverDataSendAddress;
			Internal.Communication.DataSendSize			:=	HandoverDataSendSize;
			Internal.Communication.UserDataAddress		:=	UserDataAddress;
			Internal.Communication.UserDataSize			:=	UserDataSize;
			
			Internal.Communication.DataReceive.ParaVelocity		:= Internal.Configuration.Simulation.Velocity;
			Internal.Communication.DataReceive.ParaAcceleration	:= Internal.Configuration.Simulation.Acceleration;
			Internal.Communication.DataReceive.ParaDeceleration	:= Internal.Configuration.Simulation.Deceleration;
			
			(* Give a warning to the logger, that no userdata will be transferred *)
			IF (Internal.Communication.UserDataSize = 0) THEN
				Internal.LoggerEntry.OldStatusID		:=	StatusID;
				StatusID								:=	tshWRN_USERDATA;
				Internal.LoggerEntry.LoggerMessage		:=	'COMMUNICATION - No shuttle userdata will be communicated, as userdata size = 0';
				TSH_WriteLoggerEntry;
				StatusID								:=	Internal.LoggerEntry.OldStatusID;
			END_IF
		END_IF
	END_IF
END_ACTION

(*################################################################################################################################################*)

(* Check FUB specific configuration parameter *)
ACTION TSH_AsmSend_CheckConfig:
	(* Check common inputs before *)
	TSH_CheckCommonConfig;
END_ACTION

(*################################################################################################################################################*)

(* Initialize the process (internal function blocks, etc. ) *)
ACTION TSH_AsmSend_ProcessInit:
	Internal.Process.fbAsmReadStatus.Assembly									:=	ADR(Assembly);
	
	Internal.Process.fbTrgPointEnable.ProcessPoint								:=	ADR(ProcessPoint_GetData);
	Internal.Process.fbTrgPointReadInfo.ProcessPoint							:=	ADR(ProcessPoint_GetData);
	
	Internal.Barrier.fbBarrierReadInfo.ProcessPoint								:=	ADR(ProcessPoint_GetData);
	Internal.Barrier.fbBarrierCommand.ProcessPoint								:=	ADR(ProcessPoint_GetData);
	
	Internal.Process.fbShCopyUserData.Axis										:=	ADR(Internal.Process.ShuttleRef);
	Internal.Process.fbShCopyUserData.DataAddress								:= 	Internal.Communication.UserDataAddress;
	Internal.Process.fbShCopyUserData.DataSize									:=	Internal.Communication.UserDataSize;
	Internal.Process.fbShCopyUserData.Mode										:=	mcACPTRAK_USERDATA_GET;
	
	Internal.Process.fbSecGetShuttle.Sector										:=	ADR(Sector);
	Internal.Process.fbSecGetShuttle.Mode										:=	mcACPTRAK_SEARCH_BACKWARD;
	Internal.Process.fbSecGetShuttle.AdvancedParameters.StartPosition			:=	0; (*Internal.ConfigCheck.SectorLength - Internal.Configuration.TransferAreaLength + tshDISTANCE_SEG_END;*)
	Internal.Process.fbSecGetShuttle.AdvancedParameters.EndPosition				:=	0; (* 0 = Sector length *)
	Internal.Process.fbSecGetShuttle.AdvancedParameters.SelectionMode			:=	mcACPTRAK_GET_SH_ALL;
	
	Internal.Process.fbSecReadInfo.Sector										:=	ADR(Sector);
	
	Internal.Process.fbSecStop.Sector											:=	ADR(Sector);
	(* Note: Deceleration is set dynamically from DataReceive.ParaDeceleration when fbSecStop is used *)
	
	Internal.Process.fbSecGetInfo.Sector										:=	ADR(Sector);
	
	Internal.Process.Delete.fbTrgPointEnable.ProcessPoint						:=	ADR(ProcessPoint_DeleteShuttle);
	Internal.Process.Delete.fbTrgPointReadInfo.ProcessPoint						:=	ADR(ProcessPoint_DeleteShuttle);
	
	Internal.Process.Delete.fbAsmDeleteShuttle.Assembly							:=	ADR(Assembly);
	Internal.Process.Delete.fbAsmDeleteShuttle.Axis								:=	ADR(Internal.Process.ShuttleRef);
	Internal.Process.Delete.fbAsmDeleteShuttle.Command							:=	mcACPTRAK_SH_DELETE_SPECIFIC;
	Internal.Process.Delete.fbAsmDeleteShuttle.AdvancedParameters.SuppressFollowUpErrLogEntries	:= TRUE;
	
	Internal.Process.fbRoutedMoveAbs.Axis										:= ADR(Internal.Process.ShuttleRef);
	Internal.Process.fbRoutedMoveAbs.Sector										:= ADR(Sector);
	Internal.Process.fbRoutedMoveAbs.AdvancedParameters.StartDirection			:= mcDIR_UNDEFINED;
	Internal.Process.fbRoutedMoveAbs.AdvancedParameters.EndDirection			:= mcDIR_UNDEFINED;
	Internal.Process.fbRoutedMoveAbs.AdvancedParameters.ShuttleOrientation		:= mcDIR_UNDEFINED;
	
	(* Initialize the recovery function blocks here as well *)
	Internal.Recovery.fbReset.Axis												:=	ADR(Internal.Process.ShuttleRef);
	
	Internal.Recovery.fbReadStatus.Axis											:=	ADR(Internal.Process.ShuttleRef);
	
	Internal.Recovery.fbSecGetShuttle.Sector									:=	ADR(Sector);
	
	Internal.Recovery.fbRoutedMoveAbs.Axis										:=	ADR(Internal.Process.ShuttleRef);
	Internal.Recovery.fbRoutedMoveAbs.Sector									:=	ADR(Sector);
	Internal.Recovery.fbRoutedMoveAbs.BufferMode								:=	mcABORTING;
	Internal.Recovery.fbRoutedMoveAbs.AdvancedParameters.StartDirection			:=	mcDIR_UNDEFINED;
	Internal.Recovery.fbRoutedMoveAbs.AdvancedParameters.EndDirection			:=	mcDIR_UNDEFINED;
	Internal.Recovery.fbRoutedMoveAbs.AdvancedParameters.ShuttleOrientation		:=	mcDIR_UNDEFINED;
		
	Internal.Recovery.fbAsmDeleteShuttle.Assembly								:=	ADR(Assembly);
	Internal.Recovery.fbAsmDeleteShuttle.Axis									:=	ADR(Internal.Process.ShuttleRef);
	Internal.Recovery.fbAsmDeleteShuttle.Command								:=	mcACPTRAK_SH_DELETE_SPECIFIC;
	
	Internal.Recovery.fbSecStop.Sector											:=	ADR(Sector);
	
	Internal.Recovery.fbTimer.PT												:=	tshRECOVERY_CHECK_TIME;
	Internal.Recovery.fbErrorCheckTimer.PT										:=	tshERROR_CHECK_TIME;
END_ACTION

(*################################################################################################################################################*)

(* Resets all execute and enable inputs of process relevant function blocks, which are called cyclically (except barrier) *)
ACTION TSH_AsmSend_ProcessError:	
	Internal.Process.fbReadStatus.Enable				:=	FALSE;
	Internal.Process.fbShReadInfo.Enable				:=	FALSE;
	Internal.Process.fbSecStop.Execute					:=	FALSE;
	Internal.Process.fbTrgPointEnable.Enable			:=	FALSE;
	Internal.Process.fbSecGetInfo.Execute				:=	FALSE;
	Internal.Process.fbRoutedMoveAbs.Execute			:=	FALSE;
	
	Internal.Process.Delete.fbTrgPointEnable.Enable		:=	FALSE;
	Internal.Process.Delete.fbAsmDeleteShuttle.Execute	:=	FALSE;
	Internal.Process.Delete.fbShReadInfo.Enable			:=	FALSE;
	
	(* Reset the counter from response check *)				
	Internal.ResponseTimeoutCheck.WaitedCycles			:=	0;
	
	(* Reset the initialization function blocks here as well *)
	Internal.LoggerEntry.fbCreateUsrLogBook.Execute		:=	FALSE;
	
	(* Reset the recovery function blocks here as well *)
	Internal.Recovery.fbReset.Execute					:=	FALSE;
	Internal.Recovery.fbReadStatus.Enable				:=	FALSE;
	Internal.Recovery.fbSecGetShuttle.Enable			:=	FALSE;
	Internal.Recovery.fbSecGetShuttle.Next				:=	FALSE;
	Internal.Recovery.fbRoutedMoveAbs.Execute			:=	FALSE;
	Internal.Recovery.fbAsmDeleteShuttle.Execute		:=	FALSE;
	Internal.Recovery.fbSecStop.Execute					:=	FALSE;
	Internal.Recovery.fbTimer.IN						:=	FALSE;
	Internal.Recovery.fbErrorCheckTimer.IN				:=	FALSE;
END_ACTION

(*################################################################################################################################################*)


(* Handles the core process functionality of the shuttle handover - simplified without convoy *)
ACTION TSH_AsmSend_Process:	
	CASE Internal.Process.Step OF
		tshAS_CHECK_TRIGGER:
			(* Enable function block *)
			Internal.Process.fbTrgPointEnable.Enable							:=	TRUE;
			
			IF (Internal.Process.fbTrgPointEnable.Valid) AND (Internal.Process.fbTrgPointEnable.EventCount > 0) THEN
				TSH_AsmSend_TrgPointGetInfo;
				
				(* Only when the shuttle is usable, the handover is executed *) 
				IF (Internal.Process.ShuttleUsable) THEN
					Internal.Process.Step										:=	tshAS_GET_SHUTTLE_DATA;
					
					(* Start the execution to get information about the shuttle and its status *)
					Internal.Process.fbShReadInfo.Axis							:= ADR(Internal.Process.ShuttleRef);
					Internal.Process.fbReadStatus.Axis							:= ADR(Internal.Process.ShuttleRef);
					Internal.Process.fbShReadInfo.Enable						:= TRUE;
					Internal.Process.fbReadStatus.Enable						:= TRUE;
				END_IF

			ELSIF (Internal.Process.fbTrgPointEnable.Error) THEN	
				(* Display an error *)
				Active															:=	FALSE;
				Error															:=	TRUE;
				StatusID														:=	tshERR_INTERNAL;
				Internal.LoggerEntry.LoggerMessage								:=	'INTERNAL - Error while enabling the trigger point';		
				TSH_WriteLoggerEntry;
				
				(* Set diagnostic info output *)
				Internal.Info.Diagnosis.Valid									:=	TRUE;
				Internal.Info.Diagnosis.Functionblock							:=	'MC_BR_TrgPointEnable_AcpTrak';
				Internal.Info.Diagnosis.StatusID       							:=	Internal.Process.fbTrgPointEnable.ErrorID;
				
				(* Reset the function block *)
				Internal.Process.fbTrgPointEnable.Enable						:=	FALSE;
			END_IF
				
		tshAS_GET_SHUTTLE_DATA:	
			IF (Internal.Process.fbShReadInfo.Valid) THEN				
				
				Internal.Process.ShuttleID										:=	Internal.Process.fbShReadInfo.ShuttleInfo.AdditionalInfo.ID;
				
				(* Give information about the shuttle currently in the handover *)
				IF (Internal.Configuration.LoggingMode = tshLOGGING_DEBUGGING) THEN
					Internal.LoggerEntry.OldStatusID							:=	StatusID;
					StatusID													:=	tshINFO_INTERNAL;
					Internal.LoggerEntry.LoggerMessage							:=	'HANDOVER DEBUG - Shuttle with ID ';
					brsitoa(Internal.Process.ShuttleID, ADR(Internal.LoggerEntry.ValueString));
					brsstrcat(ADR(Internal.LoggerEntry.LoggerMessage), ADR(Internal.LoggerEntry.ValueString));
					brsstrcat(ADR(Internal.LoggerEntry.LoggerMessage), ADR(' currently in handover'));
					TSH_WriteLoggerEntry;		
					StatusID													:=	Internal.LoggerEntry.OldStatusID;
				END_IF
			
				(* Copy userdata *)
				TSH_ShuttleCopyUserData;
				
				(* Continue to wait for confirmation *)
				IF NOT(Internal.ErrorCheck.ErrorDetected) THEN			
					Internal.Process.Step										:=	tshAS_WAIT_FOR_CATCH;
					Internal.Process.fbShReadInfo.Enable						:= FALSE;
					
					Internal.Process.fbRoutedMoveAbs.Execute					:= TRUE;
					Internal.Process.fbRoutedMoveAbs.Position					:= Internal.ConfigCheck.SectorLength;
					Internal.Process.fbRoutedMoveAbs.Velocity					:= Internal.Communication.DataReceive.ParaVelocity;
					Internal.Process.fbRoutedMoveAbs.Acceleration				:= Internal.Communication.DataReceive.ParaAcceleration;
					Internal.Process.fbRoutedMoveAbs.Deceleration				:= Internal.Communication.DataReceive.ParaDeceleration;
				END_IF
				
				(* Check if the current shuttle is already in error stop to prevent the handover *)
				TSH_AsmSend_CurrentShuttleCheck;
				
			ELSIF (Internal.Process.fbShReadInfo.Error) THEN
				Internal.Process.Step											:=	tshAS_CHECK_TRIGGER;
				Active															:=	FALSE;
				Error															:=	TRUE;
				StatusID														:=	tshERR_INTERNAL;
				Internal.LoggerEntry.LoggerMessage								:=	'INTERNAL - Error while reading shuttle information';		
				TSH_WriteLoggerEntry;
				
				Internal.Info.Diagnosis.Valid									:=	TRUE;
				Internal.Info.Diagnosis.Functionblock							:=	'MC_BR_ShReadInfo_AcpTrak';
				Internal.Info.Diagnosis.StatusID       							:=	Internal.Process.fbShReadInfo.ErrorID;
				
				Internal.Process.fbShReadInfo.Enable							:=	FALSE;
			END_IF
			
		tshAS_WAIT_FOR_CATCH:
			Internal.Communication.DataSend.ProcessCommands.0					:=	TRUE;	
			
			IF (Internal.Process.fbReadStatus.Valid) AND (Internal.Process.fbReadStatus.ErrorStop) THEN
				Internal.LoggerEntry.OldStatusID								:=	StatusID;
				StatusID														:=	tshWRN_HANDOVER_SHUTTLE_STOP;
				Internal.LoggerEntry.LoggerMessage								:=	'HANDOVER - The shuttle went into error stop during handover. Process continued (Details see motion logger)';		
				TSH_WriteLoggerEntry;	
				StatusID														:=	Internal.LoggerEntry.OldStatusID;
				Internal.Process.fbReadStatus.Enable							:=	FALSE;
			END_IF
			
			IF (Internal.Communication.DataReceive.ProcessStatus.11) AND NOT(Internal.Communication.DataReceive.ProcessStatus.5) AND NOT(Internal.Communication.DataReceive.ProcessStatus.8) THEN
				HandoverReady													:=	FALSE;
				Internal.Recovery.RecoveryNeeded								:=	TRUE;		
				Active															:=	FALSE;
				Error															:=	TRUE;
				StatusID														:=	tshERR_HANDOVER;
				Internal.LoggerEntry.LoggerMessage								:=	'HANDOVER - The shuttle was not able to be added on "Assembly Receive"';
				TSH_WriteLoggerEntry;	
			END_IF
			
			Internal.ResponseTimeoutCheck.Response								:=	Internal.Communication.DataReceive.ProcessStatus.8;
			TSH_CheckResponseTimeout;
			
			IF (Internal.ResponseTimeoutCheck.Responded) OR Internal.Info.Simulation.Type = tshSIM_TYPE_AR_SIM AND Internal.Process.fbRoutedMoveAbs.Active THEN
				Internal.Process.fbReadStatus.Enable							:=	FALSE;
				Internal.Communication.DataSend.ProcessCommands.0				:=	FALSE;
				Internal.Process.fbRoutedMoveAbs.Execute						:=	FALSE;
				
				Internal.Process.Step											:=	tshAS_WAIT_HANDOVER_DONE;
			ELSIF Internal.Process.fbRoutedMoveAbs.Error THEN
				Internal.Process.Step											:=	tshAS_CHECK_TRIGGER;
				Active															:=	FALSE;
				Error															:=	TRUE;
				StatusID														:=	tshERR_INTERNAL;
				Internal.LoggerEntry.LoggerMessage								:=	'INTERNAL - Error while sending the shuttle to the end of the sector';		
				TSH_WriteLoggerEntry;
				
				Internal.Info.Diagnosis.Valid									:=	TRUE;
				Internal.Info.Diagnosis.Functionblock							:=	'MC_BR_RoutedMoveAbs_AcpTrak';
				Internal.Info.Diagnosis.StatusID       							:=	Internal.Process.fbRoutedMoveAbs.ErrorID;
				
				Internal.Process.fbRoutedMoveAbs.Execute						:=	FALSE;
			ELSIF (Error) THEN
				Internal.Process.Step											:=	tshAS_CHECK_TRIGGER;
			END_IF				
		
		tshAS_WAIT_HANDOVER_DONE:
			Internal.Communication.DataSend.ProcessStatus.8						:=	TRUE;
			Internal.ResponseTimeoutCheck.Response								:=	NOT(Internal.Communication.DataReceive.ProcessStatus.8);
			TSH_CheckResponseTimeout;
			
			IF (Internal.Configuration.LoggingMode = tshLOGGING_DEBUGGING) AND (Error) THEN
				Internal.LoggerEntry.OldStatusID								:=	StatusID;
				StatusID														:=	tshINFO_INTERNAL;
				Internal.LoggerEntry.LoggerMessage								:=	'HANDOVER DEBUG - Confirmation for a successful Shuttle handover came not in time';
				TSH_WriteLoggerEntry;		
				StatusID														:=	Internal.LoggerEntry.OldStatusID;
			END_IF
			
			IF (Internal.ResponseTimeoutCheck.Responded) THEN
				brsmemset(ADR(Internal.Process.ShuttleRef),0,SIZEOF(Internal.Process.ShuttleRef));
				Internal.Process.ShuttleID										:=	0;
				Internal.Communication.DataSend.ProcessStatus.8					:=	FALSE;
				Internal.Process.Step											:=	tshAS_CHECK_TRIGGER;
			ELSIF (Error) THEN
				Internal.Process.Step											:=	tshAS_CHECK_TRIGGER;
			END_IF
		
	END_CASE
	
	CASE Internal.Process.Delete.Step OF
		tshAS_CHECK_TRIGGER:
			(* Enable function block *)
			Internal.Process.Delete.fbTrgPointEnable.Enable						:=	TRUE;
			
			IF (Internal.Process.Delete.fbTrgPointEnable.Valid) AND (Internal.Process.Delete.fbTrgPointEnable.EventCount > 0) THEN
				TSH_AsmSend_Delete_TrgPointGetInfo;
				
				Internal.Process.Delete.Step									:=	tshAS_GET_SHUTTLE_DATA;
					
				(* Start the execution to get information about the shuttle and its status *)
				Internal.Process.Delete.fbShReadInfo.Axis						:= ADR(Internal.Process.Delete.ShuttleRef);
				Internal.Process.Delete.fbShReadInfo.Enable						:= TRUE;
			ELSIF (Internal.Process.Delete.fbTrgPointEnable.Error) THEN	
				(* Display an error *)
				Active															:=	FALSE;
				Error															:=	TRUE;
				StatusID														:=	tshERR_INTERNAL;
				Internal.LoggerEntry.LoggerMessage								:=	'INTERNAL - Error while enabling the trigger point for deleting shuttles';		
				TSH_WriteLoggerEntry;
				
				(* Set diagnostic info output *)
				Internal.Info.Diagnosis.Valid									:=	TRUE;
				Internal.Info.Diagnosis.Functionblock							:=	'MC_BR_TrgPointEnable_AcpTrak';
				Internal.Info.Diagnosis.StatusID       							:=	Internal.Process.Delete.fbTrgPointEnable.ErrorID;
				
				(* Reset the function block *)
				Internal.Process.Delete.fbTrgPointEnable.Enable					:=	FALSE;
			END_IF
			
		tshAS_GET_SHUTTLE_DATA:	
			IF (Internal.Process.Delete.fbShReadInfo.Valid) THEN				
				
				Internal.Process.Delete.ShuttleID								:=	Internal.Process.Delete.fbShReadInfo.ShuttleInfo.AdditionalInfo.ID;
				
				(* Give information about the shuttle currently in the handover *)
				IF (Internal.Configuration.LoggingMode = tshLOGGING_DEBUGGING) THEN
					Internal.LoggerEntry.OldStatusID							:=	StatusID;
					StatusID													:=	tshINFO_INTERNAL;
					Internal.LoggerEntry.LoggerMessage							:=	'HANDOVER DEBUG - Shuttle with ID ';
					brsitoa(Internal.Process.Delete.ShuttleID, ADR(Internal.LoggerEntry.ValueString));
					brsstrcat(ADR(Internal.LoggerEntry.LoggerMessage), ADR(Internal.LoggerEntry.ValueString));
					brsstrcat(ADR(Internal.LoggerEntry.LoggerMessage), ADR(' currently in deletion'));
					TSH_WriteLoggerEntry;		
					StatusID													:=	Internal.LoggerEntry.OldStatusID;
				END_IF
				
				(* Disable trigger point *)
				Internal.Process.fbTrgPointEnable.Enable						:=	FALSE;
				
				(* Continue to wait for confirmation *)
				IF NOT(Internal.ErrorCheck.ErrorDetected) THEN			
					Internal.Process.Delete.Step								:=	tshAS_DELETE_SHUTTLE;
				END_IF
				
			ELSIF (Internal.Process.Delete.fbShReadInfo.Error) THEN
				Internal.Process.Delete.Step									:=	tshAS_CHECK_TRIGGER;
				Active															:=	FALSE;
				Error															:=	TRUE;
				StatusID														:=	tshERR_INTERNAL;
				Internal.LoggerEntry.LoggerMessage								:=	'INTERNAL - Error while reading shuttle information for deletion';		
				TSH_WriteLoggerEntry;
				
				Internal.Info.Diagnosis.Valid									:=	TRUE;
				Internal.Info.Diagnosis.Functionblock							:=	'MC_BR_ShReadInfo_AcpTrak';
				Internal.Info.Diagnosis.StatusID       							:=	Internal.Process.Delete.fbShReadInfo.ErrorID;
				
				Internal.Process.Delete.fbShReadInfo.Enable						:=	FALSE;
			END_IF
			
		tshAS_DELETE_SHUTTLE:
			Internal.Process.Delete.fbAsmDeleteShuttle.Axis						:=	ADR(Internal.Process.Delete.ShuttleRef);
			Internal.Process.Delete.fbAsmDeleteShuttle.Command					:=	mcACPTRAK_SH_DELETE_SPECIFIC;
			Internal.Process.Delete.fbAsmDeleteShuttle.AdvancedParameters.SegmentGroup	:=	'';
			Internal.Process.Delete.fbAsmDeleteShuttle.Execute					:=	TRUE;	
			Internal.Process.Delete.fbShReadInfo.Enable							:=	FALSE;
			
			IF (Internal.Process.Delete.fbAsmDeleteShuttle.Done) THEN
				Internal.Process.Delete.fbAsmDeleteShuttle.Execute				:=	FALSE;
					
				Internal.Info.Shuttle.Valid										:=	TRUE;
				Internal.Info.Shuttle.ShuttleRef								:=	Internal.Process.Delete.ShuttleRef;
				Internal.Info.Shuttle.ShuttleID									:=	Internal.Process.Delete.ShuttleID;
				Internal.Info.Shuttle.Action									:=	tshSHUTTLE_ACTION_DELETED;
				
				Internal.Info.HandoverCount										:=	Internal.Info.HandoverCount + 1;
				
				IF (Internal.Configuration.LoggingMode = tshLOGGING_DEBUGGING) THEN
					Internal.LoggerEntry.OldStatusID							:=	StatusID;
					StatusID													:=	tshINFO_INTERNAL;
					Internal.LoggerEntry.LoggerMessage							:=	'HANDOVER DEBUG - Shuttle ';
					brsitoa(Internal.Process.Delete.ShuttleID, ADR(Internal.LoggerEntry.ValueString));
					brsstrcat(ADR(Internal.LoggerEntry.LoggerMessage), ADR(Internal.LoggerEntry.ValueString));
					brsstrcat(ADR(Internal.LoggerEntry.LoggerMessage), ADR(' was successfully deleted'));
					TSH_WriteLoggerEntry;		
					StatusID													:=	Internal.LoggerEntry.OldStatusID;
				END_IF
				
				brsmemset(ADR(Internal.Process.Delete.ShuttleRef),0,SIZEOF(Internal.Process.Delete.ShuttleRef));
				Internal.Process.Delete.ShuttleID								:=	0;
				
				Internal.Process.Delete.Step									:= tshAS_CHECK_TRIGGER;
				
			ELSIF (Internal.Process.Delete.fbAsmDeleteShuttle.Error) THEN
				Internal.Process.Delete.Step									:=	tshAS_CHECK_TRIGGER;
				Active															:=	FALSE;
				Error															:=	TRUE;
				StatusID														:=	tshERR_INTERNAL;
				Internal.LoggerEntry.LoggerMessage								:=	'INTERNAL - Error while deleting a shuttle from the assembly';		
				TSH_WriteLoggerEntry;
				
				Internal.Info.Diagnosis.Valid									:=	TRUE;
				Internal.Info.Diagnosis.Functionblock							:=	'MC_BR_AsmDeleteShuttle_AcpTrak';
				Internal.Info.Diagnosis.StatusID       							:=	Internal.Process.Delete.fbAsmDeleteShuttle.ErrorID;
				
				Internal.Process.Delete.fbAsmDeleteShuttle.Execute				:=	FALSE;
			END_IF			
		  

	END_CASE;
	
END_ACTION

(*################################################################################################################################################*)

(* Call all function blocks, which need to be called cyclically *)
ACTION TSH_AsmSend_ProcessCallFBs:
	Internal.Process.fbAsmReadStatus();
	Internal.Process.fbTrgPointEnable();
	Internal.Barrier.fbBarrierReadInfo();
	Internal.Process.fbReadStatus();
	Internal.Process.fbShReadInfo();
	Internal.Process.fbSecReadInfo();
	Internal.Process.fbSecGetShuttle();
	Internal.Process.fbSecStop();
	Internal.Process.fbSecGetInfo();
	Internal.Process.fbRoutedMoveAbs();
	
	Internal.Process.Delete.fbTrgPointEnable();
	Internal.Process.Delete.fbAsmDeleteShuttle();
	Internal.Process.Delete.fbShReadInfo();
	
	(* Call initialization function blocks here as well *)
	Internal.LoggerEntry.fbCreateUsrLogBook();
	
	(* Call the recovery function blocks here as well *)
	Internal.Recovery.fbReset();
	Internal.Recovery.fbReadStatus();
	Internal.Recovery.fbSecGetShuttle();
	Internal.Recovery.fbRoutedMoveAbs();
	Internal.Recovery.fbAsmDeleteShuttle();
	Internal.Recovery.fbSecStop();
	Internal.Recovery.fbTimer();
	Internal.Recovery.fbErrorCheckTimer();
END_ACTION

(*################################################################################################################################################*)

(* Read an trigger point event and save the shuttle reference (Shuttle is useable, when direction is positive) *)
ACTION TSH_AsmSend_TrgPointGetInfo:
	Internal.Process.fbTrgPointReadInfo.Execute		:=	TRUE;
	Internal.Process.fbTrgPointReadInfo();
	
	IF (Internal.Process.fbTrgPointReadInfo.Done) THEN
		(* Save the shuttle reference for internal use *)
		Internal.Process.ShuttleRef						:=	Internal.Process.fbTrgPointReadInfo.TrgPointInfo.Axis;
					
		(* Check if the shuttle passed in positive direction -> Otherwise shuttle will be ignored *)
		IF (Internal.Process.fbTrgPointReadInfo.TrgPointInfo.Event	=	mcACPTRAK_TP_PASSED_POSITIVE) THEN
			Internal.Process.ShuttleUsable				:=	TRUE;
		ELSE
			Internal.Process.ShuttleUsable				:=	FALSE;
		END_IF
		(* Reset the function block *)
		Internal.Process.fbTrgPointReadInfo.Execute		:=	FALSE;
		Internal.Process.fbTrgPointReadInfo();
	ELSIF (Internal.Process.fbTrgPointReadInfo.Error) THEN
		(* Display an error *)
		Active											:=	FALSE;
		Error											:=	TRUE;
		StatusID										:=	tshERR_INTERNAL;
		Internal.LoggerEntry.LoggerMessage				:=	'INTERNAL - Error while reading trigger point event';	
		TSH_WriteLoggerEntry;
				
		(* Set diagnostic info output *)
		Internal.Info.Diagnosis.Valid					:=	TRUE;
		Internal.Info.Diagnosis.Functionblock			:=	'MC_BR_TrgPointReadInfo_AcpTrak';
		Internal.Info.Diagnosis.StatusID       			:=	Internal.Process.fbTrgPointReadInfo.ErrorID;	(* For diagnostic reasons keep the StatusID of the function block *)
		
		(* Reset the function block *)
		Internal.Process.fbTrgPointReadInfo.Execute		:=	FALSE;
		Internal.Process.fbTrgPointReadInfo();
	END_IF
END_ACTION

(*################################################################################################################################################*)

(* Read an trigger point event and save the shuttle reference (Shuttle is useable, when direction is positive) *)
ACTION TSH_AsmSend_Delete_TrgPointGetInfo:
	Internal.Process.Delete.fbTrgPointReadInfo.Execute	:=	TRUE;
	Internal.Process.Delete.fbTrgPointReadInfo();
	
	IF (Internal.Process.Delete.fbTrgPointReadInfo.Done) THEN
		(* Save the shuttle reference for internal use *)
		Internal.Process.Delete.ShuttleRef				:=	Internal.Process.Delete.fbTrgPointReadInfo.TrgPointInfo.Axis;
		
		(* Reset the function block *)
		Internal.Process.Delete.fbTrgPointReadInfo.Execute	:=	FALSE;
		Internal.Process.Delete.fbTrgPointReadInfo();
	ELSIF (Internal.Process.Delete.fbTrgPointReadInfo.Error) THEN
		(* Display an error *)
		Active											:=	FALSE;
		Error											:=	TRUE;
		StatusID										:=	tshERR_INTERNAL;
		Internal.LoggerEntry.LoggerMessage				:=	'INTERNAL - Error while reading trigger point event';	
		TSH_WriteLoggerEntry;
				
		(* Set diagnostic info output *)
		Internal.Info.Diagnosis.Valid					:=	TRUE;
		Internal.Info.Diagnosis.Functionblock			:=	'MC_BR_TrgPointReadInfo_AcpTrak';
		Internal.Info.Diagnosis.StatusID       			:=	Internal.Process.Delete.fbTrgPointReadInfo.ErrorID;	(* For diagnostic reasons keep the StatusID of the function block *)
		
		(* Reset the function block *)
		Internal.Process.Delete.fbTrgPointReadInfo.Execute	:=	FALSE;
		Internal.Process.Delete.fbTrgPointReadInfo();
	END_IF
END_ACTION

(*################################################################################################################################################*)

(* Handling of the handover pause functionality *)
ACTION TSH_AsmSend_HandoverPauseHandling:
	Internal.Barrier.PauseHandover 						:=	PauseHandover OR Internal.Communication.DataReceive.ProcessCommands.3;
	
	IF (HandoverReady) THEN
		IF (Internal.Barrier.PauseHandover AND NOT(Internal.Barrier.HandoverPaused)) THEN
			TSH_AsmSend_BarrierClose;
		ELSIF (NOT(Internal.Barrier.PauseHandover) AND (Internal.Barrier.HandoverPaused OR Internal.Barrier.HandoverReadyBarrierClosed)) THEN
			(* In case the handover is not paused and the handover becomes ready, open the barrier as well and reset the flag *)
			Internal.Barrier.HandoverReadyBarrierClosed	:= FALSE;
			(* When the handover is ready, open the barrier *)
			TSH_AsmSend_BarrierOpen;
		END_IF
	END_IF
	
	Internal.Barrier.HandoverPaused						:=	Internal.Barrier.PauseHandover;
END_ACTION

(*################################################################################################################################################*)

(* Close the barrier in front of the handover zone *)
ACTION TSH_AsmSend_BarrierClose:
	IF (Internal.Barrier.fbBarrierReadInfo.Valid) THEN
		IF (Internal.Barrier.fbBarrierReadInfo.BarrierInfo.Status <> mcACPTRAK_BARRIER_CLOSED) THEN 
			Internal.Barrier.fbBarrierCommand.Command		:=	mcACPTRAK_BARRIER_CLOSE;
			Internal.Barrier.fbBarrierCommand.Execute		:=	TRUE;
			Internal.Barrier.fbBarrierCommand();
			
			IF (Internal.Barrier.fbBarrierCommand.Done) THEN
				(* Write Info into logger, that barrier changed *)
				IF (Internal.Configuration.LoggingMode >= tshLOGGING_ADVANCED) THEN
					Internal.LoggerEntry.OldStatusID		:=	StatusID;
					StatusID								:=	tshINFO_INTERNAL;	(* For the logger entry set "Internal Info" *)
					Internal.LoggerEntry.LoggerMessage		:=	'BARRIER - The barrier is now closed';
					TSH_WriteLoggerEntry;		
					StatusID								:=	Internal.LoggerEntry.OldStatusID;	(* the "old" error ID should be displayed *)
				END_IF
				(* Reset the function block *)
				Internal.Barrier.fbBarrierCommand.Execute	:=	FALSE;
				Internal.Barrier.fbBarrierCommand();
			ELSIF (Internal.Barrier.fbBarrierCommand.Error) THEN
				(* Write an entry to the logger, that the command was not working *)
				Active										:=	FALSE;
				Error										:=	TRUE;
				StatusID									:=	tshERR_INTERNAL;
				Internal.LoggerEntry.LoggerMessage			:=	'BARRIER - Error while closing the barrier (Details see Motion logger)';
				TSH_WriteLoggerEntry;		
				
				(* Set diagnostic info output *)
				Internal.Info.Diagnosis.Valid				:=	TRUE;
				Internal.Info.Diagnosis.Functionblock		:=	'MC_BR_BarrierCommand_AcpTrak';
				Internal.Info.Diagnosis.StatusID       		:=	Internal.Barrier.fbBarrierCommand.ErrorID;	(* For diagnostic reasons keep the StatusID of the function block *)
				
				(* Reset the function block *)	
				Internal.Barrier.fbBarrierCommand.Execute	:=	FALSE;
				Internal.Barrier.fbBarrierCommand();
			END_IF
		ELSE
			(* Write Info into logger, that barrier changed *)
			IF (Internal.Configuration.LoggingMode = tshLOGGING_DEBUGGING) THEN
				Internal.LoggerEntry.OldStatusID			:=	StatusID;
				StatusID									:=	tshINFO_INTERNAL;	(* For the logger entry set "Internal Info" *)
				Internal.LoggerEntry.LoggerMessage			:=	'BARRIER - The barrier is already closed';
				TSH_WriteLoggerEntry;		
				StatusID									:=	Internal.LoggerEntry.OldStatusID;	(* the "old" error ID should be displayed *)
			END_IF
		END_IF
	ELSIF (Internal.Barrier.fbBarrierReadInfo.Error) THEN
		(* Write Info into logger, that barrier changed *)
		Active										:=	FALSE;
		Error										:=	TRUE;
		StatusID									:=	tshERR_INTERNAL;
		Internal.LoggerEntry.LoggerMessage			:=	'BARRIER - Error while reading the barrier info (Details see Motion logger)';
		TSH_WriteLoggerEntry;		
				
		(* Set diagnostic info output *)
		Internal.Info.Diagnosis.Valid				:=	TRUE;
		Internal.Info.Diagnosis.Functionblock		:=	'MC_BR_BarrierReadInfo_AcpTrak';
		Internal.Info.Diagnosis.StatusID       		:=	Internal.Barrier.fbBarrierReadInfo.ErrorID;	(* For diagnostic reasons keep the StatusID of the function block *)
	END_IF
END_ACTION

(*################################################################################################################################################*)

(* Open the barrier in front of the handover zone *)
ACTION TSH_AsmSend_BarrierOpen:
	IF (Internal.Barrier.fbBarrierReadInfo.Valid) THEN
		IF (Internal.Barrier.fbBarrierReadInfo.BarrierInfo.Status <> mcACPTRAK_BARRIER_OPENED) THEN 
			Internal.Barrier.fbBarrierCommand.Command		:=	mcACPTRAK_BARRIER_OPEN;
			Internal.Barrier.fbBarrierCommand.Execute		:=	TRUE;
			Internal.Barrier.fbBarrierCommand();
			
			IF (Internal.Barrier.fbBarrierCommand.Done) THEN
				(* Write Info into logger, that barrier changed *)
				IF (Internal.Configuration.LoggingMode >= tshLOGGING_ADVANCED) THEN
					Internal.LoggerEntry.OldStatusID		:=	StatusID;
					StatusID								:=	tshINFO_INTERNAL;	(* For the logger entry set "Internal Info" *)
					Internal.LoggerEntry.LoggerMessage		:=	'BARRIER - The barrier is now opened';
					TSH_WriteLoggerEntry;		
					StatusID								:=	Internal.LoggerEntry.OldStatusID;	(* the "old" error ID should be displayed *)
				END_IF
				(* Reset the function block *)
				Internal.Barrier.fbBarrierCommand.Execute	:=	FALSE;
				Internal.Barrier.fbBarrierCommand();
			ELSIF (Internal.Barrier.fbBarrierCommand.Error) THEN
				(* Write an entry to the logger, that the command was not working *)
				Active										:=	FALSE;
				Error										:=	TRUE;
				StatusID									:=	tshERR_INTERNAL;
				Internal.LoggerEntry.LoggerMessage			:=	'BARRIER - Error while opening the barrier (Details see Motion logger)';
				TSH_WriteLoggerEntry;				
				
				(* Set diagnostic info output *)
				Internal.Info.Diagnosis.Valid				:=	TRUE;
				Internal.Info.Diagnosis.Functionblock		:=	'MC_BR_BarrierCommand_AcpTrak';
				Internal.Info.Diagnosis.StatusID       		:=	Internal.Barrier.fbBarrierCommand.ErrorID;	(* For diagnostic reasons keep the StatusID of the function block *)
				
				(* Reset the function block *)
				Internal.Barrier.fbBarrierCommand.Execute	:=	FALSE;
				Internal.Barrier.fbBarrierCommand();
			END_IF
		ELSE
			(* Write Info into logger, that barrier changed *)
			IF (Internal.Configuration.LoggingMode = tshLOGGING_DEBUGGING) THEN
				Internal.LoggerEntry.OldStatusID			:=	StatusID;
				StatusID									:=	tshINFO_INTERNAL;	(* For the logger entry set "Internal Info" *)
				Internal.LoggerEntry.LoggerMessage			:=	'BARRIER - The barrier is already opened';
				TSH_WriteLoggerEntry;		
				StatusID									:=	Internal.LoggerEntry.OldStatusID;	(* the "old" error ID should be displayed *)
			END_IF
		END_IF
	ELSIF (Internal.Barrier.fbBarrierReadInfo.Error) THEN
		(* Write Info into logger, that barrier changed *)
		Active										:=	FALSE;
		Error										:=	TRUE;
		StatusID									:=	tshERR_INTERNAL;
		Internal.LoggerEntry.LoggerMessage			:=	'BARRIER - Error while reading the barrier info (Details see Motion logger)';
		TSH_WriteLoggerEntry;		
				
		(* Set diagnostic info output *)
		Internal.Info.Diagnosis.Valid				:=	TRUE;
		Internal.Info.Diagnosis.Functionblock		:=	'MC_BR_BarrierReadInfo_AcpTrak';
		Internal.Info.Diagnosis.StatusID       		:=	Internal.Barrier.fbBarrierReadInfo.ErrorID;	(* For diagnostic reasons keep the StatusID of the function block *)
	END_IF
END_ACTION

(*################################################################################################################################################*)

(* Add ticktets to the barrier in front of the handover zone *)
ACTION TSH_AsmSend_BarrierAddTickets:
	IF (Internal.Barrier.fbBarrierReadInfo.Valid) THEN
		(* Assign the amount of tickets to the function block -> If there are already tickets on the barrier, reduce the amount to add *)
		Internal.Barrier.fbBarrierCommand.AdvancedParameters.TicketCount	:=	Internal.Barrier.BarrierTickets - Internal.Barrier.fbBarrierReadInfo.BarrierInfo.RemainingTickets;
		(* If tickets should be added or deleted *)
		IF (Internal.Barrier.fbBarrierCommand.AdvancedParameters.TicketCount <> 0) THEN 
			Internal.Barrier.fbBarrierCommand.Command						:=	mcACPTRAK_BARRIER_ADD_TICKETS;
			Internal.Barrier.fbBarrierCommand.Execute						:=	TRUE;
			Internal.Barrier.fbBarrierCommand();
			
			IF (Internal.Barrier.fbBarrierCommand.Done) THEN
				(* Write Info into logger, that barrier changed *)
				IF (Internal.Configuration.LoggingMode >= tshLOGGING_ADVANCED) THEN
					Internal.LoggerEntry.OldStatusID						:=	StatusID;
					StatusID												:=	tshINFO_INTERNAL;	(* For the logger entry set "Internal Info" *)
					Internal.LoggerEntry.LoggerMessage						:=	'BARRIER - Added ';
					brsitoa(Internal.Barrier.fbBarrierCommand.AdvancedParameters.TicketCount, ADR(Internal.LoggerEntry.ValueString));
					brsstrcat(ADR(Internal.LoggerEntry.LoggerMessage), ADR(Internal.LoggerEntry.ValueString));
					brsstrcat(ADR(Internal.LoggerEntry.LoggerMessage), ADR(' ticket(s) to the barrier'));
					IF (Internal.Configuration.LoggingMode = tshLOGGING_DEBUGGING) THEN	(* For debuggin add additional data *)
						brsstrcat(ADR(Internal.LoggerEntry.LoggerMessage), ADR('. The barrier has now '));
						brsitoa(Internal.Barrier.fbBarrierReadInfo.BarrierInfo.RemainingTickets + 1, ADR(Internal.LoggerEntry.ValueString));
						brsstrcat(ADR(Internal.LoggerEntry.LoggerMessage), ADR(Internal.LoggerEntry.ValueString));
						brsstrcat(ADR(Internal.LoggerEntry.LoggerMessage), ADR(' ticket(s)'));
					END_IF
					TSH_WriteLoggerEntry;		
					StatusID												:=	Internal.LoggerEntry.OldStatusID;	(* the "old" error ID should be displayed *)
				END_IF
				(* Reset the function block *)
				Internal.Barrier.fbBarrierCommand.Execute					:=	FALSE;
				Internal.Barrier.fbBarrierCommand();
			ELSIF (Internal.Barrier.fbBarrierCommand.Error) THEN
				(* Write an error to the logger *)
				Active														:=	FALSE;
				Error														:=	TRUE;
				StatusID													:=	tshERR_INTERNAL;
				Internal.LoggerEntry.LoggerMessage							:=	'BARRIER - Error while adding tickets to the barrier (Details see Motion logger)';
				TSH_WriteLoggerEntry;						
				
				(* Set diagnostic info output *)
				Internal.Info.Diagnosis.Valid								:=	TRUE;
				Internal.Info.Diagnosis.Functionblock						:=	'MC_BR_BarrierCommand_AcpTrak';
				Internal.Info.Diagnosis.StatusID       						:=	Internal.Barrier.fbBarrierCommand.ErrorID;	(* For diagnostic reasons keep the StatusID of the function block *)
			
				(* Reset the function block *)
				Internal.Barrier.fbBarrierCommand.Execute					:=	FALSE;
				Internal.Barrier.fbBarrierCommand();
			END_IF
			(* No action has to be done, as ticket count = 0 *)
		ELSE
			(* Write Info into logger, that barrier changed *)
			IF (Internal.Configuration.LoggingMode = tshLOGGING_DEBUGGING) THEN
				Internal.LoggerEntry.OldStatusID							:=	StatusID;
				StatusID													:=	tshINFO_INTERNAL;	(* For the logger entry set "Internal Info" *)
				Internal.LoggerEntry.LoggerMessage							:=	'BARRIER - No tickets were add to the barrier';
				TSH_WriteLoggerEntry;		
				StatusID													:=	Internal.LoggerEntry.OldStatusID;	(* the "old" error ID should be displayed *)
			END_IF
		END_IF
	ELSIF (Internal.Barrier.fbBarrierReadInfo.Error) THEN
		(* Write Info into logger, that barrier changed *)
		Active										:=	FALSE;
		Error										:=	TRUE;
		StatusID									:=	tshERR_INTERNAL;
		Internal.LoggerEntry.LoggerMessage			:=	'BARRIER - Error while reading the barrier info (Details see Motion logger)';
		TSH_WriteLoggerEntry;		
				
		(* Set diagnostic info output *)
		Internal.Info.Diagnosis.Valid				:=	TRUE;
		Internal.Info.Diagnosis.Functionblock		:=	'MC_BR_BarrierReadInfo_AcpTrak';
		Internal.Info.Diagnosis.StatusID       		:=	Internal.Barrier.fbBarrierReadInfo.ErrorID;	(* For diagnostic reasons keep the StatusID of the function block *)
	END_IF
END_ACTION

(*################################################################################################################################################*)

(* This action resets all function blocks, which do need more than 1 cycle *)
ACTION TSH_AsmSend_ResetInDisabled:
	(* Disable all function blocks *)
	Internal.Process.fbTrgPointEnable.Enable	:=	FALSE;
	Internal.Process.fbTrgPointReadInfo.Execute	:=	FALSE;
	Internal.Barrier.fbBarrierReadInfo.Enable	:=	FALSE;
	Internal.Process.fbAsmReadStatus.Enable		:=	FALSE;
	Internal.Process.fbReadStatus.Enable		:=	FALSE;
	Internal.Process.fbShReadInfo.Enable		:=	FALSE;
	Internal.Process.fbSecReadInfo.Enable		:=	FALSE;
	Internal.Process.fbSecGetShuttle.Enable		:=	FALSE;	
	Internal.Process.fbSecStop.Execute			:=	FALSE;
	Internal.Process.fbRoutedMoveAbs.Execute	:=	FALSE;
	
	Internal.Process.Delete.fbTrgPointEnable.Enable		:=	FALSE;
	Internal.Process.Delete.fbAsmDeleteShuttle.Execute	:=	FALSE;
	Internal.Process.Delete.fbShReadInfo.Enable			:=	FALSE;
	
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
	TSH_AsmSend_ProcessCallFBs;
END_ACTION

(*################################################################################################################################################*)

(*Checks, if the current shuttle, which is in the handover is in errorstop *)
ACTION TSH_AsmSend_CurrentShuttleCheck:
	IF (Internal.Process.fbReadStatus.Valid) THEN
		IF (Internal.Process.fbReadStatus.ErrorStop) THEN
			(* Reset the command to add the shuttle on the other assembly *)
			Internal.Communication.DataSend.ProcessCommands.0	:=	FALSE;
			(* Reset the state machine *)
			Internal.Process.Step								:=	tshAS_CHECK_TRIGGER;
			(* Display an error *)
			Active												:=	FALSE;
			Error												:=	TRUE;
			StatusID											:=	tshERR_HANDOVER;
			Internal.LoggerEntry.LoggerMessage					:=	'HANDOVER - The shuttle, which is in the handover is in error stop and can not be processed (Details see motion logger)';		
			TSH_WriteLoggerEntry;	
			(* Reset the function block in case of an error stop *)
			Internal.Process.fbReadStatus.Enable			:=	FALSE;
		END_IF
	ELSIF (Internal.Process.fbReadStatus.Error) THEN
		Internal.Process.Step									:=	tshAS_CHECK_TRIGGER;
		(* Display an error *)
		Active													:=	FALSE;
		Error													:=	TRUE;
		StatusID												:=	tshERR_INTERNAL;
		Internal.LoggerEntry.LoggerMessage						:=	'INTERNAL - Reading the shuttle status is not possible (Details see motion logger)';		
		TSH_WriteLoggerEntry;
				
		(* Set diagnostic info output *)
		Internal.Info.Diagnosis.Valid							:=	TRUE;
		Internal.Info.Diagnosis.Functionblock					:=	'MC_ReadStatus';
		Internal.Info.Diagnosis.StatusID       					:=	Internal.Process.fbReadStatus.ErrorID;	(* For diagnostic reasons keep the StatusID of the function block *)
		
		(* Reset the function block *)
		Internal.Process.fbReadStatus.Enable					:=	FALSE;
	END_IF			
END_ACTION

(*################################################################################################################################################*)

(* React on all kind of errors, which can happen during the handover. (e.g. stop the handover, close the barrer, etc...) *)
ACTION TSH_AsmSend_ErrorReaction:
	(* Reset the error detected flag. If an error is still present, it will be set to true again. Is used for the timer *)	
	Internal.ErrorCheck.ErrorDetected							:=	FALSE;
	
	(* Check always (as soon as communication is valid), if the Assembly Receive is not ready *)
	IF NOT(Internal.Communication.DataReceive.AssemblyStatus.1) AND (Internal.State > tshSTATE_WAIT_COMMUNICATION) THEN		
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
		TSH_AsmSend_ErrorReaction_AssemblyError;
	END_IF
	
	(* Check always (as soon as communication is valid), if the Assembly Send is not ready *)
	IF NOT(Internal.Process.fbAsmReadStatus.AssemblyReady) AND (Internal.State > tshSTATE_WAIT_COMMUNICATION) THEN		
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
		TSH_AsmSend_ErrorReaction_AssemblyError;
	END_IF
	
	(* Check if the Function block Receive is on hold, if the Function block send is in run, on hold or in error *)
	IF (Internal.Communication.DataReceive.ProcessStatus.6) AND (Internal.State > tshSTATE_RECOVERY) THEN
		(* If auto restart is active, suppress this error reaction *)
		IF NOT(Internal.Recovery.AutoRestartActive) THEN		
			(* Log information about the error, which was detected *)
			IF (Internal.Configuration.LoggingMode = tshLOGGING_DEBUGGING) AND NOT(Internal.ErrorCheck.ErrorDetectedOld) THEN
				Internal.LoggerEntry.OldStatusID				:=	StatusID;
				StatusID										:=	tshWRN_INTERNAL;
				Internal.LoggerEntry.LoggerMessage				:=	'ERROR DETECTION - "Function block Receive" is in on hold';
				TSH_WriteLoggerEntry;		
				StatusID										:=	Internal.LoggerEntry.OldStatusID;	(* the "old" error ID should be displayed *)
			END_IF
			(*Reset the string and then set the core logger message for this error *)
			brsmemset(ADR(Internal.LoggerEntry.LoggerMessage),0,SIZEOF(Internal.LoggerEntry.LoggerMessage));
			Internal.LoggerEntry.LoggerMessage					:=	'HANDOVER - The handover is stopped as the "Function block Receive" is on hold';
			(* Use the common assembly error reaction *)
			TSH_AsmSend_ErrorReaction_AssemblyError;
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
	
	(* Check if the Function block Receive is in error, if the Function block send is in run, on hold or in error *)
	IF (Internal.Communication.DataReceive.ProcessStatus.7) AND (Internal.State > tshSTATE_RECOVERY) THEN		
		(* Log information about the error, which was detected *)
		IF (Internal.Configuration.LoggingMode = tshLOGGING_DEBUGGING) AND NOT(Internal.ErrorCheck.ErrorDetectedOld) THEN
			Internal.LoggerEntry.OldStatusID					:=	StatusID;
			StatusID											:=	tshWRN_INTERNAL;
			Internal.LoggerEntry.LoggerMessage					:=	'ERROR DETECTION - "Function block Receive" is in error';
			TSH_WriteLoggerEntry;		
			StatusID											:=	Internal.LoggerEntry.OldStatusID;	(* the "old" error ID should be displayed *)
		END_IF
		(*Reset the string and then set the core logger message for this error *)
		brsmemset(ADR(Internal.LoggerEntry.LoggerMessage),0,SIZEOF(Internal.LoggerEntry.LoggerMessage));
		Internal.LoggerEntry.LoggerMessage						:=	'HANDOVER - The handover is stopped as the "Function block Receive" is in error';
		(* Use the common assembly error reaction *)
		TSH_AsmSend_ErrorReaction_AssemblyError;
	END_IF	
	
	(* Reset the timer every cycle, so when the error is gone, the input is false *)
	Internal.Recovery.fbErrorCheckTimer.IN						:=	FALSE;
	(* Check if the Function block Receive is in error, if the Function block send is in run, on hold or in error *)
	IF (Internal.Communication.DataReceive.ProcessStatus.7) AND (Internal.State = tshSTATE_RECOVERY) THEN
		Internal.Recovery.fbErrorCheckTimer.IN					:=	Internal.Info.Recovery.RecoveryActive OR RecoveryDone;	(* When the recovery is active, it was started on both sides *)
		(* Log information about the error, which was detected *)
		IF (Internal.Configuration.LoggingMode = tshLOGGING_DEBUGGING) AND (Internal.Recovery.fbErrorCheckTimer.Q) AND NOT(Internal.ErrorCheck.ErrorDetectedOld) THEN
			Internal.LoggerEntry.OldStatusID					:=	StatusID;
			StatusID											:=	tshWRN_INTERNAL;
			Internal.LoggerEntry.LoggerMessage					:=	'ERROR DETECTION - "Function block Receive " is in error during Recovery';
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
	
	(* Check always (as soon as communication is valid), if the Function block Receive is disabled *)
	IF NOT(Internal.Communication.DataReceive.ProcessStatus.0) AND (Internal.State > tshSTATE_WAIT_COMMUNICATION) THEN		
		(* Log information about the error, which was detected *)
		IF (Internal.Configuration.LoggingMode = tshLOGGING_DEBUGGING) AND NOT(Internal.ErrorCheck.ErrorDetectedOld) THEN
			Internal.LoggerEntry.OldStatusID					:=	StatusID;
			StatusID											:=	tshWRN_INTERNAL;
			Internal.LoggerEntry.LoggerMessage					:=	'ERROR DETECTION - "Function block Receive" is disabled"';
			TSH_WriteLoggerEntry;		
			StatusID											:=	Internal.LoggerEntry.OldStatusID;	(* the "old" error ID should be displayed *)
		END_IF
		(*Reset the string and then set the core logger message for this error *)
		brsmemset(ADR(Internal.LoggerEntry.LoggerMessage),0,SIZEOF(Internal.LoggerEntry.LoggerMessage));
		Internal.LoggerEntry.LoggerMessage						:=	'HANDOVER - The handover is stopped as the "Function block Receive" is disabled';
		(* Use the common assembly error reaction *)
		TSH_AsmSend_ErrorReaction_AssemblyError;
	END_IF
	
	(* Check for shuttle errors on Assembly Receive, when handover is running *)
	IF (Internal.State = tshSTATE_RUNNING) THEN
		(* If there is an errorstop in- or outside the handover zone *)
		IF (Internal.Communication.DataReceive.ProcessStatus.12) THEN
			(* If the barrier is not closed yet, close it (Needed to not flood the logger in mode debugging, as the barrier will create entries as well) *)
			IF (Internal.Barrier.fbBarrierReadInfo.Valid) AND (Internal.Barrier.fbBarrierReadInfo.BarrierInfo.Status <> mcACPTRAK_BARRIER_CLOSED) THEN
				(* Clear all tickets and close the barrier *)
				TSH_AsmSend_BarrierClose;
			END_IF
			(* Set the error detected flag *)
			Internal.ErrorCheck.ErrorDetected					:=	TRUE;
			(* Reset the handover ready flag *)		
			HandoverReady										:=	FALSE;
			(* Log information about the error, which was detected *)
			IF (Internal.Configuration.LoggingMode = tshLOGGING_DEBUGGING) AND NOT(Internal.ErrorCheck.ErrorDetectedOld) THEN
				Internal.LoggerEntry.OldStatusID				:=	StatusID;
				StatusID										:=	tshWRN_INTERNAL;
				Internal.LoggerEntry.LoggerMessage				:=	'ERROR DETECTION - Shuttle error on "Assembly Receive"';
				TSH_WriteLoggerEntry;		
				StatusID										:=	Internal.LoggerEntry.OldStatusID;
			END_IF			
			(* If there are shuttles on the handover sector on Assembly send, stop them *)
			IF NOT(Internal.Process.NoShuttlesOnSector) THEN
				(* If there is a shuttle in the handover right now, trigger stopping *)
				Internal.Process.fbSecStop.AdvancedParameters.Deceleration	:=	Internal.Communication.DataReceive.ParaDeceleration;
				Internal.Process.fbSecStop.Execute				:=	(Internal.Process.Step > tshAS_CHECK_TRIGGER) AND (Internal.Process.Step < tshAS_WAIT_FOR_CATCH);
				(* When the timer is true, there was no new shuttle for the specified time and handove was stopped properly *)
				IF (Internal.ErrorCheck.fbTimerError.Q) THEN
					(* Recovery needed before restarting the handover *)
					Internal.Recovery.RecoveryNeeded			:=	TRUE;
					(* In state "Error", the output "RecoveryNeeded" must be set as well, without changing the state *)
					IF (Internal.State < tshSTATE_ON_HOLD) THEN
						Internal.State							:=	tshSTATE_ON_HOLD;
				
						(* Give information about the error reaction in advanced mode *)
						IF (Internal.Configuration.LoggingMode > tshLOGGING_BASIC) THEN
							Internal.LoggerEntry.OldStatusID	:=	StatusID;
							StatusID							:=	tshWRN_INTERNAL;
							Internal.LoggerEntry.LoggerMessage	:=	'HANDOVER - The handover is stopped as there are shuttles in error stop on "Assembly Receive" (Shuttles on "Assembly Send")';
							TSH_WriteLoggerEntry;		
							StatusID							:=	Internal.LoggerEntry.OldStatusID;
						END_IF
					END_IF
				END_IF
			ELSE (* If there are no shuttles on the sector, stop handover directly *)
				(* Recovery needed before restarting the handover *)
				Internal.Recovery.RecoveryNeeded				:=	TRUE;
				(* Just change the state, when it's not changed yet *)
				IF (Internal.State < tshSTATE_ON_HOLD) THEN
					Internal.State								:=	tshSTATE_ON_HOLD;				
					(* Give information about the error reaction in advanced mode *)
					IF (Internal.Configuration.LoggingMode > tshLOGGING_BASIC) THEN
						Internal.LoggerEntry.OldStatusID		:=	StatusID;
						StatusID								:=	tshWRN_INTERNAL;
						Internal.LoggerEntry.LoggerMessage		:=	'HANDOVER - The handover is stopped as there are shuttles in error stop on "Assembly Receive" (No shuttles on  "Assembly Send")';
						TSH_WriteLoggerEntry;		
						StatusID								:=	Internal.LoggerEntry.OldStatusID;	(* Warning will not be shown on the output -> Display old StatusID (zero) *)
					END_IF
				END_IF
			END_IF			
		END_IF
	END_IF
	
	(* Check the current shuttle status -> If the status of the current shuttle is not valid, the function block will still react *)
	Internal.ErrorCheck.CurrentShuttleInErrorStop				:=	Internal.Process.fbReadStatus.Valid AND Internal.Process.fbReadStatus.ErrorStop;
	Internal.ErrorCheck.CurrentShuttleDisabled					:=	Internal.Process.fbReadStatus.Valid AND Internal.Process.fbReadStatus.Disabled;
	Internal.ErrorCheck.CurrentShuttleStandstill				:=	Internal.Process.fbReadStatus.Valid AND Internal.Process.fbReadStatus.StandStill;	
		
	(* Check for shuttle errors on Assembly Send, when handover is running *)
	IF (Internal.State = tshSTATE_RUNNING) THEN
		(* Just react, if the current shuttle is not effected *)
		IF (Internal.ErrorCheck.ShuttlesInErrorStop AND NOT(Internal.ErrorCheck.CurrentShuttleInErrorStop) AND (Internal.Process.Step <> tshAS_WAIT_HANDOVER_DONE)) 
			OR (Internal.ErrorCheck.ShuttlesDisabled AND NOT(Internal.ErrorCheck.CurrentShuttleDisabled) AND (Internal.Process.Step <>	tshAS_WAIT_HANDOVER_DONE)) 
			OR (Internal.ErrorCheck.ShuttlesStandstill AND NOT(Internal.ErrorCheck.CurrentShuttleStandstill) AND (Internal.Process.Step <> 	tshAS_WAIT_HANDOVER_DONE)) THEN
			(* If the barrier is not closed yet, close it (Needed to not flood the logger in mode debugging, as the barrier will create entries as well) *)
			IF (Internal.Barrier.fbBarrierReadInfo.Valid) AND (Internal.Barrier.fbBarrierReadInfo.BarrierInfo.Status <> mcACPTRAK_BARRIER_CLOSED) THEN
				(* Clear all tickets and close the barrier *)
				TSH_AsmSend_BarrierClose;
			END_IF
			(* Set the error detected flag *)
			Internal.ErrorCheck.ErrorDetected					:=	TRUE;
			(* Reset the handover ready flag *)		
			HandoverReady										:=	FALSE;	
			(* Log information about the error, which was detected *)
			IF (Internal.Configuration.LoggingMode = tshLOGGING_DEBUGGING) AND NOT(Internal.ErrorCheck.ErrorDetectedOld) THEN
				IF (Internal.ErrorCheck.ShuttlesInErrorStop) THEN
					Internal.LoggerEntry.OldStatusID			:=	StatusID;
					StatusID									:=	tshWRN_INTERNAL;
					Internal.LoggerEntry.LoggerMessage			:=	'ERROR DETECTION - Shuttle(s) in error stop on "Assembly Send", but not the current shuttle';
					TSH_WriteLoggerEntry;		
					StatusID									:=	Internal.LoggerEntry.OldStatusID;
				ELSIF (Internal.ErrorCheck.ShuttlesDisabled) THEN
					Internal.LoggerEntry.OldStatusID			:=	StatusID;
					StatusID									:=	tshWRN_INTERNAL;
					Internal.LoggerEntry.LoggerMessage			:=	'ERROR DETECTION - Disabled shuttle(s) on "Assembly Send", but not the current shuttle';
					TSH_WriteLoggerEntry;		
					StatusID									:=	Internal.LoggerEntry.OldStatusID;
				ELSIF (Internal.ErrorCheck.ShuttlesStandstill) THEN
					Internal.LoggerEntry.OldStatusID			:=	StatusID;
					StatusID									:=	tshWRN_INTERNAL;
					Internal.LoggerEntry.LoggerMessage			:=	'ERROR DETECTION - Shuttle(s) in standstill on "Assembly Send", but not the current shuttle';
					TSH_WriteLoggerEntry;		
					StatusID									:=	Internal.LoggerEntry.OldStatusID;
				END_IF
			END_IF		
			(* If there is a shuttle in the handover right now, trigger stopping *)
			Internal.Process.fbSecStop.AdvancedParameters.Deceleration	:=	Internal.Communication.DataReceive.ParaDeceleration;
			Internal.Process.fbSecStop.Execute					:=	(Internal.Process.Step > tshAS_CHECK_TRIGGER) AND (Internal.Process.Step < tshAS_WAIT_FOR_CATCH);
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
						Internal.LoggerEntry.LoggerMessage		:=	'HANDOVER - The handover is stopped as there are shuttles without an active movement command or in error stop on "Assembly Send"';
						TSH_WriteLoggerEntry;		
						StatusID								:=	Internal.LoggerEntry.OldStatusID;
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
	
	(* Handling of the shuttle stop (MC_Stop) *)
	TSH_AsmSend_ErrorReaction_StopShuttle;
	
	(* Start the timer for error detection, which is needed to ensure no shuttles are passing the trigger point anymore *)
	Internal.ErrorCheck.fbTimerError.IN							:=	Internal.ErrorCheck.ErrorDetected AND (Internal.Process.Step = tshAS_CHECK_TRIGGER);
	Internal.ErrorCheck.fbTimerError.PT							:=	tshERROR_CHECK_TIME;
	(* Call the function block *)
	Internal.ErrorCheck.fbTimerError();
END_ACTION

(*################################################################################################################################################*)

(* Handling the MC_Stop to stop a shuttle, which is currently in the handover. *)
ACTION TSH_AsmSend_ErrorReaction_StopShuttle:
	(* Wait for the response of the function block. This function block is used to stop shuttles during the handover *)
	IF (Internal.Process.fbSecStop.Done) OR (Internal.Process.fbSecStop.Error) OR (Internal.Process.fbSecStop.CommandAborted) THEN	
		(* Reset the function block and the stop flag for the handover *)
		Internal.Process.fbSecStop.Execute					:=	FALSE;	
		(* Reset the process step *)
		Internal.Process.Step								:=	tshAS_CHECK_TRIGGER;
		(* Depending on the result change the state *)
		IF (Internal.Process.fbSecStop.Done) THEN
			(* Write an entry to the logger, that the handover has stopped *)
			Internal.LoggerEntry.OldStatusID				:=	StatusID;
			StatusID										:=	tshWRN_HANDOVER_STOP;
			Internal.LoggerEntry.LoggerMessage				:=	'HANDOVER - The shuttles currently in the handover were stopped due to an error situation';
			TSH_WriteLoggerEntry;		
			StatusID										:=	Internal.LoggerEntry.OldStatusID;
			(* If the handover is not in error or on hold, change to on hold *)
			IF (Internal.State < tshSTATE_ON_HOLD) THEN
				Internal.State								:=	tshSTATE_ON_HOLD;
			END_IF
		ELSIF (Internal.Process.fbSecStop.Error) AND NOT(Error) THEN					
			(* Display an error *)
			Active											:=	FALSE;
			Error											:=	TRUE;
			StatusID										:=	tshERR_INTERNAL;
			Internal.LoggerEntry.LoggerMessage				:=	'INTERNAL - Stopping the shuttles because of a detected error is not possible (Details see motion logger)';		
			TSH_WriteLoggerEntry;
				
			(* Set diagnostic info output *)
			Internal.Info.Diagnosis.Valid					:=	TRUE;
			Internal.Info.Diagnosis.Functionblock			:=	'MC_BR_SecStop_AcpTrak';
			Internal.Info.Diagnosis.StatusID       			:=	Internal.Process.fbSecStop.ErrorID;
		ELSIF (Internal.Process.fbSecStop.CommandAborted) THEN
			(* Give information about the error reaction in debugging mode *)
			IF (Internal.Configuration.LoggingMode = tshLOGGING_DEBUGGING) THEN
				Internal.LoggerEntry.OldStatusID			:=	StatusID;
				StatusID									:=	tshINFO_INTERNAL;
				Internal.LoggerEntry.LoggerMessage			:=	'ERROR REACTION - The stopping of the shuttles currently in the handover was aborted (Details see motion logger)';
				TSH_WriteLoggerEntry;		
				StatusID									:=	Internal.LoggerEntry.OldStatusID;
			END_IF
		END_IF
	END_IF
END_ACTION

(*################################################################################################################################################*)

(* Handles the error reaction for all assembly and functionblock related errors (same procedure *)
ACTION TSH_AsmSend_ErrorReaction_AssemblyError:
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
			
		(* If there are just shuttles on the assembly receive, a recovery is needed, but the handover can be put on hold directly *)
	ELSIF (Internal.Process.NoShuttlesOnSector) AND NOT(Internal.Communication.DataReceive.ProcessStatus.15) THEN
		(* Recovery needed before restarting the handover *)
		Internal.Recovery.RecoveryNeeded				:=	TRUE;
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
					brsstrcat(ADR(Internal.LoggerEntry.LoggerMessage),ADR(' (Shuttles on "Assembly Receive")'));
				END_IF
				TSH_WriteLoggerEntry;		
				StatusID								:=	Internal.LoggerEntry.OldStatusID;
			ELSE				
				(*Reset the string to not interfere with other messages*)
				brsmemset(ADR(Internal.LoggerEntry.LoggerMessage),0,SIZEOF(Internal.LoggerEntry.LoggerMessage));
			END_IF
		END_IF
		
		(* If there are shuttles on the assembly send, a recovery is needed, and it must be ensured no shuttle is passing the trigger point before putting the handover on hold *)
	ELSE
		(* If there is a shuttle in the handover right now, trigger stopping *)
		Internal.Process.fbSecStop.AdvancedParameters.Deceleration	:=	Internal.Communication.DataReceive.ParaDeceleration;
		Internal.Process.fbSecStop.Execute				:=	(Internal.Process.Step > tshAS_CHECK_TRIGGER) AND (Internal.Process.Step < tshAS_WAIT_FOR_CATCH);
		Internal.Recovery.fbSecStop.AdvancedParameters.Deceleration		:=	Internal.Communication.DataReceive.ParaDeceleration;
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
	
	(* If the barrier is not closed yet, close it (Needed to not flood the logger in mode debugging, as the barrier will create entries as well) *)
	IF (Internal.Barrier.fbBarrierReadInfo.Valid) AND (Internal.Barrier.fbBarrierReadInfo.BarrierInfo.Status <> mcACPTRAK_BARRIER_CLOSED) THEN
		(* Clear all tickets and close the barrier *)
		TSH_AsmSend_BarrierClose;
	END_IF
END_ACTION

(*################################################################################################################################################*)

(* Simulate the data receive interface on AsmSend for the simulation mode "STANDALONE" for each error) *)
ACTION TSH_AsmSend_SimulateCommInterface:
	(* Simulate the communication interface *)
	Internal.Communication.DataReceive.AssemblyStatus.1						:=	TRUE;	(* Assembly Ready *)
	Internal.Communication.DataReceive.AssemblyStatus.7						:=	TRUE;	(* POWERLINK communication running *)
	
	Internal.Communication.DataReceive.HeartbeatCount						:=	Internal.Communication.DataSend.HeartbeatCount + 1;	(* Communication heartbeat *)
	
	Internal.Communication.DataReceive.ProcessCommands.3					:=	FALSE;	(* Pause handover *)
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
	Internal.Communication.DataReceive.ProcessStatus.8						:=	Internal.Communication.DataSend.ProcessCommands.0;	(* Shuttle added successfully *)
	Internal.Communication.DataReceive.ProcessStatus.9						:=	FALSE;	(* FREE *)
	Internal.Communication.DataReceive.ProcessStatus.10						:=	FALSE;	(* FREE *)
	Internal.Communication.DataReceive.ProcessStatus.11						:=	FALSE;	(* Recovery needed *)
	Internal.Communication.DataReceive.ProcessStatus.12						:=	FALSE;	(* Shuttle error on AsmReceive *)
	Internal.Communication.DataReceive.ProcessStatus.13						:=	FALSE;	(* FREE *)
	Internal.Communication.DataReceive.ProcessStatus.14						:=	TRUE;	(* Shuttle in handover zone data valid *)
	Internal.Communication.DataReceive.ProcessStatus.15						:=	TRUE;	(* No Shuttles on sector *)
	
	Internal.Communication.DataReceive.RecoveryInfo.ShuttlesInHandoverArea	:=	0;
	Internal.Communication.DataReceive.RecoveryInfo.CurrentZone				:=	Internal.Communication.DataSend.RecoveryInfo.CurrentZone;
END_ACTION

(*################################################################################################################################################*)

(* Simplified Recovery of the AsmSend handover part *)
(* Logic: Move shuttle to sector end (becomes virtual), then delete. *)
(* Shuttle data (UserData, ShuttleInfo) is NOT reset - it's preserved from the original trigger. *)
ACTION TSH_AsmSend_Recovery:
	CASE Internal.Recovery.State OF
		tshRECOVERY_IDLE:
			(* Send status to other assembly *)
			Internal.Communication.DataSend.RecoveryInfo.CurrentZone.0		:=	TRUE;
			(* Disable the process point to not create events during recovery *)
			Internal.Process.fbTrgPointEnable.Enable						:=	FALSE;
			
			(* When both assemblies are in recovery mode AND Receive is ready to catch (CurrentZone.5), start the recovery logic *)
			IF (Internal.Communication.DataSend.ProcessStatus.3) AND (Internal.Communication.DataReceive.ProcessStatus.3) AND (Internal.Communication.DataReceive.RecoveryInfo.CurrentZone.0) AND (Internal.Communication.DataReceive.RecoveryInfo.CurrentZone.5) THEN
				(* Recovery is now active *)					
				Internal.Info.Recovery.RecoveryIdle							:=	FALSE;
				Internal.Info.Recovery.RecoveryActive						:=	TRUE;
				
				(* Start sequential shuttle recovery *)
				Internal.Recovery.State										:=	tshRECOVERY_ZONE_HANDOVER;
				(* Reset flags and sequence step for recovery *)
				Internal.Recovery.ShuttleResetDone							:=	FALSE;
				Internal.RecoverySequence.SequenceStep						:=	0;
			END_IF
			
		tshRECOVERY_ZONE_HANDOVER:
			(* Sequential shuttle recovery: Reset -> Read UserData -> Move -> Signal Receive -> Wait confirmation -> Next *)
			(* Send status to other assembly *)
			Internal.Communication.DataSend.RecoveryInfo.CurrentZone.2		:= TRUE;
			
			CASE Internal.RecoverySequence.SequenceStep OF
				0:	(* Delete virtual shuttles before searching *)
					Internal.Process.Delete.fbAsmDeleteShuttle.Axis							:=	0;
					Internal.Process.Delete.fbAsmDeleteShuttle.Command						:=	mcACPTRAK_SH_DELETE_VIRTUAL;
					Internal.Process.Delete.fbAsmDeleteShuttle.AdvancedParameters.SegmentGroup	:=	'';
					Internal.Process.Delete.fbAsmDeleteShuttle.Execute						:=	TRUE;
					Internal.RecoverySequence.SequenceStep									:= 1;
					
				1: (* Wait for virtual shuttle deletion *)
			
					IF (Internal.Process.Delete.fbAsmDeleteShuttle.Done) THEN
						Internal.Process.Delete.fbAsmDeleteShuttle.Execute					:=	FALSE;
						Internal.Info.Shuttle.Valid											:=	TRUE;
						Internal.Recovery.fbSecGetShuttle.Sector							:= ADR(Sector);
						Internal.Recovery.fbSecGetShuttle.Mode								:= mcACPTRAK_SEARCH_BACKWARD;
						Internal.Recovery.fbSecGetShuttle.AdvancedParameters.SelectionMode 	:= mcACPTRAK_GET_SH_ALL;
						Internal.Recovery.fbSecGetShuttle.AdvancedParameters.StartPosition 	:= 0.0;
						Internal.Recovery.fbSecGetShuttle.AdvancedParameters.EndPosition 	:= 0.0;
						Internal.Recovery.fbSecGetShuttle.Enable							:= TRUE;
						Internal.RecoverySequence.SequenceStep								:= 5;
					
						IF (Internal.Configuration.LoggingMode = tshLOGGING_DEBUGGING) THEN
							Internal.LoggerEntry.OldStatusID								:=	StatusID;
							StatusID														:=	tshINFO_INTERNAL;
							Internal.LoggerEntry.LoggerMessage								:=	'HANDOVER DEBUG - Virtual shuttles were successfully deleted';
							TSH_WriteLoggerEntry;		
							StatusID														:=	Internal.LoggerEntry.OldStatusID;
						END_IF
				
					ELSIF (Internal.Process.Delete.fbAsmDeleteShuttle.Error) THEN				
						Internal.Process.Delete.fbAsmDeleteShuttle.Execute					:= FALSE;
						Active																:= FALSE;
						Error																:= TRUE;
						StatusID															:= tshERR_RECOVERY;
						Internal.LoggerEntry.LoggerMessage									:= 'RECOVERY - Error deleting virtual shuttles';
						TSH_WriteLoggerEntry;
						Internal.Info.Diagnosis.Valid										:= TRUE;
						Internal.Info.Diagnosis.Functionblock								:= 'MC_BR_AsmDeleteShuttle_AcpTrak';
						Internal.Info.Diagnosis.StatusID									:= Internal.Process.Delete.fbAsmDeleteShuttle.ErrorID;
					END_IF			
					
				5:	(* Get shuttle from selector *)
					Internal.Recovery.fbSecGetShuttle();
					
					IF Internal.Recovery.fbSecGetShuttle.Valid AND Internal.Recovery.fbSecGetShuttle.TotalCount <> 0 THEN
						(* Shuttle found - use it *)
						Internal.Process.ShuttleRef							:= Internal.Recovery.fbSecGetShuttle.Axis;
						Internal.Recovery.ShuttleResetDone					:= FALSE;
						Internal.RecoverySequence.SequenceStep				:= 10;
						(* Log *)
						IF (Internal.Configuration.LoggingMode >= tshLOGGING_ADVANCED) THEN
							Internal.LoggerEntry.OldStatusID				:= StatusID;
							StatusID										:= tshINFO_INTERNAL;
							Internal.LoggerEntry.LoggerMessage				:= 'RECOVERY - Processing shuttle for handover';
							TSH_WriteLoggerEntry;		
							StatusID										:= Internal.LoggerEntry.OldStatusID;
						END_IF
					ELSIF Internal.Recovery.fbSecGetShuttle.Valid THEN
						(* No shuttles found - recovery done *)
						Internal.Recovery.fbSecGetShuttle.Enable			:= FALSE;
						Internal.Recovery.State								:= tshRECOVERY_DONE;
					ELSIF Internal.Recovery.fbSecGetShuttle.Error THEN
						(* Error searching *)
						Internal.Recovery.fbSecGetShuttle.Enable			:= FALSE;
						Active												:= FALSE;
						Error												:= TRUE;
						StatusID											:= tshERR_RECOVERY;
						Internal.LoggerEntry.LoggerMessage					:= 'RECOVERY - Error searching for shuttles';
						TSH_WriteLoggerEntry;
					END_IF
					
				10:	(* Step 1: Reset shuttle if in error *)
					IF NOT Internal.Recovery.ShuttleResetDone THEN
						Internal.Recovery.fbReset.Axis						:= ADR(Internal.Process.ShuttleRef);
						Internal.Recovery.fbReset.Execute					:= TRUE;
						Internal.Recovery.fbReset();
						
						IF Internal.Recovery.fbReset.Done OR Internal.Recovery.fbReset.Error THEN
							Internal.Recovery.fbReset.Execute				:= FALSE;
							Internal.Recovery.ShuttleResetDone				:= TRUE;
							Internal.RecoverySequence.SequenceStep			:= 20;
						END_IF
					ELSE
						Internal.RecoverySequence.SequenceStep				:= 20;
					END_IF
					
				20:	(* Step 2: Read UserData from shuttle *)
					(* Copy userdata *)
					TSH_ShuttleCopyUserData;
					Internal.RecoverySequence.SequenceStep					:= 30;
					
				30:	(* Step 3: Start movement to sector end and signal Receive *)
					Internal.Recovery.fbRoutedMoveAbs.Axis					:= ADR(Internal.Process.ShuttleRef);
					Internal.Recovery.fbRoutedMoveAbs.Position				:= Internal.ConfigCheck.SectorLength;
					Internal.Recovery.fbRoutedMoveAbs.Velocity				:= Internal.Communication.DataReceive.ParaVelocity;
					Internal.Recovery.fbRoutedMoveAbs.Acceleration			:= Internal.Communication.DataReceive.ParaAcceleration;
					Internal.Recovery.fbRoutedMoveAbs.Deceleration			:= Internal.Communication.DataReceive.ParaDeceleration;
					Internal.Recovery.fbRoutedMoveAbs.Execute				:= TRUE;
					Internal.Recovery.fbRoutedMoveAbs();
					
					IF Internal.Recovery.fbRoutedMoveAbs.Active THEN
						Internal.Recovery.fbRoutedMoveAbs.Execute			:= FALSE;
						(* Set the add-shuttle command; Standalone Send simulation uses it to emulate the catch confirmation *)
						Internal.Communication.DataSend.ProcessCommands.0	:= TRUE;
						Internal.RecoverySequence.SequenceStep				:= 40;
						(* Log *)
						IF (Internal.Configuration.LoggingMode >= tshLOGGING_ADVANCED) THEN
							Internal.LoggerEntry.OldStatusID				:= StatusID;
							StatusID										:= tshINFO_INTERNAL;
							Internal.LoggerEntry.LoggerMessage				:= 'RECOVERY - Shuttle moving to sector end, signaling Receive';
							TSH_WriteLoggerEntry;		
							StatusID										:= Internal.LoggerEntry.OldStatusID;
						END_IF
					ELSIF Internal.Recovery.fbRoutedMoveAbs.Error THEN
						Internal.Recovery.fbRoutedMoveAbs.Execute			:= FALSE;
						Active												:= FALSE;
						Error												:= TRUE;
						StatusID											:= tshERR_RECOVERY;
						Internal.LoggerEntry.LoggerMessage					:= 'RECOVERY - Error moving shuttle to sector end';
						TSH_WriteLoggerEntry;
						Internal.Info.Diagnosis.Valid						:= TRUE;
						Internal.Info.Diagnosis.Functionblock				:= 'MC_BR_RoutedMoveAbs_AcpTrak';
						Internal.Info.Diagnosis.StatusID					:= Internal.Recovery.fbRoutedMoveAbs.ErrorID;
					END_IF
					
				40:	(* Step 4: Wait for Receive confirmation (ProcessStatus.8) *)
					IF Internal.Communication.DataReceive.ProcessStatus.8 THEN
						(* Receive has caught the shuttle *)
						Internal.Communication.DataSend.ProcessCommands.0	:= FALSE;
						Internal.RecoverySequence.SequenceStep				:= 50;
						(* Log *)
						IF (Internal.Configuration.LoggingMode >= tshLOGGING_ADVANCED) THEN
							Internal.LoggerEntry.OldStatusID				:= StatusID;
							StatusID										:= tshINFO_INTERNAL;
							Internal.LoggerEntry.LoggerMessage				:= 'RECOVERY - Receive confirmed shuttle catch';
							TSH_WriteLoggerEntry;		
							StatusID										:= Internal.LoggerEntry.OldStatusID;
						END_IF
					END_IF
					
				50: (* Step 5: Delete the shuttle *)
					Internal.Process.Delete.fbAsmDeleteShuttle.Axis							:=	ADR(Internal.Process.ShuttleRef);
					Internal.Process.Delete.fbAsmDeleteShuttle.Command						:=	mcACPTRAK_SH_DELETE_SPECIFIC;
					Internal.Process.Delete.fbAsmDeleteShuttle.AdvancedParameters.SegmentGroup	:=	'';
					Internal.Process.Delete.fbAsmDeleteShuttle.Execute						:=	TRUE;	
			
					IF (Internal.Process.Delete.fbAsmDeleteShuttle.Done) THEN
						Internal.Process.Delete.fbAsmDeleteShuttle.Execute					:=	FALSE;
					
						Internal.Info.Shuttle.Valid											:=	TRUE;
						Internal.Info.Shuttle.ShuttleRef									:=	Internal.Process.ShuttleRef;
						Internal.Info.Shuttle.ShuttleID										:=	0;
						Internal.Info.Shuttle.Action										:=	tshSHUTTLE_ACTION_DELETED;
				
						Internal.Info.HandoverCount											:=	Internal.Info.HandoverCount + 1;
				
						IF (Internal.Configuration.LoggingMode = tshLOGGING_DEBUGGING) THEN
							Internal.LoggerEntry.OldStatusID								:=	StatusID;
							StatusID														:=	tshINFO_INTERNAL;
							Internal.LoggerEntry.LoggerMessage								:=	'HANDOVER DEBUG - Shuttle ';
							brsitoa(Internal.Process.Delete.ShuttleID, ADR(Internal.LoggerEntry.ValueString));
							brsstrcat(ADR(Internal.LoggerEntry.LoggerMessage), ADR(Internal.LoggerEntry.ValueString));
							brsstrcat(ADR(Internal.LoggerEntry.LoggerMessage), ADR(' was successfully deleted'));
							TSH_WriteLoggerEntry;		
							StatusID														:=	Internal.LoggerEntry.OldStatusID;
						END_IF
				
						brsmemset(ADR(Internal.Process.ShuttleRef),0,SIZEOF(Internal.Process.ShuttleRef));
				
						Internal.RecoverySequence.SequenceStep								:= 60;
				
					ELSIF (Internal.Process.Delete.fbAsmDeleteShuttle.Error) THEN				
						Internal.Process.Delete.fbAsmDeleteShuttle.Execute					:= FALSE;
						Active																:= FALSE;
						Error																:= TRUE;
						StatusID															:= tshERR_RECOVERY;
						Internal.LoggerEntry.LoggerMessage									:= 'RECOVERY - Error deleting shuttle';
						TSH_WriteLoggerEntry;
						Internal.Info.Diagnosis.Valid										:= TRUE;
						Internal.Info.Diagnosis.Functionblock								:= 'MC_BR_AsmDeleteShuttle_AcpTrak';
						Internal.Info.Diagnosis.StatusID									:= Internal.Process.Delete.fbAsmDeleteShuttle.ErrorID;
					END_IF			
					
				60:	(* Step 6: Confirm to Receive and get next shuttle *)
					Internal.Communication.DataSend.ProcessStatus.8			:= TRUE;
					
					(* Wait for Receive to acknowledge (ProcessStatus.8 goes FALSE) *)
					IF NOT Internal.Communication.DataReceive.ProcessStatus.8 THEN
						Internal.Communication.DataSend.ProcessStatus.8		:= FALSE;
						Internal.Info.HandoverCount							:= Internal.Info.HandoverCount + 1;
						
						(* Check for more shuttles *)
						Internal.Recovery.fbSecGetShuttle.Next				:= TRUE;
						Internal.Recovery.fbSecGetShuttle();
						
						IF Internal.Recovery.fbSecGetShuttle.Valid AND Internal.Recovery.fbSecGetShuttle.RemainingCount <> 0 THEN
							(* More shuttles - process next *)
							Internal.Process.ShuttleRef						:= Internal.Recovery.fbSecGetShuttle.Axis;
							Internal.Recovery.fbSecGetShuttle.Next			:= FALSE;
							Internal.Recovery.ShuttleResetDone				:= FALSE;
							Internal.RecoverySequence.SequenceStep			:= 10;
						ELSE
							(* No more shuttles - done *)
							Internal.Recovery.fbSecGetShuttle.Enable		:= FALSE;
							Internal.Recovery.fbSecGetShuttle.Next			:= FALSE;
							Internal.Recovery.State							:= tshRECOVERY_DONE;
							(* Log *)
							IF (Internal.Configuration.LoggingMode >= tshLOGGING_ADVANCED) THEN
								Internal.LoggerEntry.OldStatusID			:= StatusID;
								StatusID									:= tshINFO_INTERNAL;
								Internal.LoggerEntry.LoggerMessage			:= 'RECOVERY - All shuttles processed';
								TSH_WriteLoggerEntry;		
								StatusID									:= Internal.LoggerEntry.OldStatusID;
							END_IF
						END_IF
					END_IF
			END_CASE
			
		tshRECOVERY_DONE:			
			(* Send status to other assembly *)
			Internal.Communication.DataSend.RecoveryInfo.CurrentZone.4		:=	TRUE;
			Internal.Communication.DataSend.ProcessStatus.4					:=	TRUE;
			
			(* Wait for both sides to be finished *)
			IF (Internal.Communication.DataReceive.RecoveryInfo.CurrentZone.4 OR Internal.Communication.DataReceive.ProcessStatus.4) THEN
				(* The recovery finished successfully *)
				RecoveryBusy												:=	FALSE;					
				Internal.Info.Recovery.RecoveryActive						:=	FALSE;
				RecoveryDone												:=	TRUE;
			END_IF
		
	END_CASE
END_ACTION