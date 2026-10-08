(*Communication Data Types*)

TYPE
	TshCommReceiveToSendType :ARRAY[0..tshTO_SENDER_BUFFER_SIZE]OF USINT; (*Communication buffer datatype from AsmReceive to AsmSend communication*)
	TshCommReceiveToSendInternalType : 	STRUCT  (*Internal communication buffer datatype from AsmReceive to AsmSend communication*)
		AssemblyStatus : USINT; (*.0 = Disabled
		.1 = Ready
		.2 = Homing
		.3 = Stopping
		.4 = ErrorStop
		.5 = FREE
		.6 = FREE
		.7 = RESERVED*)
		ProcessCommands : USINT; (*.0 = FREE
		.1 = FREE
		.2 = FREE
		.3 = PauseHandover
		.4 = EnableTransferAreaMonitoring
		.5 = Simulation mode "Just Routing" (0 = Inactive, 1 = Active)
		.6 = FREE
		.7 = FREE*)
		ProcessStatus : UINT; (*.0 = Enabled
		.1 = Initialized and ready
		.2 = Handover area empty
		.3 = Recovering
		.4 = Recovery Done
		.5 = Running
		.6 = On hold
		.7 = Error
		.8 = all Shuttles added successfully
		.9 = Convoy
		.10 = FREE
		.11 = RecoveryNeeded
		.12 = ShuttleErrorstop on AsmReceive
		.13 = FREE
		.14 = ShuttleInHandoverArea data valid
		.15 = NoShuttlesOnSector*)
		HeartbeatCount : UDINT; (*Counter is increased by the Send side to check if the communication is still working*)
		UserDataSize : UDINT; (*Userdatasize to check, if the same size is assigned on both sides => Otherwise error*)
		ParaVelocity : REAL; (*Current velocity in the parameter structure of the function block Receive*)
		ParaAcceleration : REAL; (*Current acceleration in the parameter structure of the function block Receive*)
		ParaDeceleration : REAL; (*Current deceleration in the parameter structure of the function block Receive*)
		RecoveryInfo : TshCommRecoveryInfoType; (*Recovery information*)
	END_STRUCT;
	TshCommSendToReceiveInternalType : 	STRUCT  (*Internal communication buffer datatype from AsmSend to AsmReceive communication*)
		AssemblyStatus : USINT; (*.0 = Disabled
		.1 = Ready
		.2 = Homing
		.3 = Stopping
		.4 = ErrorStop
		.5 = FREE
		.6 = FREE
		.7 = RESERVED*)
		ProcessCommands : USINT; (*.0 = Add shuttle
		.1 = FREE
		.2 = FREE
		.3 = FREE
		.4 = EnableTransferAreaMonitoring
		.5 = Simulation mode "Just Routing" (0 = Inactive, 1 = Active)
		.6 = FREE
		.7 = FREE*)
		ProcessStatus : UINT; (*.0 = Enabled
		.1 = Initialized and ready
		.2 = Handover area empty
		.3 = Recovering
		.4 = Recovery Done
		.5 = Running
		.6 = On hold
		.7 = Error
		.8 = all Shuttles deleted successfully
		.9 = Convoy
		.10 = HandoverPaused
		.11 = RecoveryNeeded
		.12 = ShuttleErrorstop on AsmSend
		.13 = FREE
		.14 = ShuttleInHandoverArea data valid
		.15 = NoShuttlesOnSector*)
		HeartbeatCount : UDINT; (*Counter is increased by the Send side to check if the communication is still working*)
		UserDataSize : UDINT; (*Userdatasize to check, if the same size is assigned on both sides => Otherwise error*)
		RecoveryInfo : TshCommRecoveryInfoType; (*Recovery information*)
	END_STRUCT;
	TshCommRecoveryInfoType : 	STRUCT  (*Recovery information datatype*)
		ShuttlesInHandoverArea : USINT; (*Number of shuttles in the handover zone*)
		CurrentZone : USINT; (*.0 = Idle
		.1 = Recover Area Receive
		.2 = Recover Area Handover
		.3 = Recover Area Send
		.4 = Done
		.5 = Receive Catching Active (Send may proceed)
		.6 = FREE
		.7 = FREE*)
	END_STRUCT;
END_TYPE

(*TSH_AsmSendShuttleDelete*)

