(*********************************************************************************
 * Copyright: B&R Industrial Automation GmbH 
 * Author:    B&R CD - CPE 
 * Created:   December 17, 2020
 *
 * Description:
 * - Common actions, which can be used in both function blocks
 *
 * Actions (Right click on the action name -> "Go to Implementation", to jump to the code):
 * - TSH_InitializeLogbook
 * - TSH_InitializeLogbookFailed
 * - TSH_WriteLoggerEntry
 * - TSH_CopyConfig
 * - TSH_CheckCommonInputs
 * - TSH_CheckCommonConfig
 * - TSH_CheckCommTimeout
 * - TSH_CheckSystem
 * - TSH_CheckResponseTimeout
 * - TSH_CheckForShuttles
 * - TSH_HandoverMonitoring
 * - TSH_ShuttleCopyUserData
 * - TSH_CheckVersions
 * - TSH_Recovery_ErrorReset
 * - TSH_CheckRecoveryPossible
 * - TSH_ResetHandoverAreaMonitoring
 *********************************************************************************)

(*Get Ident of system user logbook or create the logbook*)
ACTION TSH_InitializeLogbook:
	(* To still be able to enter logger entries, check which logbook can be used *)
	IF (Internal.Configuration.LogbookType = tshLOGBOOK_USE_USERDEFINED AND NOT(Internal.Configuration.LogbookName = '')) THEN
		Internal.LoggerEntry.fbGetUsrLogIdent.Name			:=	Internal.Configuration.LogbookName;
	ELSE
		Internal.LoggerEntry.fbGetUsrLogIdent.Name			:=	'$$arlogusr'; (* System user logbook *)
	END_IF
	
	Internal.LoggerEntry.fbGetUsrLogIdent.Execute			:=	TRUE;		
	Internal.LoggerEntry.fbGetUsrLogIdent();
	
	IF (Internal.LoggerEntry.fbGetUsrLogIdent.Done) THEN
		(* The initialization of the function block can move on *)
		Internal.LoggerEntry.Initialized					:=	TRUE;
		(* Save the Ident for writing logger entries *)
		Internal.LoggerEntry.fbWriteUsrLogEntry.Ident		:=	Internal.LoggerEntry.fbGetUsrLogIdent.Ident;
		(* Reset the function block *)
		Internal.LoggerEntry.fbGetUsrLogIdent.Execute		:=	FALSE;		
		Internal.LoggerEntry.fbGetUsrLogIdent();
		
	ELSIF (Internal.LoggerEntry.fbGetUsrLogIdent.Error AND Internal.LoggerEntry.fbGetUsrLogIdent.StatusID = arEVENTLOG_ERR_LOGBOOK_NOT_FOUND 
		AND Internal.Configuration.LogbookType = tshLOGBOOK_USE_USERDEFINED AND NOT(Internal.Configuration.LogbookName = '')) THEN
		(* Userdefined logbook is not yet existing, so trigger the creation of it (Wait with the reset of the GetIdent FB)*)
		Internal.LoggerEntry.fbCreateUsrLogBook.Name		:=	Internal.Configuration.LogbookName;
		Internal.LoggerEntry.fbCreateUsrLogBook.Persistence	:=	arEVENTLOG_PERSISTENCE_PERSIST;
		Internal.LoggerEntry.fbCreateUsrLogBook.Size		:=	tshLOGBOOK_DEFAULT_SIZE;
		Internal.LoggerEntry.fbCreateUsrLogBook.Execute		:=	TRUE;
		
	ELSIF (Internal.LoggerEntry.fbGetUsrLogIdent.Error) THEN
		(* Save the StatusID in case of an error *)
		Active												:=	FALSE;
		Error												:=	TRUE;
		StatusID											:=	tshERR_INTERNAL;
		(* Set the info output *)
		Internal.Info.Diagnosis.Valid						:=	TRUE;
		Internal.Info.Diagnosis.Functionblock				:=	'ArEventLogGetIdent';
		Internal.Info.Diagnosis.StatusID					:=	Internal.LoggerEntry.fbGetUsrLogIdent.StatusID;
		(* Reset the function block *)
		Internal.LoggerEntry.fbGetUsrLogIdent.Execute		:=	FALSE;		
		Internal.LoggerEntry.fbGetUsrLogIdent();
	END_IF
	
	(* FB is working asynchronous, so it takes multiple cycles to create a logbook *)
	IF (Internal.LoggerEntry.fbCreateUsrLogBook.Done) THEN
		(* The initialization of the function block can move on *)
		Internal.LoggerEntry.Initialized					:=	TRUE;
		(* Save the Ident for writing logger entries *)
		Internal.LoggerEntry.fbWriteUsrLogEntry.Ident		:=	Internal.LoggerEntry.fbCreateUsrLogBook.Ident;
		(* Reset the function block *)
		Internal.LoggerEntry.fbCreateUsrLogBook.Execute		:=	FALSE;
		(* Reset the function block *)
		Internal.LoggerEntry.fbGetUsrLogIdent.Execute		:=	FALSE;		
		Internal.LoggerEntry.fbGetUsrLogIdent();
		
	ELSIF (Internal.LoggerEntry.fbCreateUsrLogBook.Error) THEN
		(* Save the StatusID in case of an error *)
		Active												:=	FALSE;
		Error												:=	TRUE;
		StatusID											:=	tshERR_INTERNAL;
		(* Set the info output *)
		Internal.Info.Diagnosis.Valid						:=	TRUE;
		Internal.Info.Diagnosis.Functionblock				:=	'ArEventLogCreate';
		Internal.Info.Diagnosis.StatusID					:=	Internal.LoggerEntry.fbCreateUsrLogBook.StatusID;
		(* Reset the function block *)
		Internal.LoggerEntry.fbCreateUsrLogBook.Execute		:=	FALSE;
		(* Reset the function block *)
		Internal.LoggerEntry.fbGetUsrLogIdent.Execute		:=	FALSE;		
		Internal.LoggerEntry.fbGetUsrLogIdent();
		(* Provide info to the user if possible, what happened *)
		TSH_InitializeLogbookFailed;
	END_IF
	
	(* Set common logbook settings, which need to be set just once *)
	Internal.LoggerEntry.fbWriteUsrLogEntry.AddData			:=	ADR(Internal.LoggerEntry.LoggerMessage);
	Internal.LoggerEntry.fbWriteUsrLogEntry.AddDataFormat	:=	arEVENTLOG_ADDFORMAT_TEXT;
