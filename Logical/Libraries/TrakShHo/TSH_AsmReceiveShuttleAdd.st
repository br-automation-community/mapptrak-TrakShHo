(*********************************************************************************
 * Copyright: B&R Industrial Automation GmbH 
 * Author:    B&R CD - CPE 
 * Created:   December 17, 2020
 *
 * Function block: TSH_AsmReceiveShuttleAdd
 *
 * Description:
 * - Receives shuttle data and information from the other assembly
 * - Creates a new shuttle with initial velocity to the system
 * - Writes the shuttle data to the newly created shuttle and resizes them
 * - Sends confirmation TO the other assembly
 * - Starts a movement to the configured target
 *********************************************************************************)

(* Adds shuttles to the assembly with data from the other assembly and sends them to a target *)
FUNCTION_BLOCK TSH_AsmReceiveShuttleAdd
	IF (Enable) THEN
		//####################################################################################//
		// FUNCTION BLOCK IS ENABLED
		//####################################################################################//
		
		(* Receive the communication handover data when possible *)
		IF (Internal.Simulation.UsedMode <> tshSIM_MODE_STANDALONE) THEN
			IF (Internal.Communication.DataReceiveAddress <> 0) THEN
				brsmemcpy(ADR(Internal.Communication.DataReceive), Internal.Communication.DataReceiveAddress, SIZEOF(Internal.Communication.DataReceive));
			END_IF
		ELSE
			(* When the standalone simulation is active, the interface must be simulated *)
			TSH_AsmReceive_SimulateCommInterface;
		END_IF
		
		(* Check if the POWERLINK communication is still working (Heartbeat bit is changing) *)
		TSH_CheckCommTimeout;
		
		(* Check the status of the assembly and handover zone for error situations *)
		TSH_HandoverMonitoring;
		
		(* Check for an update command *)
		TSH_AsmReceive_UpdateParameter;
		
		(* Check if there is any error happening during the handover *)
		TSH_AsmReceive_ErrorReaction;
		
		(* Check if recovery is possible in the current state *)
		TSH_CheckRecoveryPossible;
		
		(* Go to error state any time, when an error occurs *)
		IF (Error) THEN
			Internal.State												:=	tshSTATE_ERROR;
		END_IF
		
		(* Reset the shuttle info output, when the handover is not in running or already done *)		
		IF (Internal.State <> tshSTATE_RUNNING) OR (Internal.Process.Step = tshAR_WAIT_FOR_CATCH) THEN
			brsmemset(ADR(Internal.Info.Shuttle),0,SIZEOF(Internal.Info.Shuttle));
		END_IF
	
		(* Function block states *)
		CASE Internal.State OF		
			tshSTATE_INIT:
				Internal.Communication.DataSend.ProcessStatus.0			:=	TRUE;	(* Set process status "FUB Enabled" *)				
				Active													:=	TRUE;	(* Function block is busy and must be called *)
				
				(* Copy the configuration to internal buffer to use the settings *)
				TSH_CopyConfig;
				
				(* Initialize logger *)
				TSH_InitializeLogbook;	
				IF (Internal.Configuration.HandoverName = '') THEN
					(* Define a fallback ObjectID, if the user doesn't specify a name. It will be used for "entered by" in the logger *)
					Internal.LoggerEntry.fbWriteUsrLogEntry.ObjectID	:=	'TSH_AsmReceiveShuttleAdd';
				ELSE
					Internal.LoggerEntry.fbWriteUsrLogEntry.ObjectID	:=	Internal.Configuration.HandoverName;
					brsstrcat(ADR(Internal.LoggerEntry.fbWriteUsrLogEntry.ObjectID),ADR(' - Receive'));
				END_IF
				
				IF (Internal.LoggerEntry.Initialized) THEN					
					(* After the logger is initialized, the normal initialization can move on *)
					(* Check the used library versions and give Info to the user *)
					TSH_CheckVersions;
					
					(* Check all inputs *)
					TSH_AsmReceive_CheckInputs;
									
					(* Check system settings (e.g. cycle time *)
					TSH_CheckSystem;
					
					(* Check all configuration parameter *)
					TSH_AsmReceive_CheckConfig;		
					
					(* Check all parameter *)
					TSH_AsmReceive_CheckParameter;	
				END_IF			
			
				(* If initialization failed error is true *)
				IF (Error) THEN		
					TSH_WriteLoggerEntry;
					Internal.LoggerEntry.LogbookCreateError				:=	FALSE;	(* Reset the flag, so only the error message gets added to the system user logbook *)
					Internal.State										:=	tshSTATE_ERROR;
				ELSIF (Internal.LoggerEntry.Initialized) THEN
					(* After the logger is initialized and the fub initialization is successful, move on *)
					Internal.Communication.DataSend.ProcessStatus.1		:=	TRUE;	(*Initialized and communication ready *)
					
					(* Configuration parameter which have to be checked by both assemblies and have to match *)
					Internal.Communication.DataSend.UserDataSize		:=	Internal.Communication.UserDataSize;
					
					(* Initialize the function blocks used inside *)
					TSH_AsmReceive_ProcessInit;
					
					(* Create a logger entry, that initialization was successfully done *)
					Internal.LoggerEntry.OldStatusID					:=	StatusID;
					StatusID											:=	tshSCS_HANDOVER_INIT;
					Internal.LoggerEntry.LoggerMessage					:=	'INIT - Initialization successful';
					TSH_WriteLoggerEntry;
					StatusID											:=	Internal.LoggerEntry.OldStatusID;	(*Output stays old statusId (zero)*)
				
					(* Start monitoring *)
					Internal.Process.EnableMonitoring					:=	TRUE;
					
					Internal.State										:=	tshSTATE_WAIT_COMMUNICATION;
				END_IF
		
			tshSTATE_WAIT_COMMUNICATION:
				(* Wait for the other function block to be enabled and initialized *)
				IF (Internal.Communication.DataReceive.ProcessStatus.0) AND (Internal.Communication.DataReceive.ProcessStatus.1) THEN					
					(* Check for a mismatch in the userdata size *)
					IF (Internal.Communication.DataReceive.UserDataSize <> Internal.Communication.DataSend.UserDataSize) THEN
						(* Write an error to the logbook, as the settings are not matching *)
						Active											:=	FALSE;
						Error											:=	TRUE;
						StatusID										:=	tshERR_WRONG_USERDATA_SIZE;
						Internal.LoggerEntry.LoggerMessage				:=	'COMMUNICATION - The userdata size is not matching the size on the other assembly';		
						TSH_WriteLoggerEntry;
					ELSE
						(* Create a logger entry, that handover settings are matching *)
						Internal.LoggerEntry.OldStatusID				:=	StatusID;
						StatusID										:=	tshSCS_HANDOVER_INIT;
						Internal.LoggerEntry.LoggerMessage				:=	'INIT - Settings for handover are matching';
						TSH_WriteLoggerEntry;
						StatusID										:=	Internal.LoggerEntry.OldStatusID;	(*Output stays old statusId (zero)*)
						Internal.State									:=	tshSTATE_CHECK_HANDOVER_ZONE;
					END_IF				
				END_IF
			
			tshSTATE_CHECK_HANDOVER_ZONE:				
				(* Check if there are shuttles on one of the two handover sectors *)
				TSH_CheckForShuttles;
				
				IF (Internal.Recovery.RecoveryNeeded) THEN
					(* When recovery is needed wait for the start command *)
					IF (StartRecovery) AND NOT(Internal.Recovery.StartRecoveryOld) THEN					
						(* Reset the "needed" flag, as recovery will be started now *)
						Internal.Recovery.RecoveryNeeded				:=	FALSE;					
						(* Set output, that recovery is busy now, but on idle *)
						RecoveryBusy									:=	TRUE;
						Internal.Info.Recovery.RecoveryIdle				:=	TRUE;
						Internal.State									:=	tshSTATE_RECOVERY;
					END_IF
				ELSE
					(* No recovery needed, so handover can be started *)
					Internal.State										:=	tshSTATE_RUNNING;
				END_IF
			
			tshSTATE_RECOVERY:
				(* Set the right status *)
				Internal.Communication.DataSend.ProcessStatus.3			:=	TRUE;
				Internal.Communication.DataSend.ProcessStatus.5			:=	FALSE;
				Internal.Communication.DataSend.ProcessStatus.6			:=	FALSE;
				Internal.Communication.DataSend.ProcessStatus.7			:=	FALSE;
							
				(* Call recovery logic *)
				TSH_AsmReceive_Recovery;
				
				(* During CATCHING and DONE states, also run the process to catch shuttles from Send *)
				IF (Internal.Recovery.State = tshRECOVERY_CATCHING) OR (Internal.Recovery.State = tshRECOVERY_DONE) THEN
					TSH_AsmReceive_Process;
				END_IF
				
				(* When the input is reset, then the process can go on *)
				IF (RecoveryDone) AND NOT(StartRecovery) AND (Internal.Communication.DataReceive.ProcessStatus.4) THEN
					(* Reset status *)
					Internal.Communication.DataSend.ProcessStatus.3		:=	FALSE;
					RecoveryBusy										:=	FALSE;
					RecoveryDone										:=	FALSE;	
					(* Reset recovery communication *)
					brsmemset(ADR(Internal.Communication.DataSend.RecoveryInfo),0,SIZEOF(Internal.Communication.DataSend.RecoveryInfo));
					(* Reset recovery info *)
					brsmemset(ADR(Internal.Info.Recovery),0,SIZEOF(Internal.Info.Recovery));
					(* Go to the init state *)
					Internal.Recovery.State								:=	tshRECOVERY_IDLE;
					Internal.RecoverySequence.SequenceStep				:=	0;
					(* Change the state *)
					Internal.State										:=	tshSTATE_RUNNING;
				END_IF
		
			tshSTATE_RUNNING:
				(* Set the right status *)
				Internal.Communication.DataSend.ProcessStatus.3			:=	FALSE;
				Internal.Communication.DataSend.ProcessStatus.5			:=	TRUE;
				Internal.Communication.DataSend.ProcessStatus.6			:=	FALSE;
				Internal.Communication.DataSend.ProcessStatus.7			:=	FALSE;
				
				(* Wait for the second assembly to be ready as well, then execute this part once *)
				IF (Internal.Communication.DataSend.ProcessStatus.5) AND (Internal.Communication.DataReceive.ProcessStatus.5) AND NOT(HandoverReady) AND NOT(Internal.ErrorCheck.ErrorDetected) THEN
					HandoverReady										:=	TRUE;	(* Set the output, that now the handover can start *)	
					Internal.Communication.DataSend.ProcessStatus.4		:=	FALSE;
				ELSIF (Internal.Communication.DataReceive.ProcessStatus.3 OR Internal.Communication.DataReceive.ProcessStatus.11) AND NOT(Internal.Communication.DataReceive.RecoveryInfo.CurrentZone.4)
					AND NOT(HandoverReady) AND NOT(Internal.ErrorCheck.ErrorDetected) THEN
					(* If the other assembly is recovering or recovery is needed, go to state "ON_HOLD" *)
					(* Create a logger entry, that recovery is needed on other assembly *)
					Internal.LoggerEntry.OldStatusID					:=	StatusID;
					StatusID											:=	tshWRN_INTERNAL;
					Internal.LoggerEntry.LoggerMessage					:=	'RECOVERY - Function block is put on hold, as other assembly needs recovery';
					TSH_WriteLoggerEntry;
					StatusID											:=	Internal.LoggerEntry.OldStatusID;	(*Output stays old statusId (zero)*)				
					(* Switch to on hold, to check if recovery is really needed and to trigger recovery if needed (If Recovery is not needed, will go back to Running with Autostart) *)
					Internal.State										:=	tshSTATE_ON_HOLD;
				END_IF
				
				TSH_AsmReceive_Process;
				
			tshSTATE_ON_HOLD:
				(* Set the right status *)
				Internal.Communication.DataSend.ProcessStatus.3			:=	FALSE;
				Internal.Communication.DataSend.ProcessStatus.4			:=	FALSE;
				Internal.Communication.DataSend.ProcessStatus.5			:=	FALSE;
				Internal.Communication.DataSend.ProcessStatus.6			:=	TRUE;
				Internal.Communication.DataSend.ProcessStatus.7			:=	FALSE;
				Internal.Communication.DataSend.ProcessStatus.8			:=	FALSE;
								
				(* Check if there are shuttles on one of the two handover sectors *)
				TSH_CheckForShuttles;
				
				(* The handover area monitoring can be deactivate, as no process or recovery is active *)
				TSH_ResetHandoverAreaMonitoring;
				
				(* Reset the recovery status *)
				RecoveryBusy											:=	FALSE;
				RecoveryDone											:=	FALSE;
				Internal.Info.Recovery.RecoveryIdle						:=	FALSE;
				Internal.Info.Recovery.RecoveryActive					:=	FALSE;
				Internal.Info.Recovery.RecoveryFailed					:=	FALSE;
				
				(* Reset the process related variables *)
				Internal.Process.Step									:=	tshAR_WAIT_FOR_CATCH;
				Internal.Process.fbShReadInfo.Enable					:=	FALSE;
				
				(* Reset the counter from response check -> If handover was stopped in the waiting*)				
				Internal.ResponseTimeoutCheck.WaitedCycles				:=	0;
				
				(* Reset the auto restart flag *)
				Internal.Recovery.AutoRestartActive						:=	FALSE;
				
				(* When no Recovery is needed and both assemblies are ready, the handover can be restarted *)
				IF NOT(Internal.Recovery.RecoveryNeeded) THEN					
					(* Set the auto restart flag *)
					Internal.Recovery.AutoRestartActive					:=	TRUE;
					IF (Internal.Communication.DataReceive.AssemblyStatus.1) AND (Internal.Communication.DataSend.AssemblyStatus.1) AND NOT(Internal.ErrorCheck.ErrorDetected) THEN
						Internal.State									:=	tshSTATE_RUNNING;
						(* Reset diagnostic info output *)
						brsmemset(ADR(Internal.Info.Diagnosis),0,SIZEOF(Internal.Info.Diagnosis));		
						(* Write an entry to the logger, that the handover has stopped *)
						Internal.LoggerEntry.OldStatusID				:=	StatusID;
						StatusID										:=	tshSCS_HANDOVER_RESTART;
						Internal.LoggerEntry.LoggerMessage				:=	'HANDOVER - The handover was restarted successfully';
						TSH_WriteLoggerEntry;		
						StatusID										:=	Internal.LoggerEntry.OldStatusID;	(* the "old" error ID should be displayed *)
					END_IF
				END_IF
				(* If needed, recover the handover, otherwise just a reset with disabling is possible *)
				IF (Internal.Recovery.RecoveryNeeded) AND (StartRecovery) AND NOT(Internal.Recovery.StartRecoveryOld) THEN					
					(* Reset diagnostic info output *)
					brsmemset(ADR(Internal.Info.Diagnosis),0,SIZEOF(Internal.Info.Diagnosis));			
					(* Reset the "needed" flag, as recovery will be started now *)
					Internal.Recovery.RecoveryNeeded					:=	FALSE;					
					(* Set output, that recovery is busy now, but on idle *)
					RecoveryBusy										:=	TRUE;
					Internal.Info.Recovery.RecoveryIdle					:=	TRUE;
					Internal.State										:=	tshSTATE_RECOVERY;
				END_IF				
		
			tshSTATE_ERROR:	
				(* Reset communication *)
				Internal.Communication.DataSend.ProcessStatus.2			:=	FALSE;
				Internal.Communication.DataSend.ProcessStatus.3			:=	FALSE;
				Internal.Communication.DataSend.ProcessStatus.4			:=	FALSE;
				Internal.Communication.DataSend.ProcessStatus.5			:=	FALSE;
				Internal.Communication.DataSend.ProcessStatus.6			:=	FALSE;
				Internal.Communication.DataSend.ProcessStatus.8			:=	FALSE;
				
				(* Set error flag for communication *)
				Internal.Communication.DataSend.ProcessStatus.7			:=	TRUE;
				
				(* Reset the recovery *)
				TSH_Recovery_ErrorReset;
				
				(* The handover area monitoring can be deactivate, as no process or recovery is active *)
				TSH_ResetHandoverAreaMonitoring;				
				
				(* Reset outputs *)
				Active													:=	FALSE;			
				HandoverReady											:=	FALSE;
				
				RecoveryDone											:=	FALSE;
				RecoveryBusy											:=	FALSE;
				Internal.Info.Recovery.RecoveryIdle						:=	FALSE;
				Internal.Info.Recovery.RecoveryActive					:=	FALSE;
				
				(* Reset all function blocks of the process *)
				TSH_AsmReceive_ProcessError;
			
				(* Reset the auto restart flag *)
				Internal.Recovery.AutoRestartActive						:=	FALSE;
				
				(* If needed, recover the handover, otherwise just a reset with disabling is possible *)
				IF (Internal.Recovery.RecoveryNeeded) AND (StartRecovery) AND NOT(Internal.Recovery.StartRecoveryOld) THEN
					(* Reset error information *)
					Error												:=	FALSE;
					Active												:=	TRUE;
					StatusID											:=	0;
					(* Reset diagnostic info output *)
					brsmemset(ADR(Internal.Info.Diagnosis),0,SIZEOF(Internal.Info.Diagnosis));			
					(* Reset the "needed" flag, as recovery will be started now *)
					Internal.Recovery.RecoveryNeeded					:=	FALSE;					
					(* Set output, that recovery is busy now, but on idle *)
					RecoveryBusy										:=	TRUE;
					Internal.Info.Recovery.RecoveryIdle					:=	TRUE;
					Internal.Info.Recovery.RecoveryFailed				:=	FALSE;
					Internal.State										:=	tshSTATE_RECOVERY;
				END_IF
		
		END_CASE
		(* Show the user that a recovery is needed, only if it is possible *)
		RecoveryNeeded													:=	Internal.Recovery.RecoveryNeeded AND Internal.Recovery.RecoveryPossible;
		
		(* Monitor the situation if auto pause must be activated *)
		TSH_AsmReceive_AutoPauseMonitoring;
		
		(* Show the user that the handover is currently paused and send the command to the other side anytime *)
		Internal.Communication.DataSend.ProcessCommands.3				:=	PauseHandover OR Internal.Monitoring.AutoPauseActive;
		HandoverPaused													:=	Internal.Communication.DataReceive.ProcessStatus.10;
		
		(* Show the status of the other assembly on the output *)
		AsmSendInError													:=	Internal.Communication.DataReceive.AssemblyStatus.4;
		
		(* Save the state of the input StartRecovery *)
		Internal.Recovery.StartRecoveryOld								:=	StartRecovery;
			
		(* Call all function blocks, which need to be called cyclically *)
		TSH_AsmReceive_ProcessCallFBs;
		
		(* Copy the internal info to the info output structure *)
		brsmemcpy(ADR(Info),ADR(Internal.Info),SIZEOF(Internal.Info));
		
		(* send the communication handover data *)
		IF (Internal.Communication.DataSendAddress <> 0) AND (Internal.Simulation.UsedMode <> tshSIM_MODE_STANDALONE) THEN
			Internal.Communication.DataSend.ParaVelocity				:=	Internal.Parameter.Target.Velocity;
			Internal.Communication.DataSend.ParaAcceleration			:=	Internal.Parameter.Target.Acceleration;
			Internal.Communication.DataSend.ParaDeceleration			:=	Internal.Parameter.Target.Deceleration;
			brsmemcpy(Internal.Communication.DataSendAddress, ADR(Internal.Communication.DataSend), SIZEOF(Internal.Communication.DataSend));	(* System Data -> Userdata is read from the Function block ShCopyUserData*)
		END_IF
	ELSE
		//####################################################################################//
		// FUNCTION BLOCK IS DISABLED
		//####################################################################################//
		
		(* First abort catch mode if still active - requires multiple cycles *)
		TSH_AsmReceive_AbortCatch;
		
		IF Internal.Process.AbortCatchDone THEN
			Active														:=	FALSE;
			Error														:=	FALSE;
			StatusID													:=	0;
			
			UpdateDone													:=	FALSE;
			HandoverReady												:=	FALSE;
			AsmSendInError												:=	FALSE;
			RecoveryNeeded												:=	FALSE;
			RecoveryDone												:=	FALSE;
			RecoveryBusy												:=	FALSE;
			HandoverPaused												:=	FALSE;
			
			(* Reset internal data and output structure once, when function block was enabled before *)
			IF (Internal.Communication.DataSend.ProcessStatus.0) THEN
				(* Reset the function blocks *)
				TSH_AsmReceive_ResetInDisabled;
				
				brsmemset(ADR(Info), 0 , SIZEOF(Info));
				IF (Internal.Communication.DataSendAddress <> 0) THEN
					brsmemset(Internal.Communication.DataSendAddress, 0, SIZEOF(Internal.Communication.DataSend));	(* Reset the data send buffer*)
				END_IF
				brsmemset(ADR(Internal), 0 , SIZEOF(Internal));	
			END_IF
		END_IF
	END_IF
	
	(* Set a bit to true, to check, if the communication is interrupted, or just the function block is disabled *)
	IF (ADR(HandoverDataSend) <> 0) THEN
		Internal.Communication.DataSend.AssemblyStatus.7				:=	TRUE;	(* Set the bit to true, to send it to the other assembly *)
		brsmemcpy(ADR(HandoverDataSend), ADR(Internal.Communication.DataSend), SIZEOF(Internal.Communication.DataSend));	(* Copy the bit to the communication buffer if possible *)
		Internal.Communication.DataSend.AssemblyStatus.7				:=	Enable;	(* Reset the bit to enable, that no internal data is true if disabled *)
	END_IF
END_FUNCTION_BLOCK