TYPE
	TshAsmSendInternalType : 	STRUCT  (*AsmSend internal datatype*)
		State : TshInternalStateEnum; (*Function block state*)
		LoggerEntry : TshInternalLoggerEntryType; (*Logger entry data*)
		VersionCheck : TshInternalVersionCheckType; (*Check the library versions*)
		Configuration : TshConfigSendType; (*Configuration data*)
		ConfigCheck : TshInternalConfigCheckType; (*Configuration check*)
		Communication : TshAsmSendInternalCommType; (*Communication data*)
		SystemCheck : TshInternalSystemCheckType; (*System check*)
		TimeoutCheck : TshInternalTimeoutCheckType; (*Timeout check*)
		Process : TshAsmSendInternalProcessType; (*Process data*)
		Barrier : TshAsmSendInternalBarrierType; (*Barrier handling*)
		ResponseTimeoutCheck : TshInternalResponseCheckType; (*Response timeout check*)
		ErrorCheck : TshInternalErrorCheckType; (*Handover error check*)
		Recovery : TshInternalRecoveryType; (*Recovery data*)
		RecoverySequence : TshInternalRecoverySequenceType; (*Recovery sequence*)
		Info : TshInfoType; (*Info Structure*)
		Simulation : TshInternalSimulationType; (*Simulation data*)
	END_STRUCT;
	TshAsmSendInternalCommType : 	STRUCT  (*Internal AsmSend communication datatype*)
		DataReceive : TshCommReceiveToSendInternalType; (*Internal data receive buffer*)
		DataReceiveAddress : UDINT; (*Address of the receive buffer, which is connected to the PLK Interface*)
		DataSend : TshCommSendToReceiveInternalType; (*Internal data send buffer*)
		DataSendAddress : UDINT; (*Address of the send buffer, which is connected to the PLK Interface*)
		DataSendSize : UDINT; (*Size of the send buffer, which is connected to the PLK Interface*)
		UserDataAddress : UDINT; (*Address of the user data buffer, where data is provided to the user*)
		UserDataSize : UDINT; (*Size of the custom shuttle userdata*)
	END_STRUCT;
	TshAsmSendInternalProcessType : 	STRUCT  (*Internal AsmSend process datatype*)
		Step : TshAsmSendInternalProcStepEnum; (*Process step*)
		EnableMonitoring : BOOL; (*Enable for the handover monitoring (Number of shuttles, error stops, ...)*)
		EnableTransferAreaMonitoring : BOOL; (*Enable for special transfer area monitoring (Number of shuttles, error stops, ...)*)
		EnableSegMonitoring : BOOL; (*Enable segment monitoring if a segment is connected*)
		NoShuttlesOnSector : BOOL; (*Currently no shuttles on the sector*)
		ShuttleUsable : BOOL; (*The shuttle which passed the process point can be used for the handover*)
		ShuttleRef : McAxisType; (*Reference of the current shuttle*)
		ShuttleID : UDINT; (*ID of the current shuttle*)
		fbAsmReadStatus : MC_BR_AsmReadStatus_AcpTrak; (*Function block to read the assembly status*)
		fbSegReadStatus : MC_BR_SegReadStatus_AcpTrak; (*Function block to read the segment status*)
		fbTrgPointEnable : MC_BR_TrgPointEnable_AcpTrak; (*Function block to enable the process point*)
		fbTrgPointReadInfo : MC_BR_TrgPointReadInfo_AcpTrak; (*Function block to read out a trigger event on the process point*)
		fbReadStatus : MC_ReadStatus; (*Function block to read the current shuttle status*)
		fbShReadInfo : MC_BR_ShReadInfo_AcpTrak; (*Function block to get the shuttle info*)
		fbShCopyUserData : MC_BR_ShCopyUserData_AcpTrak; (*Function block to copy the shuttle userdata*)
		fbSecGetShuttle : MC_BR_SecGetShuttle_AcpTrak; (*Function block to get a shuttle in a certain area with certain credentials*)
		fbSecReadInfo : MC_BR_SecReadInfo_AcpTrak; (*Function block to read the sector info*)
		fbSecStop : MC_BR_SecStop_AcpTrak; (*Function block to stop all shuttles on a sector with a specified deceleration*)
		fbSecGetInfo : MC_BR_SecGetInfo_AcpTrak; (*Function block to get the sector info*)
		fbRoutedMoveAbs : MC_BR_RoutedMoveAbs_AcpTrak; (*Function block to move the shuttle towards the end of the send sector*)
		Delete : TshAsmSendInternalProcDeleteType;
	END_STRUCT;
	TshAsmSendInternalProcStepEnum : 
		( (*Internal AsmSend process step enumeration*)
		tshAS_CHECK_TRIGGER := 0, (*Waiting for a shuttle to move over the process point*)
		tshAS_GET_SHUTTLE_DATA, (*Reading the shuttle information  and userdata*)
		tshAS_WAIT_FOR_CATCH, (*Wait for the confirmation, that the shuttle was caught on AsmReceive*)
		tshAS_DELETE_SHUTTLE, (*Delete the shuttle from the assembly*)
		tshAS_WAIT_HANDOVER_DONE (*Wait for the confirmation, that the shuttle handover is done*)
		);
	TshAsmSendInternalBarrierType : 	STRUCT  (*Internal AsmSend barrier handling datatype*)
		PauseHandover : BOOL; (*Internal Pause handover signal (from both assemblies)*)
		HandoverPaused : BOOL; (*Internal handover paused signal (for both assemblies)*)
		HandoverReadyBarrierClosed : BOOL; (*Barrier was not opened since the last time handover became ready*)
		BarrierTickets : DINT; (*Number of tickets which will be added to the barrier*)
		fbBarrierReadInfo : MC_BR_BarrierReadInfo_AcpTrak; (*Function block to read the barrier information*)
		fbBarrierCommand : MC_BR_BarrierCommand_AcpTrak; (*Function block to give a command to the barrier*)
	END_STRUCT;
	TshAsmSendInternalProcDeleteType : 	STRUCT  (*Internal AsmSend delete shuttle datatype*)
		Step : TshAsmSendInternalProcStepEnum; (*Process step*)
		fbTrgPointEnable : MC_BR_TrgPointEnable_AcpTrak; (*Function block to enable the process point*)
		fbTrgPointReadInfo : MC_BR_TrgPointReadInfo_AcpTrak; (*Function block to read out a trigger event on the process point*)
		fbAsmDeleteShuttle : MC_BR_AsmDeleteShuttle_AcpTrak; (*Function block to delete a shuttle*)
		fbShReadInfo : MC_BR_ShReadInfo_AcpTrak; (*Function block to get the shuttle info*)
		ShuttleRef : McAxisType; (*Reference of the current shuttle*)
		ShuttleID : UDINT; (*ID of the current shuttle*)
	END_STRUCT;