END_ACTION

(*################################################################################################################################################*)

(*If the initialization failed, write an entry to the system user logbook*)
ACTION TSH_InitializeLogbookFailed:
	(* Get the ident of the system user logbook to enter an error for the user*)
	Internal.LoggerEntry.fbGetUsrLogIdent.Name			:=	'$$arlogusr'; (* System user logbook *)	
	Internal.LoggerEntry.fbGetUsrLogIdent.Execute		:=	TRUE;		
	Internal.LoggerEntry.fbGetUsrLogIdent();
	IF (Internal.LoggerEntry.fbGetUsrLogIdent.Done) THEN
		(* The initialization of the function block can move on *)
		Internal.LoggerEntry.LogbookCreateError			:=	TRUE;
		(* Save the Ident for writing logger entries *)
		Internal.LoggerEntry.fbWriteUsrLogEntry.Ident	:=	Internal.LoggerEntry.fbGetUsrLogIdent.Ident;
		(* Provide a logger message for the user, which will be entered to the system user logbook *)
		CASE Internal.LoggerEntry.fbCreateUsrLogBook.StatusID OF
			arEVENTLOG_ERR_NAME_INVALID:
				Internal.LoggerEntry.LoggerMessage		:=	'LOGBOOK - arEVENTLOG_ERR_NAME_INVALID - Check the naming (Name was "';
				brsstrcat(ADR(Internal.LoggerEntry.LoggerMessage),ADR(Internal.LoggerEntry.fbCreateUsrLogBook.Name));
				brsstrcat(ADR(Internal.LoggerEntry.LoggerMessage),ADR('")'));
				
			arEVENTLOG_ERR_SIZE_INVALID:
				Internal.LoggerEntry.LoggerMessage		:=	'LOGBOOK - arEVENTLOG_ERR_SIZE_INVALID - Check the size (Size was ';
				brsitoa(Internal.LoggerEntry.fbCreateUsrLogBook.Size ,ADR(Internal.LoggerEntry.ValueString));
				brsstrcat(ADR(Internal.LoggerEntry.LoggerMessage),ADR(Internal.LoggerEntry.ValueString));
				brsstrcat(ADR(Internal.LoggerEntry.LoggerMessage),ADR(' Byte)'));
				
			arEVENTLOG_ERR_PERSISTENCE_INVAL:
				Internal.LoggerEntry.LoggerMessage		:=	'LOGBOOK - arEVENTLOG_ERR_PERSISTENCE_INVAL - Check the persistence (Value was ';
				brsitoa(Internal.LoggerEntry.fbCreateUsrLogBook.Persistence ,ADR(Internal.LoggerEntry.ValueString));
				brsstrcat(ADR(Internal.LoggerEntry.LoggerMessage),ADR(Internal.LoggerEntry.ValueString));
				brsstrcat(ADR(Internal.LoggerEntry.LoggerMessage),ADR(')'));
				
			arEVENTLOG_ERR_LOGBOOK_EXISTS:
				Internal.LoggerEntry.LoggerMessage		:=	'LOGBOOK - arEVENTLOG_ERR_LOGBOOK_EXISTS - The logbook already exists (Name was "';
				brsstrcat(ADR(Internal.LoggerEntry.LoggerMessage),ADR(Internal.LoggerEntry.fbCreateUsrLogBook.Name));
				brsstrcat(ADR(Internal.LoggerEntry.LoggerMessage),ADR('")'));
				
			arEVENTLOG_ERR_MODULE_EXISTS:
				Internal.LoggerEntry.LoggerMessage		:=	'LOGBOOK - arEVENTLOG_ERR_MODULE_EXISTS - A BR-module with the same name already exists (Name was "';
				brsstrcat(ADR(Internal.LoggerEntry.LoggerMessage),ADR(Internal.LoggerEntry.fbCreateUsrLogBook.Name));
				brsstrcat(ADR(Internal.LoggerEntry.LoggerMessage),ADR('")'));
				
			ELSE
				Internal.LoggerEntry.LoggerMessage		:=	'LOGBOOK - ERROR - An unspecified error happened during creation of the logbook';
				
		END_CASE
	END_IF
	(* Reset the function block *)
	Internal.LoggerEntry.fbGetUsrLogIdent.Execute		:=	FALSE;		
	Internal.LoggerEntry.fbGetUsrLogIdent();
END_ACTION

(*################################################################################################################################################*)

(*Write an entry to the system user logbookd*)
ACTION TSH_WriteLoggerEntry:
	(* The EventID might be different with every entry *)
	Internal.LoggerEntry.fbWriteUsrLogEntry.EventID			:=	StatusID;
	(* The actual string size is taken to save memory (+1 because of 0-termination byte "\0")*)
	Internal.LoggerEntry.fbWriteUsrLogEntry.AddDataSize		:=	brsstrlen(ADR(Internal.LoggerEntry.LoggerMessage)) + 1;
	(* Create a logger entry only, if the logger is initialized or the system user logger can be used after creation failed. Otherwise it will overwrite another error *)
	Internal.LoggerEntry.fbWriteUsrLogEntry.Execute			:=	Internal.LoggerEntry.Initialized OR Internal.LoggerEntry.LogbookCreateError;	
	Internal.LoggerEntry.fbWriteUsrLogEntry();
	
	IF (Internal.LoggerEntry.fbWriteUsrLogEntry.Done) THEN
		(* Reset additional error info *)
		brsmemset(ADR(Internal.LoggerEntry.LoggerMessage), 0, SIZEOF(Internal.LoggerEntry.LoggerMessage));
		(* Reset command to create logbook entry *)
		Internal.LoggerEntry.fbWriteUsrLogEntry.Execute		:=	FALSE;
		(* Function block call *)
		Internal.LoggerEntry.fbWriteUsrLogEntry();
	ELSIF (Internal.LoggerEntry.fbWriteUsrLogEntry.Error) THEN
		(* Save the StatusID of the function block to display it on the output for diagnosis and keept the last logger message for the functional error*)
		Active												:=	FALSE;
		Error												:=	TRUE;
		StatusID											:=	tshERR_INTERNAL;
		(* Set the info output *)
		Internal.Info.Diagnosis.Valid						:=	TRUE;
		Internal.Info.Diagnosis.Functionblock				:=	'ArEventLogWrite';
		Internal.Info.Diagnosis.StatusID					:=	Internal.LoggerEntry.fbWriteUsrLogEntry.StatusID;
		(* Set command to write logbook entry *)
		Internal.LoggerEntry.fbWriteUsrLogEntry.Execute		:=	FALSE;
		(* Function block call *)
		Internal.LoggerEntry.fbWriteUsrLogEntry();
	END_IF;
END_ACTION

(*################################################################################################################################################*)

(*Copy the configuration values from the external variable to an internal buffer*)
ACTION TSH_CopyConfig:
	(* Just need to check, if there was no error before *)
	IF NOT(Error) AND NOT(ADR(Configuration) = 0) AND NOT(Internal.ConfigCheck.CopyDone) THEN
		(* Copy configuration data to internal structure *)
		brsmemcpy(ADR(Internal.Configuration), ADR(Configuration), SIZEOF(Internal.Configuration));
		(* Only copy config values once during INIT*)
		Internal.ConfigCheck.CopyDone	:=	TRUE;
	END_IF
END_ACTION

(*################################################################################################################################################*)

(*Check common inputs of the function blocks (specific ones are checked in the FUB)*)
ACTION TSH_CheckCommonInputs:
	(* Just need to check, if there was no error before *)
	IF NOT(Error) THEN
		(* Common Inputs of the function blocks *)
		IF (ADR(Assembly) = 0) THEN
			Active									:=	FALSE;
			Error									:=	TRUE;
			StatusID								:=	tshERR_NO_ASM_REF;
			Internal.LoggerEntry.LoggerMessage		:=	'INPUT - No assembly connected to the function block';
		ELSIF (ADR(Sector) = 0) THEN
			Active									:=	FALSE;
			Error									:=	TRUE;
			StatusID								:=	tshERR_NO_SEC_REF;
			Internal.LoggerEntry.LoggerMessage		:=	'INPUT - No sector connected to the function block';
		ELSIF (ADR(Configuration) = 0) THEN
			Active									:=	FALSE;
			Error									:=	TRUE;
			StatusID								:=	tshERR_NO_CONFIG_REF;
			Internal.LoggerEntry.LoggerMessage		:=	'INPUT - No configuration structure connected to the function block';
		END_IF
	END_IF
END_ACTION

(*################################################################################################################################################*)

(*Check common configuration parameter of the function block*)
ACTION TSH_CheckCommonConfig:
	(* Just need to check, if there was no error before *)
	IF NOT(Error) THEN
		(* Reading the length of the sector for configration parameter check *)
		Internal.ConfigCheck.fbSecGetInfo.Execute			:=	TRUE;
		Internal.ConfigCheck.fbSecGetInfo.Sector			:=	ADR(Sector);
		Internal.ConfigCheck.fbSecGetInfo();	
		
		(* Execution was successful *)
		IF (Internal.ConfigCheck.fbSecGetInfo.Done) THEN
			(* Save the sector data for later use *)
			Internal.ConfigCheck.SectorLength				:=	Internal.ConfigCheck.fbSecGetInfo.SectorInfo.Length;
			Internal.ConfigCheck.SectorName					:=	Internal.ConfigCheck.fbSecGetInfo.SectorInfo.Name;
			(* Reset function block *)
			Internal.ConfigCheck.fbSecGetInfo.Execute		:=	FALSE;
			Internal.ConfigCheck.fbSecGetInfo();
			
			IF (Internal.Configuration.LoggingMode < tshLOGGING_BASIC) OR (Internal.Configuration.LoggingMode > tshLOGGING_DEBUGGING) THEN (* Wrong debugging mode was selected *)
				Active										:=	FALSE;
				Error										:=	TRUE;
				StatusID									:=	tshERR_CONFIG_VALUE;
				Internal.LoggerEntry.LoggerMessage			:=	'CONFIG - The selected logging mode is not supported';
			END_IF
			IF (Internal.Configuration.Simulation.ModeForArSim = tshSIM_MODE_NORMAL_OPERATION) THEN (* Wrong simulation mode was selected *)
				Active										:=	FALSE;
				Error										:=	TRUE;
				StatusID									:=	tshERR_CONFIG_VALUE;
				Internal.LoggerEntry.LoggerMessage			:=	'CONFIG - The simulation mode "tshSIM_MODE_NORMAL_OPERATION" is not supported with ArSim';
			END_IF
			IF (Internal.Configuration.Simulation.ModeForArSim < tshSIM_MODE_STANDALONE) THEN (* Wrong simulation mode was selected *)
				Active										:=	FALSE;
				Error										:=	TRUE;
				StatusID									:=	tshERR_CONFIG_VALUE;
				Internal.LoggerEntry.LoggerMessage			:=	'CONFIG - Unknown simulation mode selected for ArSim';	
			END_IF
			IF (Internal.Configuration.Simulation.ModeForSimOnPLC > tshSIM_MODE_STANDALONE) OR (Internal.Configuration.Simulation.ModeForSimOnPLC < tshSIM_MODE_NORMAL_OPERATION) THEN (* Wrong simulation mode was selected *)
				Active										:=	FALSE;
				Error										:=	TRUE;
				StatusID									:=	tshERR_CONFIG_VALUE;
				Internal.LoggerEntry.LoggerMessage			:=	'CONFIG - Unknown simulation mode selected for SimOnPLC';	
			END_IF			
		ELSIF (Internal.ConfigCheck.fbSecGetInfo.Error) THEN
			(* Write an entry to the logger and give information to the info structure *)
			Active											:=	FALSE;
			Error											:=	TRUE;
			StatusID										:=	tshERR_INTERNAL;
			Internal.LoggerEntry.LoggerMessage				:=	'INTERNAL - Reading sector length not possible (Details see Motion Logger)';
			
			Internal.Info.Diagnosis.Valid					:=	TRUE;
			Internal.Info.Diagnosis.Functionblock			:=	'MC_BR_SecGetInfo_AcpTrak';
			Internal.Info.Diagnosis.StatusID       			:=	Internal.ConfigCheck.fbSecGetInfo.ErrorID;	(* For diagnostic reasons keep the StatusID of the function block *)
			
			(* Reset the function block *)
			Internal.ConfigCheck.fbSecGetInfo.Execute		:=	FALSE;
			Internal.ConfigCheck.fbSecGetInfo();
		END_IF
	END_IF
END_ACTION

(*################################################################################################################################################*)

(*Check the POWERLINK Communication*)
ACTION TSH_CheckCommTimeout:
	(* Sent heartbeat signal is inverted received heartbeat signal *)
	IF (Internal.TimeoutCheck.IncreaseHeartbeat) THEN
		Internal.Communication.DataSend.HeartbeatCount	:=	Internal.Communication.DataReceive.HeartbeatCount + 1;		
	ELSE
		Internal.Communication.DataSend.HeartbeatCount	:=	Internal.Communication.DataReceive.HeartbeatCount;
	END_IF
	
	(* Check, if heartbeat signal changed from previous cycle -> Other side must be enabled as well, otherwise there is no communication *)
	IF (Internal.Communication.DataReceive.HeartbeatCount <> Internal.TimeoutCheck.OldHeartbeatCount) AND (Internal.State > tshSTATE_WAIT_COMMUNICATION) THEN
		Internal.TimeoutCheck.MissedCycles				:=	0;		
	ELSIF NOT(Internal.TimeoutCheck.TimedOut) THEN
		Internal.TimeoutCheck.MissedCycles				:=	Internal.TimeoutCheck.MissedCycles + 1;
	END_IF	
	
	Internal.TimeoutCheck.TimedOut						:= (Internal.TimeoutCheck.MissedCycles > tshCOMMUNICATION_TIMEOUT_CYCLES);
	
	IF (Internal.TimeoutCheck.TimedOut) AND NOT(Error) THEN
		(* Display an error and give information to the logger *)
		Active											:=	FALSE;
		Error											:=	TRUE;
		StatusID										:=	tshERR_COMMUNICATION_TIMEOUT;
		Internal.LoggerEntry.LoggerMessage				:=	'COMMUNICATION - POWERLINK communication between PLCs timed out after ';
		brsftoa(UDINT_TO_REAL(Internal.SystemCheck.CycleTime * tshCOMMUNICATION_TIMEOUT_CYCLES) /1000, ADR(Internal.LoggerEntry.ValueString));
		brsstrcat(ADR(Internal.LoggerEntry.LoggerMessage), ADR(Internal.LoggerEntry.ValueString));
		brsstrcat(ADR(Internal.LoggerEntry.LoggerMessage), ADR(' ms'));
		TSH_WriteLoggerEntry;
	END_IF
	
	Internal.TimeoutCheck.OldHeartbeatCount				:=	Internal.Communication.DataReceive.HeartbeatCount;
END_ACTION

(*################################################################################################################################################*)

(*Check the cycle time, if it's small enough*)
ACTION TSH_CheckSystem:
	IF NOT(Error) THEN
		Internal.SystemCheck.fbRTInfo.enable			:=	TRUE;
		Internal.SystemCheck.fbRTInfo();
	
		IF (Internal.SystemCheck.fbRTInfo.status = ERR_OK) THEN
			(* Save cycle time for later use *)
			Internal.SystemCheck.CycleTime				:=	Internal.SystemCheck.fbRTInfo.cycle_time;
		
			IF (Internal.SystemCheck.CycleTime > tshMAXIMUM_CYCLE_TIME) THEN
				(* Display an error and give information to the logger *)
				Active									:=	FALSE;
				Error									:=	TRUE;
				StatusID								:=	tshERR_INTERNAL;
				Internal.LoggerEntry.LoggerMessage		:=	'SYSTEM - Cycle time of the task class, the function block is used in, is too high (Cycle time must be smaller than ';
				brsitoa(tshMAXIMUM_CYCLE_TIME/1000, ADR(Internal.LoggerEntry.ValueString));
				brsstrcat(ADR(Internal.LoggerEntry.LoggerMessage), ADR(Internal.LoggerEntry.ValueString));
				brsstrcat(ADR(Internal.LoggerEntry.LoggerMessage), ADR('ms)'));
			END_IF
		ELSIF (Internal.SystemCheck.fbRTInfo.status = ERR_FUB_BUSY) OR (Internal.SystemCheck.fbRTInfo.status = ERR_FUB_ENABLE_FALSE) THEN
			(* Busy or not enabled *)
		ELSE
			(* Display an error and give information to the logger *)
			Active										:=	FALSE;
			Error										:=	TRUE;
			StatusID									:=	tshERR_INTERNAL;
			Internal.LoggerEntry.LoggerMessage			:=	'INTERNAL - Reading the cycle time not possible';
			
			(* Set diagnostic info output *)
			Internal.Info.Diagnosis.Valid				:=	TRUE;
			Internal.Info.Diagnosis.Functionblock		:=	'RTInfo';
			Internal.Info.Diagnosis.StatusID       		:=	Internal.SystemCheck.fbRTInfo.status;	(* For diagnostic reasons keep the StatusID of the function block *)
		END_IF
		(* Reset the function block *)
		Internal.SystemCheck.fbRTInfo.enable			:=	FALSE;
		Internal.SystemCheck.fbRTInfo();
		
		(* Check for Simulation *)
		Internal.Simulation.ArSim						:=	DiagCpuIsSimulated();
		
		Internal.Simulation.fbAsmGetInfo.Assembly		:=	ADR(Assembly);
		Internal.Simulation.fbAsmGetInfo.Execute		:=	TRUE;		
		Internal.Simulation.fbAsmGetInfo();
		
		IF (Internal.Simulation.fbAsmGetInfo.Done) THEN
			Internal.Simulation.SimOnPLC				:=	(Internal.Simulation.fbAsmGetInfo.AssemblyInfo.SimulationOnPlcMode = mcACPTRAK_SIM_STATE_ON);
		ELSIF (Internal.Simulation.fbAsmGetInfo.Error) THEN
			(* Display an error and give information to the logger *)
			Active										:=	FALSE;
			Error										:=	TRUE;
			StatusID									:=	tshERR_INTERNAL;
			Internal.LoggerEntry.LoggerMessage			:=	'INTERNAL - Reading the assembly information is not possible';
			
			(* Set diagnostic info output *)
			Internal.Info.Diagnosis.Valid				:=	TRUE;
			Internal.Info.Diagnosis.Functionblock		:=	'MC_BR_AsmGetInfo_AcpTrak';
			Internal.Info.Diagnosis.StatusID       		:=	Internal.Simulation.fbAsmGetInfo.ErrorID;	(* For diagnostic reasons keep the StatusID of the function block *)
		END_IF
		
		(* Reset the function block *)
		Internal.Simulation.fbAsmGetInfo.Execute		:=	FALSE;		
		Internal.Simulation.fbAsmGetInfo();	
		
		IF NOT(Error) THEN
			(* Save current Status ID *)
			Internal.LoggerEntry.OldStatusID			:=	StatusID;
			StatusID									:=	tshWRN_SIMULATION;
			
			IF (Internal.Simulation.ArSim) THEN
				(* Simulation on ArSim / simulated CPU *)
				Internal.Simulation.UsedMode			:=	Internal.Configuration.Simulation.ModeForArSim;
				Internal.Info.Simulation.Mode			:=	Internal.Simulation.UsedMode;
				Internal.Info.Simulation.Type			:=	tshSIM_TYPE_AR_SIM;				
				(* Create a logger entry *)
				Internal.LoggerEntry.LoggerMessage		:=	'SIMULATION - Simulation on ARsim / simulated PLC is active';
				TSH_WriteLoggerEntry;				
			ELSIF (Internal.Simulation.SimOnPLC) THEN
				(* Simulation on PLC with simulated segments *)
				Internal.Simulation.UsedMode			:=	Internal.Configuration.Simulation.ModeForSimOnPLC;
				Internal.Info.Simulation.Mode			:=	Internal.Simulation.UsedMode;
				Internal.Info.Simulation.Type			:=	tshSIM_TYPE_SIM_ON_PLC;			
				(* Create a logger entry *)
				Internal.LoggerEntry.LoggerMessage		:=	'SIMULATION - Segments simulation on PLC is active';	
				TSH_WriteLoggerEntry;
			ELSE
				(* No simulation *)
				Internal.Simulation.UsedMode			:=	tshSIM_MODE_NORMAL_OPERATION;
				Internal.Info.Simulation.Mode			:=	Internal.Simulation.UsedMode;
				Internal.Info.Simulation.Type			:=	tshSIM_TYPE_OFF;					
			END_IF
			(* Set the old status id *)
			StatusID									:=	Internal.LoggerEntry.OldStatusID;
		END_IF
	END_IF
END_ACTION

(*################################################################################################################################################*)

(*Same mechanism as TSH_CheckCommTimeout, but for time critical process response*)
ACTION TSH_CheckResponseTimeout:	
	(* Check, if a response was coming -> After specified time, an error is triggered *)
	IF (Internal.ResponseTimeoutCheck.Response) THEN
		Internal.ResponseTimeoutCheck.WaitedCycles	:=	0;
		Internal.ResponseTimeoutCheck.Responded		:=	TRUE;
	ELSE
		Internal.ResponseTimeoutCheck.WaitedCycles	:=	Internal.ResponseTimeoutCheck.WaitedCycles + 1;
		Internal.ResponseTimeoutCheck.Responded		:=	FALSE;
	END_IF
	
	IF (Internal.ResponseTimeoutCheck.WaitedCycles > tshCOMMUNICATION_TIMEOUT_CYCLES) THEN
		(* The response came too late *)
		Internal.ResponseTimeoutCheck.Responded		:=	FALSE;
		(* Reset the counter *)
		Internal.ResponseTimeoutCheck.WaitedCycles	:=	0;
		(* Handover is stopped and not ready anymore *)
		HandoverReady								:=	FALSE;
		(* Recovery is needed, as the handover was stopped during the process *)
		Internal.Recovery.RecoveryNeeded			:=	TRUE;
		IF NOT(Error) THEN
			(* Display an error and give information to the logger *)
			Active									:=	FALSE;
			Error									:=	TRUE;
			StatusID								:=	tshERR_NO_RESPONSE;
			Internal.LoggerEntry.LoggerMessage		:=	'HANDOVER - There was no response of the other assembly within ';
			brsitoa(tshCOMMUNICATION_TIMEOUT_CYCLES, ADR(Internal.LoggerEntry.ValueString));
			brsstrcat(ADR(Internal.LoggerEntry.LoggerMessage), ADR(Internal.LoggerEntry.ValueString));
			brsstrcat(ADR(Internal.LoggerEntry.LoggerMessage), ADR(' cycles'));
			TSH_WriteLoggerEntry;
		END_IF
	END_IF
END_ACTION

(*################################################################################################################################################*)

(*If there are now shuttles on both handover sectors, no recovery is needed*)
ACTION TSH_CheckForShuttles:	
	(* Wait for any communication feedback of the other assembly *)
	Internal.Recovery.RecoveryNeeded	:=	NOT(Internal.Communication.DataReceive.ProcessStatus.15 AND Internal.Process.NoShuttlesOnSector);
END_ACTION
	
(*################################################################################################################################################*)

(*The status of the assembly and the number of shuttles on the handover sector are checked cyclically*)
ACTION TSH_HandoverMonitoring:
	(* Monitor the assembly status and communicate it to the other assembly *)
	Internal.Process.fbAsmReadStatus.Enable					:=	Internal.Process.EnableMonitoring;
	Internal.Process.fbSegReadStatus.Enable					:=	Internal.Process.EnableMonitoring AND Internal.Process.EnableSegMonitoring;
	
	IF (Internal.Process.fbAsmReadStatus.Error) THEN
		(* Display an error and give information to the logger *)
		Active												:=	FALSE;
		Error												:=	TRUE;
		StatusID											:=	tshERR_INTERNAL;
		Internal.LoggerEntry.LoggerMessage					:=	'INTERNAL - Reading assembly status not possible';
		TSH_WriteLoggerEntry;
			
		(* Set diagnostic info output *)
		Internal.Info.Diagnosis.Valid						:=	TRUE;
		Internal.Info.Diagnosis.Functionblock				:=	'MC_BR_AsmReadStatus_AcpTrak';
		Internal.Info.Diagnosis.StatusID       				:=	Internal.Process.fbAsmReadStatus.ErrorID;	(* For diagnostic reasons keep the StatusID of the function block *)
		
		(* Reset the function block *)
		Internal.Process.fbAsmReadStatus.Enable				:=	FALSE;
	ELSIF (Internal.Process.fbSegReadStatus.Error) THEN
		(* Display an error and give information to the logger *)
		Active												:=	FALSE;
		Error												:=	TRUE;
		StatusID											:=	tshERR_INTERNAL;
		Internal.LoggerEntry.LoggerMessage					:=	'INTERNAL - Reading segment status not possible';
		TSH_WriteLoggerEntry;
			
		(* Set diagnostic info output *)
		Internal.Info.Diagnosis.Valid						:=	TRUE;
		Internal.Info.Diagnosis.Functionblock				:=	'MC_BR_SegReadStatus_AcpTrak';
		Internal.Info.Diagnosis.StatusID       				:=	Internal.Process.fbSegReadStatus.ErrorID;	(* For diagnostic reasons keep the StatusID of the function block *)
		
		(* Reset the function block *)
		Internal.Process.fbSegReadStatus.Enable				:=	FALSE;
	ELSIF (Internal.Process.fbAsmReadStatus.Valid AND Internal.Process.fbSegReadStatus.Valid AND Internal.Process.EnableSegMonitoring) THEN
		Internal.Communication.DataSend.AssemblyStatus.0	:=	Internal.Process.fbAsmReadStatus.AssemblyDisabled OR Internal.Process.fbSegReadStatus.SegmentDisabled;
		Internal.Communication.DataSend.AssemblyStatus.1	:=	Internal.Process.fbAsmReadStatus.AssemblyReady AND Internal.Process.fbSegReadStatus.SegmentReady;
		Internal.Communication.DataSend.AssemblyStatus.2	:=	Internal.Process.fbAsmReadStatus.AssemblyHoming;
		Internal.Communication.DataSend.AssemblyStatus.3	:=	Internal.Process.fbAsmReadStatus.AssemblyStopping OR Internal.Process.fbSegReadStatus.SegmentStopping;
		Internal.Communication.DataSend.AssemblyStatus.4	:=	Internal.Process.fbAsmReadStatus.AssemblyErrorStop OR Internal.Process.fbSegReadStatus.SegmentErrorStop;
	ELSIF (Internal.Process.fbAsmReadStatus.Valid AND NOT(Internal.Process.EnableSegMonitoring)) THEN
		(* Communicate the status to the other assembly *)
		Internal.Communication.DataSend.AssemblyStatus.0	:=	Internal.Process.fbAsmReadStatus.AssemblyDisabled;
		Internal.Communication.DataSend.AssemblyStatus.1	:=	Internal.Process.fbAsmReadStatus.AssemblyReady;
		Internal.Communication.DataSend.AssemblyStatus.2	:=	Internal.Process.fbAsmReadStatus.AssemblyHoming;
		Internal.Communication.DataSend.AssemblyStatus.3	:=	Internal.Process.fbAsmReadStatus.AssemblyStopping;
		Internal.Communication.DataSend.AssemblyStatus.4	:=	Internal.Process.fbAsmReadStatus.AssemblyErrorStop;
	END_IF
	
	(* Monitor the number of shuttles on the sector and check for error stops *)
	Internal.Process.fbSecReadInfo.Enable					:=	Internal.Process.EnableMonitoring;
	IF (Internal.Process.fbSecReadInfo.Valid) THEN
		(* If there are no shuttles on the sector at all, this makes recovery easy. Give this info to the other assembly as well *)
		Internal.Process.NoShuttlesOnSector					:=	(Internal.Process.fbSecReadInfo.SectorInfo.ShuttleCount.Count = 0);
		Internal.Communication.DataSend.ProcessStatus.15	:=	Internal.Process.NoShuttlesOnSector;
		(* Check if there are any shuttles without an active movement command *)
		Internal.ErrorCheck.ShuttlesDisabled				:=	(Internal.Process.fbSecReadInfo.SectorInfo.ShuttleCount.InDisabled > 0);
		Internal.ErrorCheck.ShuttlesStandstill				:=	(Internal.Process.fbSecReadInfo.SectorInfo.ShuttleCount.InStandstill > 0);
		Internal.ErrorCheck.ShuttlesInErrorStop				:=	(Internal.Process.fbSecReadInfo.SectorInfo.ShuttleCount.InErrorStop > 0);
		(* Set the flag, when there is at least one shuttle in error on the handover sector*)
		Internal.Communication.DataSend.ProcessStatus.12	:=	Internal.ErrorCheck.ShuttlesInErrorStop;
	ELSIF (Internal.Process.fbSecReadInfo.Error) THEN
		(* Display an error and give information to the logger *)
		Active												:=	FALSE;
		Error												:=	TRUE;
		StatusID											:=	tshERR_INTERNAL;
		Internal.LoggerEntry.LoggerMessage					:=	'INTERNAL - Reading sector information not possible';
		TSH_WriteLoggerEntry;
		
		(* Set diagnostic info output *)
		Internal.Info.Diagnosis.Valid						:=	TRUE;
		Internal.Info.Diagnosis.Functionblock				:=	'MC_BR_SecReadInfo_AcpTrak';
		Internal.Info.Diagnosis.StatusID       				:=	Internal.Process.fbSecReadInfo.ErrorID;	(* For diagnostic reasons keep the StatusID of the function block *)
		
		(* Reset the function block *)
		Internal.Process.fbSecReadInfo.Enable				:=	FALSE;
	END_IF
	
	(* Monitor the number of shuttles inside the handover zone (Total and in Error) *)	
	Internal.Process.fbSecGetShuttle.Enable					:=	Internal.Process.EnableTransferAreaMonitoring OR Internal.Communication.DataReceive.ProcessCommands.4;
	
	(* When there is valid data, check the number of shuttles *)
	IF (Internal.Process.fbSecGetShuttle.Valid) THEN
		(* Reset the function block for the next call => Every 3 cycles there is new data*)
		Internal.Process.fbSecGetShuttle.Enable				:=	FALSE;
		(* Send the flag, that the data is valid *)
		Internal.Communication.DataSend.ProcessStatus.14	:=	TRUE;
		(* Set the right status bit of number of shuttles in the handover area *)
		Internal.Communication.DataSend.ProcessStatus.2		:=	(Internal.Process.fbSecGetShuttle.TotalCount = 0);
		(* Save the number of shuttles in the handover area *)
		Internal.Communication.DataSend.RecoveryInfo.ShuttlesInHandoverArea	:=	UINT_TO_USINT(Internal.Process.fbSecGetShuttle.TotalCount);
	END_IF
	
	(* Once the data must not be monitored anymore, reset the valid flag *)
	IF NOT(Internal.Process.fbSecGetShuttle.Valid) AND NOT(Internal.Process.EnableTransferAreaMonitoring) AND NOT(Internal.Communication.DataReceive.ProcessCommands.4) THEN
		Internal.Communication.DataSend.ProcessStatus.14	:=	FALSE;
	END_IF
	
	(* Monitor the RecoveryNeeded flag of both assemblies *)
	Internal.Communication.DataSend.ProcessStatus.11		:=	Internal.Recovery.RecoveryNeeded;	(* Give information to the other assembly, that recovery is needed *)
	
END_ACTION

(*################################################################################################################################################*)

(*Copy the userdate from/to a shuttle*)
ACTION TSH_ShuttleCopyUserData:
	(* If no userdata should be transferred, then the function block doesn't need to be called *)
	IF (Internal.Communication.UserDataSize > 0) THEN
		Internal.Process.fbShCopyUserData.Execute			:=	TRUE;
		Internal.Process.fbShCopyUserData();
	
		IF (Internal.Process.fbShCopyUserData.Done) THEN
			(* If variable is assigned, copy provide user data *)
			IF (Internal.Communication.UserDataAddress > 0) THEN
				brsmemcpy(Internal.Communication.UserDataAddress, Internal.Process.fbShCopyUserData.DataAddress, Internal.Communication.UserDataSize);
			END_IF
			
			(* Reset the function block *)
			Internal.Process.fbShCopyUserData.Execute		:=	FALSE;
			Internal.Process.fbShCopyUserData();
		ELSIF (Internal.Process.fbShCopyUserData.Error) THEN
			(* Display an error *)
			Active											:=	FALSE;
			Error											:=	TRUE;
			StatusID										:=	tshERR_INTERNAL;
			Internal.LoggerEntry.LoggerMessage				:=	'INTERNAL - Error while copying userdata of the shuttle (Details see motion logger)';
			TSH_WriteLoggerEntry;		
		
			(* Set diagnostic info output *)
			Internal.Info.Diagnosis.Valid					:=	TRUE;
			Internal.Info.Diagnosis.Functionblock			:=	'MC_BR_ShCopyUserData_AcpTrak';
			Internal.Info.Diagnosis.StatusID       			:=	Internal.Process.fbShCopyUserData.ErrorID;
			
			(* Reset the function block *)
			Internal.Process.fbShCopyUserData.Execute		:=	FALSE;
			Internal.Process.fbShCopyUserData();
		END_IF
	END_IF
END_ACTION

(*################################################################################################################################################*)

(*Used to get the version of the TrakShHo and mapp Motion for diagnostic reasons*)
ACTION TSH_CheckVersions:
	(* Use MO_ver() to get the versions of the wished components *)
	MO_ver(ADR('TrakShHo'), 0, ADR(Internal.VersionCheck.TrakShHo));
	MO_ver(ADR('McAcpTrak'), 0, ADR(Internal.VersionCheck.McAcpTrak));
	
	(* Copy the version info to the internal info structure *)
	brsmemcpy(ADR(Internal.Info.LibraryInfo.TrakShHo),ADR(Internal.VersionCheck.TrakShHo.version),SIZEOF(Internal.VersionCheck.TrakShHo.version));
	brsmemcpy(ADR(Internal.Info.LibraryInfo.McAcpTrak),ADR(Internal.VersionCheck.McAcpTrak.version),SIZEOF(Internal.VersionCheck.McAcpTrak.version));
	
	(* Create info entries in the logger with the used versions *)
	(* Store old StatusID *)
	Internal.LoggerEntry.OldStatusID	:=	StatusID;
	StatusID							:=	tshINFO_INTERNAL;
	
	(* Write the logger entries *)
	Internal.LoggerEntry.LoggerMessage	:=	'VERSION - TrakShHo library is used with version ';
	brsstrcat(ADR(Internal.LoggerEntry.LoggerMessage), ADR(Internal.Info.LibraryInfo.TrakShHo));
	TSH_WriteLoggerEntry;
	
	Internal.LoggerEntry.LoggerMessage	:=	'VERSION - McAcpTrak library is used with version ';
	brsstrcat(ADR(Internal.LoggerEntry.LoggerMessage), ADR(Internal.Info.LibraryInfo.McAcpTrak));
	TSH_WriteLoggerEntry;
	
	(* Reset the StatusID *)
	StatusID							:=	Internal.LoggerEntry.OldStatusID;
END_ACTION

(*################################################################################################################################################*)

(*Reset the recovery related parameter, state machines etc. in case of an error*)
ACTION TSH_Recovery_ErrorReset:
	(* Reset the communication *)
	Internal.Communication.DataSend.RecoveryInfo.CurrentZone		:=	0;	
	(* Reset the state machine *)
	Internal.Recovery.State											:=	tshRECOVERY_IDLE;
	(* Reset the sequence variables *)
	Internal.RecoverySequence.SequenceStep							:=	0;
END_ACTION

(*################################################################################################################################################*)

(*Check if a recovery is possible in the current state*)
ACTION TSH_CheckRecoveryPossible:
	(* Recovery is only possible, if both assemblies are READY *)	
	Internal.Recovery.RecoveryPossible	:=	Internal.Communication.DataSend.AssemblyStatus.1 AND Internal.Communication.DataReceive.AssemblyStatus.1;
END_ACTION

(*################################################################################################################################################*)

(*Reset the monitoring of the handover area, as it is not needed in current state*)
ACTION TSH_ResetHandoverAreaMonitoring:
	(* Reset the monitoring - Mainly used in Recovery *)
	Internal.Process.EnableTransferAreaMonitoring		:=	FALSE;
	Internal.Communication.DataSend.ProcessCommands.4	:=	FALSE;
END_ACTION