END_TYPE

(*TSH_AsmReceiveShuttleAdd*)

TYPE
	TshAsmReceiveInternalType : 	STRUCT  (*AsmReceive internal datatype*)
		State : TshInternalStateEnum; (*Function block state*)
		LoggerEntry : TshInternalLoggerEntryType; (*Logger entry data*)
		VersionCheck : TshInternalVersionCheckType; (*Check the library versions*)
		Configuration : TshConfigReceiveType; (*Configuration data*)
		ConfigCheck : TshInternalConfigCheckType; (*Configuration check*)
		Parameter : TshAsmReceiveParType; (*Parameter data*)
		ParCheck : TshInternalParCheckType; (*Parameter check*)
		Communication : TshAsmReceiveInternalCommType; (*Communication data*)
		SystemCheck : TshInternalSystemCheckType; (*System check*)
		TimeoutCheck : TshInternalTimeoutCheckType; (*Timeout check*)
		Process : TshAsmReceiveInternalProcessType; (*Process data*)
		Monitoring : TshAsmReceiveInternalMonitorType; (*Monitoring data*)
		ResponseTimeoutCheck : TshInternalResponseCheckType; (*Response timeout check*)
		ErrorCheck : TshInternalErrorCheckType; (*Handover error check*)
		Recovery : TshInternalRecoveryType; (*Recovery function blocks and state*)
		RecoverySequence : TshInternalRecoverySequenceType; (*Recovery sequence*)
		Info : TshInfoType; (*Info Structure*)
		Simulation : TshInternalSimulationType; (*Simulation data*)
	END_STRUCT;
	TshAsmReceiveInternalCommType : 	STRUCT  (*Internal AsmReceive communication datatype*)
		DataSend : TshCommReceiveToSendInternalType; (*Internal data send buffer*)
		DataSendAddress : UDINT; (*Address of the send buffer, which is connected to the PLK Interface*)
		DataReceive : TshCommSendToReceiveInternalType; (*Internal data receive buffer*)
		DataReceiveAddress : UDINT; (*Address of the receive buffer, which is connected to the PLK Interface*)
		DataReceiveSize : UDINT; (*Size of the receive buffer, which is connected to the PLK Interface*)
		UserDataAddress : UDINT; (*Address of the user data buffer, where data is provided to the user*)
		UserDataSize : UDINT; (*Size of the custom shuttle userdata*)
	END_STRUCT;
	TshAsmReceiveInternalProcessType : 	STRUCT  (*Internal AsmReceive process datatype*)
		Step : TshAsmReceiveInternProcStepEnum; (*Process step*)
		EnableMonitoring : BOOL; (*Enable for the handover monitoring (Number of shuttles, error stops, ...)*)
		EnableTransferAreaMonitoring : BOOL; (*Enable for special transfer area monitoring (Number of shuttles, error stops, ...)*)
		EnableSegMonitoring : BOOL; (*Enable segment monitoring if a segment is connected*)
		NoShuttlesOnSector : BOOL; (*Currently no shuttles on the sector*)
		ShuttleRef : McAxisType; (*Reference of the added shuttle*)
		ShuttleID : UDINT; (*ID of the added shuttle*)
		fbAsmReadStatus : MC_BR_AsmReadStatus_AcpTrak; (*Function block to read the assembly status*)
		fbSegReadStatus : MC_BR_SegReadStatus_AcpTrak; (*Function block to read the segment status*)
		fbShReadInfo : MC_BR_ShReadInfo_AcpTrak; (*Function block to get the shuttle info*)
		fbShCopyUserData : MC_BR_ShCopyUserData_AcpTrak; (*Function block to copy the shuttle userdata*)
		fbSecAddShuttle : MC_BR_SecAddShuttle_AcpTrak; (*Function block to add a shuttle with catch mode*)
		fbSecGetShuttle : MC_BR_SecGetShuttle_AcpTrak; (*Function block to get a shuttle in a certain area with certain credentials*)
		fbSecReadInfo : MC_BR_SecReadInfo_AcpTrak; (*Function block to read the sector info*)
		fbReset : MC_Reset; (*Function block to reset a shuttle in error stop*)
		fbStop : MC_Stop; (*Function block to stop a shuttle*)
		fbReadStatus : MC_ReadStatus; (*Function block to read the shuttle status*)
		fbShResize : MC_BR_ShResize_AcpTrak; (*Function block to resize a shuttle*)
		fbRoutedMoveAbs : MC_BR_RoutedMoveAbs_AcpTrak;
		AbortCatchStep : USINT; (*Step for aborting catch mode*)
		AbortCatchDone : BOOL; (*Abort catch mode completed*)
		RoutedMoveAbsActiveOld : BOOL; (*Flag for checking Active flag*)
	END_STRUCT;
	TshAsmReceiveInternalMonitorType : 	STRUCT 
		AutoPauseActive : BOOL; (*The handover must be paused due to the observed situation*)
		QueuingAreaLength : LREAL; (*Length of the area shuttles can queue up = Zone Receive (Including safety area)*)
		ShuttleLength : LREAL; (*Total length of the shuttle (EtF + EtB)*)
		MaxNumberOfShuttles : INT; (*Maximum number of shuttles allowed on the handover sector*)
	END_STRUCT;
	TshAsmReceiveInternProcStepEnum : 
		( (*Internal AsmReceive process step enumeration*)
		tshAR_WAIT_FOR_CATCH := 0, (*Waiting for the catch command from AsmSend*)
		tshAR_ADD_SHUTTLE, (*Add a shuttle on the catch position*)
		tshAR_MOVE_SHUTTLE, (*Move the shuttle with RoutedMoveAbs*)
		tshAR_WAIT_CONFIRMATION, (*Wait for the confirmation, that the shuttle was deleted on AsmSend*)
		tshAR_RESIZE_SHUTTLE (*Resize the shuttle according to the configured size (Parameters)*)
		);
	TshAsmReceiveParType : 	STRUCT  (*AsmReceive parameter datatype*)
		AutoPause : TshAsmReceiveParAutoPauseType; (*Auto Pause feature*)
		Target : TshAsmReceiveParTargetType; (*Target for the shuttle*)
		ShuttleSize : TshAsmReceiveParShuttleSizeType; (*New size of the shuttle*)
		CatchPosition : LREAL; (*Position on the Sector where shuttles are caught*)
		RecoverySearchLength : LREAL; (*Max search length for recovery shuttle search [mm]. 0 = entire sector*)
	END_STRUCT;
	TshAsmReceiveParAutoPauseType : 	STRUCT  (*AsmReceive auto pause parameter datatype*)
		EnableHandoverAutoPause : TshAsmReceiveParAutoPauseEnum; (*Mode to automatically pause the handover in case shuttles are queuing back into the handover*)
		UserOffset : SINT; (*User offset for the maximum number of shuttles (Increase or decrease the number)*)
	END_STRUCT;
	TshAsmReceiveParAutoPauseEnum : 
		( (*Auto pause functionality enabling enumeration*)
		tshHANDOVER_AUTO_PAUSE_DISABLE := 0, (*Disable auto pause*)
		tshHANDOVER_AUTO_PAUSE_ENABLE (*Enable auto pause*)
		);
	TshAsmReceiveParTargetType : 	STRUCT  (*AsmReceive target parameter datatype*)
		Sector : McSectorType; (*Target sector*)
		Position : LREAL; (*Target position on the target sector*)
		Velocity : REAL; (*Velocity for the shuttle to move to the target sector*)
		Acceleration : REAL; (*Acceleration for the shuttle to move to the target sector*)
		Deceleration : REAL; (*Deceleration for the shuttle to move to the target sector*)
		StartDirection : McDirectionEnum; (*Start direction for the shuttle to move to the target sector*)
		EndDirection : McDirectionEnum; (*End direction for the shuttle to move to the target sector*)
		ShuttleOrientation : McDirectionEnum; (*Shuttle orientation for the shuttle to move to the target sector*)
	END_STRUCT;
	TshAsmReceiveParShuttleSizeType : 	STRUCT  (*AsmReceive shuttle size parameter datatype*)
		EnableResize : TshAsmReceiveParEnableResizeEnum; (*Enable / Disable the resize functionality*)
		ExtendToFront : LREAL; (*Extend to front of the shuttle*)
		ExtendToBack : LREAL; (*Extend to back of the shuttle*)
		Width : LREAL; (*Width of the shuttle*)
	END_STRUCT;
	TshAsmReceiveParEnableResizeEnum : 
		( (*Resize functionality enabling enumeration*)
		tshSHUTTLE_RESIZE_DISABLE := 0, (*Disable shuttle resize*)
		tshSHUTTLE_RESIZE_ENABLE (*Enable shuttle resize*)
		);
	TshInternalParCheckType : 	STRUCT  (*Internal AsmReceive parameter check datatype*)
		ParCheckDone : BOOL; (*The parameter check is done*)
		OldError : BOOL; (*The value of the error output before the check*)
		OldActive : BOOL; (*The value of the active output before the check*)
		OldStatusID : DINT; (*The value of the statusID output before the check*)
	END_STRUCT;
END_TYPE

(*Additional Information output of handover function blocks*)

TYPE
	TshInfoType : 	STRUCT  (*Information datatype*)
		LibraryInfo : TshInfoLibInfoType; (*Information about the used library versions*)
		Shuttle : TshInfoShuttleType; (*Shuttle information*)
		Recovery : TshInfoRecoveryType; (*Recovery information*)
		Diagnosis : TshInfoDiagType; (*Diagnostic information*)
		Simulation : TshInfoSimType; (*Simulation information*)
		HandoverCount : UDINT; (*Counter for handover procedures since enable*)
	END_STRUCT;
	TshInfoLibInfoType : 	STRUCT  (*Information about versions*)
		TrakShHo : TshString10Type; (*Version of TrakShHo library*)
		McAcpTrak : TshString10Type; (*Version of McAcpTrak library (mapp Motion)*)
	END_STRUCT;
	TshInfoShuttleType : 	STRUCT  (*Shuttle information datatype*)
		Valid : BOOL; (*Data is valid*)
		ShuttleRef : McAxisType; (*Reference of the shuttle*)
		ShuttleID : UDINT; (*ID of the shuttle*)
		Action : TshInfoShuttleActionEnum; (*Action what happened with the shuttle*)
	END_STRUCT;
	TshInfoShuttleActionEnum : 
		( (*Info shuttle action enumeration*)
		tshSHUTTLE_ACTION_DELETED, (*The shuttle was deleted*)
		tshSHUTTLE_ACTION_ADDED (*The shuttle was added*)
		);
	TshInfoRecoveryType : 	STRUCT  (*Recovery information datatype*)
		RecoveryIdle : BOOL; (*The recovery is started, but must wait for the second assembly to also start the recovery (RecoveryBusy = TRUE)*)
		RecoveryActive : BOOL; (*The recovery is started and now active (RecoveryBusy = TRUE)*)
		RecoveryFailed : BOOL; (*The recovery failed (RecoveryBusy = RecoveryDone = FALSE; Error = TRUE)*)
	END_STRUCT;
	TshInfoDiagType : 	STRUCT  (*Diagnosis information datatype*)
		Valid : BOOL; (*The information is valid*)
		Functionblock : TshString32Type; (*Name of the function block which caused an error*)
		StatusID : DINT; (*Status ID of the function block which caused the error*)
	END_STRUCT;
	TshInfoSimType : 	STRUCT  (*Simulation information datatype*)
		Type : TshInfoSimTypeEnum; (*Simulation type (OFF / AR_SIM / SIM_ON_PLC)*)
		Mode : TshConfigSimulationTypeEnum; (*Current used simulation mode*)
	END_STRUCT;
	TshInfoSimTypeEnum : 
		( (*Simulation types*)
		tshSIM_TYPE_OFF := 0, (*No Simulation active*)
		tshSIM_TYPE_AR_SIM, (*Target system is ArSim*)
		tshSIM_TYPE_SIM_ON_PLC (*Target system is PLC with simulated segments*)
		);
END_TYPE

(*Common Datatypes and Enumerations*)

TYPE
	TshConfigSendType : 	STRUCT  (*Configuration datatype for TSH_AsmSendShuttleDelete*)
		LoggingMode : TshConfigLoggingModeEnum; (*The logging mode decides, what information will be put into the system user logbook by the handover funtion block*)
		Simulation : TshConfigSimulationType; (*Configuration of the simulation modes for different target systems*)
		HandoverName : TshString25Type; (*Will be used for the logger to distinguish between multiple handovers. If empty, the function block name (e.g. TSH_AsmSendShuttleDelete) is used.*)
		LogbookType : TshLogbookTypeEnum; (*The logbook type decides, if the system user logbook or a userdefined logbook is used*)
		LogbookName : TshString10Type; (*Name for the userdefined logbook (Only with type = tshLOGBOOK_USE_USERDEFINED)*)
	END_STRUCT;
	TshConfigReceiveType : 	STRUCT  (*Configuration datatype for TSH_AsmReceiveShuttleAdd*)
		Movement : TshConfigMovementType; (*Movement parameters needed for recovery movements - only required for Receive*)
		LoggingMode : TshConfigLoggingModeEnum; (*The logging mode decides, what information will be put into the system user logbook by the handover funtion block*)
		Simulation : TshConfigSimulationType; (*Configuration of the simulation modes for different target systems*)
		HandoverName : TshString25Type; (*Will be used for the logger to distinguish between multiple handovers. If empty, the function block name (e.g. TSH_AsmReceiveShuttleAdd) is used.*)
		LogbookType : TshLogbookTypeEnum; (*The logbook type decides, if the system user logbook or a userdefined logbook is used*)
		LogbookName : TshString10Type; (*Name for the userdefined logbook (Only with type = tshLOGBOOK_USE_USERDEFINED)*)
	END_STRUCT;
	TshConfigMovementType : 	STRUCT  (*Movement parameters needed for recovery movements*)
		Velocity : REAL; (*Velocity for recovery movements*)
		Acceleration : REAL; (*Maximum System Acceleration (as specified in Shuttle stereotype)*)
		Deceleration : REAL; (*Maximum System Deceleration (as specified in Shuttle stereotype)*)
	END_STRUCT;
	TshConfigLoggingModeEnum : 
		( (*The logging mode decides, what information will be put into the system user logbook by the handover funtion block*)
		tshLOGGING_BASIC := 0, (*Beside errors and warnings, the most important information (e.g. config values) are put into the logbook*)
		tshLOGGING_ADVANCED, (*Additionally to the basic logger entries, some more detailled information about the handover  (e.g. Shuttle data, handover delay, etc.)*)
		tshLOGGING_DEBUGGING (*Here all important information for debugging is logged (e.g. state changes inside the function block, timings, etc.) - This might fill the user logger quite fast, so just the most actual data will be available*)
		);
	TshConfigSimulationType : 	STRUCT  (*Which mode should be used for the handover in simulation*)
		ModeForArSim : TshConfigSimulationTypeEnum; (*Simulation mode for target system = ARsim*)
		ModeForSimOnPLC : TshConfigSimulationTypeEnum; (*Simulation mode for target system = PLC with simulated segments*)
		Velocity : REAL; (*Simulated velocity parameter received by Send from Receive*)
		Acceleration : REAL; (*Simulated acceleration parameter received by Send from Receive*)
		Deceleration : REAL; (*Simulated deceleration parameter received by Send from Receive*)
	END_STRUCT;
	TshConfigSimulationTypeEnum : 
		( (*Simulation modes*)
		tshSIM_MODE_NORMAL_OPERATION := 0, (*[Only SimOnPLC] Normal operation as it is in the machine*)
		tshSIM_MODE_STANDALONE (*[ArSim and SimOnPLC] Standalone operation. Shuttles can be added with input on function block. Shuttles will be deleted at the end.*)
		);
	TshLogbookTypeEnum : 
		( (*The logbook type decides, if the system user logbook or a userdefined logbook is used*)
		tshLOGBOOK_USE_DEFAULT := 0, (*Use the system user logbook*)
		tshLOGBOOK_USE_USERDEFINED (*Use the specified logbook*)
		);
END_TYPE

(*Common Internal Datatypes and Enumerations*)

TYPE
	TshInternalStateEnum : 
		( (*Internal state enumeration*)
		tshSTATE_INIT := 0, (*Initialization state of the function block*)
		tshSTATE_WAIT_COMMUNICATION, (*Waiting for communication to the other function block*)
		tshSTATE_CHECK_HANDOVER_ZONE, (*Check if the handover zone is free*)
		tshSTATE_RECOVERY, (*Recover the handover*)
		tshSTATE_RUNNING, (*Handover process*)
		tshSTATE_ON_HOLD, (*Handover is not ready, and will wait for conditions to start*)
		tshSTATE_ERROR (*An error happened*)
		);
	TshInternalLoggerEntryType : 	STRUCT  (*Internal logger entry datatype*)
		Initialized : BOOL; (*The user logging is initialized*)
		LogbookCreateError : BOOL; (*An error happened during the logbook creation*)
		LoggerMessage : TshString255Type; (*Message which should be added to the logger*)
		ValueString : TshString10Type; (*Value string, if numeric data should be added to the logger entry*)
		fbGetUsrLogIdent : ArEventLogGetIdent; (*Function block to read the Ident of the defined user logbook*)
		fbCreateUsrLogBook : ArEventLogCreate; (*Function block to create a custom user logbook*)
		fbWriteUsrLogEntry : ArEventLogWrite; (*Function block to write an entry to the defined user logbook*)
		OldStatusID : DINT; (*Old status ID of the function block (To keep ID, when entering Warnings, Infos and Successes)*)
	END_STRUCT;
	TshInternalConfigCheckType : 	STRUCT  (*Internal config check datatype*)
		CopyDone : BOOL; (*Values have been copied from external variable to internal buffer*)
		SectorLength : LREAL; (*Length of the handover sector*)
		SectorName : TshString32Type; (*Name of the handover sector*)
		SafetyZoneLength : LREAL; (*Dynamically calculated safety zone length based on braking distance + shuttle size*)
		fbSecGetInfo : MC_BR_SecGetInfo_AcpTrak; (*Function block to read the sector information*)
	END_STRUCT;
	TshInternalTimeoutCheckType : 	STRUCT  (*Internal timeout check datatype*)
		IncreaseHeartbeat : BOOL; (*Flag to decide, if the heartbeat should be increased by the current instance (Only Send should increase)*)
		OldHeartbeatCount : UDINT; (*Old heartbeat count to check with the current one*)
		MissedCycles : USINT; (*Number of cycles, the heartbeat was not changning*)
		TimedOut : BOOL; (*The communication between PLCs timed out*)
	END_STRUCT;
	TshInternalResponseCheckType : 	STRUCT  (*Internal response check datatype*)
		Response : BOOL; (*Response input the check is waiting for*)
		Responded : BOOL; (*Response output of the check*)
		WaitedCycles : USINT; (*Number of cycles waited for response since command was sent*)
	END_STRUCT;
	TshInternalSystemCheckType : 	STRUCT  (*Internal system check datatype*)
		CycleTime : UDINT; (*Cycletime of the task the function block is used in*)
		fbRTInfo : RTInfo; (*Function block to read the cycle time*)
	END_STRUCT;
	TshInternalErrorCheckType : 	STRUCT  (*Internal error check datatype*)
		ErrorDetected : BOOL; (*An error is detected in the handover*)
		ErrorDetectedOld : BOOL; (*Old value of the ErrorDetected flag*)
		ShuttlesInErrorStop : BOOL; (*There are shuttles in error stop on the assembly*)
		ShuttlesDisabled : BOOL; (*There are shuttles disabled on the assembly*)
		ShuttlesStandstill : BOOL; (*There are shuttles in standstill on the assembly*)
		CurrentShuttleInErrorStop : BOOL; (*The shuttle currently in the handover is in error stop*)
		CurrentShuttleDisabled : BOOL; (*The shuttle currently in the handover is disabled*)
		CurrentShuttleStandstill : BOOL; (*The shuttle currently in the handover is in standstill*)
		fbTimerError : TON; (*Timer to check if there are no new shuttles passing the triggerpoint*)
		fbTimerAutoRestart : TON; (*Timer to wait before the auto restart flag is reset after restarting*)
	END_STRUCT;
	TshInternalRecoveryType : 	STRUCT  (*Internal recovery datatype*)
		AutoRestartActive : BOOL; (*Automatic restart of the recovery active, as no recovery is needed (Needed for error reactions)*)
		StartRecoveryOld : BOOL; (*Save the state of the input "StartRecovery" in order to wait for a rising edge*)
		RecoveryNeeded : BOOL; (*Internal RecoveryNeeded flag*)
		RecoveryPossible : BOOL; (*Internal RecoveryPossible flag*)
		ShuttleResetDone : BOOL; (*Flag indicating shuttle reset was executed during recovery*)
		State : TshInternalRecoveryStateEnum; (*Recovery state*)
		fbSecGetShuttle : MC_BR_SecGetShuttle_AcpTrak; (*Function block to read out all shuttle references on the sector*)
		fbReset : MC_Reset; (*Function block to reset a shuttle in error stop*)
		fbReadStatus : MC_ReadStatus; (*Function block to read the status of a shuttle*)
		fbRoutedMoveAbs : MC_BR_RoutedMoveAbs_AcpTrak; (*Function block to move a shuttle to an absolute position*)
		fbAsmDeleteShuttle : MC_BR_AsmDeleteShuttle_AcpTrak; (*Function block to delete a shuttle*)
		fbSecStop : MC_BR_SecStop_AcpTrak; (*Function block to stop all shuttles on a sector with a specified deceleration*)
		fbTimer : TON; (*Function block to check, if a shuttle is in position for a certain time*)
		fbErrorCheckTimer : TON; (*Function block to check, if a error is present after a certain time*)
	END_STRUCT;
	TshInternalRecoveryStateEnum : 
		( (*Recovery state enumeration*)
		tshRECOVERY_IDLE := 0, (*Recovery is waiting to be started*)
		tshRECOVERY_ZONE_RECEIVE, (*Recovering on assembly receive after handover zone*)
		tshRECOVERY_CATCHING, (*Receive is catching shuttles from Send during recovery*)
		tshRECOVERY_ZONE_HANDOVER, (*Recovering the handover zone*)
		tshRECOVERY_ZONE_SEND, (*Recovering on assembly send before handover zone*)
		tshRECOVERY_DONE (*Recovering done successfully*)
		);
	TshInternalRecoverySequenceType : 	STRUCT  (*Internal recovery sequence datatype*)
		SequenceStep : USINT; (*Current sequence step*)
	END_STRUCT;
	TshInternalSimulationType : 	STRUCT  (*Internal simulation datatype*)
		SimAddShuttleOld : BOOL; (*Old value of the input*)
		ArSim : BOOL; (*Target system is ArSim*)
		SimOnPLC : BOOL; (*Target system is PLC with simulated Segments*)
		UsedMode : TshConfigSimulationTypeEnum; (*Mode for the according target system*)
		fbAsmGetInfo : MC_BR_AsmGetInfo_AcpTrak; (*Check if Simulation on PLC is active*)
	END_STRUCT;
	TshInternalVersionCheckType : 	STRUCT  (*Internal version check datatype*)
		TrakShHo : MoVerStruc_typ; (*Version information of TrakShHo library*)
		McAcpTrak : {REDUND_UNREPLICABLE} MoVerStruc_typ; (*Version information of McAcpTrak library*)
	END_STRUCT;
END_TYPE

(*Common derived Datatypes*)

TYPE
	TshString10Type :STRING[10]; (*Derived datatype of STRING with 10 characters*)
	TshString25Type :STRING[25]; (*Derived datatype of STRING with 25 characters*)
	TshString32Type :STRING[32]; (*Derived datatype of STRING with 32 characters*)
	TshString255Type :STRING[255]; (*Derived datatype of STRING with 255 characters*)
END_TYPE
